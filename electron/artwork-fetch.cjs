"use strict";
const http = require("node:http");
const https = require("node:https");
const net = require("node:net");

// Limit the local-certificate exception to the selected LAN player's AirPlay
// image. Re-evaluated at every redirect; public CDN TLS validation stays enabled.
function localPlayerArtworkTlsOptions(parsed, deviceIp) {
  if(parsed.protocol!=="https:" || parsed.hostname!==String(deviceIp||"").trim() ||
     parsed.pathname!=="/data/AirplayArtWorkData.jpeg" || net.isIP(parsed.hostname)!==4) return {};
  const parts=parsed.hostname.split(".").map(Number);
  const privateIp=parts[0]===10 || (parts[0]===172 && parts[1]>=16 && parts[1]<=31) ||
      (parts[0]===192 && parts[1]===168);
  return privateIp ? {rejectUnauthorized:false} : {};
}

function fetchArtworkDataUrl({ url, timeout = 5000, deviceIp = "" } = {}, redirects = 0) {
  return new Promise((resolve) => {
    let parsed;
    try { parsed = new URL(String(url || "").trim()); }
    catch { return resolve({ok:false,status:0,error:"Invalid artwork URL"}); }
    if (!["http:","https:"].includes(parsed.protocol)) return resolve({ok:false,status:0,error:"Unsupported artwork protocol"});
    const transport = parsed.protocol === "https:" ? https : http;
    const req = transport.get(parsed, {timeout:Number(timeout)||5000, ...localPlayerArtworkTlsOptions(parsed, deviceIp), headers:{"User-Agent":"airControl/4.4.21","Accept":"image/*,*/*;q=0.8"}}, (res) => {
      if ([301,302,303,307,308].includes(res.statusCode) && res.headers.location && redirects < 4) {
        res.resume();
        const next = new URL(res.headers.location, parsed).toString();
        return fetchArtworkDataUrl({url:next,timeout,deviceIp}, redirects+1).then(resolve);
      }
      if (!(res.statusCode >= 200 && res.statusCode < 300)) { res.resume(); return resolve({ok:false,status:res.statusCode||0,error:`Artwork HTTP ${res.statusCode||0}`}); }
      const chunks=[]; let size=0; const max=5*1024*1024;
      res.on("data", c=>{ size+=c.length; if(size<=max) chunks.push(c); else req.destroy(new Error("Artwork too large")); });
      res.on("end", ()=>{
        if(size>max) return;
        const data=Buffer.concat(chunks); const mime=String(res.headers["content-type"]||"image/jpeg").split(";")[0].trim()||"image/jpeg";
        resolve({ok:true,status:res.statusCode,dataUrl:`data:${mime};base64,${data.toString("base64")}`,mime,size,sourceUrl:parsed.toString()});
      });
    });
    req.on("timeout", ()=>req.destroy(new Error("Artwork request timed out")));
    req.on("error", e=>resolve({ok:false,status:0,error:e.message}));
  });
}

module.exports={fetchArtworkDataUrl,localPlayerArtworkTlsOptions};
