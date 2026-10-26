const {test} = require('node:test');
const assert = require('node:assert/strict');
const {randomBytes, randomUUID, createHmac} = require('node:crypto');
const {Pool} = require('pg');
const argon2 = require('argon2');
const jwt = require('jsonwebtoken');
const Ajv = require('ajv');
const addFormats = require('ajv-formats');
const fixtures = require('../../contracts/fixtures/auth-users.json');
const contract = require('../../contracts/http/openapi.json');
const {createApp} = require('../dist/main');
const {loadAuthConfiguration, JWT_ISSUER, JWT_AUDIENCE} = require('../dist/auth');
process.env.AUTH_JWT_SECRET = randomBytes(48).toString('base64');
process.env.AUTH_TOKEN_TTL_SECONDS = '900';
const secret = process.env.AUTH_JWT_SECRET;
const ajv = new Ajv({strict:false});
addFormats(ajv);

function check(method, path, response) {
  const schema = contract.paths[path][method.toLowerCase()].responses[response.statusCode];
  assert(schema, `Undocumented ${method} ${path}: ${response.statusCode}`);
  if (response.statusCode === 204) {assert.equal(response.body, ''); return;}
  const validate = ajv.compile({...schema.content['application/json'].schema, components:contract.components});
  assert(validate(response.json()), JSON.stringify(validate.errors));
}

async function setup() {
  let app = await createApp({demo:false, environment:'production'});
  const pool = new Pool({connectionString:process.env.DATABASE_URL});
  const users = new Set();
  const limitKeys = new Set();
  const ip = `127.${[...randomBytes(3)].map(n => n % 254 + 1).join('.')}`;
  const key = (scope, value) => createHmac('sha256', secret).update(`${scope}\0${value}`).digest('hex');
  const call = async(method, path, payload, token, extra={}) => {
    limitKeys.add(key('register:ip', ip));
    limitKeys.add(key('login:ip', ip));
    if (typeof payload?.email === 'string') limitKeys.add(key('login:email', payload.email.toLowerCase()));
    const response = await app.getHttpAdapter().getInstance().inject({
      method, url:path, remoteAddress:ip, headers:{...(token ? {authorization:`Bearer ${token}`} : {}), ...extra},
      ...(payload !== undefined ? {payload} : {}),
    });
    if (path.startsWith('/v1/auth/')) check(method, path, response);
    if (path === '/v1/auth/register' && response.statusCode === 201) users.add(response.json().user.id);
    return response;
  };
  return {
    pool, call, key, ip,
    restart: async() => {await app.close(); app = await createApp({demo:false, environment:'production'});},
    close: async() => {
      try {
        await pool.query('DELETE FROM users WHERE id=ANY($1::uuid[])', [[...users]]);
        await pool.query('DELETE FROM auth_rate_limits WHERE key=ANY($1::text[])', [[...limitKeys]]);
      } finally {await pool.end(); await app.close();}
    },
  };
}

const registration = (index=0) => ({...fixtures.users[index],
  email:`${randomUUID()}-${fixtures.users[index].email}`, password:randomBytes(24).toString('base64')});
const dateFromToday = days => {
  const value = new Date();
  value.setUTCDate(value.getUTCDate() + days);
  return value.toISOString().slice(0,10);
};

test('auth configuration fails closed for absent/short secret, invalid TTL and production demo', async() => {
  for (const env of [{}, {AUTH_JWT_SECRET:'short'}, {AUTH_JWT_SECRET:secret, AUTH_TOKEN_TTL_SECONDS:'0'},
    {AUTH_JWT_SECRET:secret, AUTH_TOKEN_TTL_SECONDS:'1h'}, {AUTH_JWT_SECRET:secret, AUTH_TOKEN_TTL_SECONDS:'86401'}]) {
    assert.throws(() => loadAuthConfiguration(env));
  }
  assert.equal(loadAuthConfiguration({AUTH_JWT_SECRET:secret}).ttlSeconds, 900);
  await assert.rejects(createApp({demo:true, environment:'production'}), /demo/i);
  await assert.rejects(createApp({demo:true, environment:'staging'}), /demo/i);
});

