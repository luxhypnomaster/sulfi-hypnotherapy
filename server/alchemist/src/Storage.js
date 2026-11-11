/* Private Drive tree bootstrap. Adapter methods must return permission readbacks. */
var AlchemistStorage=(function(){
  'use strict';
  var layout={
    '00_Система':['config','registry','indexes','grants','audit','backups'],
    '10_Дневник':['entries','images','audio','video','revisions'],
    '20_Библиотека':['audio_tracks','modules','templates','sessions','collections'],
    '30_Медиа':['covers','images','audio_other','video_other','immutable_blobs'],
    '40_Пакеты':['drafts','published','imports','archived'],
    '50_Каталог':['publications','index_shards','snapshots','tombstones'],
    '90_Техническое':['pending_uploads','quarantine','temp','gc_candidates']};
  function bootstrap(drive,registry,parent,owner){
    function verified(id,p){var f=drive.get(id);if(!f||f.mimeType!=='application/vnd.google-apps.folder'||(p&&f.parent!==p)||f.owner!==owner||!f.permissions||f.permissions.length!==1||f.permissions.some(function(x){return x.role!=='owner'||x.subject!==owner;}))throw new Error('UNSAFE_FOLDER_ACL');return f;}
    verified(parent,null);
    function ensure(key,name,p){
      var stored=registry.get(key),f;
      if(stored){f=verified(stored,p);if(f.name!==name)throw new Error('REGISTRY_NAME_MISMATCH');return f.id;}
      var found=drive.find(name,p);if(found.length>1)throw new Error('AMBIGUOUS_FOLDER');
      f=found.length?verified(found[0].id,p):drive.create(name,p);verified(f.id,p);registry.put(key,f.id);return f.id;
    }
    var root=ensure('root','Хранилище Сервера Проекта Алхимик',parent),result={root:root,schemaVersion:1,folders:{}};
    Object.keys(layout).forEach(function(name){var top=ensure(name,name,root);result.folders[name]=top;layout[name].forEach(function(child){result.folders[name+'/'+child]=ensure(name+'/'+child,child,top);});});
    return result;
  }
  return {bootstrap:bootstrap,layout:layout};
})();
