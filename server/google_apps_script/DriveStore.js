var SulfiDriveStore = (function () {
  'use strict';
  var name = 'sulfi-diary-state-v1.json';
  function file() {
    var folderId = PropertiesService.getScriptProperties().getProperty('SULFI_DIARY_FOLDER_ID');
    if (!folderId) SulfiDiary.fault(503);
    var folder = DriveApp.getFolderById(folderId);
    if (folder.getSharingAccess() !== DriveApp.Access.PRIVATE ||
        folder.getEditors().length || folder.getViewers().length) SulfiDiary.fault(503);
    var files = folder.getFilesByName(name), found = files.hasNext() ? files.next() : null;
    if (files.hasNext()) SulfiDiary.fault(503);
    if (found && (found.getSharingAccess() !== DriveApp.Access.PRIVATE ||
        found.getEditors().length || found.getViewers().length)) SulfiDiary.fault(503);
    return {folder: folder, file: found};
  }
  function readFile(found) {
    if (!found) return SulfiDiary.empty();
    if (found.getSize() > 2000000) SulfiDiary.fault(503);
    var state = JSON.parse(found.getBlob().getDataAsString('UTF-8'));
    if (state.schemaVersion !== 1 || !Number.isSafeInteger(state.revision) ||
        !Number.isSafeInteger(state.mutation) || !state.documents) SulfiDiary.fault(503);
    return state;
  }
  return {
    read: function () { return readFile(file().file); },
    write: function (operation) {
      var lock = LockService.getScriptLock();
      if (!lock.tryLock(10000)) SulfiDiary.fault(503);
      try {
        var target = file(), state = readFile(target.file), result = operation(state);
        var serialized = JSON.stringify(state);
        if (Utilities.newBlob(serialized).getBytes().length > 2000000) SulfiDiary.fault(413);
        if (target.file) target.file.setContent(serialized);
        else target.folder.createFile(name, serialized, 'application/json');
        return result;
      } finally { lock.releaseLock(); }
    }
  };
})();