test('register/login/me/logout persist, use Argon2id and isolate sessions', async() => {
  const t = await setup();
  try {
    const alice = registration();
    const bob = {...registration(1), password:alice.password};
    const registered = await t.call('POST', '/v1/auth/register', alice);
    assert.equal(registered.statusCode, 201);
    assert.equal(registered.headers['cache-control'], 'no-store');
    const a = registered.json();
    const b = (await t.call('POST', '/v1/auth/register', bob)).json();
    assert.equal(a.tokenType, 'Bearer');
    assert.equal(a.expiresIn, 900);
    const hashes = await t.pool.query('SELECT password_hash FROM users WHERE id=ANY($1::uuid[])', [[a.user.id,b.user.id]]);
    assert(hashes.rows.every(r => r.password_hash.startsWith('$argon2id$')));
    assert.notEqual(hashes.rows[0].password_hash, hashes.rows[1].password_hash);
    assert(await argon2.verify(hashes.rows[0].password_hash, alice.password));
    assert(!JSON.stringify(a).includes('password'));
    const decoded = jwt.verify(a.accessToken, secret, {algorithms:['HS256'], issuer:JWT_ISSUER, audience:JWT_AUDIENCE});
    assert.equal(decoded.sub, a.user.id);
    assert.equal(decoded.exp - decoded.iat, 900);

    assert.equal((await t.call('POST', '/v1/auth/register', {...alice, email:alice.email.toUpperCase()})).statusCode, 409);
    const login = await t.call('POST', '/v1/auth/login', {email:alice.email.toUpperCase(),password:alice.password});
    assert.equal(login.statusCode, 200);
    const second = login.json().accessToken;
    await t.restart();
    assert.deepEqual((await t.call('GET', '/v1/auth/me', undefined, a.accessToken)).json(), a.user);
    assert.deepEqual((await t.call('GET', '/v1/auth/me', undefined, b.accessToken)).json(), b.user);
    const aliceAccounts = (await t.call('GET', '/v1/me/accounts', undefined, a.accessToken)).json().items;
    const bobAccounts = (await t.call('GET', '/v1/me/accounts', undefined, b.accessToken)).json().items;
    assert.equal(aliceAccounts.length, 1);
    assert.equal(aliceAccounts[0].type, 'PERSONAL');
    assert.equal(aliceAccounts[0].accessRole, 'OWNER');
    assert.equal(bobAccounts.length, 1);
    assert.notEqual(aliceAccounts[0].id, bobAccounts[0].id);
    assert.equal((await t.pool.query(`SELECT count(*)::int AS count FROM accounts
      WHERE owner_user_id=$1 AND data->>'type'='PERSONAL'`,[a.user.id])).rows[0].count, 1);
    assert.equal((await t.call('GET', '/v1/purchase-requests?accountId=personal-buyer', undefined, a.accessToken)).statusCode, 404);
    assert.equal((await t.call('GET', '/v1/purchase-requests/private-other-user', undefined, b.accessToken)).statusCode, 404);
    assert.equal((await t.call('POST', '/v1/trips', {}, a.accessToken)).statusCode, 400);

    assert.equal((await t.call('POST', '/v1/auth/logout', undefined, a.accessToken)).statusCode, 204);
    await t.restart();
    assert.equal((await t.call('GET', '/v1/auth/me', undefined, a.accessToken)).statusCode, 401);
    assert.equal((await t.call('GET', '/v1/me/accounts', undefined, a.accessToken)).statusCode, 401);
    assert.equal((await t.call('GET', '/v1/trips', undefined, a.accessToken)).statusCode, 401);
    assert.equal((await t.call('GET', '/v1/purchase-requests?accountId=personal-buyer', undefined, a.accessToken)).statusCode, 401);
    assert.equal((await t.call('POST', '/v1/purchase-requests', {}, a.accessToken)).statusCode, 401);
    assert.equal((await t.call('POST', '/v1/auth/logout', undefined, a.accessToken)).statusCode, 401);
    assert.equal((await t.call('GET', '/v1/auth/me', undefined, second)).statusCode, 200);
    assert.equal((await t.call('GET', '/v1/auth/me', undefined, b.accessToken)).statusCode, 200);
  } finally {await t.close();}
});

