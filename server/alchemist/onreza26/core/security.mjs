import {createHmac,timingSafeEqual} from 'node:crypto';
export function fail(code,status=503) {const e=new Error(code);e.code=code;e.status=status;throw e;}
export function secret(encoded) {
 if(typeof encoded!=='string'||!/^[A-Za-z0-9+/]+={0,2}$/.test(encoded))fail('SECRET_REQUIRED');
 const bytes=Buffer.from(encoded,'base64');if(bytes.length<32)fail('SECRET_REQUIRED');return bytes;
}
const mac=(key,body)=>createHmac('sha256',key).update(body).digest();
const equal=(a,b)=>a.length===b.length&&timingSafeEqual(a,b);
export function sign(claims,key) {
 const h=Buffer.from(JSON.stringify({alg:'HS256',typ:'JWT'})).toString('base64url');
 const p=Buffer.from(JSON.stringify(claims)).toString('base64url');
 return h+'.'+p+'.'+mac(key,h+'.'+p).toString('base64url');
}
export function verify(token,key,{issuer,audience,clock,kind}) {
 try {
  if(typeof token!=='string'||token.length>4096)fail('AUTH_REQUIRED',401);
  const parts=token.split('.');if(parts.length!==3||parts.some(p=>!p||!/^[A-Za-z0-9_-]+$/.test(p)))fail('AUTH_REQUIRED',401);
  const [h,p,s]=parts,header=JSON.parse(Buffer.from(h,'base64url'));
  if(header.alg!=='HS256'||header.typ!=='JWT'||!equal(mac(key,h+'.'+p),Buffer.from(s,'base64url')))fail('AUTH_REQUIRED',401);
  const c=JSON.parse(Buffer.from(p,'base64url')),now=clock();
  if(c.iss!==issuer||c.aud!==audience||c.kind!==kind||!Number.isSafeInteger(c.exp)||c.exp<=now||!Number.isSafeInteger(c.iat)||c.iat>now||c.exp-c.iat>300||typeof c.sub!=='string'||!c.sub||c.sub.length>200)fail('AUTH_REQUIRED',401);
  if(kind==='session'&&(!/^[a-zA-Z0-9_-]{1,128}$/.test(c.sid||'')||!/^[a-zA-Z0-9_-]{1,128}$/.test(c.iid||'')||!Number.isSafeInteger(c.rv)||c.rv<1||!Array.isArray(c.scopes)||!c.scopes.includes('client:public')||c.scopes.some(s=>s!=='client:public')))fail('AUTH_REQUIRED',401);
  return c;
 } catch(e) {if(e.code==='AUTH_REQUIRED')throw e;fail('AUTH_REQUIRED',401);}
}
export function seal(payload,key) {const body=JSON.stringify(payload);return {body,mac:mac(key,body).toString('base64url')};}
export function unseal(envelope,key) {
 try {if(!envelope||typeof envelope.body!=='string'||typeof envelope.mac!=='string'||!equal(mac(key,envelope.body),Buffer.from(envelope.mac,'base64url')))fail('PROJECTION_UNAVAILABLE');return JSON.parse(envelope.body);}
 catch {fail('PROJECTION_UNAVAILABLE');}
}
export function checkSession(row,c,now) {
 if(!row||row.sid!==c.sid||row.uid!==c.sub||row.iid!==c.iid||row.roleVersion!==c.rv||row.expiresAt<=now||row.revoked||!row.scopes.includes('client:public'))fail('SESSION_REVOKED',403);
 return {uid:row.uid,sid:row.sid,iid:row.iid,roleVersion:row.roleVersion};
}
