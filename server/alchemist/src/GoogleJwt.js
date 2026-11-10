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
    if (response.getResponseCode() !== 200) AlchemistCatalog.fail(503);
    var body = response.getContentText();
    if (body.length > 100000) AlchemistCatalog.fail(503);
    var certs = JSON.parse(body);
    if (!certs || typeof certs !== 'object') AlchemistCatalog.fail(503);
    cache.put(key, body, 1800);
    return certs;
  }
  function verify(token) {
    var properties = PropertiesService.getScriptProperties();
    var audience = properties.getProperty('ALCHEMIST_GOOGLE_WEB_CLIENT_ID');
    var owner = properties.getProperty('ALCHEMIST_OWNER_SUB');
    if (!audience || !/^[\w-]+\.apps\.googleusercontent\.com$/.test(audience) || !owner) AlchemistCatalog.fail(503);
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
    if (!Object.prototype.hasOwnProperty.call(certs, header.kid)) certs = certificates(true);
    var cert = Object.prototype.hasOwnProperty.call(certs, header.kid) ? certs[header.kid] : null;
    if (typeof cert !== 'string') AlchemistCatalog.fail(401);
    try {
      if (!AlchemistRsa.verify(token, cert)) AlchemistCatalog.fail(401);
    } catch (_) { AlchemistCatalog.fail(401); }
    var now = Math.floor(Date.now() / 1000);
    if (['accounts.google.com', 'https://accounts.google.com'].indexOf(claims.iss) < 0 ||
        claims.aud !== audience || typeof claims.sub !== 'string' || !claims.sub ||
        !Number.isInteger(claims.exp) || !Number.isInteger(claims.iat) ||
        claims.exp <= now || claims.iat > now + 60 || claims.exp <= claims.iat ||
        claims.exp - claims.iat > 3700 ||
        (claims.nbf !== undefined && (!Number.isInteger(claims.nbf) || claims.nbf > now)) ||
        claims.email_verified !== true || typeof claims.email !== 'string') AlchemistCatalog.fail(401);
    // Identity is verified above. Authority comes only from server-side subjects.
    var grants=JSON.parse(properties.getProperty('ALCHEMIST_GRANTS')||'{}');
    claims.roles=claims.sub===owner?['owner']:(Object.prototype.hasOwnProperty.call(grants,claims.sub)?grants[claims.sub]:['client']);
    if(!Array.isArray(claims.roles))AlchemistCatalog.fail(503,'INVALID_GRANTS');
    return claims;
  }
  return {verify: verify};
})();