test('real PF/PJ ownership isolates users and one user can buy and travel', async() => {
  const t = await setup();
  const requestIds=[];
  let tripId;
  try {
    const aliceInput=registration();
    const bobInput=registration(1);
    const charlieInput=registration();
    const alice=(await t.call('POST','/v1/auth/register',aliceInput)).json();
    const bob=(await t.call('POST','/v1/auth/register',bobInput)).json();
    const charlie=(await t.call('POST','/v1/auth/register',charlieInput)).json();
    const alicePf=(await t.call('GET','/v1/me/accounts',undefined,alice.accessToken)).json().items[0];
    const bobPf=(await t.call('GET','/v1/me/accounts',undefined,bob.accessToken)).json().items[0];

    const organization=await t.call('POST','/v1/me/accounts/organizations',{displayName:'Empresa Sintética Alfa'},alice.accessToken);
    check('POST','/v1/me/accounts/organizations',organization);
    assert.equal(organization.statusCode,201);
    assert.equal(organization.json().accessRole,'OWNER');
    const organizationId=organization.json().id;

    const unauthorized=await t.call('POST',`/v1/me/accounts/${organizationId}/members`,{email:charlieInput.email},bob.accessToken);
    check('POST','/v1/me/accounts/{accountId}/members',unauthorized);
    assert.equal(unauthorized.statusCode,404);
    const invite=await t.call('POST',`/v1/me/accounts/${organizationId}/members`,{email:bobInput.email.toUpperCase()},alice.accessToken);
    check('POST','/v1/me/accounts/{accountId}/members',invite);
    assert.equal(invite.statusCode,204);

    const aliceAccounts=(await t.call('GET','/v1/me/accounts',undefined,alice.accessToken)).json().items;
    const bobAccounts=(await t.call('GET','/v1/me/accounts',undefined,bob.accessToken)).json().items;
    const charlieAccounts=(await t.call('GET','/v1/me/accounts',undefined,charlie.accessToken)).json().items;
    assert.deepEqual(aliceAccounts.map(a=>a.id).sort(),[alicePf.id,organizationId].sort());
    assert.deepEqual(bobAccounts.map(a=>a.id).sort(),[bobPf.id,organizationId].sort());
    assert.equal(bobAccounts.find(a=>a.id===organizationId).accessRole,'MEMBER');
    assert.equal(charlieAccounts.length,1);
    assert(!charlieAccounts.some(a=>a.id===organizationId || a.id===alicePf.id || a.id===bobPf.id));

    const tripInput={origin:'Recife',destination:'Lisboa',departureDate:'2026-12-20',timeZone:'America/Recife',availableWeightGrams:3000,pricePerKg:{amount:'100',currency:'USD'}};
    const trip=await t.call('POST','/v1/trips',tripInput,alice.accessToken,{'idempotency-key':`real-trip-${randomUUID()}`});
    assert.equal(trip.statusCode,201,trip.body);tripId=trip.json().id;
    assert.equal(trip.json().travelerName,alice.user.displayName);
    assert.equal(trip.json().isDemo,false);

    const makeRequest=accountId=>({accountId,tripId,product:{description:'Produto sintético',price:{amount:'10',currency:'USD'},estimatedWeightGrams:100}});
    const ownRequest=await t.call('POST','/v1/purchase-requests',makeRequest(alicePf.id),alice.accessToken,{'idempotency-key':`real-${randomUUID()}`});
    assert.equal(ownRequest.statusCode,201,ownRequest.body);requestIds.push(ownRequest.json().id);
    const companyRequest=await t.call('POST','/v1/purchase-requests',makeRequest(organizationId),bob.accessToken,{'idempotency-key':`real-${randomUUID()}`});
    assert.equal(companyRequest.statusCode,201,companyRequest.body);requestIds.push(companyRequest.json().id);
    assert.equal((await t.call('POST','/v1/purchase-requests',makeRequest(organizationId),charlie.accessToken,{'idempotency-key':`real-${randomUUID()}`})).statusCode,404);
    assert.equal((await t.call('GET',`/v1/purchase-requests/${companyRequest.json().id}`,undefined,alice.accessToken)).statusCode,200);
    assert.equal((await t.call('GET',`/v1/purchase-requests/${companyRequest.json().id}`,undefined,charlie.accessToken)).statusCode,404);
  } finally {
    if(requestIds.length) await t.pool.query('DELETE FROM purchase_requests WHERE id=ANY($1::text[])',[requestIds]);
    if(tripId) await t.pool.query('DELETE FROM trips WHERE id=$1',[tripId]);
    await t.close();
  }
});

