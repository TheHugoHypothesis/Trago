import { Pool, PoolClient } from 'pg';
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';
export const componentRoot = resolve(__dirname, '..');
export class Database {
 readonly pool: Pool;
 constructor() {
  if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required; PostgreSQL has no fallback');
  this.pool = new Pool({ connectionString: process.env.DATABASE_URL, max: 5, connectionTimeoutMillis: 5000 });
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
