const {test}=require('node:test');
process.env.AUTH_JWT_SECRET ??= require('node:crypto').randomBytes(48).toString('base64');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {createApp}=require('../dist/main.js');
const Ajv=require('ajv');
const ajv=new Ajv({strict:false});require('ajv-formats')(ajv);
const contractPath = process.env.CONTRACT_PATH || [
 path.resolve(__dirname, '../../contracts/http/openapi.json'),
 path.resolve(__dirname, '../../../contracts/http/openapi.json'),
].find(p => fs.existsSync(p));
const contract=require(contractPath);
ajv.addSchema({...contract,$id:'contract'});
function checkResponse(method,url,status,body) {
 const pathname=new URL(url,'http://local').pathname;
 const path=pathname.replace(/^\/v1\/purchase-requests\/[^/]+\/(accept|reject)$/,'/v1/purchase-requests/{id}/$1')
  .replace(/^\/v1\/purchase-requests\/[^/]+$/,'/v1/purchase-requests/{id}');
 const schema=contract.paths[path][method.toLowerCase()].responses[status]?.content?.['application/json']?.schema;
 assert(schema,`Undocumented status ${status}`);
 const valid=ajv.compile({...schema,components:contract.components});
 assert(valid(body),JSON.stringify(valid.errors));
}

