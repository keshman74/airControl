"use strict";
const assert=require("node:assert/strict");
const fs=require("node:fs"),os=require("node:os"),path=require("node:path");
const http=require("node:http"),https=require("node:https");
const {execFileSync}=require("node:child_process");
const {fetchArtworkDataUrl,localPlayerArtworkTlsOptions,normalizeArtworkUrl}=require("../electron/artwork-fetch.cjs");
(async()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),"aircontrol-artwork-test-"));
 execFileSync("openssl",["req","-x509","-newkey","rsa:2048","-nodes","-keyout",path.join(dir,"key.pem"),"-out",path.join(dir,"cert.pem"),"-days","1","-subj","/CN=localhost"],{stdio:"ignore"});
 const jpeg=Buffer.from([255,216,255,224,0,2,255,217]);
 const server=https.createServer({key:fs.readFileSync(path.join(dir,"key.pem")),cert:fs.readFileSync(path.join(dir,"cert.pem"))},(req,res)=>{
  const u=new URL(req.url,"https://localhost");
  if(u.searchParams.get("redirect")==="local"){res.writeHead(302,{Location:"/data/AirplayArtWorkData.jpeg?resolved=1"});res.end();return;}
  if(u.searchParams.get("redirect")==="external"){res.writeHead(302,{Location:"https://cdn.example.test/data/AirplayArtWorkData.jpeg"});res.end();return;}
  if(u.searchParams.has("slow"))return;
  res.writeHead(200,{"Content-Length":jpeg.length});res.end(jpeg);
 });
 await new Promise(r=>server.listen(0,"127.0.0.1",r));
 const port=server.address().port,realGet=https.get;
 // Route test hosts to loopback while retaining the real TLS handshake.
 const seen=[];
 https.get=(url,options,cb)=>{
  seen.push({url:url.toString(),options:{...options}});
  const routed=new URL(url);routed.hostname="127.0.0.1";routed.port=String(port);
  return realGet(routed,{...options,servername:"localhost"},cb);
 };
 try{
  const url="https://192.168.0.21/data/AirplayArtWorkData.jpeg";
  // Reproduce the old behavior with an actual self-signed HTTPS server.
  let result=await fetchArtworkDataUrl({url});
  assert.equal(result.ok,false);assert.match(result.error,/self.signed|certificate/i);
  result=await fetchArtworkDataUrl({url,deviceIp:"192.168.0.21"});
  assert.equal(result.ok,true);assert.equal(result.mime,"image/jpeg");
  assert.equal(result.size,jpeg.length);
  assert.equal(result.dataUrl,"data:image/jpeg;base64,"+jpeg.toString("base64"));
  for(const args of [
    {url,deviceIp:"192.168.0.22"},
    {url:"https://cdn.example.test/data/AirplayArtWorkData.jpeg",deviceIp:"192.168.0.21"},
    {url:"https://192.168.0.21/other.jpg",deviceIp:"192.168.0.21"}
  ]){result=await fetchArtworkDataUrl(args);assert.equal(result.ok,false);}
  result=await fetchArtworkDataUrl({url:url+"?redirect=local",deviceIp:"192.168.0.21"});
  assert.equal(result.ok,true);assert.match(result.sourceUrl,/\?resolved=1$/);
  result=await fetchArtworkDataUrl({url:url+"?redirect=external",deviceIp:"192.168.0.21"});
  assert.equal(result.ok,false);assert.equal(seen.at(-1).options.rejectUnauthorized,undefined);
  result=await fetchArtworkDataUrl({url:url+"?slow=1",deviceIp:"192.168.0.21",timeout:30});
  assert.equal(result.ok,false);assert.match(result.error,/timed out/i);
  assert.equal((await fetchArtworkDataUrl({url:"file:///tmp/test.jpg"})).ok,false);
  for(const host of ["10.0.0.5","172.16.0.5","172.31.255.254","192.168.0.21"]){
   assert.equal(localPlayerArtworkTlsOptions(new URL("https://"+host+"/data/AirplayArtWorkData.jpeg"),host).rejectUnauthorized,false);
   assert.equal(localPlayerArtworkTlsOptions(new URL("https://"+host+"/data/airplay_f67a80954965fd2f79a144f41d4bbe38.jpg"),host).rejectUnauthorized,false);
  }
  for(const host of ["172.15.0.5","172.32.0.5","127.0.0.1","8.8.8.8","192.168.0.21.evil.test"]){
   assert.deepEqual(localPlayerArtworkTlsOptions(new URL("https://"+host+"/data/AirplayArtWorkData.jpeg"),host),{});
  }
  const relative="/data/airplay_f67a80954965fd2f79a144f41d4bbe38.jpg";
  const a31Ip="192.168.0.35";
  const normalized=normalizeArtworkUrl({url:relative,deviceIp:a31Ip,deviceProtocol:"http",devicePort:80});
  assert.equal(normalized.toString(),"http://192.168.0.35"+relative);
  assert.equal(normalizeArtworkUrl({url:"/data/not-artwork.jpg",deviceIp:a31Ip}),null);
  assert.equal(normalizeArtworkUrl({url:relative}),null);
  const plain=http.createServer((req,res)=>{res.writeHead(200,{"Content-Type":"image/jpeg"});res.end(jpeg);});
  await new Promise(r=>plain.listen(0,"127.0.0.1",r));
  try{
   assert.equal((await fetchArtworkDataUrl({url:"http://127.0.0.1:"+plain.address().port+"/cover.jpg"})).ok,true);
   const realHttpGet=http.get;
   http.get=(url,options,cb)=>{
    const routed=new URL(url);
    if(routed.hostname===a31Ip){routed.hostname="127.0.0.1";routed.port=String(plain.address().port);}
    return realHttpGet(routed,options,cb);
   };
   try{
    result=await fetchArtworkDataUrl({url:relative,deviceIp:a31Ip,deviceProtocol:"http",devicePort:80});
    assert.equal(result.ok,true);assert.equal(result.mime,"image/jpeg");
    assert.equal(result.dataUrl,"data:image/jpeg;base64,"+jpeg.toString("base64"));
    assert.equal(result.sourceUrl,"http://192.168.0.35"+relative);
   }finally{http.get=realHttpGet;}
  }finally{await new Promise(r=>plain.close(r));}
  console.log("Actual artwork regression passed: selected-player TLS isolation plus A31 relative UPnP artwork path normalization/fetch, response bytes, timeout, redirect and HTTP compatibility.");
 }finally{
  https.get=realGet;server.closeAllConnections();await new Promise(r=>server.close(r));
  fs.rmSync(dir,{recursive:true,force:true});
 }
})().catch(e=>{console.error(e);process.exitCode=1;});
