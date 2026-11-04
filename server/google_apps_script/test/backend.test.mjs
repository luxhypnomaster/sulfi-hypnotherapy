import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import {generateKeyPairSync, sign} from 'node:crypto';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = new URL('../', import.meta.url);
const {privateKey, publicKey} = generateKeyPairSync('rsa', {modulusLength: 2048});
const pem = publicKey.export({type: 'spki', format: 'pem'});
const owner = 'luxhypnomaster@gmail.com', audience = 'test-client.apps.googleusercontent.com';
const plain = v => JSON.parse(JSON.stringify(v));
const encode = v => Buffer.from(typeof v === 'string' ? v : JSON.stringify(v)).toString('base64url');
function jwt(overrides = {}, header = {}) {
  const now = Math.floor(Date.now() / 1000);
  const input = encode({alg: 'RS256', kid: 'current-key', ...header}) + '.' + encode({
    iss: 'https://accounts.google.com', aud: audience, sub: '123', email: owner,
    email_verified: true, iat: now, exp: now + 3600, ...overrides,
  });
  return input + '.' + sign('RSA-SHA256', Buffer.from(input), privateKey).toString('base64url');
}
function harness() {
  const cache = new Map(), properties = new Map([
    ['SULFI_GOOGLE_WEB_CLIENT_ID', audience], ['SULFI_AUTHOR_EMAIL', owner],
  ]);
  let fetches = 0, state, reads = 0;
  const context = vm.createContext({
    PropertiesService: {getScriptProperties: () => ({getProperty: k => properties.get(k)})},
    CacheService: {getScriptCache: () => ({get: k => cache.get(k), put: (k, v) => cache.set(k, v)})},
    UrlFetchApp: {fetch: (url, options) => {
      fetches++; assert.equal(url, 'https://www.googleapis.com/oauth2/v1/certs');
      assert.equal(options.followRedirects, false);
      return {getResponseCode: () => 200, getContentText: () => JSON.stringify({'current-key': pem})};
    }},
    Utilities: {
      base64EncodeWebSafe: encode,
      base64DecodeWebSafe: v => Buffer.from(v, 'base64url'),
      newBlob: v => ({getDataAsString: () => Buffer.from(v).toString('utf8'), getBytes: () => [...Buffer.from(v)]}),
    },
    ContentService: {MimeType: {JSON: 'application/json'}, createTextOutput: v => ({
      setMimeType: () => JSON.parse(v),
    })},
  });
  for (const file of ['vendor/jsrsasign.js', 'Code.js', 'GoogleJwt.js', 'DriveStore.js']) {
    vm.runInContext(readFileSync(new URL(file, root), 'utf8'), context, {filename: file});
  }
  state = plain(context.SulfiDiary.empty());
  const driveStore = context.SulfiDriveStore;
  const store = {
    read: () => { reads++; return plain(state); },
    write: operation => {
      const candidate = plain(state), result = operation(candidate);
      state = candidate; return plain(result);
    },
  };
  context.SulfiDriveStore = store;
  return {context, properties, cache, store, driveStore,
    get state() {return plain(state);}, get reads() {return reads;}, get fetches() {return fetches;},
    call: (method, route, body, token = jwt(), query = {}) => plain(
      context.SulfiDiary.dispatch(method, route, query, body, token, store)),
    post: request => context.doPost({postData: {contents: JSON.stringify(request)}}),
  };
}
const input = (id, version = 0, publish, text = 'Текст Сульфи') => ({
  expectedVersion: version, entry: {id, version, message: 'Послание', body: text},
  ...(publish === undefined ? {} : {publish}),
});
const status = (fn, code) => assert.throws(fn, error => error.diaryStatus === code);

