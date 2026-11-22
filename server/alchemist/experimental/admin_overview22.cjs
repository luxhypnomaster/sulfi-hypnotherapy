'use strict';
// Derived cache only; actual records/jobs/feedback remain authoritative. Reads
// never scan all content when no relevant committed data has changed.
function overviewCache22(db,store){
 db.exec(`CREATE TABLE IF NOT EXISTS t22_overview_version(id INTEGER PRIMARY KEY CHECK(id=1),revision INTEGER NOT NULL);
 INSERT OR IGNORE INTO t22_overview_version VALUES(1,0);`);
 for(const table of ['records','t22_feedback'])for(const event of ['INSERT','UPDATE','DELETE']){
  const changed=event==='UPDATE'&&table==='records'?'WHEN old.payload IS NOT new.payload':'';
  db.exec(`CREATE TRIGGER IF NOT EXISTS t22_overview_${table}_${event} AFTER ${event} ON ${table} ${changed} BEGIN UPDATE t22_overview_version SET revision=revision+1 WHERE id=1;END;`);
 }
 for(const event of ['INSERT','UPDATE','DELETE']){
  const value=event==='DELETE'?'old':'new',changed=event==='UPDATE'?' AND old.payload IS NOT new.payload':'';
  db.exec(`CREATE TRIGGER IF NOT EXISTS t22_overview_values_${event} AFTER ${event} ON t22_values WHEN ${value}.ns IN ('jobs','incidents','identities','roles','backups','rating-cache')${changed} BEGIN UPDATE t22_overview_version SET revision=revision+1 WHERE id=1;END;`);
 }
 return (actor,compute)=>{
  const revision=db.prepare('SELECT revision FROM t22_overview_version WHERE id=1').get().revision,cached=store.get('overview-cache','current');
  if(cached?.revision===revision)return {...cached.value,scope:'admin:'+actor.uid};
  const value=compute();store.set('overview-cache','current',{revision,value});return value;
 };
}
module.exports={overviewCache22};
