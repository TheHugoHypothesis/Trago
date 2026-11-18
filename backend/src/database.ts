import { Pool, PoolClient, PoolConfig } from 'pg';
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';
export const componentRoot = resolve(__dirname, '..');

export function loadDatabaseConfiguration(env: NodeJS.ProcessEnv, production: boolean): PoolConfig {
 const connectionString = env.DATABASE_URL;
 let url: URL;
 try {
  url = new URL(connectionString ?? '');
 } catch {
  throw new Error('DATABASE_URL must be a valid PostgreSQL URL');
 }
 if (!['postgres:', 'postgresql:'].includes(url.protocol) || !url.hostname ||
     url.pathname.length < 2 || url.search || url.hash ||
     (production && (!url.username || !url.password))) {
  throw new Error('DATABASE_URL must specify a PostgreSQL host and database, without query or fragment');
 }
 const tls = env.DATABASE_TLS ?? 'false';
 const schema = env.DATABASE_SCHEMA;
 const render = env.RENDER === 'true';
 const caFile = env.DATABASE_TLS_CA_FILE?.trim();
 const inlineCa = env.DATABASE_TLS_CA?.trim();
 if (!['true', 'false'].includes(tls) || ((production || caFile || inlineCa) && tls !== 'true')) {
  throw new Error('DATABASE_TLS must be true in production and when a CA is configured');
 }
 if ((schema && !/^[a-z][a-z0-9_]{0,62}$/.test(schema)) ||
     (production && (!schema || schema === 'public' || schema === 'information_schema' || schema.startsWith('pg_')))) {
  throw new Error('DATABASE_SCHEMA must identify a dedicated schema in production');
 }
 if (render && (schema !== 'trago' || !/^trago_app(?:\.[a-z0-9]{20})?$/.test(url.username))) {
  throw new Error('Render requires the trago_app database role and trago schema');
 }
 if (caFile && inlineCa) throw new Error('Configure only one PostgreSQL CA source');
 const ca = caFile ? readFileSync(caFile, 'utf8').trim() : inlineCa;
 if (render && !ca) throw new Error('Render requires an explicit PostgreSQL CA');
 return {
  connectionString,
  ssl: tls === 'true' ? {rejectUnauthorized: true, ...(ca ? {ca} : {})} : false,
  max: 5,
  connectionTimeoutMillis: 5000,
  idleTimeoutMillis: 10000,
  onConnect: schema ? async client => {
   if (render) {
    const {rows} = await client.query(`
     SELECT current_user = 'trago_app' AND session_user = 'trago_app'
       AND NOT (rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls)
       AND NOT EXISTS (SELECT 1 FROM pg_auth_members WHERE member = pg_roles.oid)
       AS restricted FROM pg_roles WHERE rolname = current_user
    `);
    if (rows[0]?.restricted !== true) throw new Error('Render database role is not restricted');
   }
   await client.query(`SET search_path TO "${schema}"`);
   const {rows} = await client.query('SELECT current_schema() AS schema');
   if (rows[0].schema !== schema) throw new Error('DATABASE_SCHEMA is missing or inaccessible');
  } : undefined,
 };
}

export class Database {
 readonly pool: Pool;
 constructor(production: boolean) {
  this.pool = new Pool(loadDatabaseConfiguration(process.env, production));
  this.pool.on('error', () => console.error('Idle PostgreSQL connection interrupted'));
 }
 async transaction<T>(action: (client: PoolClient) => Promise<T>): Promise<T> {
  const c = await this.pool.connect();
  try {await c.query('BEGIN'); const result=await action(c); await c.query('COMMIT'); return result;}
  catch (error) {await c.query('ROLLBACK'); throw error;}
  finally {c.release();}
 }
 async initialize(seed: boolean) {
  await this.transaction(async c => {
   await c.query('SELECT pg_advisory_xact_lock(740106001)');
   await c.query('CREATE TABLE IF NOT EXISTS api_migrations (version text PRIMARY KEY)');
   for (const name of readdirSync(resolve(componentRoot,'migrations')).filter(n=>n.endsWith('.sql')).sort()) {
    const exists=await c.query('SELECT 1 FROM api_migrations WHERE version=$1',[name]);
    if (!exists.rowCount) {await c.query(readFileSync(resolve(componentRoot,'migrations',name),'utf8'));await c.query('INSERT INTO api_migrations VALUES($1)',[name]);}
   }
   if (seed) await this.seed(c);
  });
 }
 private async seed(c: PoolClient) {
  const defaultPath = resolve(componentRoot, '../contracts/fixtures/demo.json');
  const fixturePath = process.env.FIXTURE_PATH || (existsSync(defaultPath) ? defaultPath : resolve(componentRoot, '../../contracts/fixtures/demo.json'));
  const fixture = JSON.parse(readFileSync(fixturePath, 'utf8'));
  for (const id of fixture.users) await c.query('INSERT INTO demo_users VALUES($1) ON CONFLICT DO NOTHING',[id]);
  const accounts=[...fixture.accounts,{id:'company-numeric',type:'ORGANIZATION',displayName:'Segunda empresa sintética',taxId:'12.345.678/0001-95'}];
  for (const {ownerId,...data} of accounts) await c.query('INSERT INTO accounts(id,owner_id,data) VALUES($1,$2,$3) ON CONFLICT DO NOTHING',[data.id,ownerId ?? null,data]);
  for (const m of [...fixture.memberships,{userId:'buyer',accountId:'company-numeric',active:true},{userId:'outsider',accountId:'company-numeric',active:false}])
   await c.query('INSERT INTO memberships VALUES($1,$2,$3) ON CONFLICT DO NOTHING',[m.userId,m.accountId,m.active]);
  for (const data of fixture.trips) await c.query(`INSERT INTO trips(id,traveler_id,data,total_capacity_grams)
   VALUES($1,$2,$3,$4) ON CONFLICT DO NOTHING`,[data.id,'traveler',data,data.availableWeightGrams]);
 }
 async onModuleDestroy() {await this.pool.end();}
}