test('real trip lifecycle validates, isolates, edits and cancels without deleting requests', async() => {
  const t=await setup();
  const tripIds=[]; const requestIds=[];
  try {
    const aliceInput=registration(); const bobInput=registration(1);
    const alice=(await t.call('POST','/v1/auth/register',aliceInput)).json();
    const bob=(await t.call('POST','/v1/auth/register',bobInput)).json();
    const bobPf=(await t.call('GET','/v1/me/accounts',undefined,bob.accessToken)).json().items[0];
    const valid={origin:'Recife',destination:'Lisboa',departureDate:dateFromToday(30),timeZone:'UTC',availableWeightGrams:3000,pricePerKg:{amount:'100',currency:'USD'}};
    const key=`trip-${randomUUID()}`;

    const [created,repeated]=await Promise.all([
      t.call('POST','/v1/trips',valid,alice.accessToken,{'idempotency-key':key}),
      t.call('POST','/v1/trips',valid,alice.accessToken,{'idempotency-key':key}),
    ]);
    assert.equal(created.statusCode,201,created.body);tripIds.push(created.json().id);
    assert.equal(created.json().status,'AVAILABLE');
    assert.equal(repeated.statusCode,201);assert.equal(repeated.json().id,created.json().id);
    assert.equal((await t.call('POST','/v1/trips',{...valid,destination:'Porto'},alice.accessToken,{'idempotency-key':key})).statusCode,409);

    for(const invalid of [
      {...valid,departureDate:dateFromToday(-1)},
      {...valid,destination:'recife'},
      {...valid,availableWeightGrams:0},
      {...valid,pricePerKg:{amount:'0',currency:'USD'}},
    ]) assert.equal((await t.call('POST','/v1/trips',invalid,alice.accessToken,{'idempotency-key':`invalid-${randomUUID()}`})).statusCode,400);
    assert.equal((await t.call('POST','/v1/trips',valid,alice.accessToken)).statusCode,400);

    const available=await t.call('GET','/v1/trips',undefined,bob.accessToken);
    assert(available.json().items.some(trip=>trip.id===created.json().id));
    const own=await t.call('GET','/v1/me/trips',undefined,alice.accessToken);
    check('GET','/v1/me/trips',own);assert(own.json().items.some(trip=>trip.id===created.json().id));
    assert(!(await t.call('GET','/v1/me/trips',undefined,bob.accessToken)).json().items.some(trip=>trip.id===created.json().id));
    const detail=await t.call('GET',`/v1/trips/${created.json().id}`,undefined,bob.accessToken);
    check('GET','/v1/trips/{id}',detail);assert.equal(detail.statusCode,200);

    const editedInput={...valid,destination:'Porto',availableWeightGrams:2500};
    const forbiddenEdit=await t.call('PATCH',`/v1/trips/${created.json().id}`,editedInput,bob.accessToken);
    check('PATCH','/v1/trips/{id}',forbiddenEdit);assert.equal(forbiddenEdit.statusCode,404);
    const edited=await t.call('PATCH',`/v1/trips/${created.json().id}`,editedInput,alice.accessToken);
    check('PATCH','/v1/trips/{id}',edited);assert.equal(edited.statusCode,200);assert.equal(edited.json().destination,'Porto');

    const requestPayload={accountId:bobPf.id,tripId:created.json().id,product:{description:'Produto sintético',price:{amount:'10',currency:'USD'},estimatedWeightGrams:100}};
    const request=await t.call('POST','/v1/purchase-requests',requestPayload,bob.accessToken,{'idempotency-key':`request-${randomUUID()}`});
    assert.equal(request.statusCode,201,request.body);requestIds.push(request.json().id);
    assert.equal((await t.call('PATCH',`/v1/trips/${created.json().id}`,valid,alice.accessToken)).statusCode,409);

    assert.equal((await t.call('POST',`/v1/trips/${created.json().id}/cancel`,undefined,bob.accessToken)).statusCode,404);
    const cancelled=await t.call('POST',`/v1/trips/${created.json().id}/cancel`,undefined,alice.accessToken);
    check('POST','/v1/trips/{id}/cancel',cancelled);assert.equal(cancelled.statusCode,200);assert.equal(cancelled.json().status,'CANCELLED');
    assert.equal((await t.call('POST',`/v1/trips/${created.json().id}/cancel`,undefined,alice.accessToken)).json().status,'CANCELLED');
    assert(!(await t.call('GET','/v1/trips',undefined,bob.accessToken)).json().items.some(trip=>trip.id===created.json().id));
    assert.equal((await t.call('GET',`/v1/trips/${created.json().id}`,undefined,bob.accessToken)).statusCode,404);
    assert.equal((await t.call('GET',`/v1/trips/${created.json().id}`,undefined,alice.accessToken)).json().status,'CANCELLED');
    assert.equal((await t.call('POST','/v1/purchase-requests',requestPayload,bob.accessToken,{'idempotency-key':`request-${randomUUID()}`})).statusCode,409);
    assert.equal((await t.pool.query('SELECT count(*)::int AS count FROM purchase_requests WHERE id=$1',[request.json().id])).rows[0].count,1);

    const expiring=await t.call('POST','/v1/trips',{...valid,destination:'Madri'},alice.accessToken,{'idempotency-key':`trip-${randomUUID()}`});
    assert.equal(expiring.statusCode,201);tripIds.push(expiring.json().id);
    await t.pool.query("UPDATE trips SET data=jsonb_set(data,'{departureDate}',to_jsonb($2::text)) WHERE id=$1",[expiring.json().id,dateFromToday(-1)]);
    const expired=(await t.call('GET','/v1/me/trips',undefined,alice.accessToken)).json().items.find(trip=>trip.id===expiring.json().id);
    assert.equal(expired.status,'EXPIRED');
    assert.equal((await t.call('PATCH',`/v1/trips/${expiring.json().id}`,valid,alice.accessToken)).statusCode,409);
    assert.equal((await t.call('POST',`/v1/trips/${expiring.json().id}/cancel`,undefined,alice.accessToken)).statusCode,409);
  } finally {
    if(requestIds.length) await t.pool.query('DELETE FROM purchase_requests WHERE id=ANY($1::text[])',[requestIds]);
    if(tripIds.length) await t.pool.query('DELETE FROM trips WHERE id=ANY($1::text[])',[tripIds]);
    await t.close();
  }
});

