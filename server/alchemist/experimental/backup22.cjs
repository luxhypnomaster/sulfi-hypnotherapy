'use strict';
const crypto=require('node:crypto'),fs=require('node:fs'),path=require('node:path');
const {digest22,canonical22,fail}=require('./project_store22.cjs');
const groups=['database','identity','roles','grants','catalog','diary','revisions','assets','indexes','config'];
function verifyBundle(b){if(b?.schemaVersion!==1||!b.groups||!Array.isArray(b.files))fail(422,'BACKUP_SCHEMA');for(const g of groups)if(!Object.hasOwn(b.groups,g))fail(422,'INCOMPLETE_BACKUP');
 const seen=new Set();for(const f of b.files){if(typeof f.path!=='string'||!f.path||f.path.startsWith('/')||f.path.split(/[\\/]/).includes('..')||seen.has(f.path))fail(422,'UNSAFE_BACKUP_PATH');seen.add(f.path);const data=Buffer.from(f.base64,'base64');if(data.length!==f.bytes||crypto.createHash('sha256').update(data).digest('hex')!==f.sha256)fail(422,'BACKUP_FILE_HASH');}
 if(digest22({groups:b.groups,files:b.files.map(({base64,...v})=>v)})!==b.manifestHash)fail(422,'BACKUP_MANIFEST_HASH');return b;
}
function pack(values,files){const b={schemaVersion:1,groups:values,files:files.map(f=>({path:f.path,bytes:f.bytes.length,sha256:crypto.createHash('sha256').update(f.bytes).digest('hex'),base64:f.bytes.toString('base64')}))};b.manifestHash=digest22({groups:b.groups,files:b.files.map(({base64,...v})=>v)});return verifyBundle(b);}
function encrypt(bundle,key){verifyBundle(bundle);if(!Buffer.isBuffer(key)||key.length!==32)fail(422,'BACKUP_KEY_REQUIRED');const iv=crypto.randomBytes(12),cipher=crypto.createCipheriv('aes-256-gcm',key,iv);cipher.setAAD(Buffer.from('ALCHEMIC-BACKUP-1'));return Buffer.concat([Buffer.from('ALCBK1'),iv,...seal(cipher,bundle)]);}
function seal(cipher,bundle){const data=Buffer.concat([cipher.update(canonical22(bundle),'utf8'),cipher.final()]);return [cipher.getAuthTag(),data];}
function decrypt(bytes,key){if(bytes.subarray(0,6).toString()!=='ALCBK1')fail(422,'BACKUP_FORMAT');try{const c=crypto.createDecipheriv('aes-256-gcm',key,bytes.subarray(6,18));c.setAAD(Buffer.from('ALCHEMIC-BACKUP-1'));c.setAuthTag(bytes.subarray(18,34));return verifyBundle(JSON.parse(Buffer.concat([c.update(bytes.subarray(34)),c.final()]).toString('utf8')));}catch(_){fail(422,'BACKUP_AUTH_OR_INTEGRITY');}}
async function verifiedPrivateBackup(bundle,key,destination,{restoreVerifier}={}){
 if(destination?.privateVerified!==true)fail(403,'PRIVATE_BACKUP_DESTINATION_REQUIRED');
 const bytes=encrypt(bundle,key),sha256=crypto.createHash('sha256').update(bytes).digest('hex');
 const receipt=await destination.put(bytes,{sha256,bytes:bytes.length}),read=await destination.read(receipt);
 if(crypto.createHash('sha256').update(read).digest('hex')!==sha256)fail(422,'BACKUP_READBACK_MISMATCH');
 const restored=decrypt(read,key);let proof=null;
 if(restoreVerifier){proof=await restoreVerifier(read,key);if(proof?.databaseVerified!==true||proof.manifestHash!==restored.manifestHash||proof.filesVerified!==restored.files.length)fail(422,'RESTORE_PROOF_REQUIRED');}
 return {...receipt,sha256,bytes:bytes.length,uploaded:true,integrityVerified:true,restoreVerified:proof!==null,manifestHash:restored.manifestHash,...(proof?{restoreProof:{manifestHash:proof.manifestHash,filesVerified:proof.filesVerified,databaseVerified:true}}:{})};
}
function restoreIsolated(bytes,key,root){const b=decrypt(bytes,key);if(fs.existsSync(root))fail(409,'RESTORE_DESTINATION_EXISTS');fs.mkdirSync(root,{recursive:true,mode:0o700});try{for(const f of b.files){const out=path.join(root,f.path);fs.mkdirSync(path.dirname(out),{recursive:true,mode:0o700});fs.writeFileSync(out,Buffer.from(f.base64,'base64'),{mode:0o600,flag:'wx'});if(crypto.createHash('sha256').update(fs.readFileSync(out)).digest('hex')!==f.sha256)fail(422,'RESTORE_FILE_READBACK');}fs.writeFileSync(path.join(root,'RESTORED_METADATA.json'),canonical22(b.groups),{mode:0o600,flag:'wx'});return {manifestHash:b.manifestHash,files:b.files.length,restored:true};}catch(_){fail(503,'ISOLATED_RESTORE_INCOMPLETE');}}
function captureCandidate(base,store,media=[]){
 let snapshot,values,descriptors;base.db.exec('BEGIN DEFERRED');try{
  const schema=base.db.prepare("SELECT type,name,sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' ORDER BY type,name").all();
  const tables=schema.filter(r=>r.type==='table').map(r=>{if(!/^[A-Za-z0-9_]+$/.test(r.name))fail(422,'BACKUP_TABLE_NAME');return {name:r.name,rows:base.db.prepare('SELECT * FROM '+r.name).all()};});snapshot={schema,tables};
  const records=base.records(),old=store.list('catalog-revisions').map(r=>r.value),historical=base.db.prepare('SELECT payload FROM immutable').all().flatMap(r=>JSON.parse(r.payload).items||[]),seen=new Set();
  descriptors=[...records,...old,...historical].filter(r=>{const key=[r.contentId,r.revisionId,r.sha256].join(':');if(!(r.byteLength>0)||seen.has(key))return false;seen.add(key);return true;});
  values={database:snapshot,identity:store.list('identities'),roles:store.list('roles'),grants:store.list('governance'),catalog:records,diary:records.filter(r=>r.type==='diaryEntry'),revisions:old,assets:descriptors.map(r=>({contentId:r.contentId,revisionId:r.revisionId,sha256:r.sha256,bytes:r.byteLength})),indexes:store.list('rating-targets'),config:store.list('ratings')};base.db.exec('COMMIT');
 }catch(e){base.db.exec('ROLLBACK');throw e;}
 const files=[],hashes=new Set();for(const r of descriptors){const m=media.find(m=>m.contentId===r.contentId&&m.revisionId===r.revisionId);if(!m)fail(422,'BACKUP_MISSING_MEDIA');const bytes=fs.readFileSync(m.path);if(bytes.length!==r.byteLength||crypto.createHash('sha256').update(bytes).digest('hex')!==r.sha256)fail(422,'BACKUP_MEDIA_SOURCE_HASH');if(!hashes.has(r.sha256)){files.push({path:'media/'+r.sha256,bytes});hashes.add(r.sha256);}}
 files.push({path:'database/snapshot.json',bytes:Buffer.from(canonical22(snapshot))});return pack(values,files);
}
function restoreDatabaseIsolated(bytes,key,root){
 const b=decrypt(bytes,key),snapshot=b.groups.database;if(!Array.isArray(snapshot.schema)||!Array.isArray(snapshot.tables))fail(422,'BACKUP_DATABASE_SCHEMA');
 const result=restoreIsolated(bytes,key,root),{DatabaseSync}=require('node:sqlite'),out=path.join(root,'RESTORED.sqlite'),db=new DatabaseSync(out);
 try{db.exec('BEGIN IMMEDIATE');for(const s of snapshot.schema.filter(s=>s.type==='table')){if(!/^[A-Za-z0-9_]+$/.test(s.name)||!s.sql.startsWith('CREATE TABLE'))fail(422,'BACKUP_DATABASE_SCHEMA');db.exec(s.sql);}
  for(const table of snapshot.tables){if(!/^[A-Za-z0-9_]+$/.test(table.name))fail(422,'BACKUP_TABLE_NAME');for(const row of table.rows){const names=Object.keys(row);if(names.some(n=>!/^[A-Za-z0-9_]+$/.test(n)))fail(422,'BACKUP_COLUMN_NAME');db.prepare('INSERT INTO '+table.name+'('+names.join(',')+') VALUES('+names.map(()=>'?').join(',')+')').run(...names.map(n=>row[n]));}}
  for(const s of snapshot.schema.filter(s=>s.type==='index'||s.type==='trigger'))db.exec(s.sql);db.exec('COMMIT');if(db.prepare('PRAGMA integrity_check').get().integrity_check!=='ok')fail(422,'RESTORE_INTEGRITY');fs.chmodSync(out,0o600);return {...result,databaseVerified:true,filesVerified:b.files.length,path:out};
 }catch(e){try{db.exec('ROLLBACK');}catch(_){}throw e;}finally{db.close();}
}
module.exports={groups,pack,encrypt,decrypt,verifiedPrivateBackup,restoreIsolated,captureCandidate,restoreDatabaseIsolated};
