import Ajv from 'ajv';
import addFormats from 'ajv-formats';
import {readFileSync, existsSync} from 'node:fs';
import {resolve} from 'node:path';
import {componentRoot} from './database';
export class ApiError extends Error {
 constructor(readonly status: number, readonly code: string, message: string) {super(message);}
}
export function invalid(): never {throw new ApiError(400,'INVALID_INPUT','Entrada inválida.');}
const defaultContractPath = resolve(componentRoot, '../contracts/http/openapi.json');
const contractPath = process.env.CONTRACT_PATH || (existsSync(defaultContractPath) ? defaultContractPath : resolve(componentRoot, '../../contracts/http/openapi.json'));
const contract=JSON.parse(readFileSync(contractPath,'utf8'));
const ajv=new Ajv({strict:false,coerceTypes:false,allErrors:false});
addFormats(ajv);
ajv.addSchema({...contract,$id:'trago'});
const validators=new Map<string,ReturnType<Ajv['compile']>>();
export function validate(name:string, data:unknown) {
 let fn=validators.get(name);
 if (!fn) {fn=ajv.compile({$ref:`trago#/components/schemas/${name}`});validators.set(name,fn);}
 if (!fn(data)) invalid();
}
export function date(value:unknown): value is string {
 return typeof value==='string' && /^\d{4}-\d{2}-\d{2}$/.test(value) && !Number.isNaN(Date.parse(value)) && new Date(value).toISOString().slice(0,10)===value;
}
export function timeZone(value:string) {
 try {new Intl.DateTimeFormat('pt-BR',{timeZone:value});} catch {invalid();}
}
export function safeWeight(value:number) {if (!Number.isSafeInteger(value)) invalid();}
