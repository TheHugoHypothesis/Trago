import 'reflect-metadata';
import {ArgumentsHost, Catch, Controller, ExceptionFilter, Get, HttpException, Inject, Module, Param, Post, Query, Req, Body} from '@nestjs/common';
import {NestFactory} from '@nestjs/core';
import {FastifyAdapter, NestFastifyApplication} from '@nestjs/platform-fastify';
import {randomUUID} from 'node:crypto';
import {Database} from './database';
import {ApiService, Query as QueryValues} from './service';
import {ApiError} from './validation';
interface Request {headers:Record<string,string|string[]|undefined>}
interface Configuration {demo:boolean;environment:string}
const CONFIG=Symbol('configuration');
@Catch()
class Errors implements ExceptionFilter {
 catch(error:unknown,host:ArgumentsHost) {
  const status=error instanceof ApiError?error.status:error instanceof HttpException?error.getStatus():500;
  const code=error instanceof ApiError?error.code:status===400?'INVALID_INPUT':status===404?'NOT_FOUND':'INTERNAL_ERROR';
  const message=error instanceof ApiError?error.message:status===400?'Entrada inválida.':status===404?'Recurso não encontrado.':'Falha interna.';
  host.switchToHttp().getResponse().status(status).send({code,message,correlationId:randomUUID()});
 }
}
@Controller()
class ApiController {
 constructor(private readonly service:ApiService,@Inject(CONFIG) private readonly config:Configuration) {}
 private actor(req:Request) {
  const auth=req.headers.authorization;
  const match=typeof auth==='string'?/^Bearer dev:(buyer|traveler|outsider|revoked)$/.exec(auth):null;
  if(!this.config.demo || this.config.environment==='production' || !match) throw new ApiError(401,'UNAUTHENTICATED','Sessão inválida ou expirada.');
  return match[1];
 }
 @Get('health') async health() {await this.service.db.pool.query('SELECT 1');return {status:'ok'};}
 @Get('v1/me/accounts') accounts(@Req() r:Request) {return this.service.accounts(this.actor(r));}
 @Get('v1/trips') trips(@Req() r:Request,@Query() q:QueryValues) {this.actor(r);return this.service.searchTrips(q);}
 @Post('v1/trips') createTrip(@Req() r:Request,@Body() b:unknown) {return this.service.createTrip(this.actor(r),b);}
 @Get('v1/purchase-requests') list(@Req() r:Request,@Query() q:QueryValues) {return this.service.listRequests(this.actor(r),q);}
 @Post('v1/purchase-requests') create(@Req() r:Request,@Body() b:unknown) {return this.service.createRequest(this.actor(r),b,r.headers['idempotency-key']);}
 @Get('v1/purchase-requests/:id') request(@Req() r:Request,@Param('id') id:string) {return this.service.request(this.actor(r),id);}
}
@Module({})
class ApiModule {}
export async function createApp(options?:Configuration):Promise<NestFastifyApplication> {
 const config=options??{demo:process.env.TRAGO_DEMO_AUTH==='true',environment:process.env.NODE_ENV??'development'};
 if(config.environment==='production' && config.demo) throw new Error('Demo authentication configuration is forbidden in production');
 const db=new Database();
 try {
  await db.initialize(config.demo && config.environment!=='production');
  const app=await NestFactory.create<NestFastifyApplication>({module:ApiModule,controllers:[ApiController],providers:[
   {provide:CONFIG,useValue:config},{provide:Database,useValue:db},{provide:ApiService,useFactory:()=>new ApiService(db)}
  ]},new FastifyAdapter({bodyLimit:65536,logger:false}),{logger:false});
  app.useGlobalFilters(new Errors());
  app.enableCors({origin:['http://localhost:3000','http://127.0.0.1:3000'],methods:['GET','POST','OPTIONS'],allowedHeaders:['Authorization','Content-Type','Idempotency-Key']});
  app.enableShutdownHooks();
  await app.init(); await app.getHttpAdapter().getInstance().ready();
  return app;
 } catch(error) {await db.pool.end();throw error;}
}
if(require.main===module) {
 createApp().then(app=>app.listen(3001,'0.0.0.0')).catch(()=>{console.error('API startup failed; check PostgreSQL connectivity and demo configuration.');process.exitCode=1;});
}
