// Assemble only the NEW GAS source; never push the old diary project source.
import {mkdirSync,readFileSync,writeFileSync,readdirSync} from 'node:fs';import {resolve} from 'node:path';import {createHash} from 'node:crypto';
const out=resolve(process.argv[2]||'build/alchemist');mkdirSync(out,{recursive:true});
const inputs=readdirSync('server/alchemist/src').filter(f=>f.endsWith('.js')).map(f=>['server/alchemist/src/'+f,f]);
inputs.push(['server/google_apps_script/vendor/jsrsasign.js','RsaVendor.js']);
const manifest={timeZone:'Etc/UTC',runtimeVersion:'V8',webapp:{executeAs:'USER_DEPLOYING',access:'ANYONE_ANONYMOUS'},dependencies:{enabledAdvancedServices:[{userSymbol:'Drive',version:'v3',serviceId:'drive'}]},oauthScopes:['https://www.googleapis.com/auth/drive','https://www.googleapis.com/auth/script.external_request']};
const hashes={};
const readiness=JSON.parse(readFileSync('server/alchemist/deployment-readiness.json','utf8'));

for(const [path,name] of inputs){let text=readFileSync(path,'utf8');if(name==='RsaVendor.js')text=text.replaceAll('SulfiRsa','AlchemistRsa');writeFileSync(resolve(out,name),text);hashes[name]=createHash('sha256').update(text).digest('hex');}
writeFileSync(resolve(out,'appsscript.json'),JSON.stringify(manifest,null,2)+'\n');
writeFileSync(resolve(out,'SOURCE_HASHES.json'),JSON.stringify({fullSourceReady:readiness.fullSourceVerified===true,files:hashes},null,2)+'\n');
console.log('GAS source assembled; source gate='+String(readiness.fullSourceVerified===true)+'; no cloud operations');
