/* Bounded-memory SHA-256 with serializable checkpoint. No secret material. */
var AlchemistSha256=(function(){
 'use strict';
 var K=[0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2];
 function rotate(x,n){return x>>>n|x<<32-n;}
 function create(saved){
  var state=saved?JSON.parse(JSON.stringify(saved)):{h:[0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19],tail:[],bytes:0};
  if(!Array.isArray(state.h)||state.h.length!==8||!Array.isArray(state.tail)||state.tail.length>=64||!Number.isSafeInteger(state.bytes)||state.bytes<0||state.bytes%64!==state.tail.length)throw Error('INVALID_HASH_CHECKPOINT');
  function block(b){var w=new Array(64);for(var i=0;i<16;i++)w[i]=(b[i*4]&255)<<24|(b[i*4+1]&255)<<16|(b[i*4+2]&255)<<8|b[i*4+3]&255;
   for(i=16;i<64;i++){var x=w[i-15],y=w[i-2];w[i]=(w[i-16]+(rotate(x,7)^rotate(x,18)^x>>>3)+w[i-7]+(rotate(y,17)^rotate(y,19)^y>>>10))|0;}
   var a=state.h[0],c=state.h[2],d=state.h[3],e=state.h[4],f=state.h[5],g=state.h[6],h=state.h[7],bb=state.h[1];
   for(i=0;i<64;i++){var t1=(h+(rotate(e,6)^rotate(e,11)^rotate(e,25))+(e&f^~e&g)+K[i]+w[i])|0,t2=((rotate(a,2)^rotate(a,13)^rotate(a,22))+(a&bb^a&c^bb&c))|0;h=g;g=f;f=e;e=d+t1|0;d=c;c=bb;bb=a;a=t1+t2|0;}
   var values=[a,bb,c,d,e,f,g,h];for(i=0;i<8;i++)state.h[i]=(state.h[i]+values[i])|0;
  }
  function update(bytes){if(!Number.isSafeInteger(state.bytes+bytes.length))throw Error('HASH_SIZE_OVERFLOW');state.bytes+=bytes.length;
   for(var i=0;i<bytes.length;i++){state.tail.push(bytes[i]&255);if(state.tail.length===64){block(state.tail);state.tail=[];}}return api;}
  function snapshot(){return JSON.parse(JSON.stringify(state));}
  function hex(){var prior=snapshot(),tail=state.tail.slice(),count=state.bytes;tail.push(128);while(tail.length%64!==56)tail.push(0);var high=Math.floor(count/536870912),low=(count*8)>>>0;[high,low].forEach(function(n){tail.push(n>>>24&255,n>>>16&255,n>>>8&255,n&255);});for(var i=0;i<tail.length;i+=64)block(tail.slice(i,i+64));var value=state.h.map(function(n){return ('00000000'+(n>>>0).toString(16)).slice(-8);}).join('');state=prior;return value;}
  var api={update:update,snapshot:snapshot,hex:hex};return api;
 }
 return {create:create};
})();
