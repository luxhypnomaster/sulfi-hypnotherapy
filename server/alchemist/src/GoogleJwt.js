/* Signature verification only: jsrsasign is NOT used for randomness or signing. */
var AlchemistJwt = (function () {
  'use strict';
  function certificates(refresh) {
    var cache = CacheService.getScriptCache(), key = 'alchemist-google-certs-v1';
    var cached = refresh ? null : cache.get(key);
    if (cached) return JSON.parse(cached);
    var response = UrlFetchApp.fetch('https://www.googleapis.com/oauth2/v1/certs', {
      muteHttpExceptions: true, followRedirects: false, validateHttpsCertificates: true
    });
    if (response.getResponseCode() !== 200) AlchemistCatalog.fail(503,'AUTH_CERTIFICATES_UNAVAILABLE');
    var body = response.getContentText();
    if (body.length > 100000) AlchemistCatalog.fail(503,'AUTH_CERTIFICATES_UNAVAILABLE');
    var certs = JSON.parse(body);
    if (!certs || typeof certs !== 'object') AlchemistCatalog.fail(503,'AUTH_CERTIFICATES_UNAVAILABLE');
    cache.put(key, body, 1800);cache.put('alchemist-cert-refreshed-at',String(Date.now()),1800);
    return certs;
  }
  function verify(token, bootstrap) {
    var properties = PropertiesService.getScriptProperties();
    var webAudience=properties.getProperty('ALCHEMIST_GOOGLE_WEB_CLIENT_ID');
    // Native users must present the exact Web audience. CI identity is valid
    // only for the separately owner-bound bootstrap, not ordinary API calls.
    var audience = bootstrap ? [bootstrap.audience] : webAudience ? [webAudience] : JSON.parse(properties.getProperty('ALCHEMIST_GOOGLE_AUDIENCES')||'null');
    var owner = bootstrap ? bootstrap.ownerSubject : properties.getProperty('ALCHEMIST_OWNER_SUB');
    if (!Array.isArray(audience)||!audience.length||audience.some(function(a){return typeof a!=='string'||!/^[\w-]+\.apps\.googleusercontent\.com$/.test(a);}) || !owner) AlchemistCatalog.fail(503,'AUTH_CONFIGURATION_REQUIRED');
    if (typeof token !== 'string' || token.length > 16384 ||
        !/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(token)) AlchemistCatalog.fail(401);
    var header, claims;
    try {
      var parts = token.split('.');
      header = JSON.parse(AlchemistRsa.decode(parts[0]));
      claims = JSON.parse(AlchemistRsa.decode(parts[1]));
    } catch (_) { AlchemistCatalog.fail(401); }
    if (header.alg !== 'RS256' || typeof header.kid !== 'string' ||
        header.kid.length > 256 || header.crit !== undefined) AlchemistCatalog.fail(401);
    var certs = certificates(false);
    if (!Object.prototype.hasOwnProperty.call(certs, header.kid)) {var refreshed=Number(CacheService.getScriptCache().get('alchemist-cert-refreshed-at')||0);if(Date.now()-refreshed<60000)AlchemistCatalog.fail(401,'UNKNOWN_KEY_ID');certs = certificates(true);}
    var cert = Object.prototype.hasOwnProperty.call(certs, header.kid) ? certs[header.kid] : null;
    if (typeof cert !== 'string') AlchemistCatalog.fail(401);
    try {
      if (!AlchemistRsa.verify(token, cert)) AlchemistCatalog.fail(401);
    } catch (_) { AlchemistCatalog.fail(401); }
    var now = Math.floor(Date.now() / 1000);
    if (audience.indexOf(claims.aud)<0) AlchemistCatalog.fail(401,'TOKEN_AUDIENCE_INVALID');
    if (Number.isInteger(claims.exp) && claims.exp<=now) AlchemistCatalog.fail(401,'TOKEN_EXPIRED');
    if (['accounts.google.com','https://accounts.google.com'].indexOf(claims.iss)<0) AlchemistCatalog.fail(401,'TOKEN_ISSUER_INVALID');
    if (['accounts.google.com', 'https://accounts.google.com'].indexOf(claims.iss) < 0 ||
        audience.indexOf(claims.aud)<0 || typeof claims.sub !== 'string' || !/^[a-zA-Z0-9_-]{1,256}$/.test(claims.sub) || ['constructor','prototype','__proto__'].indexOf(claims.sub)>=0 ||
        !Number.isInteger(claims.exp) || !Number.isInteger(claims.iat) ||
        claims.exp <= now || claims.iat > now + 60 || claims.exp <= claims.iat ||
        claims.exp - claims.iat > 3700 ||
        (claims.nbf !== undefined && (!Number.isInteger(claims.nbf) || claims.nbf > now)) ||
        claims.email_verified !== true || typeof claims.email !== 'string') AlchemistCatalog.fail(401);
    // Identity is verified above. Authority comes only from server-side subjects.
    if(bootstrap){claims.roles=claims.sub===owner?['owner']:['client'];return claims;}
    var authConfig=JSON.parse(properties.getProperty('ALCHEMIST_AUTH_CONFIG')||'null');
    var revoked=authConfig?authConfig.revoked:JSON.parse(properties.getProperty('ALCHEMIST_REVOKED_SUBJECTS')||'{}');
    if(Object.prototype.hasOwnProperty.call(revoked,claims.sub)&&revoked[claims.sub]===true)AlchemistCatalog.fail(401,'IDENTITY_REVOKED');
    // 16-A: one immutable master. Legacy grant data remains stored, but cannot
    // promote another subject. Every other valid identity is automatically CLIENT.
    claims.role=claims.sub===owner?'MASTER':'CLIENT';
    claims.roles=claims.sub===owner?['owner']:['client'];
    return claims;
  }
  return {verify: verify};
})();