test('traveler decisions are authorized, transactional, idempotent and visible to buyer', async() => {
  const t=await setup();
  const tripIds=[]; const requestIds=[];
  try {
    const traveler=(await t.call('POST','/v1/auth/register',registration())).json();
    const buyer=(await t.call('POST','/v1/auth/register',registration(1))).json();
    const outsider=(await t.call('POST','/v1/auth/register',registration())).json();
    const buyerPf=(await t.call('GET','/v1/me/accounts',undefined,buyer.accessToken)).json().items[0];
    const makeTrip=async(destination)=>{
      const result=await t.call('POST','/v1/trips',{origin:'Recife',destination,departureDate:dateFromToday(30),timeZone:'UTC',availableWeightGrams:3000,pricePerKg:{amount:'100',currency:'USD'}},traveler.accessToken,{'idempotency-key':`trip-${randomUUID()}`});
      assert.equal(result.statusCode,201,result.body);tripIds.push(result.json().id);return result.json();
    };
    const makeRequest=async(trip,suffix)=>{
      const result=await t.call('POST','/v1/purchase-requests',{accountId:buyerPf.id,tripId:trip.id,product:{description:`Produto ${suffix}`,price:{amount:'10',currency:'USD'},estimatedWeightGrams:100}},buyer.accessToken,{'idempotency-key':`request-${randomUUID()}`});
      assert.equal(result.statusCode,201,result.body);assert.equal(result.json().status,'PENDING');requestIds.push(result.json().id);return result.json();
    };

    const trip=await makeTrip('Lisboa');
    const acceptedRequest=await makeRequest(trip,'aceite');
    const incoming=await t.call('GET','/v1/me/incoming-requests',undefined,traveler.accessToken);
    check('GET','/v1/me/incoming-requests',incoming);
    assert(incoming.json().items.some(item=>item.id===acceptedRequest.id));
    assert.equal((await t.call('GET',`/v1/purchase-requests/${acceptedRequest.id}`,undefined,traveler.accessToken)).statusCode,200);
    assert.equal((await t.call('GET',`/v1/purchase-requests/${acceptedRequest.id}`,undefined,buyer.accessToken)).statusCode,200);
    assert.equal((await t.call('GET',`/v1/purchase-requests/${acceptedRequest.id}`,undefined,outsider.accessToken)).statusCode,404);
    assert.equal((await t.call('POST',`/v1/purchase-requests/${acceptedRequest.id}/accept`,undefined,outsider.accessToken)).statusCode,404);

    const accepted=await t.call('POST',`/v1/purchase-requests/${acceptedRequest.id}/accept`,undefined,traveler.accessToken);
    check('POST','/v1/purchase-requests/{id}/accept',accepted);
    assert.equal(accepted.statusCode,200);assert.equal(accepted.json().status,'ACCEPTED');
    assert.equal((await t.call('POST',`/v1/purchase-requests/${acceptedRequest.id}/accept`,undefined,traveler.accessToken)).json().status,'ACCEPTED');
    const conflict=await t.call('POST',`/v1/purchase-requests/${acceptedRequest.id}/reject`,undefined,traveler.accessToken);
    assert.equal(conflict.statusCode,409);assert.equal(conflict.json().code,'DECISION_CONFLICT');
    assert.equal((await t.pool.query('SELECT count(*)::int AS count FROM purchase_request_events WHERE request_id=$1',[acceptedRequest.id])).rows[0].count,1);

    const rejectedRequest=await makeRequest(trip,'rejeição');
    const rejected=await t.call('POST',`/v1/purchase-requests/${rejectedRequest.id}/reject`,undefined,traveler.accessToken);
    assert.equal(rejected.statusCode,200);assert.equal(rejected.json().status,'REJECTED');

    const racedRequest=await makeRequest(trip,'corrida');
    const raced=await Promise.all([
      t.call('POST',`/v1/purchase-requests/${racedRequest.id}/accept`,undefined,traveler.accessToken),
      t.call('POST',`/v1/purchase-requests/${racedRequest.id}/reject`,undefined,traveler.accessToken),
    ]);
    assert.deepEqual(raced.map(result=>result.statusCode).sort(),[200,409]);
    assert.equal((await t.pool.query('SELECT count(*)::int AS count FROM purchase_request_events WHERE request_id=$1',[racedRequest.id])).rows[0].count,1);

    const cancelledTrip=await makeTrip('Porto');
    const cancelledRequest=await makeRequest(cancelledTrip,'cancelado');
    assert.equal((await t.call('POST',`/v1/trips/${cancelledTrip.id}/cancel`,undefined,traveler.accessToken)).statusCode,200);
    assert.equal((await t.call('POST',`/v1/purchase-requests/${cancelledRequest.id}/accept`,undefined,traveler.accessToken)).statusCode,409);
    const expiredTrip=await makeTrip('Madri');
    const expiredRequest=await makeRequest(expiredTrip,'expirado');
    await t.pool.query("UPDATE trips SET data=jsonb_set(data,'{departureDate}',to_jsonb($2::text)) WHERE id=$1",[expiredTrip.id,dateFromToday(-1)]);
    assert.equal((await t.call('POST',`/v1/purchase-requests/${expiredRequest.id}/accept`,undefined,traveler.accessToken)).statusCode,409);

    const sent=(await t.call('GET',`/v1/purchase-requests?accountId=${buyerPf.id}`,undefined,buyer.accessToken)).json().items;
    assert.equal(sent.find(item=>item.id===acceptedRequest.id).status,'ACCEPTED');
    assert.equal(sent.find(item=>item.id===rejectedRequest.id).status,'REJECTED');
  } finally {
    if(requestIds.length) await t.pool.query('DELETE FROM purchase_requests WHERE id=ANY($1::text[])',[requestIds]);
    if(tripIds.length) await t.pool.query('DELETE FROM trips WHERE id=ANY($1::text[])',[tripIds]);
    await t.close();
  }
});

