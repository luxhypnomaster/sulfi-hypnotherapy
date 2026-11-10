/* Container signatures only, not a claim to decode every codec on Android. */
var AlchemistMime=(function(){
 function matches(mime,bytes){var b=bytes.map(function(x){return x&255;});function starts(a){return b.length>=a.length&&a.every(function(x,i){return b[i]===x;});}function ascii(at,s){return b.length>=at+s.length&&s.split('').every(function(x,i){return b[at+i]===x.charCodeAt(0);});}
  if(mime==='image/png')return starts([137,80,78,71,13,10,26,10]);
  if(mime==='image/jpeg')return starts([255,216,255]);
  if(mime==='image/webp')return ascii(0,'RIFF')&&ascii(8,'WEBP');
  if(mime==='audio/wav')return ascii(0,'RIFF')&&ascii(8,'WAVE');
  if(mime==='audio/mpeg')return ascii(0,'ID3')||b.length>2&&b[0]===255&&(b[1]&224)===224;
  if(mime==='audio/aac')return b.length>2&&b[0]===255&&(b[1]&246)===240;
  if(mime==='audio/ogg')return ascii(0,'OggS');
  if(['audio/mp4','video/mp4','video/quicktime'].indexOf(mime)>=0)return ascii(4,'ftyp');
  if(mime==='video/webm')return starts([26,69,223,163]);
  if(mime==='application/zip')return starts([80,75,3,4])||starts([80,75,5,6]);
  return false;
 }
 return {matches:matches};
})();
