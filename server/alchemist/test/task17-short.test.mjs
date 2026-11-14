// Candidate server diff only. No deployment, Google identity or live Drive.
import {test} from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';

test('17 short message publishes without invented blocks/CTA; empty, unauthorized and private cases stay protected', () => {
  const c=vm.createContext({});
  for(const f of ['Catalog','AtomicStore','Diary']) vm.runInContext(readFileSync(new URL('../src/'+f+'.js',import.meta.url),'utf8'),c);
  let head=null,n=0; const files=new Map();
  const io={head:()=>head,read:k=>structuredClone(files.get(k)),writeVerified:v=>{const k=String(++n);files.set(k,structuredClone(v));return k;},setHead:k=>head=k,digest:s=>createHash('sha256').update(s).digest('hex')};
  const store=c.AlchemistAtomicStore.create(io);
  const core=c.AlchemistCatalog.create({store,lock:f=>f(),now:()=>new Date(0).toISOString(),digest:v=>io.digest(JSON.stringify(v)),canReadAsset:()=>true,validatePublication:()=>{},encodeCursor:JSON.stringify,decodeCursor:JSON.parse});
  const diary=c.AlchemistDiary.create(core,store,{uuid:()=>String(++n),now:()=>new Date(0).toISOString()});
  const owner={sub:'owner',roles:['owner']},client={sub:'client',roles:['client']};
  const entry={id:'short17',title:'Заголовок',message:'Добавь себе в библиотеку',blocks:[]};
  diary.execute('entry.createDraft',owner,{requestId:'create',entry,visibility:'public'});
  assert.equal(diary.execute('feed.list',null,{}).entries.length,0);
  assert.throws(()=>diary.execute('entry.publish',client,{entryId:entry.id,requestId:'bad',ifMatch:'1'}),/AUTHOR_REQUIRED/);
  const published=diary.execute('entry.publish',owner,{entryId:entry.id,requestId:'publish',ifMatch:'1'});
  assert.equal(published.entry.status,'published');
  assert.equal(published.entry.message,entry.message);
  assert.equal(published.entry.blocks.length,0);
  assert.equal(published.entry.contentLinks.length,0);
  assert.equal(diary.execute('entry.publish',owner,{entryId:entry.id,requestId:'publish',ifMatch:'1'}).etag,published.etag);
  const feed=diary.execute('feed.list',client,{}).entries;
  assert.equal(feed.length,1);assert.equal(feed[0].entry.message,entry.message);
  diary.execute('entry.createDraft',owner,{requestId:'empty',entry:{...entry,id:'empty17',message:'  '},visibility:'public'});
  assert.throws(()=>diary.execute('entry.publish',owner,{entryId:'empty17',requestId:'empty-pub',ifMatch:'1'}),/EMPTY_ENTRY/);
  diary.execute('entry.createDraft',owner,{requestId:'private',entry:{...entry,id:'private17'},visibility:'private'});
  diary.execute('entry.publish',owner,{entryId:'private17',requestId:'private-pub',ifMatch:'1'});
  assert.equal(diary.execute('feed.list',client,{}).entries.length,1);
});