test('capacity reservations serialize accepts, cancellation and rollback atomically', async() => {
  const t=await setup();
  const tripIds=[]; const requestIds=[];
  try {
    const traveler=(await t.call('POST','/v1/auth/register',registration())).json();
    const buyer=(await t.call('POST','/v1/auth/register',registration(1))).json();
    const account=(await t.call('GET','/v1/me/accounts',undefined,buyer.accessToken)).json().items[0];
    const makeTrip=async(destination)=>{
      const response=await t.call('POST','/v1/trips',{origin:'Recife',destination,departureDate:dateFromToday(30),timeZone:'UTC',availableWeightGrams:1000,pricePerKg:{amount:'100',currency:'USD'}},traveler.accessToken,{'idempotency-key':`capacity-trip-${randomUUID()}`});
      assert.equal(response.statusCode,201,response.body);tripIds.push(response.json().id);
      assert.deepEqual([response.json().totalWeightGrams,response.json().reservedWeightGrams,response.json().availableWeightGrams],[1000,0,1000]);
      return response.json();
    };
    const makeRequest=async(trip,weight,label)=>{
      const response=await t.call('POST','/v1/purchase-requests',{accountId:account.id,tripId:trip.id,product:{description:label,price:{amount:'10',currency:'USD'},estimatedWeightGrams:weight}},buyer.accessToken,{'idempotency-key':`capacity-request-${randomUUID()}`});
      assert.equal(response.statusCode,201,response.body);requestIds.push(response.json().id);return response.json();
    };
    const capacity=async tripId=>(await t.pool.query('SELECT total_capacity_grams AS total,reserved_capacity_grams AS reserved FROM trips WHERE id=$1',[tripId])).rows[0];

    const sequential=await makeTrip('Lisboa');
    const first=await makeRequest(sequential,600,'Reserva válida');
    const insufficient=await makeRequest(sequential,600,'Sem capacidade restante');
    const accepted=await t.call('POST',`/v1/purchase-requests/${first.id}/accept`,undefined,traveler.accessToken);
    assert.equal(accepted.statusCode,200);assert.deepEqual(accepted.json().tripCapacity,{totalWeightGrams:1000,reservedWeightGrams:600,availableWeightGrams:400});
    assert.deepEqual(await capacity(sequential.id),{total:1000,reserved:600});
    const tripResponse=await t.call('GET',`/v1/trips/${sequential.id}`,undefined,buyer.accessToken);
    check('GET','/v1/trips/{id}',tripResponse);const tripAfterAccept=tripResponse.json();
    assert.deepEqual([tripAfterAccept.totalWeightGrams,tripAfterAccept.reservedWeightGrams,tripAfterAccept.availableWeightGrams],[1000,600,400]);
    const repeated=await t.call('POST',`/v1/purchase-requests/${first.id}/accept`,undefined,traveler.accessToken);
    assert.equal(repeated.statusCode,200);assert.equal((await capacity(sequential.id)).reserved,600);
    const noCapacity=await t.call('POST',`/v1/purchase-requests/${insufficient.id}/accept`,undefined,traveler.accessToken);
    assert.equal(noCapacity.statusCode,422);assert.equal(noCapacity.json().code,'CAPACITY_EXCEEDED');
    assert.equal((await t.call('GET',`/v1/purchase-requests/${insufficient.id}`,undefined,buyer.accessToken)).json().status,'PENDING');
    const rejected=await t.call('POST',`/v1/purchase-requests/${insufficient.id}/reject`,undefined,traveler.accessToken);
    assert.equal(rejected.statusCode,200);assert.equal((await capacity(sequential.id)).reserved,600);

    const racedTrip=await makeTrip('Porto');
    const raceA=await makeRequest(racedTrip,600,'Concorrente A');
    const raceB=await makeRequest(racedTrip,600,'Concorrente B');
    const raced=await Promise.all([
      t.call('POST',`/v1/purchase-requests/${raceA.id}/accept`,undefined,traveler.accessToken),
      t.call('POST',`/v1/purchase-requests/${raceB.id}/accept`,undefined,traveler.accessToken),
    ]);
    assert.deepEqual(raced.map(result=>result.statusCode).sort(),[200,422]);
    assert.equal((await capacity(racedTrip.id)).reserved,600);
    const acceptedWeight=(await t.pool.query(`SELECT coalesce(sum((data#>>'{product,estimatedWeightGrams}')::int),0)::int AS weight
      FROM purchase_requests WHERE trip_id=$1 AND status='ACCEPTED'`,[racedTrip.id])).rows[0].weight;
    assert.equal(acceptedWeight,600);

    const cancellationTrip=await makeTrip('Madri');
    const cancellationRequest=await makeRequest(cancellationTrip,600,'Aceite versus cancelamento');
    const cancellationRace=await Promise.all([
      t.call('POST',`/v1/purchase-requests/${cancellationRequest.id}/accept`,undefined,traveler.accessToken),
      t.call('POST',`/v1/trips/${cancellationTrip.id}/cancel`,undefined,traveler.accessToken),
    ]);
    assert.equal(cancellationRace[1].statusCode,200);
    assert([200,409].includes(cancellationRace[0].statusCode));
    const cancellationState=(await t.pool.query('SELECT status,reserved_capacity_grams AS reserved FROM trips WHERE id=$1',[cancellationTrip.id])).rows[0];
    const requestState=(await t.pool.query('SELECT status FROM purchase_requests WHERE id=$1',[cancellationRequest.id])).rows[0].status;
    assert.equal(cancellationState.status,'CANCELLED');
    assert.equal(cancellationState.reserved,requestState==='ACCEPTED'?600:0);

    const rollbackTrip=await makeTrip('Roma');
    const rollbackRequest=await makeRequest(rollbackTrip,400,'Rollback integral');
    const functionName=`fail_event_${randomUUID().replaceAll('-','')}`;
    const triggerName=`fail_event_trigger_${randomUUID().replaceAll('-','')}`;
    await t.pool.query(`CREATE FUNCTION ${functionName}() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'forced audit failure'; END $$`);
    await t.pool.query(`CREATE TRIGGER ${triggerName} BEFORE INSERT ON purchase_request_events FOR EACH ROW WHEN (NEW.request_id='${rollbackRequest.id}') EXECUTE FUNCTION ${functionName}()`);
    try {
      assert.equal((await t.call('POST',`/v1/purchase-requests/${rollbackRequest.id}/accept`,undefined,traveler.accessToken)).statusCode,500);
    } finally {
      await t.pool.query(`DROP TRIGGER ${triggerName} ON purchase_request_events`);
      await t.pool.query(`DROP FUNCTION ${functionName}()`);
    }
    assert.equal((await capacity(rollbackTrip.id)).reserved,0);
    assert.equal((await t.pool.query('SELECT status FROM purchase_requests WHERE id=$1',[rollbackRequest.id])).rows[0].status,'PENDING');
    assert.equal((await t.pool.query('SELECT count(*)::int AS count FROM purchase_request_events WHERE request_id=$1',[rollbackRequest.id])).rows[0].count,0);
  } finally {
    if(requestIds.length) await t.pool.query('DELETE FROM purchase_requests WHERE id=ANY($1::text[])',[requestIds]);
    if(tripIds.length) await t.pool.query('DELETE FROM trips WHERE id=ANY($1::text[])',[tripIds]);
    await t.close();
  }
});

