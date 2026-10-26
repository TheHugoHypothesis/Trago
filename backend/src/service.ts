import {randomUUID} from 'node:crypto';
import {PoolClient} from 'pg';
import {Database} from './database';
import {ApiError, date, invalid, safeWeight, timeZone, validate} from './validation';
type Money={amount:string;currency:'USD'|'BRL'};
type TripInput={origin:string;destination:string;departureDate:string;timeZone:string;availableWeightGrams:number;pricePerKg:Money};
type RequestInput={accountId:string;tripId:string;product:{description:string;url?:string;price:Money;estimatedWeightGrams:number}};
type OrganizationInput={displayName:string};
type OrganizationMemberInput={email:string};
type TripStatus='AVAILABLE'|'CANCELLED'|'EXPIRED';
type TripRow={id:string;data:TripInput&{id:string;travelerName:string;isDemo:boolean};status:'AVAILABLE'|'CANCELLED';traveler_id:string|null;traveler_user_id:string|null;total_capacity_grams:number;reserved_capacity_grams:number};
type RequestStatus='PENDING'|'ACCEPTED'|'REJECTED';
type RequestRow={id:string;data:RequestInput&{id:string;status:RequestStatus;createdAt:string;updatedAt?:string};status:RequestStatus;trip_id:string;account_id:string};
export type Query=Record<string,unknown>;
const missing=()=>new ApiError(404,'NOT_FOUND','Recurso não encontrado.');
const forbidden=()=>new ApiError(403,'FORBIDDEN','Operação não autorizada.');
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
function localDate(timeZoneValue:string) {
 const parts=new Intl.DateTimeFormat('en-US',{timeZone:timeZoneValue,year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts();
 const value=(part:string)=>parts.find(item=>item.type===part)!.value;
 return `${value('year')}-${value('month')}-${value('day')}`;
}
export class ApiService {
 constructor(readonly db:Database) {}
 async accounts(actor:string) {
  const real=uuid.test(actor);
  const r=real
   ? await this.db.pool.query(`SELECT a.data || jsonb_build_object('accessRole',
      CASE WHEN a.owner_user_id=$1::uuid THEN 'OWNER' ELSE 'MEMBER' END) AS data
      FROM accounts a WHERE a.owner_user_id=$1::uuid OR EXISTS
      (SELECT 1 FROM account_memberships m WHERE m.account_id=a.id AND m.user_id=$1::uuid AND m.active)
      ORDER BY CASE WHEN a.data->>'type'='PERSONAL' THEN 0 ELSE 1 END,a.id`,[actor])
   : await this.db.pool.query(`SELECT a.data || jsonb_build_object('accessRole',
      CASE WHEN a.owner_id=$1 THEN 'OWNER' ELSE 'MEMBER' END) AS data
      FROM accounts a WHERE a.owner_id=$1 OR EXISTS
      (SELECT 1 FROM memberships m WHERE m.account_id=a.id AND m.user_id=$1 AND m.active) ORDER BY a.id`,[actor]);
  return {items:r.rows.map(r=>r.data)};
 }
 async createOrganization(actor:string,input:unknown) {
  if(!uuid.test(actor)) throw forbidden();
  validate('OrganizationAccountInput',input);
  const displayName=(input as OrganizationInput).displayName.trim();
  if(displayName.length<2) invalid();
  const account={id:randomUUID(),type:'ORGANIZATION',displayName,accessRole:'OWNER'};
  await this.db.pool.query('INSERT INTO accounts(id,owner_user_id,data) VALUES($1,$2,$3)',
   [account.id,actor,{id:account.id,type:account.type,displayName:account.displayName}]);
  return account;
 }
 async addOrganizationMember(actor:string,accountId:string,input:unknown) {
  if(!uuid.test(actor)) throw forbidden();
  validate('OrganizationMemberInput',input);
  const email=(input as OrganizationMemberInput).email.toLowerCase();
  await this.db.transaction(async c=>{
   const account=await c.query(`SELECT id FROM accounts WHERE id=$1 AND owner_user_id=$2::uuid
     AND data->>'type'='ORGANIZATION' FOR UPDATE`,[accountId,actor]);
   if(!account.rowCount) throw missing();
   const target=await c.query<{id:string}>('SELECT id FROM users WHERE email=$1',[email]);
   if(!target.rowCount) throw missing();
   if(target.rows[0].id===actor) return;
   await c.query(`INSERT INTO account_memberships(account_id,user_id,role,active) VALUES($1,$2,'MEMBER',true)
     ON CONFLICT(account_id,user_id) DO UPDATE SET active=true`,[accountId,target.rows[0].id]);
  });
 }
 private async authorize(actor:string,account:string,c?:PoolClient) {
  const real=uuid.test(actor);
  const result=real
   ? await (c??this.db.pool).query(`SELECT a.id FROM accounts a WHERE a.id=$2 AND
      (a.owner_user_id=$1::uuid OR EXISTS(SELECT 1 FROM account_memberships m
       WHERE m.account_id=a.id AND m.user_id=$1::uuid AND m.active))`,[actor,account])
   : await (c??this.db.pool).query(`SELECT a.id FROM accounts a WHERE a.id=$2 AND
      (a.owner_id=$1 OR EXISTS(SELECT 1 FROM memberships m WHERE m.account_id=a.id AND m.user_id=$1 AND m.active))`,[actor,account]);
  if (!result.rowCount) throw missing();
 }
 private tripInput(input:unknown):TripInput {
  validate('TripInput',input); const data=input as TripInput;
  if (!date(data.departureDate)) invalid();
  timeZone(data.timeZone);safeWeight(data.availableWeightGrams);
  const origin=data.origin.trim(); const destination=data.destination.trim();
  if(origin.length<2 || destination.length<2 || origin.localeCompare(destination,undefined,{sensitivity:'accent'})===0) invalid();
  if(data.departureDate<=localDate(data.timeZone) || BigInt(data.pricePerKg.amount)<=0n) invalid();
  return {...data,origin,destination};
 }
 private tripStatus(row:Pick<TripRow,'data'|'status'>):TripStatus {
  if(row.status==='CANCELLED') return 'CANCELLED';
  return row.data.departureDate<localDate(row.data.timeZone)?'EXPIRED':'AVAILABLE';
 }
 private capacity(row:Pick<TripRow,'total_capacity_grams'|'reserved_capacity_grams'>) {
  return {totalWeightGrams:row.total_capacity_grams,reservedWeightGrams:row.reserved_capacity_grams,
   availableWeightGrams:row.total_capacity_grams-row.reserved_capacity_grams};
 }
 private trip(row:Pick<TripRow,'data'|'status'|'total_capacity_grams'|'reserved_capacity_grams'>) {
  return {...row.data,...this.capacity(row),status:this.tripStatus(row)};
 }
 private ownsTrip(actor:string,row:Pick<TripRow,'traveler_id'|'traveler_user_id'>) {
  return uuid.test(actor)?row.traveler_user_id===actor:row.traveler_id===actor;
 }
 async createTrip(actor:string,input:unknown,key:unknown) {
  const real=uuid.test(actor);
  if (!real && actor!=='traveler') throw forbidden();
  const data=this.tripInput(input);
  if(typeof key!=='string'||key.length<8||key.length>128) invalid();
  return this.db.transaction(async c=>{
   await c.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))',[JSON.stringify([actor,'createTrip',key])]);
   const existing=await c.query<TripRow&{same:boolean}>(`SELECT t.*,i.payload=$4::jsonb AS same
     FROM trip_idempotency i JOIN trips t ON t.id=i.trip_id
     WHERE i.actor_id=$1 AND i.operation=$2 AND i.key=$3`,[actor,'createTrip',key,JSON.stringify(data)]);
   if(existing.rowCount) {
    if(!existing.rows[0].same) throw new ApiError(409,'IDEMPOTENCY_CONFLICT','Chave já utilizada com outro conteúdo.');
    return this.trip(existing.rows[0]);
   }
   let travelerName='Viajante (exemplo)';
   if(real) {
    const user=await c.query<{display_name:string}>('SELECT display_name FROM users WHERE id=$1',[actor]);
    if(!user.rowCount) throw forbidden();
    travelerName=user.rows[0].display_name;
   }
   const trip={...data,id:randomUUID(),travelerName,isDemo:!real};
   await c.query(`INSERT INTO trips(id,traveler_id,traveler_user_id,data,status,total_capacity_grams)
     VALUES($1,$2,$3,$4,'AVAILABLE',$5)`,[trip.id,real?null:actor,real?actor:null,trip,data.availableWeightGrams]);
   await c.query(`INSERT INTO trip_idempotency(actor_id,operation,key,payload,trip_id)
     VALUES($1,$2,$3,$4,$5)`,[actor,'createTrip',key,data,trip.id]);
   return {...trip,totalWeightGrams:data.availableWeightGrams,reservedWeightGrams:0,
    availableWeightGrams:data.availableWeightGrams,status:'AVAILABLE' as const};
  });
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
  const result=await this.db.pool.query<TripRow>(`SELECT * FROM trips WHERE status='AVAILABLE' AND
   total_capacity_grams>reserved_capacity_grams AND
   data->>'departureDate'>=to_char(now() AT TIME ZONE (data->>'timeZone'),'YYYY-MM-DD') AND
   ($1::text IS NULL OR lower(data->>'origin')=lower($1)) AND
   ($2::text IS NULL OR lower(data->>'destination')=lower($2)) AND
   ($3::text IS NULL OR data->>'departureDate'=$3) AND
   ($4::text IS NULL OR (data->>'departureDate',id)>($4,$5))
   ORDER BY data->>'departureDate',id LIMIT 21`,[query.origin??null,query.destination??null,query.departureDate??null,cursor?.date??null,cursor?.id??null]);
  const items=result.rows.slice(0,20).map(r=>this.trip(r));
  const last=items.at(-1);
  return {items,nextCursor:result.rows.length>20?Buffer.from(JSON.stringify({date:last!.departureDate,id:last!.id,filters})).toString('base64url'):null};
 }
 async ownTrips(actor:string) {
  const real=uuid.test(actor);
  const result=real
   ? await this.db.pool.query<TripRow>('SELECT * FROM trips WHERE traveler_user_id=$1::uuid ORDER BY created_at DESC,id DESC',[actor])
   : await this.db.pool.query<TripRow>('SELECT * FROM trips WHERE traveler_id=$1 ORDER BY created_at DESC,id DESC',[actor]);
  return {items:result.rows.map(row=>this.trip(row))};
 }
 async getTrip(actor:string,id:string) {
  const result=await this.db.pool.query<TripRow>('SELECT * FROM trips WHERE id=$1',[id]);
  if(!result.rowCount) throw missing();
  const row=result.rows[0];
  if(this.tripStatus(row)!=='AVAILABLE' && !this.ownsTrip(actor,row)) throw missing();
  return this.trip(row);
 }
 async updateTrip(actor:string,id:string,input:unknown) {
  const data=this.tripInput(input);
  return this.db.transaction(async c=>{
   const result=await c.query<TripRow>('SELECT * FROM trips WHERE id=$1 FOR UPDATE',[id]);
   if(!result.rowCount || !this.ownsTrip(actor,result.rows[0])) throw missing();
   const current=result.rows[0];
   if(this.tripStatus(current)!=='AVAILABLE') throw new ApiError(409,'TRIP_UNAVAILABLE','Viagem cancelada ou expirada não pode ser editada.');
   const requests=await c.query('SELECT 1 FROM purchase_requests WHERE trip_id=$1 LIMIT 1',[id]);
   if(requests.rowCount) throw new ApiError(409,'TRIP_HAS_REQUESTS','Viagem com pedidos associados não pode ser editada.');
   const updated={...data,id:current.data.id,travelerName:current.data.travelerName,isDemo:current.data.isDemo};
   await c.query('UPDATE trips SET data=$2,total_capacity_grams=$3,updated_at=now() WHERE id=$1',[id,updated,data.availableWeightGrams]);
   return {...updated,totalWeightGrams:data.availableWeightGrams,reservedWeightGrams:0,
    availableWeightGrams:data.availableWeightGrams,status:'AVAILABLE' as const};
  });
 }
 async cancelTrip(actor:string,id:string) {
  return this.db.transaction(async c=>{
   const result=await c.query<TripRow>('SELECT * FROM trips WHERE id=$1 FOR UPDATE',[id]);
   if(!result.rowCount || !this.ownsTrip(actor,result.rows[0])) throw missing();
   const current=result.rows[0];
   if(current.status==='CANCELLED') return this.trip(current);
   if(this.tripStatus(current)==='EXPIRED') throw new ApiError(409,'TRIP_UNAVAILABLE','Viagem expirada não pode ser cancelada.');
   await c.query("UPDATE trips SET status='CANCELLED',updated_at=now() WHERE id=$1",[id]);
   return {...current.data,...this.capacity(current),status:'CANCELLED' as const};
  });
 }
 async createRequest(actor:string,input:unknown,key:unknown) {
  validate('RequestInput',input);
  if(typeof key!=='string'||key.length<8||key.length>128) invalid();
  const data=input as RequestInput;safeWeight(data.product.estimatedWeightGrams);
  if(data.product.url) {try {const u=new URL(data.product.url);if(!['https:','http:'].includes(u.protocol)) invalid();} catch {invalid();}}
  return this.db.transaction(async c=>{
   await this.authorize(actor,data.accountId,c);
   const real=uuid.test(actor);
   // Serialize this scoped key, including across processes; JSONB equality ignores object key order.
   await c.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))',[JSON.stringify([actor,data.accountId,'createPurchaseRequest',key])]);
   const existing=await c.query(`SELECT r.data,i.payload=$5::jsonb AS same FROM ${real?'user_idempotency':'idempotency'} i
    JOIN purchase_requests r ON r.id=i.request_id WHERE i.${real?'actor_user_id':'actor_id'}=$1 AND i.account_id=$2 AND i.operation=$3 AND i.key=$4`,[actor,data.accountId,'createPurchaseRequest',key,JSON.stringify(data)]);
   if(existing.rowCount) {
    if(!existing.rows[0].same) throw new ApiError(409,'IDEMPOTENCY_CONFLICT','Chave já utilizada com outro conteúdo.');
    return existing.rows[0].data;
   }
   const trip=await c.query<TripRow>('SELECT * FROM trips WHERE id=$1 FOR SHARE',[data.tripId]);
   if(!trip.rowCount) throw missing();
   if(this.tripStatus(trip.rows[0])!=='AVAILABLE') throw new ApiError(409,'TRIP_UNAVAILABLE','Viagem indisponível para novos pedidos.');
   const remaining=trip.rows[0].total_capacity_grams-trip.rows[0].reserved_capacity_grams;
   if(data.product.estimatedWeightGrams>remaining) throw new ApiError(422,'CAPACITY_EXCEEDED','Peso estimado excede a capacidade disponível da viagem.');
   const createdAt=new Date().toISOString();
   const request={...data,id:randomUUID(),status:'PENDING' as const,createdAt};
   await c.query(`INSERT INTO purchase_requests(id,account_id,trip_id,actor_id,data,actor_user_id,status)
     VALUES($1,$2,$3,$4,$5,$6,'PENDING')`,[request.id,data.accountId,data.tripId,real?null:actor,request,real?actor:null]);
   if(real) await c.query(`INSERT INTO user_idempotency(actor_user_id,account_id,operation,key,payload,request_id)
     VALUES($1,$2,$3,$4,$5,$6)`,[actor,data.accountId,'createPurchaseRequest',key,data,request.id]);
   else await c.query(`INSERT INTO idempotency(actor_id,account_id,operation,key,payload,request_id)
     VALUES($1,$2,$3,$4,$5,$6)`,[actor,data.accountId,'createPurchaseRequest',key,data,request.id]);
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
  const real=uuid.test(actor);
  const result=real
   ? await this.db.pool.query(`SELECT r.data FROM purchase_requests r JOIN accounts a ON a.id=r.account_id JOIN trips t ON t.id=r.trip_id
      WHERE r.id=$2 AND (a.owner_user_id=$1::uuid OR EXISTS (SELECT 1 FROM account_memberships m
       WHERE m.account_id=a.id AND m.user_id=$1::uuid AND m.active) OR t.traveler_user_id=$1::uuid)`,[actor,id])
   : await this.db.pool.query(`SELECT r.data FROM purchase_requests r JOIN accounts a ON a.id=r.account_id JOIN trips t ON t.id=r.trip_id
      WHERE r.id=$2 AND (a.owner_id=$1 OR EXISTS (SELECT 1 FROM memberships m WHERE m.account_id=a.id AND m.user_id=$1 AND m.active)
       OR t.traveler_id=$1)`,[actor,id]);
  if(!result.rowCount) throw missing();
  return result.rows[0].data;
 }
 async incomingRequests(actor:string) {
  const real=uuid.test(actor);
  const result=real
   ? await this.db.pool.query(`SELECT r.data FROM purchase_requests r JOIN trips t ON t.id=r.trip_id
      WHERE t.traveler_user_id=$1::uuid ORDER BY r.updated_at DESC,r.id DESC`,[actor])
   : await this.db.pool.query(`SELECT r.data FROM purchase_requests r JOIN trips t ON t.id=r.trip_id
      WHERE t.traveler_id=$1 ORDER BY r.updated_at DESC,r.id DESC`,[actor]);
  return {items:result.rows.map(row=>row.data)};
 }
 async decideRequest(actor:string,id:string,decision:Exclude<RequestStatus,'PENDING'>) {
  const real=uuid.test(actor);
  return this.db.transaction(async c=>{
   const reference=await c.query<{trip_id:string}>('SELECT trip_id FROM purchase_requests WHERE id=$1',[id]);
   if(!reference.rowCount) throw missing();
   // Every operation that coordinates trip/request state locks the trip first.
   const tripResult=await c.query<TripRow>('SELECT * FROM trips WHERE id=$1 FOR UPDATE',[reference.rows[0].trip_id]);
   if(!tripResult.rowCount || !this.ownsTrip(actor,tripResult.rows[0])) throw missing();
   const result=await c.query<RequestRow>('SELECT * FROM purchase_requests WHERE id=$1 AND trip_id=$2 FOR UPDATE',[id,reference.rows[0].trip_id]);
   if(!result.rowCount) throw missing();
   const row=result.rows[0]; const tripRow=tripResult.rows[0];
   if(row.status===decision) return {...row.data,tripCapacity:this.capacity(tripRow)};
   if(row.status!=='PENDING') throw new ApiError(409,'DECISION_CONFLICT','A solicitação já recebeu uma decisão diferente.');
   if(this.tripStatus(tripRow)!=='AVAILABLE') throw new ApiError(409,'TRIP_UNAVAILABLE','Viagem cancelada ou expirada não permite decisões.');
   let capacity=this.capacity(tripRow);
   if(decision==='ACCEPTED') {
    const weight=row.data.product.estimatedWeightGrams;safeWeight(weight);
    if(weight>capacity.availableWeightGrams) throw new ApiError(422,'CAPACITY_EXCEEDED','Capacidade disponível insuficiente para aceitar esta solicitação.');
    const reserved=tripRow.reserved_capacity_grams+weight;
    await c.query('UPDATE trips SET reserved_capacity_grams=$2,updated_at=now() WHERE id=$1',[tripRow.id,reserved]);
    capacity={totalWeightGrams:tripRow.total_capacity_grams,reservedWeightGrams:reserved,
     availableWeightGrams:tripRow.total_capacity_grams-reserved};
   }
   const decidedAt=new Date().toISOString();
   const updated={...row.data,status:decision,updatedAt:decidedAt};
   await c.query('UPDATE purchase_requests SET status=$2,data=$3,updated_at=$4,decided_at=$4 WHERE id=$1',
    [id,decision,updated,decidedAt]);
   await c.query(`INSERT INTO purchase_request_events(request_id,actor_id,actor_user_id,from_status,to_status,created_at)
      VALUES($1,$2,$3,'PENDING',$4,$5)`,[id,real?null:actor,real?actor:null,decision,decidedAt]);
   return {...updated,tripCapacity:capacity};
  });
 }
}
