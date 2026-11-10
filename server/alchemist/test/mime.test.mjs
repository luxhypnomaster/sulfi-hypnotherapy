import {test} from 'node:test';import assert from 'node:assert/strict';import vm from 'node:vm';import {readFileSync} from 'node:fs';
const c=vm.createContext({});vm.runInContext(readFileSync(new URL('../src/Mime.js',import.meta.url),'utf8'),c);
test('actual container magic allowlist rejects MIME spoof, executable, truncated image and wrong container',()=>{
 const cases=[['image/png',[137,80,78,71,13,10,26,10]],['image/jpeg',[255,216,255]],['image/webp',Buffer.from('RIFFxxxxWEBP')],['audio/wav',Buffer.from('RIFFxxxxWAVE')],['audio/mpeg',Buffer.from('ID3 fixture')],['audio/aac',[255,241,80]],['audio/ogg',Buffer.from('OggS')],['audio/mp4',Buffer.from('xxxxftyp')],['video/mp4',Buffer.from('xxxxftyp')],['video/quicktime',Buffer.from('xxxxftyp')],['video/webm',[26,69,223,163]],['application/zip',[80,75,3,4]]];
 for(const [mime,bytes]of cases){assert.equal(c.AlchemistMime.matches(mime,Array.from(bytes)),true,mime);assert.equal(c.AlchemistMime.matches(mime,Array.from(Buffer.from('MZ executable'))),false,mime);assert.equal(c.AlchemistMime.matches(mime,[]),false,mime);}
 assert.equal(c.AlchemistMime.matches('image/png',[137,80]),false);assert.equal(c.AlchemistMime.matches('image/webp',Array.from(Buffer.from('RIFFxxxxWAVE'))),false);
});