test('invalid credentials, malformed input and concurrent duplicate registration', async() => {
  const t = await setup();
  try {
    const user = registration();
    for (const invalid of [{...user,email:'invalid'}, {...user,password:'short'}, {...user,displayName:'   '},
      {...user, password:'a'.repeat(129)}, {...user, role:'admin'}, {...user, password:123}]) {
      assert.equal((await t.call('POST', '/v1/auth/register', invalid)).statusCode, 400);
    }
    const concurrent = await Promise.all([t.call('POST','/v1/auth/register',user), t.call('POST','/v1/auth/register',user)]);
    assert.deepEqual(concurrent.map(r=>r.statusCode).sort(), [201,409]);
    assert.equal((await t.pool.query('SELECT count(*)::int AS count FROM users WHERE email=$1',[user.email])).rows[0].count, 1);
    assert.equal((await t.pool.query(`SELECT count(*)::int AS count FROM accounts a JOIN users u ON u.id=a.owner_user_id
      WHERE u.email=$1 AND a.data->>'type'='PERSONAL'`,[user.email])).rows[0].count, 1);
    const wrong = await t.call('POST','/v1/auth/login',{email:user.email,password:'incorrect-password'});
    const unknown = await t.call('POST','/v1/auth/login',{email:registration().email,password:'incorrect-password'});
    assert.equal(wrong.statusCode,401);
    assert.equal(unknown.statusCode,401);
    assert.equal(wrong.json().message,unknown.json().message);
    assert.equal(wrong.json().code,unknown.json().code);
    assert.equal(wrong.json().accessToken,undefined);
    assert.equal((await t.call('POST','/v1/auth/login',{email:user.email,password:null})).statusCode,400);
  } finally {await t.close();}
});