test('real RSA signature verification accepts the configured Google issuer/audience/owner', () => {
  const h = harness();
  assert.equal(h.context.SulfiJwt.verify(jwt()).email, owner);
  h.context.SulfiJwt.verify(jwt());
  assert.equal(h.fetches, 1, 'certificates are cached');
});
for (const [label, claims, header, code] of [
  ['other owner', {email: 'reader@example.test'}, {}, 403],
  ['unverified email', {email_verified: false}, {}, 401],
  ['other audience', {aud: 'other-client'}, {}, 401],
  ['array audience', {aud: [audience]}, {}, 401],
  ['other issuer', {iss: 'https://attacker.test'}, {}, 401],
  ['expired token', {exp: Math.floor(Date.now() / 1000) - 1}, {}, 401],
  ['missing iat', {iat: null}, {}, 401],
  ['future iat', {iat: Math.floor(Date.now() / 1000) + 120}, {}, 401],
  ['future nbf', {nbf: Math.floor(Date.now() / 1000) + 120}, {}, 401],
  ['wrong algorithm', {}, {alg: 'HS256'}, 401],
  ['unrecognized critical header', {}, {crit: ['private']}, 401],
  ['unknown key', {}, {kid: 'unknown'}, 401],
]) test('authentication rejects ' + label, () => {
  const h = harness();
  status(() => h.context.SulfiJwt.verify(jwt(claims, header)), code);
});
test('a modified token is rejected even with plausible claims and matching kid', () => {
  const h = harness(), token = jwt(), parts = token.split('.');
  const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString());
  payload.sub = 'forged'; parts[1] = encode(payload);
  status(() => h.context.SulfiJwt.verify(parts.join('.')), 401);
});
test('missing server configuration fails closed', () => {
  const h = harness(); h.properties.delete('SULFI_GOOGLE_WEB_CLIENT_ID');
  status(() => h.call('GET', 'author/me'), 503);
});
test('anonymous GET exposes only the public route; private calls authenticate before reading storage', () => {
  const h = harness();
  assert.equal(h.context.doGet({pathInfo: 'author/entries'}).status, 404);
  const denied = h.post({method: 'GET', route: 'author/entries', token: 'invalid'});
  assert.equal(denied.status, 401); assert.equal(h.reads, 0);
  assert.equal(JSON.stringify(denied).includes('invalid'), false);
});
test('draft → publish → edit draft → unpublish preserves private content and increments revisions', () => {
  const h = harness();
  const draft = h.call('PUT', 'author/entries/post-1', input('post-1')).entry;
  assert.equal(draft.status, 'draft'); assert.equal(draft.version, 1);
  assert.equal(h.state.revision, 0);
  assert.deepEqual(h.call('GET', 'public/entries', null, null).entries, []);
  const publication = h.call('PUT', 'author/entries/post-1', input('post-1', 1, true)).entry;
  assert.equal(publication.number, 1); assert.equal(publication.version, 2);
  const edited = h.call('PUT', 'author/entries/post-1', input('post-1', 2, undefined, 'Приватные правки')).entry;
  assert.equal(edited.version, 3); assert.equal(h.state.revision, 1);
  assert.equal(h.call('GET', 'public/entries', null, null).entries[0].body, 'Текст Сульфи');
  const unpublish = h.call('PUT', 'author/entries/post-1', input('post-1', 3, false, 'Приватные правки')).entry;
  assert.equal(unpublish.status, 'unpublished');
  const feed = h.call('GET', 'public/entries', null, null, {since: '1'});
  assert.deepEqual(feed.entries, []); assert.deepEqual(feed.removedIds, ['post-1']);
  assert.equal(feed.revision, '2');
  assert.equal(h.call('GET', 'author/entries').entries[0].body, 'Приватные правки');
});
test('optimistic version conflicts preserve existing state; client timestamps/status/number are ignored', () => {
  const h = harness(), body = input('stable', 0, true);
  body.entry.number = 999; body.entry.status = 'unpublished'; body.entry.createdAt = '1900-01-01';
  const result = h.call('PUT', 'author/entries/stable', body).entry;
  assert.equal(result.number, 1); assert.equal(result.status, 'published');
  assert.notEqual(result.createdAt, '1900-01-01');
  const before = h.state;
  status(() => h.call('PUT', 'author/entries/stable', body), 409);
  assert.deepEqual(h.state, before);
});
test('pagination is stable; mid-sync publication rejects old cursors; future since is rejected', () => {
  const h = harness();
  for (const id of ['a', 'b', 'c']) h.call('PUT', 'author/entries/' + id, input(id, 0, true));
  const first = h.call('GET', 'public/entries', null, null, {limit: '2'});
  assert.equal(first.entries.length, 2); assert.ok(first.nextPage);
  const second = h.call('GET', 'public/entries', null, null, {limit: '2', page: first.nextPage});
  assert.deepEqual([...first.entries, ...second.entries].map(v => v.id), ['a', 'b', 'c']);
  h.call('PUT', 'author/entries/b', input('b', 1, false));
  status(() => h.call('GET', 'public/entries', null, null, {page: first.nextPage}), 409);
  status(() => h.call('GET', 'public/entries', null, null, {since: '999'}), 409);
});
test('malformed IDs, wrong entry ID, oversized bodies and non-boolean publish are rejected', () => {
  const h = harness();
  for (const id of ['constructor', '__proto__']) status(() => h.call('PUT', 'author/entries/' + id, input(id)), 400);
  status(() => h.call('PUT', 'author/entries/a', input('b')), 400);
  status(() => h.call('PUT', 'author/entries/a', input('a', 0, true, 'x'.repeat(400001))), 400);
  status(() => h.call('PUT', 'author/entries/a', {...input('a'), publish: 'true'}), 400);
  assert.equal(h.state.mutation, 0);
});
test('HTTP envelopes carry logical errors without leaking tokens or private text', () => {
  const h = harness(), token = jwt({email: 'other@example.test'});
  const response = h.post({method: 'PUT', route: 'author/entries/a', token, body: input('a')});
  assert.equal(response.status, 403);
  assert.equal(JSON.stringify(response).includes(token), false);
  assert.equal(JSON.stringify(response).includes('Текст Сульфи'), false);
});

