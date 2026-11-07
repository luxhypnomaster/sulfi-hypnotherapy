/* Sulfi diary backend. No private audio/session data is accepted by this API. */
var SulfiDiary = (function () {
  'use strict';
  function fault(status) { var e = new Error('Diary request failed'); e.diaryStatus = status; throw e; }
  function integer(value, fallback) {
    if (value === undefined || value === null || value === '') return fallback;
    if (!/^\d+$/.test(String(value))) fault(400);
    var n = Number(value);
    if (!Number.isSafeInteger(n) || n < 0) fault(400);
    return n;
  }
  function empty() { return {schemaVersion: 1, revision: 0, mutation: 0, nextNumber: 1, documents: {}}; }
  function clone(value) { return JSON.parse(JSON.stringify(value)); }
  function id(value) {
    if (typeof value !== 'string' || !/^[\w-]{1,128}$/.test(value) ||
        ['__proto__', 'prototype', 'constructor'].indexOf(value) >= 0) fault(400);
    return value;
  }
  function page(items, query, revision, kind) {
    var offset = 0, since = integer(query.since, 0);
    if (since > revision) fault(409);
    if (query.page) {
      var cursor;
      try { cursor = JSON.parse(Utilities.newBlob(Utilities.base64DecodeWebSafe(query.page)).getDataAsString()); }
      catch (_) { fault(400); }
      if (cursor.revision !== revision || cursor.since !== since || cursor.kind !== kind) fault(409);
      offset = integer(cursor.offset, -1);
      if (offset < 0 || offset >= items.length) fault(400);
    }
    var limit = Math.min(50, integer(query.limit, 50));
    if (limit < 1) fault(400);
    var slice = [], size = 0;
    while (offset + slice.length < items.length && slice.length < limit) {
      var next = items[offset + slice.length], bytes = JSON.stringify(next).length * 3;
      if (slice.length && size + bytes > 1400000) break;
      slice.push(next); size += bytes;
    }
    var end = offset + slice.length;
    return {items: slice, nextPage: end < items.length ? Utilities.base64EncodeWebSafe(JSON.stringify({
      revision: revision, since: since, offset: end, kind: kind
    })) : null};
  }
  function dispatch(method, route, query, body, token, store) {
    query = query || {};
    if (method === 'GET' && route === 'public/entries') {
      var state = store.read(), since = integer(query.since, 0);
      var changed = Object.keys(state.documents).sort().map(function (key) {
        var d = state.documents[key];
        return {id: key, entry: d.published, revision: d.changeRevision};
      }).filter(function (d) { return d.revision > since; });
      var result = page(changed, query, state.revision, 'public');
      return {entries: result.items.filter(function (d) { return d.entry !== null; }).map(function (d) {
        return clone(d.entry);
      }), removedIds: result.items.filter(function (d) { return d.entry === null; }).map(function (d) {
        return d.id;
      }), revision: String(state.revision), nextPage: result.nextPage};
    }
    // Authenticate BEFORE accessing private storage or returning author data.
    var actor = SulfiJwt.verify(token);
    if (method === 'GET' && route === 'author/me') {
      return {canPublish: true, expiresAt: new Date(actor.exp * 1000).toISOString()};
    }
    if (method === 'GET' && route === 'author/entries') {
      var privateState = store.read();
      var list = Object.keys(privateState.documents).sort().map(function (key) {
        return privateState.documents[key].working;
      });
      var authors = page(list, query, privateState.mutation, 'author');
      return {entries: authors.items.map(clone), nextPage: authors.nextPage};
    }
    var match = /^author\/entries\/([\w-]+)$/.exec(route);
    if (method !== 'PUT' || !match) fault(404);
    var key = id(match[1]), input = body && body.entry;
    if (!input || input.id !== key || typeof input.message !== 'string' || typeof input.body !== 'string' ||
        input.message.length > 1000 || input.body.length > 400000 ||
        !Number.isSafeInteger(body.expectedVersion) || body.expectedVersion < 0 ||
        (Object.prototype.hasOwnProperty.call(body, 'publish') && typeof body.publish !== 'boolean')) fault(400);
    if (body.publish === true && (!input.message.trim() || !input.body.trim())) fault(400);
    return store.write(function (state) {
      var existing = Object.prototype.hasOwnProperty.call(state.documents, key) ? state.documents[key] : null;
      if (body.expectedVersion !== (existing ? existing.working.version : 0)) fault(409);
      var now = new Date().toISOString();
      var working = {id: key, message: input.message, body: input.body,
        createdAt: existing ? existing.working.createdAt : now, updatedAt: now,
        publishedAt: existing ? existing.working.publishedAt : null,
        number: existing ? existing.working.number : state.nextNumber++,
        version: body.expectedVersion + 1, status: existing ? existing.working.status : 'draft'};
      var published = existing ? existing.published : null, changeRevision = existing ? existing.changeRevision : 0;
      if (body.publish === true) {
        working.status = 'published'; working.publishedAt = now; published = clone(working);
        changeRevision = ++state.revision;
      } else if (body.publish === false) {
        working.status = 'unpublished'; published = null; changeRevision = ++state.revision;
      }
      // A draft save NEVER overwrites the publicly readable snapshot.
      state.documents[key] = {working: working, published: published, changeRevision: changeRevision};
      state.mutation++;
      return {entry: clone(working)};
    });
  }
  return {dispatch: dispatch, fault: fault, empty: empty};
})();

function sulfiResponse(operation) {
  var envelope;
  try { envelope = {status: 200, data: operation()}; }
  catch (e) { envelope = {status: e.diaryStatus || 503, data: {error: 'Diary request failed'}}; }
  return ContentService.createTextOutput(JSON.stringify(envelope)).setMimeType(ContentService.MimeType.JSON);
}
function doGet(e) {
  return sulfiResponse(function () {
    if (!e || e.pathInfo !== 'public/entries') SulfiDiary.fault(404);
    return SulfiDiary.dispatch('GET', e.pathInfo, e.parameter, null, null, SulfiDriveStore);
  });
}
function doPost(e) {
  return sulfiResponse(function () {
    if (!e || !e.postData || e.postData.contents.length > 1500000) SulfiDiary.fault(400);
    var request;
    try { request = JSON.parse(e.postData.contents); } catch (_) { SulfiDiary.fault(400); }
    if (!request || typeof request.route !== 'string' || !/^author\//.test(request.route)) SulfiDiary.fault(404);
    return SulfiDiary.dispatch(request.method, request.route, request.query, request.body, request.token, SulfiDriveStore);
  });
}