test('missing, tampered, expired, wrong-algorithm and demo tokens cannot authorize production', async() => {
  const t = await setup();
  try {
    const registered = (await t.call('POST','/v1/auth/register',registration())).json();
    const payload = jwt.decode(registered.accessToken);
    const sign = changes => jwt.sign({...payload,...changes},secret,{algorithm:'HS256'});
    const parts = registered.accessToken.split('.');
    parts[2] = (parts[2][0] === 'a' ? 'b' : 'a') + parts[2].slice(1);
    const noExpiry = {...payload}; delete noExpiry.exp;
    const invalidTokens = [undefined, 'dev:buyer', 'dev:traveler', 'invalid', parts.join('.'),
      sign({exp:Math.floor(Date.now()/1000)-1}), sign({aud:'other'}), sign({iss:'other'}),
      sign({sub:randomUUID()}), sign({jti:randomUUID()}), jwt.sign(noExpiry,secret),
      jwt.sign(payload,secret,{algorithm:'HS384'}), jwt.sign(payload,null,{algorithm:'none'})];
    for (const token of invalidTokens) {
      assert.equal((await t.call('GET','/v1/auth/me',undefined,token)).statusCode,401);
      assert.equal((await t.call('GET','/v1/trips',undefined,token)).statusCode,401);
      assert.equal((await t.call('GET','/v1/me/accounts',undefined,token)).statusCode,401);
    }
    assert.equal((await t.call('POST','/v1/purchase-requests',{},undefined)).statusCode,401);
    await t.pool.query("UPDATE auth_sessions SET created_at=now()-interval '1 day', expires_at=now()-interval '1 second' WHERE id=$1",[payload.jti]);
    assert.equal((await t.call('GET','/v1/auth/me',undefined,registered.accessToken)).statusCode,401);
  } finally {await t.close();}
});

test('login rate limits survive restart, expire and ignore forged forwarding headers', async() => {
  const t = await setup();
  try {
    const user = registration();
    await t.call('POST','/v1/auth/register',user);
    for (let i=0;i<10;i++) {
      assert.equal((await t.call('POST','/v1/auth/login',{email:user.email,password:'wrong-password'},undefined,{'x-forwarded-for':`192.0.2.${i}`})).statusCode,401);
    }
    await t.restart();
    assert.equal((await t.call('POST','/v1/auth/login',user)).statusCode,400); // unexpected displayName
    assert.equal((await t.call('POST','/v1/auth/login',{email:user.email,password:user.password})).statusCode,429);
    await t.pool.query("UPDATE auth_rate_limits SET window_started_at=now()-interval '16 minutes' WHERE key=$1",[t.key('login:email',user.email)]);
    assert.equal((await t.call('POST','/v1/auth/login',{email:user.email,password:user.password})).statusCode,200);
    for (let i=0;i<17;i++) await t.call('POST','/v1/auth/login',{},undefined,{'x-forwarded-for':`192.0.2.${i}`});
    assert.equal((await t.call('POST','/v1/auth/login',{},undefined,{'x-forwarded-for':'192.0.2.200'})).statusCode,429);
  } finally {await t.close();}
});