test('PostgreSQL: PF/PJ isolation, persistence, idempotency and validation', async()=>{
 const app=await createApp({demo:true,environment:'test'});
 let closed=false;
 const requestIds=[];let publishedId;
 const server=app.getHttpAdapter().getInstance();
 const call=async(method,url,actor='buyer',payload,key)=>{
  const r=await server.inject({method,url,headers:{authorization:`Bearer dev:${actor}`,...(key?{'idempotency-key':key}:{})},...(payload?{payload}:{})});
  const body=r.json();checkResponse(method,url,r.statusCode,body);
  return {status:r.statusCode,body};
 };
 try {
 assert.deepEqual((await call('GET','/health')).body,{status:'ok'});
 const cors=await server.inject({method:'OPTIONS',url:'/v1/me/accounts',headers:{origin:'http://localhost:3000','access-control-request-method':'GET','access-control-request-headers':'authorization'}});
 assert.equal(cors.statusCode,204);assert.equal(cors.headers['access-control-allow-origin'],'http://localhost:3000');
 const malformed=await server.inject({method:'POST',url:'/v1/trips',headers:{authorization:'Bearer dev:traveler','content-type':'application/json','idempotency-key':'malformed-trip-key'},payload:'{'});
 assert.equal(malformed.statusCode,400);checkResponse('POST','/v1/trips',400,malformed.json());
 assert.equal((await call('GET','/v1/me/accounts','invalid')).status,401);
 const accounts=(await call('GET','/v1/me/accounts')).body.items;
 assert(accounts.some(a=>a.taxId==='12.ABC.345/01DE-35'));
 assert(accounts.some(a=>a.id==='company-numeric'));
 assert.equal((await call('GET','/v1/me/accounts','revoked')).body.items.length,0);
 const trip={origin:'Teste origem',destination:'Teste destino',departureDate:'2026-12-20',timeZone:'America/Sao_Paulo',availableWeightGrams:1000,pricePerKg:{amount:'100',currency:'USD'}};
 assert.equal((await call('POST','/v1/trips','buyer',trip,'trip-buyer-key')).status,403);
 const published=await call('POST','/v1/trips','traveler',trip,'trip-publish-key');
 assert.equal(published.status,201);publishedId=published.body.id;
 assert((await call('GET','/v1/trips?origin=Teste%20origem&departureDate=2026-12-20')).body.items.some(t=>t.id===published.body.id));
 assert.equal((await call('GET','/v1/trips?departureDate=2026-02-30')).status,400);
 {
  const mk=(w,n)=>({accountId:'personal-buyer',tripId:published.body.id,product:{description:'Cap '+n,price:{amount:'1',currency:'BRL'},estimatedWeightGrams:w}});
  const over=await call('POST','/v1/purchase-requests','buyer',mk(1001,'x'),'cap-over-key-1');
  assert.equal(over.status,422);assert.equal(over.body.code,'CAPACITY_EXCEEDED');
  for(let i=0;i<22;i++) {const r=await call('POST','/v1/purchase-requests','buyer',mk(1000,i),`cap-page-key-${i}-${Date.now()}`);assert.equal(r.status,201);requestIds.push(r.body.id);}
  const p1=await call('GET','/v1/purchase-requests?accountId=personal-buyer');
  assert.equal(p1.body.items.length,20);assert(p1.body.nextCursor);
  const dates=p1.body.items.map(r=>r.createdAt);assert.deepEqual(dates,[...dates].sort().reverse());
  const p2=await call('GET','/v1/purchase-requests?accountId=personal-buyer&cursor='+p1.body.nextCursor);
  assert.equal(p2.status,200);assert(!p2.body.items.some(r=>p1.body.items.some(q=>q.id===r.id)));
  assert.equal((await call('GET','/v1/purchase-requests?accountId=personal-buyer&cursor='+p1.body.nextCursor+'x')).status,400);
  assert.equal((await call('GET','/v1/purchase-requests?accountId=company-demo&cursor='+p1.body.nextCursor)).status,400);
 }
 let saved;
 for(const accountId of ['personal-buyer','company-demo','company-numeric']) {
 const payload={accountId,tripId:'trip-ny-sp',product:{description:'Produto sintético',price:{amount:'12345678901234567890',currency:'BRL'},estimatedWeightGrams:10}};
 const key=`test-${require('node:crypto').randomUUID()}`;
 const [result,concurrent]=await Promise.all([call('POST','/v1/purchase-requests','buyer',payload,key),call('POST','/v1/purchase-requests','buyer',payload,key)]);
 assert.deepEqual(result,concurrent);
 assert.equal(result.status,201,JSON.stringify(result.body)); saved=result.body;requestIds.push(saved.id);
 assert.deepEqual((await call('POST','/v1/purchase-requests','buyer',payload,key)).body,saved);
 assert.equal((await call('POST','/v1/purchase-requests','buyer',{...payload,product:{...payload.product,description:'Outro'}},key)).status,409);
 for(const actor of ['outsider','traveler','revoked']) {
 assert.equal((await call('GET',`/v1/purchase-requests/${saved.id}`,actor)).status,actor==='traveler'?200:404);
 assert.equal((await call('GET',`/v1/purchase-requests?accountId=${accountId}`,actor)).status,404);
 assert.equal((await call('POST','/v1/purchase-requests',actor,payload,key)).status,404);
 }
 assert.equal((await call('GET',`/v1/purchase-requests/${saved.id}`)).status,200);
 for(const product of [{...payload.product,estimatedWeightGrams:0},{...payload.product,price:{amount:'1.2',currency:'USD'}},{...payload.product,url:'not a url'}])
 assert.equal((await call('POST','/v1/purchase-requests','buyer',{...payload,product},key)).status,400);
 }
 await app.close();closed=true;
 const restarted=await createApp({demo:true,environment:'test'});
 try {const r=await restarted.getHttpAdapter().getInstance().inject({url:`/v1/purchase-requests/${saved.id}`,headers:{authorization:'Bearer dev:buyer'}});assert.equal(r.statusCode,200);assert.deepEqual(r.json(),saved);} finally {await restarted.close();}
 } finally {
 const {Pool}=require('pg');const cleanup=new Pool({connectionString:process.env.DATABASE_URL});
 try {await cleanup.query('DELETE FROM idempotency WHERE request_id=ANY($1::text[])',[requestIds]);await cleanup.query('DELETE FROM purchase_requests WHERE id=ANY($1::text[])',[requestIds]);if(publishedId) await cleanup.query('DELETE FROM trips WHERE id=$1',[publishedId]);} finally {await cleanup.end();if(!closed) await app.close();}
 }
});
test('demo authentication is explicit and production rejects demo configuration',async()=>{
 await assert.rejects(()=>createApp({demo:true,environment:'production'}),/demo/i);
 const app=await createApp({demo:false,environment:'production'});
 try {assert.equal((await app.getHttpAdapter().getInstance().inject({url:'/v1/me/accounts',headers:{authorization:'Bearer dev:buyer'}})).statusCode,401);} finally {await app.close();}
 const demo=await createApp({demo:true,environment:'test'});
 try {
  const server=demo.getHttpAdapter().getInstance();
  assert.equal((await server.inject({url:'/v1/me/accounts',headers:{authorization:'Bearer dev:buyer'}})).statusCode,200);
  assert.equal((await server.inject({url:'/v1/auth/me',headers:{authorization:'Bearer dev:buyer'}})).statusCode,401);
  assert.equal((await server.inject({method:'POST',url:'/v1/auth/logout',headers:{authorization:'Bearer dev:buyer'}})).statusCode,401);
 } finally {await demo.close();}
});


