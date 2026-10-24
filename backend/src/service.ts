import {randomUUID} from 'node:crypto';
import {PoolClient} from 'pg';
import {Database} from './database';
import {ApiError, date, invalid, safeWeight, timeZone, validate} from './validation';
type Money={amount:string;currency:'USD'|'BRL'};
type TripInput={origin:string;destination:string;departureDate:string;timeZone:string;availableWeightGrams:number;pricePerKg:Money};
type RequestInput={accountId:string;tripId:string;product:{description:string;url?:string;price:Money;estimatedWeightGrams:number}};
export type Query=Record<string,unknown>;
const missing=()=>new ApiError(404,'NOT_FOUND','Recurso não encontrado.');
export class ApiService {
 constructor(readonly db:Database) {}
 async accounts(actor:string) {
  const r=await this.db.pool.query(`SELECT a.data FROM accounts a WHERE a.owner_id=$1 OR EXISTS
   (SELECT 1 FROM memberships m WHERE m.account_id=a.id AND m.user_id=$1 AND m.active) ORDER BY a.id`,[actor]);
  return {items:r.rows.map(r=>r.data)};
 }
 private async authorize(actor:string,account:string,c?:PoolClient) {
  const result=await (c??this.db.pool).query(`SELECT a.id FROM accounts a WHERE a.id=$2 AND
   (a.owner_id=$1 OR EXISTS(SELECT 1 FROM memberships m WHERE m.account_id=a.id AND m.user_id=$1 AND m.active))`,[actor,account]);
  if (!result.rowCount) throw missing();
 }
 async createTrip(actor:string,input:unknown) {
  if (actor!=='traveler') throw new ApiError(403,'FORBIDDEN','Operação indisponível para esta identidade.');
  validate('TripInput',input); const data=input as TripInput;
  if (!date(data.departureDate)) invalid();
  timeZone(data.timeZone);safeWeight(data.availableWeightGrams);
  const trip={...data,id:randomUUID(),travelerName:'Viajante (exemplo)',isDemo:true};
  await this.db.pool.query('INSERT INTO trips VALUES($1,$2,$3)',[trip.id,actor,trip]);
  return trip;
 }
 async searchTrips(query:Query) {
  if (Object.keys(query).some(k=>!['origin','destination','departureDate','cursor'].includes(k))) invalid();
  // Cursors contain encoded filters plus the last row; they need their own bounded limit.
  for (const [key,value] of Object.entries(query)) {
   const limit=key==='cursor'?32768:500;
   if (typeof value!=='string' || !value.trim() || value.length>limit) invalid();
  }
  if (query.departureDate!==undefined && !date(query.departureDate)) invalid();
  let cursor: {date:string;id:string;filters:string}|undefined;
  const filters=JSON.stringify([query.origin??null,query.destination??null,query.departureDate??null]);
  if(query.cursor!==undefined) {
   try {
    if (!/^[A-Za-z0-9_-]+$/.test(query.cursor as string)) invalid();
    cursor=JSON.parse(Buffer.from(query.cursor as string,'base64url').toString('utf8'));
    if(!cursor || !date(cursor.date) || typeof cursor.id!=='string' || cursor.filters!==filters) invalid();
   } catch {invalid();}
  }
  const result=await this.db.pool.query(`SELECT data FROM trips WHERE
   ($1::text IS NULL OR lower(data->>'origin')=lower($1)) AND
   ($2::text IS NULL OR lower(data->>'destination')=lower($2)) AND
   ($3::text IS NULL OR data->>'departureDate'=$3) AND
   ($4::text IS NULL OR (data->>'departureDate',id)>($4,$5))
   ORDER BY data->>'departureDate',id LIMIT 21`,[query.origin??null,query.destination??null,query.departureDate??null,cursor?.date??null,cursor?.id??null]);
  const items=result.rows.slice(0,20).map(r=>r.data);
  const last=items.at(-1);
  return {items,nextCursor:result.rows.length>20?Buffer.from(JSON.stringify({date:last.departureDate,id:last.id,filters})).toString('base64url'):null};
 }
 async createRequest(actor:string,input:unknown,key:unknown) {
  validate('RequestInput',input);
  if(typeof key!=='string'||key.length<8||key.length>128) invalid();
  const data=input as RequestInput;safeWeight(data.product.estimatedWeightGrams);
  if(data.product.url) {try {const u=new URL(data.product.url);if(!['https:','http:'].includes(u.protocol)) invalid();} catch {invalid();}}
  return this.db.transaction(async c=>{
   await this.authorize(actor,data.accountId,c);
   // Serialize this scoped key, including across processes; JSONB equality ignores object key order.
   await c.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))',[JSON.stringify([actor,data.accountId,'createPurchaseRequest',key])]);
   const existing=await c.query(`SELECT r.data,i.payload=$5::jsonb AS same FROM idempotency i
    JOIN purchase_requests r ON r.id=i.request_id WHERE i.actor_id=$1 AND i.account_id=$2 AND i.operation=$3 AND i.key=$4`,[actor,data.accountId,'createPurchaseRequest',key,JSON.stringify(data)]);
   if(existing.rowCount) {
    if(!existing.rows[0].same) throw new ApiError(409,'IDEMPOTENCY_CONFLICT','Chave já utilizada com outro conteúdo.');
    return existing.rows[0].data;
   }
   const trip=await c.query('SELECT data FROM trips WHERE id=$1',[data.tripId]);
   if(!trip.rowCount) throw missing();
   if(data.product.estimatedWeightGrams>trip.rows[0].data.availableWeightGrams) throw new ApiError(422,'CAPACITY_EXCEEDED','Peso estimado excede a capacidade disponível da viagem.');
   const request={...data,id:randomUUID(),status:'DRAFT',createdAt:new Date().toISOString()};
   await c.query('INSERT INTO purchase_requests VALUES($1,$2,$3,$4,$5)',[request.id,data.accountId,data.tripId,actor,request]);
   await c.query('INSERT INTO idempotency VALUES($1,$2,$3,$4,$5,$6)',[actor,data.accountId,'createPurchaseRequest',key,data,request.id]);
   return request;
  });
 }
 async listRequests(actor:string,query:Query) {
  if(Object.keys(query).some(k=>!['accountId','cursor'].includes(k)) || typeof query.accountId!=='string' || !query.accountId) invalid();
  if(query.cursor!==undefined && (typeof query.cursor!=='string' || !query.cursor || query.cursor.length>32768)) invalid();
  await this.authorize(actor,query.accountId);
  let cursor: {createdAt:string;id:string;accountId:string}|undefined;
  if(query.cursor!==undefined) {
   try {
    if (!/^[A-Za-z0-9_-]+$/.test(query.cursor as string)) invalid();
    cursor=JSON.parse(Buffer.from(query.cursor as string,'base64url').toString('utf8'));
    if(!cursor || typeof cursor.createdAt!=='string' || typeof cursor.id!=='string' || cursor.accountId!==query.accountId) invalid();
   } catch {invalid();}
  }
  const result=await this.db.pool.query(`SELECT data FROM purchase_requests WHERE account_id=$1 AND
   ($2::text IS NULL OR (data->>'createdAt',id)<($2,$3))
   ORDER BY data->>'createdAt' DESC,id DESC LIMIT 21`,[query.accountId,cursor?.createdAt??null,cursor?.id??null]);
  const items=result.rows.slice(0,20).map(r=>r.data);
  const last=items.at(-1);
  return {items,nextCursor:result.rows.length>20?Buffer.from(JSON.stringify({createdAt:last.createdAt,id:last.id,accountId:query.accountId})).toString('base64url'):null};
 }
 async request(actor:string,id:string) {
  const result=await this.db.pool.query(`SELECT r.data FROM purchase_requests r JOIN accounts a ON a.id=r.account_id
   WHERE r.id=$2 AND (a.owner_id=$1 OR EXISTS (SELECT 1 FROM memberships m WHERE m.account_id=a.id AND m.user_id=$1 AND m.active))`,[actor,id]);
  if(!result.rowCount) throw missing();
  return result.rows[0].data;
 }
}
