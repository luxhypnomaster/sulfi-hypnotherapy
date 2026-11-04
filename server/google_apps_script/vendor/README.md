# jsrsasign

`lib/jsrsasign-all-min.js` from npm `jsrsasign@11.1.5` (MIT), embedded unchanged
inside a small Apps Script V8 adapter. The adapter supplies the browser name
expected by the upstream big-integer implementation and exports only JWT decode
and RS256 verification. It does not expose signing/key-generation functions.
The upstream bundle reports internal version 11.1.4; that is also true of the
published 11.1.5 package. Included license: `LICENSE.txt`.

SHA-256 of the upstream bundle before the adapter:
`214aa1e644ec40329c9cd26d4ba3b1a4946536aa64aa4501783be25e43bad8b2`.

Used ONLY for RS256 public-key signature verification, not random numbers,
encryption, password storage, key generation or signing. No remote code loading.
Tests exercise actual RSA signatures using independently generated Node keys.