test('pagination accepts its cursor with long filters and rejects invalid cursors',async()=>{
 const app=await createApp({demo:true,environment:'test'});
 const server=app.getHttpAdapter().getInstance();
 const ids=[];
 const suffix=require('node:crypto').randomUUID();
 const origin=('Origem '+suffix).padEnd(180,'x');
 const destination=('Destino '+suffix).padEnd(180,'y');
 const query=new URLSearchParams({origin,destination});
 const search=cursor=>server.inject({url:'/v1/trips?'+query+(cursor===undefined?'':'&cursor='+encodeURIComponent(cursor)),headers:{authorization:'Bearer dev:buyer'}});
 try {
  for(let i=0;i<21;i++) {
   const r=await server.inject({method:'POST',url:'/v1/trips',headers:{authorization:'Bearer dev:traveler','idempotency-key':`pagination-trip-${suffix}-${i}`},payload:{origin,destination,departureDate:'2026-12-20',timeZone:'UTC',availableWeightGrams:1000,pricePerKg:{amount:'100',currency:'USD'}}});
   assert.equal(r.statusCode,201);ids.push(r.json().id);
  }
  const first=await search();assert.equal(first.statusCode,200);
  checkResponse('GET','/v1/trips',200,first.json());
  assert.equal(first.json().items.length,20);assert.equal(typeof first.json().nextCursor,'string');
  const second=await search(first.json().nextCursor);
  assert.equal(second.statusCode,200,second.body);checkResponse('GET','/v1/trips',200,second.json());
  assert.equal(second.json().items.length,1);assert.equal(second.json().nextCursor,null);
  assert.deepEqual([...first.json().items,...second.json().items].map(t=>t.id).sort(),ids.sort());
  for(const cursor of ['invalid!', 'x'.repeat(32769),Buffer.from(JSON.stringify({date:'2026-12-20',id:ids[0],filters:'wrong'})).toString('base64url')]) {
   const r=await search(cursor);assert.equal(r.statusCode,400);checkResponse('GET','/v1/trips',400,r.json());
  }
  const changed=await server.inject({url:'/v1/trips?'+new URLSearchParams({origin,destination:destination+'z',cursor:first.json().nextCursor}),headers:{authorization:'Bearer dev:buyer'}});
  assert.equal(changed.statusCode,400);
 } finally {
  const {Pool}=require('pg');const cleanup=new Pool({connectionString:process.env.DATABASE_URL});
  try {await cleanup.query('DELETE FROM trips WHERE id=ANY($1::text[])',[ids]);} finally {await cleanup.end();await app.close();}
 }
});

test('CORS explicitly allows both local origins and excludes external origins',async()=>{
 const app=await createApp({demo:true,environment:'test'});
 try {
  const server=app.getHttpAdapter().getInstance();
  for(const origin of ['http://localhost:3000','http://127.0.0.1:3000','https://external.example','http://localhost:3000.evil.example']) {
   const allowed=['http://localhost:3000','http://127.0.0.1:3000'].includes(origin);
   for(const method of ['OPTIONS','GET']) {
    const r=await server.inject({method,url:'/v1/me/accounts',headers:{origin,authorization:'Bearer dev:buyer',...(method==='OPTIONS'?{'access-control-request-method':'GET','access-control-request-headers':'authorization,content-type,idempotency-key'}:{})}});
    assert.equal(r.headers['access-control-allow-origin'],allowed?origin:undefined);
    if(allowed) assert.equal(r.statusCode,method==='OPTIONS'?204:200);
   }
  }
 } finally {await app.close();}
});
