/* Signature verification only: jsrsasign is NOT used for randomness or signing. */
var SulfiJwt = (function () {
  'use strict';
  function certificates(refresh) {
    var cache = CacheService.getScriptCache(), key = 'sulfi-google-certs-v1';
    var cached = refresh ? null : cache.get(key);
    if (cached) return JSON.parse(cached);
    var response = UrlFetchApp.fetch('https://www.googleapis.com/oauth2/v1/certs', {
      muteHttpExceptions: true, followRedirects: false, validateHttpsCertificates: true
    });
    if (response.getResponseCode() !== 200) SulfiDiary.fault(503);
    var body = response.getContentText();
    if (body.length > 100000) SulfiDiary.fault(503);
    var certs = JSON.parse(body);
    if (!certs || typeof certs !== 'object') SulfiDiary.fault(503);
    cache.put(key, body, 1800);
    return certs;
  }
  function verify(token) {
    var properties = PropertiesService.getScriptProperties();
    var audience = properties.getProperty('SULFI_GOOGLE_WEB_CLIENT_ID');
    var owner = properties.getProperty('SULFI_AUTHOR_EMAIL');
    if (!audience || !/^[\w-]+\.apps\.googleusercontent\.com$/.test(audience) || !owner) SulfiDiary.fault(503);
    if (typeof token !== 'string' || token.length > 16384 ||
        !/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(token)) SulfiDiary.fault(401);
    var header, claims;
    try {
      var parts = token.split('.');
      header = JSON.parse(SulfiRsa.decode(parts[0]));
      claims = JSON.parse(SulfiRsa.decode(parts[1]));
    } catch (_) { SulfiDiary.fault(401); }
    if (header.alg !== 'RS256' || typeof header.kid !== 'string' ||
        header.kid.length > 256 || header.crit !== undefined) SulfiDiary.fault(401);
    var certs = certificates(false);
    if (!Object.prototype.hasOwnProperty.call(certs, header.kid)) certs = certificates(true);
    var cert = Object.prototype.hasOwnProperty.call(certs, header.kid) ? certs[header.kid] : null;
    if (typeof cert !== 'string') SulfiDiary.fault(401);
    try {
      if (!SulfiRsa.verify(token, cert)) SulfiDiary.fault(401);
    } catch (_) { SulfiDiary.fault(401); }
    var now = Math.floor(Date.now() / 1000);
    if (['accounts.google.com', 'https://accounts.google.com'].indexOf(claims.iss) < 0 ||
        claims.aud !== audience || typeof claims.sub !== 'string' || !claims.sub ||
        !Number.isInteger(claims.exp) || !Number.isInteger(claims.iat) ||
        claims.exp <= now || claims.iat > now + 60 || claims.exp <= claims.iat ||
        claims.exp - claims.iat > 3700 ||
        (claims.nbf !== undefined && (!Number.isInteger(claims.nbf) || claims.nbf > now)) ||
        claims.email_verified !== true || typeof claims.email !== 'string') SulfiDiary.fault(401);
    if (claims.email.toLowerCase() !== owner.toLowerCase()) SulfiDiary.fault(403);
    return claims;
  }
  return {verify: verify};
})();
