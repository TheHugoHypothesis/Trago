const {test}=require('node:test');
const assert=require('node:assert/strict');
const {randomUUID}=require('node:crypto');
const {readFile}=require('node:fs/promises');
const path=require('node:path');
const {Pool}=require('pg');

const migrations=name=>readFile(path.resolve(__dirname,'../migrations',name),'utf8');

async function prepare(client,schema,acceptedWeight) {
  await client.query(`CREATE SCHEMA ${schema}`);
  await client.query(`SET search_path TO ${schema}`);
  for(const name of ['001_initial.sql','002_auth.sql','003_account_ownership.sql','004_trip_management.sql','005_request_decisions.sql']) {
    await client.query(await migrations(name));
  }
  await client.query("INSERT INTO demo_users(id) VALUES('buyer'),('traveler')");
  await client.query(`INSERT INTO accounts(id,owner_id,data) VALUES('account','buyer',$1)`,[{id:'account',type:'PERSONAL',displayName:'Conta de teste'}]);
  const trip={id:'trip',travelerName:'Viajante',origin:'A',destination:'B',departureDate:'2099-01-01',timeZone:'UTC',availableWeightGrams:1000,pricePerKg:{amount:'1',currency:'USD'},isDemo:true};
  await client.query(`INSERT INTO trips(id,traveler_id,data,status) VALUES('trip','traveler',$1,'AVAILABLE')`,[trip]);
  const request={id:'request',accountId:'account',tripId:'trip',product:{description:'Legado aceito',price:{amount:'1',currency:'USD'},estimatedWeightGrams:acceptedWeight},status:'ACCEPTED',createdAt:new Date().toISOString()};
  await client.query(`INSERT INTO purchase_requests(id,account_id,trip_id,actor_id,data,status) VALUES('request','account','trip','buyer',$1,'ACCEPTED')`,[request]);
}

test('capacity migration backfills accepted legacy requests and rejects overbooking',async()=>{
  const pool=new Pool({connectionString:process.env.DATABASE_URL});
  const client=await pool.connect();
  const valid=`capacity_valid_${randomUUID().replaceAll('-','')}`;
  const invalid=`capacity_invalid_${randomUUID().replaceAll('-','')}`;
  try {
    await prepare(client,valid,600);
    await client.query(await migrations('006_trip_capacity_reservations.sql'));
    const capacity=(await client.query('SELECT total_capacity_grams AS total,reserved_capacity_grams AS reserved FROM trips')).rows[0];
    assert.deepEqual(capacity,{total:1000,reserved:600});

    await client.query('SET search_path TO public');
    await prepare(client,invalid,1200);
    await client.query('BEGIN');
    await assert.rejects(client.query(await migrations('006_trip_capacity_reservations.sql')),/exceed or invalidate/);
    await client.query('ROLLBACK');
  } finally {
    await client.query('SET search_path TO public');
    await client.query(`DROP SCHEMA IF EXISTS ${valid} CASCADE`);
    await client.query(`DROP SCHEMA IF EXISTS ${invalid} CASCADE`);
    client.release();
    await pool.end();
  }
});