function driveFixture(h) {
  const files = []; let shared = false, releases = 0, creates = 0;
  const file = text => ({text,
    getSharingAccess: () => 'PRIVATE', getEditors: () => [], getViewers: () => [],
    getSize() {return Buffer.byteLength(this.text);},
    getBlob() {return {getDataAsString: () => this.text};},
    setContent(value) {this.text = value;},
  });
  const folder = {
    getSharingAccess: () => shared ? 'ANYONE' : 'PRIVATE',
    getEditors: () => [], getViewers: () => [],
    getFilesByName: name => {
      assert.equal(name, 'sulfi-diary-state-v1.json'); let index = 0;
      return {hasNext: () => index < files.length, next: () => files[index++]};
    },
    createFile: (name, text, mime) => {
      assert.equal(mime, 'application/json'); files.push(file(text)); creates++;
    },
  };
  h.properties.set('SULFI_DIARY_FOLDER_ID', 'private-diary-folder');
  h.context.DriveApp = {Access: {PRIVATE: 'PRIVATE'}, getFolderById: id => {
    assert.equal(id, 'private-diary-folder'); return folder;
  }};
  h.context.LockService = {getScriptLock: () => ({tryLock: () => true, releaseLock: () => releases++})};
  h.context.SulfiDriveStore = h.driveStore;
  return {files, file, get releases() {return releases;}, get creates() {return creates;},
    share: () => {shared = true;}};
}
test('Drive store: anonymous feed does not create files; authenticated writes persist under a lock', () => {
  const h = harness(), drive = driveFixture(h);
  assert.deepEqual(h.context.doGet({pathInfo: 'public/entries', parameter: {}}).data.entries, []);
  assert.equal(drive.creates, 0);
  const request = {method: 'PUT', route: 'author/entries/a', token: jwt(), body: input('a')};
  assert.equal(h.post(request).status, 200); assert.equal(drive.creates, 1);
  const saved = drive.files[0].text;
  assert.equal(JSON.parse(saved).documents.a.working.body, 'Текст Сульфи');
  assert.equal(h.post(request).status, 409);
  assert.equal(drive.files[0].text, saved); assert.equal(drive.releases, 2);
});
test('Drive store refuses shared folders, duplicate state files and corrupt state without resetting data', () => {
  const h = harness(), drive = driveFixture(h);
  drive.share();
  assert.equal(h.context.doGet({pathInfo: 'public/entries', parameter: {}}).status, 503);
  assert.equal(drive.creates, 0);
  const other = harness(), duplicate = driveFixture(other);
  duplicate.files.push(duplicate.file('{}'), duplicate.file('{}'));
  status(() => other.driveStore.read(), 503);
  assert.equal(duplicate.files.length, 2);
  duplicate.files.pop();
  status(() => other.driveStore.read(), 503);
  assert.equal(duplicate.files[0].text, '{}');
});
