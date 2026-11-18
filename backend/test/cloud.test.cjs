require('./disposable-database.cjs');
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {randomBytes} = require('node:crypto');
const {Pool} = require('pg');
const {createApp, loadHttpConfiguration} = require('../dist/main');
const {Database, loadDatabaseConfiguration} = require('../dist/database');
const {AuthService, loadAuthConfiguration} = require('../dist/auth');

test('cloud configuration requires verified TLS and a private schema', () => {
  const env = {DATABASE_URL:process.env.TRAGO_TEST_CLOUD_URL, DATABASE_TLS:'true', DATABASE_SCHEMA:'trago'};
  assert.deepEqual(loadDatabaseConfiguration(env, true).ssl, {rejectUnauthorized:true});
  assert.throws(() => loadDatabaseConfiguration({...env, DATABASE_TLS:'false'}, true), /TLS/);
  assert.throws(() => loadDatabaseConfiguration({...env, DATABASE_URL:env.DATABASE_URL+'?sslmode=no-verify'}, true), /DATABASE_URL/);
  assert.throws(() => loadDatabaseConfiguration({...env, DATABASE_SCHEMA:'public'}, true), /DATABASE_SCHEMA/);
  assert.throws(() => loadDatabaseConfiguration({...env, RENDER:'true', DATABASE_URL:process.env.DATABASE_URL}, true), /trago_app/);
  assert.throws(() => loadDatabaseConfiguration({...env, RENDER:'true'}, true), /explicit PostgreSQL CA/);
  const caFile = require('node:path').resolve(__dirname,'../../certs/prod-ca-2021.crt');
  const config = loadDatabaseConfiguration({...env, RENDER:'true', DATABASE_TLS_CA_FILE:caFile}, true);
  assert.match(config.ssl.ca, /^-----BEGIN CERTIFICATE-----/);
  assert.throws(() => loadDatabaseConfiguration({
    ...env, RENDER:'true', DATABASE_TLS_CA_FILE:caFile, DATABASE_TLS_CA:process.env.TRAGO_TEST_TLS_CA,
  }, true), /one PostgreSQL CA source/);
  assert.deepEqual(loadHttpConfiguration({PORT:'10000', TRUST_PROXY_HOPS:'2'}), {port:10000, trustProxyHops:2});
  assert.throws(() => loadHttpConfiguration({PORT:'65536'}), /PORT/);
  assert.throws(() => loadHttpConfiguration({TRUST_PROXY_HOPS:'true'}), /TRUST_PROXY_HOPS/);
});

test('Render startup enforces verified TLS, a restricted role and configured proxy trust', async () => {
  process.env.NODE_ENV = 'production';
  process.env.TRUST_PROXY_HOPS = '2';
  process.env.DATABASE_URL = process.env.TRAGO_TEST_CLOUD_URL;
  process.env.DATABASE_TLS = 'true';
  process.env.DATABASE_SCHEMA = 'trago';
  process.env.AUTH_JWT_SECRET = randomBytes(48).toString('base64');
  await assert.rejects(createApp(), {code:'DEPTH_ZERO_SELF_SIGNED_CERT'});
  process.env.RENDER = 'true';
  process.env.DATABASE_TLS_CA = process.env.TRAGO_TEST_TLS_CA;
  const admin = new Pool({connectionString:process.env.TRAGO_TEST_DATABASE_URL});
  try {
    await admin.query('ALTER ROLE trago_app CREATEDB');
    await assert.rejects(createApp(), /role is not restricted/);
    await admin.query('ALTER ROLE trago_app NOCREATEDB');
    await admin.query('GRANT pg_read_all_data TO trago_app');
    await assert.rejects(createApp(), /role is not restricted/);
  } finally {
    await admin.query('ALTER ROLE trago_app NOCREATEDB');
    await admin.query('REVOKE pg_read_all_data FROM trago_app');
    await admin.end();
  }
  const app = await createApp();
  try {
    const db = app.get(Database);
    const {rows:[session]} = await db.pool.query(`
      SELECT current_schema() AS schema, current_user AS role,
        (SELECT ssl FROM pg_stat_ssl WHERE pid = pg_backend_pid()) AS tls,
        (SELECT count(*)::int FROM api_migrations) AS migrations,
        (SELECT count(*)::int FROM demo_users) AS fixtures`);
    assert.deepEqual(session, {schema:'trago', role:'trago_app', tls:true, migrations:6, fixtures:0});
    const server = app.getHttpAdapter().getInstance();
    assert.equal((await server.inject({url:'/health'})).statusCode, 200);
    assert.equal((await server.inject({url:'/v1/me/accounts',headers:{authorization:'Bearer dev:buyer'}})).statusCode, 401);
    for (let attempt = 0; attempt <= 10; attempt++) {
      const response = await server.inject({method:'POST', url:'/v1/auth/register', payload:{},
        remoteAddress:'192.0.2.5',
        headers:{'x-forwarded-for':`203.0.113.${attempt+1}, 198.51.100.10, 192.0.2.4`}});
      assert.equal(response.statusCode, attempt < 10 ? 400 : 429);
    }
    const otherClient = await server.inject({method:'POST',url:'/v1/auth/register',payload:{},
      remoteAddress:'192.0.2.5', headers:{'x-forwarded-for':'198.51.100.11, 192.0.2.4'}});
    assert.equal(otherClient.statusCode, 400);
    for (let attempt = 0; attempt <= 10; attempt++) {
      const response = await server.inject({method:'POST',url:'/v1/auth/register',payload:{},
        remoteAddress:'192.0.2.6',headers:{'x-forwarded-for':`203.0.113.${attempt+1}`}});
      assert.equal(response.statusCode, attempt < 10 ? 400 : 429);
    }
  } finally {
    await app.close();
  }
});

test('authentication rejects work at capacity and releases slots on failure', async () => {
  const env = {AUTH_JWT_SECRET:randomBytes(48).toString('base64'), AUTH_MAX_CONCURRENT:'1'};
  assert.throws(() => loadAuthConfiguration({...env, AUTH_MAX_CONCURRENT:'5'}), /AUTH_MAX_CONCURRENT/);
  let release;
  const query = new Promise(resolve => { release = resolve; });
  const auth = new AuthService({pool:{query:() => query}}, loadAuthConfiguration(env));
  const first = auth.login({}, '127.0.0.1');
  await assert.rejects(auth.register({}, '127.0.0.1'), {status:503, code:'AUTH_BUSY'});
  release({rows:[{attempts:1}]});
  await assert.rejects(first, {status:400});
  await assert.rejects(auth.register({}, '127.0.0.1'), {status:400});
});
