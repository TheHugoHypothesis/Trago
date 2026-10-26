import 'reflect-metadata';
import {ArgumentsHost, Catch, Controller, ExceptionFilter, Get, Header, HttpCode, HttpException, Inject, Module, Param, Patch, Post, Query, Req, Body} from '@nestjs/common';
import {NestFactory} from '@nestjs/core';
import {FastifyAdapter, NestFastifyApplication} from '@nestjs/platform-fastify';
import {randomUUID} from 'node:crypto';
import {Database} from './database';
import {ApiService, Query as QueryValues} from './service';
import {ApiError} from './validation';
import {AuthService, loadAuthConfiguration} from './auth';
interface Request {headers:Record<string,string|string[]|undefined>;ip:string}
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
 constructor(private readonly service:ApiService,private readonly auth:AuthService,@Inject(CONFIG) private readonly config:Configuration) {}
 private async actor(req:Request) {
  const auth=req.headers.authorization;
  const match=typeof auth==='string'?/^Bearer dev:(buyer|traveler|outsider|revoked)$/.exec(auth):null;
  if(this.config.demo && ['development','test'].includes(this.config.environment) && match) return match[1];
  return (await this.auth.session(auth)).user.id;
 }
 @Get('health') async health() {await this.service.db.pool.query('SELECT 1');return {status:'ok'};}
 @Get('v1/me/accounts') async accounts(@Req() r:Request) {return this.service.accounts(await this.actor(r));}
 @Post('v1/me/accounts/organizations') async createOrganization(@Req() r:Request,@Body() b:unknown) {
  return this.service.createOrganization(await this.actor(r),b);
 }
 @Post('v1/me/accounts/:accountId/members') @HttpCode(204)
 async addOrganizationMember(@Req() r:Request,@Param('accountId') accountId:string,@Body() b:unknown) {
  await this.service.addOrganizationMember(await this.actor(r),accountId,b);
 }
 @Get('v1/trips') async trips(@Req() r:Request,@Query() q:QueryValues) {await this.actor(r);return this.service.searchTrips(q);}
 @Post('v1/trips') async createTrip(@Req() r:Request,@Body() b:unknown) {return this.service.createTrip(await this.actor(r),b,r.headers['idempotency-key']);}
 @Get('v1/me/trips') async ownTrips(@Req() r:Request) {return this.service.ownTrips(await this.actor(r));}
 @Get('v1/trips/:id') async trip(@Req() r:Request,@Param('id') id:string) {return this.service.getTrip(await this.actor(r),id);}
 @Patch('v1/trips/:id') async updateTrip(@Req() r:Request,@Param('id') id:string,@Body() b:unknown) {
  return this.service.updateTrip(await this.actor(r),id,b);
 }
 @Post('v1/trips/:id/cancel') @HttpCode(200) async cancelTrip(@Req() r:Request,@Param('id') id:string) {
  return this.service.cancelTrip(await this.actor(r),id);
 }
 @Get('v1/purchase-requests') async list(@Req() r:Request,@Query() q:QueryValues) {return this.service.listRequests(await this.actor(r),q);}
 @Get('v1/me/incoming-requests') async incoming(@Req() r:Request) {return this.service.incomingRequests(await this.actor(r));}
 @Post('v1/purchase-requests') async create(@Req() r:Request,@Body() b:unknown) {return this.service.createRequest(await this.actor(r),b,r.headers['idempotency-key']);}
 @Get('v1/purchase-requests/:id') async request(@Req() r:Request,@Param('id') id:string) {return this.service.request(await this.actor(r),id);}
 @Post('v1/purchase-requests/:id/accept') @HttpCode(200)
 async acceptRequest(@Req() r:Request,@Param('id') id:string) {return this.service.decideRequest(await this.actor(r),id,'ACCEPTED');}
 @Post('v1/purchase-requests/:id/reject') @HttpCode(200)
 async rejectRequest(@Req() r:Request,@Param('id') id:string) {return this.service.decideRequest(await this.actor(r),id,'REJECTED');}
}

@Controller('v1/auth')
class AuthController {
 constructor(private readonly auth:AuthService) {}
 @Post('register') @Header('Cache-Control','no-store')
 register(@Req() r:Request,@Body() b:unknown) {return this.auth.register(b,r.ip);}
 @Post('login') @HttpCode(200) @Header('Cache-Control','no-store')
 login(@Req() r:Request,@Body() b:unknown) {return this.auth.login(b,r.ip);}
 @Get('me') @Header('Cache-Control','no-store')
 async me(@Req() r:Request) {return (await this.auth.session(r.headers.authorization)).user;}
 @Post('logout') @HttpCode(204) @Header('Cache-Control','no-store')
 logout(@Req() r:Request) {return this.auth.logout(r.headers.authorization);}
}
@Module({})
class ApiModule {}
export async function createApp(options?:Configuration):Promise<NestFastifyApplication> {
 const config=options??{demo:process.env.TRAGO_DEMO_AUTH==='true',environment:process.env.NODE_ENV??'development'};
 if(config.demo && !['development','test'].includes(config.environment)) throw new Error('Demo authentication is allowed only in development/test');
 const authConfig=loadAuthConfiguration();
 const db=new Database();
 try {
  await db.initialize(config.demo && config.environment!=='production');
  const auth=new AuthService(db,authConfig);
  await auth.initialize();
  const app=await NestFactory.create<NestFastifyApplication>({module:ApiModule,controllers:[ApiController,AuthController],providers:[
   {provide:CONFIG,useValue:config},{provide:Database,useValue:db},{provide:ApiService,useFactory:()=>new ApiService(db)},
   {provide:AuthService,useValue:auth}
  ]},new FastifyAdapter({bodyLimit:65536,logger:false}),{logger:false});
  app.useGlobalFilters(new Errors());
  const corsOrigins=process.env.CORS_ORIGINS?.split(',').map(origin=>origin.trim()).filter(Boolean)
   ?? (config.environment==='production'?[]:['http://localhost:3000','http://127.0.0.1:3000']);
  app.enableCors({origin:corsOrigins,methods:['GET','POST','PATCH','OPTIONS'],allowedHeaders:['Authorization','Content-Type','Idempotency-Key']});
  app.enableShutdownHooks();
  await app.init(); await app.getHttpAdapter().getInstance().ready();
  return app;
 } catch(error) {await db.pool.end();throw error;}
}
if(require.main===module) {
 createApp().then(app=>app.listen(3001,'0.0.0.0')).catch(()=>{console.error('API startup failed; check PostgreSQL, AUTH_JWT_SECRET, AUTH_TOKEN_TTL_SECONDS and demo configuration.');process.exitCode=1;});
}
