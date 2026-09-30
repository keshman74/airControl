const { app, BrowserWindow, ipcMain, session, systemPreferences } = require("electron");
const path = require("path");
const https = require("https");
const http = require("http");
const os = require("os");
const net = require("net");

function encodeA33Instruct(instruct = "") {
  return encodeURIComponent(String(instruct))
    .replace(/%3A/gi, ":")
    .replace(/%2B/gi, "+")
    .replace(/%2F/gi, "/")
    .replace(/%7B/gi, "{")
    .replace(/%7D/gi, "}")
    .replace(/%22/gi, '"')
    .replace(/%5B/gi, "[")
    .replace(/%5D/gi, "]")
    .replace(/%2C/gi, ",");
}


function encodeLinkplayCommand(command = "") {
  // Linkplay uses /httpapi.asp?command=... . Keep command separators and URL
  // slashes readable, but keep + encoded because a raw + in a query is a space.
  return encodeURIComponent(String(command))
    .replace(/%3A/gi, ":")
    .replace(/%2F/gi, "/")
    .replace(/%7B/gi, "{")
    .replace(/%7D/gi, "}")
    .replace(/%22/gi, '\"')
    .replace(/%5B/gi, "[")
    .replace(/%5D/gi, "]")
    .replace(/%2C/gi, ",");
}

function requestDevice({ ip, port = 8443, protocol = "https", instruct, apiStyle = "aircloud", timeout = 5000 }) {
  return new Promise((resolve, reject) => {
    const transport = protocol === "https" ? https : http;
    const isLinkplay = apiStyle === "linkplay";
    const options = {
      hostname: ip,
      port,
      path: isLinkplay
        ? `/httpapi.asp?command=${encodeLinkplayCommand(instruct)}`
        : `/?Instruct=${encodeA33Instruct(instruct)}`,
      method: "GET",
      timeout: isLinkplay ? Math.max(Number(timeout) || 0, 8000) : timeout,
      headers: isLinkplay ? {
        "Accept": "application/json,text/plain,*/*",
        "User-Agent": "airCloudCTRL/0.4.0.1",
        "Connection": "close"
      } : {"Connection":"close"},
      agent: false,
      ...(protocol === "https" ? { rejectUnauthorized: false } : {})
    };

    const req = transport.request(options, (res) => {
      let body = "";
      res.setEncoding("utf8");
      res.on("data", chunk => body += chunk);
      res.on("end", () => {
        const cleanBody = String(body || "").replace(/^\uFEFF/, "").trim();
        let parsed = cleanBody;
        try {
          parsed = JSON.parse(cleanBody);
        } catch {
          // Some A33 firmware returns TuneIn status JSON containing stray control
          // bytes inside metadata fields (commonly around TrackImage). curl warns
          // that the response is binary and strict JSON.parse then fails. Strip only
          // illegal JSON control bytes and retry so native TuneIn status remains usable.
          if (!isLinkplay) {
            try {
              const sanitized = cleanBody.replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, "");
              parsed = JSON.parse(sanitized);
            } catch {}
          }
        }
        resolve({ ok: res.statusCode >= 200 && res.statusCode < 300, status: res.statusCode, data: parsed, raw: cleanBody });
      });
    });

    req.on("timeout", () => req.destroy(new Error("Device request timed out")));
    req.on("error", reject);
    req.end();
  });
}

ipcMain.handle("device:request", async (_event, args) => requestDevice(args));

// v4.4.25: verbose DEVICE PIPELINE Terminal diagnostics removed.
// v4.4.26: compact, deduplicated Multiroom-only diagnostic. No artwork/metadata dumps.
ipcMain.on("diagnostic:multiroom", (_event, p={}) => {
  const v = x => (x === undefined || x === null || x === "") ? "<empty>" : String(x);
  console.log("\n========== MULTIROOM v4.4.26 ==========");
  console.log(`Name: ${v(p.name)} | ${v(p.hardware)} | ${v(p.project)} | ${v(p.ip)}`);
  console.log(`group: ${v(p.group)} | master_uuid: ${v(p.master_uuid)} | slave: ${v(p.slave)}`);
  console.log(`MultiroomStatus: ${v(p.MultiroomStatus)} | Host: ${v(p.Host)} | Device: ${v(p.Device)}`);
  console.log(`GroupName: ${v(p.GroupName)} | uuid: ${v(p.uuid)}`);
  console.log("========================================\n");
});


// Dedicated Linkplay probe. This deliberately mirrors a plain Node http.get()
// call, which is useful for older A31 firmware and also gives the renderer a
// precise diagnostic (URL, HTTP status, transport error) when Add Device fails.
function linkplayGet({ ip, command = "getStatusEx", protocol = "http", port, timeout = 8000 }) {
  return new Promise((resolve) => {
    const host = String(ip || "").trim();
    const cmd = String(command || "getStatusEx");
    const scheme = String(protocol || "http").toLowerCase() === "https" ? "https" : "http";
    const targetPort = Number(port) || (scheme === "https" ? 443 : 80);
    const transport = scheme === "https" ? https : http;
    const pathName = `/httpapi.asp?command=${encodeLinkplayCommand(cmd)}`;
    const url = `${scheme}://${host}:${targetPort}${pathName}`;
    const req = transport.get({
      hostname: host,
      port: targetPort,
      path: pathName,
      headers: { "Connection": "close", "User-Agent": "airCloudCTRL/0.4.1.3" },
      agent: false,
      ...(scheme === "https" ? { rejectUnauthorized: false } : {})
    }, (res) => {
      let body = "";
      res.setEncoding("utf8");
      res.on("data", chunk => body += chunk);
      res.on("end", () => {
        const raw = String(body || "").replace(/^\uFEFF/, "").trim();
        let data = raw;
        try { data = JSON.parse(raw); } catch {}
        resolve({
          ok: res.statusCode >= 200 && res.statusCode < 300,
          status: res.statusCode,
          data,
          raw,
          url
        });
      });
    });
    req.setTimeout(Number(timeout) || 8000, () => {
      req.destroy(new Error("Linkplay request timed out"));
    });
    req.on("error", (error) => resolve({ ok:false, status:0, error:error.message, raw:error.message, url }));
  });
}

async function linkplayAutoProbe({ ip, command = "getStatusEx", preferredProtocol = "http", preferredPort, timeout = 8000 } = {}) {
  const pref = String(preferredProtocol || "http").toLowerCase() === "https" ? "https" : "http";
  const candidates = [];
  const pushCandidate = (protocol, port) => {
    const normalizedProtocol = protocol === "https" ? "https" : "http";
    const normalizedPort = Number(port) || (normalizedProtocol === "https" ? 443 : 80);
    if (!candidates.some(x => x.protocol === normalizedProtocol && x.port === normalizedPort)) {
      candidates.push({ protocol: normalizedProtocol, port: normalizedPort });
    }
  };

  // Respect the user's choice first, then try the two canonical Linkplay endpoints.
  pushCandidate(pref, preferredPort);
  pushCandidate("https", 443);
  pushCandidate("http", 80);

  let last = null;
  for (const endpoint of candidates) {
    const result = await linkplayGet({
      ip,
      command,
      protocol: endpoint.protocol,
      port: endpoint.port,
      timeout
    });
    last = { ...result, protocol: endpoint.protocol, port: endpoint.port };

    const data = result?.data;
    const looksLikeDevice = data && typeof data === "object" && (
      data.uuid || data.DeviceName || data.GroupName || data.project || data.hardware ||
      command !== "getStatusEx"
    );
    if (result?.ok && looksLikeDevice) return last;
  }
  return last || { ok:false, status:0, error:"No Linkplay endpoint responded", raw:"No Linkplay endpoint responded" };
}

ipcMain.handle("linkplay:probe", async (_event, args) => linkplayGet(args || {}));
ipcMain.handle("linkplay:autoProbe", async (_event, args) => linkplayAutoProbe(args || {}));

// Linkplay A31 MCU passthrough (TCP/8899). The verified A31 protocol wraps
// ASCII MCU commands in a 20-byte frame: magic, payload length, checksum,
// eight reserved bytes, then the command itself. Responses use the same frame.
function makeLinkplayMcuFrame(command = "") {
  const payload = Buffer.from(String(command), "utf8");
  const frame = Buffer.alloc(20 + payload.length);
  frame[0] = 0x18; frame[1] = 0x96; frame[2] = 0x18; frame[3] = 0x20;
  frame.writeUInt32LE(payload.length, 4);
  let checksum = 0;
  for (const byte of payload) checksum = (checksum + byte) >>> 0;
  frame.writeUInt32LE(checksum, 8);
  // bytes 12..19 are reserved and remain zero.
  payload.copy(frame, 20);
  return frame;
}

function parseLinkplayMcuFrames(buffer = Buffer.alloc(0)) {
  const payloads = [];
  let offset = 0;
  while (offset + 20 <= buffer.length) {
    // Resynchronise conservatively if a device ever prefixes noise.
    if (!(buffer[offset] === 0x18 && buffer[offset+1] === 0x96 && buffer[offset+2] === 0x18 && buffer[offset+3] === 0x20)) {
      offset += 1;
      continue;
    }
    const len = buffer.readUInt32LE(offset + 4);
    if (len > 1024 * 1024 || offset + 20 + len > buffer.length) break;
    payloads.push(buffer.subarray(offset + 20, offset + 20 + len).toString("utf8"));
    offset += 20 + len;
  }
  return payloads;
}

function linkplayMcuRequest({ ip, command, port = 8899, timeout = 1100, expectReply = true } = {}) {
  return new Promise((resolve) => {
    const host = String(ip || "").trim();
    const cmd = String(command || "");
    if (!host || !cmd) return resolve({ok:false,error:"Missing Linkplay MCU IP or command",payloads:[]});

    const socket = net.createConnection({host, port:Number(port) || 8899});
    const chunks = [];
    let settled = false;
    let timer = null;
    const finish = (result) => {
      if (settled) return;
      settled = true;
      if (timer) clearTimeout(timer);
      try { socket.destroy(); } catch {}
      resolve(result);
    };
    const finishFromChunks = () => {
      const rawBuffer = Buffer.concat(chunks);
      const payloads = parseLinkplayMcuFrames(rawBuffer);
      finish({ok:true,payloads,rawHex:rawBuffer.toString("hex"),command:cmd});
    };

    socket.on("connect", () => {
      socket.write(makeLinkplayMcuFrame(cmd), (err) => {
        if (err) return finish({ok:false,error:err.message,payloads:[],command:cmd});
        if (!expectReply) {
          // Give the kernel a brief moment to flush the small frame, matching the
          // successfully verified manual A31 write tests, then close cleanly.
          setTimeout(() => finish({ok:true,payloads:[],command:cmd}), 80);
        }
      });
      if (expectReply) timer = setTimeout(finishFromChunks, Math.max(250, Number(timeout) || 1100));
    });
    socket.on("data", chunk => chunks.push(Buffer.from(chunk)));
    socket.on("end", () => expectReply ? finishFromChunks() : finish({ok:true,payloads:[],command:cmd}));
    socket.on("error", error => finish({ok:false,error:error.message,payloads:[],command:cmd}));
    socket.setTimeout(Math.max(500, Number(timeout) || 1100) + 500, () => expectReply ? finishFromChunks() : finish({ok:true,payloads:[],command:cmd}));
  });
}

ipcMain.handle("linkplay:mcuRequest", async (_event, args) => linkplayMcuRequest(args || {}));

function decodeXmlEntities(value = "") {
  let out = String(value || "");
  for (let i = 0; i < 3; i++) {
    const next = out
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/&quot;/g, '"')
      .replace(/&apos;/g, "'")
      .replace(/&#39;/g, "'")
      .replace(/&amp;/g, "&");
    if (next === out) break;
    out = next;
  }
  return out;
}

function xmlTag(xml = "", localName = "") {
  const name = String(localName).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const re = new RegExp(`<(?:(?:[A-Za-z0-9_-]+):)?${name}(?:\\s[^>]*)?>([\\s\\S]*?)<\\/(?:(?:[A-Za-z0-9_-]+):)?${name}>`, "i");
  const match = String(xml || "").match(re);
  return match ? decodeXmlEntities(match[1]).trim() : "";
}

function hmsToSeconds(value = "") {
  const parts = String(value || "").trim().split(":").map(Number);
  if (parts.length !== 3 || parts.some(n => !Number.isFinite(n))) return 0;
  return Math.max(0, parts[0] * 3600 + parts[1] * 60 + parts[2]);
}

function linkplayUpnpPositionInfo({ ip, timeout = 3500 } = {}) {
  return new Promise((resolve) => {
    const host = String(ip || "").trim();
    const body = `<?xml version="1.0" encoding="utf-8"?>` +
      `<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">` +
      `<s:Body><u:GetPositionInfo xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"><InstanceID>0</InstanceID></u:GetPositionInfo></s:Body></s:Envelope>`;
    const req = http.request({
      hostname: host,
      port: 49152,
      path: "/upnp/control/rendertransport1",
      method: "POST",
      timeout: Number(timeout) || 3500,
      headers: {
        "Content-Type": 'text/xml; charset="utf-8"',
        "SOAPAction": '"urn:schemas-upnp-org:service:AVTransport:1#GetPositionInfo"',
        "Content-Length": Buffer.byteLength(body),
        "Connection": "close",
        "User-Agent": "airCloudCTRL/3.0.2"
      },
      agent: false
    }, (res) => {
      let xml = "";
      res.setEncoding("utf8");
      res.on("data", chunk => xml += chunk);
      res.on("end", () => {
        const rawMeta = xmlTag(xml, "TrackMetaData") || xmlTag(xml, "CurrentTrackMetaData") || xmlTag(xml, "AVTransportURIMetaData");
        const meta = decodeXmlEntities(rawMeta);
        let art = xmlTag(meta, "albumArtURI");
        if (art && art.startsWith("/")) art = `http://${host}:49152${art}`;
        const title = xmlTag(meta, "title");
        const artist = xmlTag(meta, "artist") || xmlTag(meta, "creator");
        const album = xmlTag(meta, "album");
        const progress = hmsToSeconds(xmlTag(xml, "RelTime"));
        const total = hmsToSeconds(xmlTag(xml, "TrackDuration"));
        resolve({
          ok: res.statusCode >= 200 && res.statusCode < 300,
          status: res.statusCode,
          data: { title, artist, album, art, progress, total, rawMeta: meta },
          raw: xml
        });
      });
    });
    req.on("timeout", () => req.destroy(new Error("UPnP metadata request timed out")));
    req.on("error", error => resolve({ok:false,status:0,error:error.message,raw:error.message}));
    req.end(body);
  });
}

ipcMain.handle("linkplay:upnpPositionInfo", async (_event, args) => {
  return linkplayUpnpPositionInfo(args || {});
});


// v4.4.17: load artwork in Electron main and return a data URL to the renderer.
// This avoids renderer mixed-content/CORS/CDN restrictions for Linkplay metadata art.
function fetchArtworkDataUrl({ url, timeout = 5000 } = {}, redirects = 0) {
  return new Promise((resolve) => {
    let parsed;
    try { parsed = new URL(String(url || "").trim()); }
    catch { return resolve({ok:false,status:0,error:"Invalid artwork URL"}); }
    if (!["http:","https:"].includes(parsed.protocol)) return resolve({ok:false,status:0,error:"Unsupported artwork protocol"});
    const transport = parsed.protocol === "https:" ? https : http;
    const req = transport.get(parsed, {timeout:Number(timeout)||5000, headers:{"User-Agent":"airControl/4.4.21","Accept":"image/*,*/*;q=0.8"}}, (res) => {
      if ([301,302,303,307,308].includes(res.statusCode) && res.headers.location && redirects < 4) {
        res.resume();
        const next = new URL(res.headers.location, parsed).toString();
        return fetchArtworkDataUrl({url:next,timeout}, redirects+1).then(resolve);
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
ipcMain.handle("artwork:resolve", async (_event, args) => fetchArtworkDataUrl(args || {}));

// --- Room EQ test-signal server ------------------------------------------------
const TEST_AUDIO_PORT = 48721;
let testAudioServer = null;
let testBuffers = null;

function makeWav(samples, sampleRate = 48000) {
  const dataSize = samples.length * 2;
  const buffer = Buffer.alloc(44 + dataSize);
  buffer.write("RIFF", 0);
  buffer.writeUInt32LE(36 + dataSize, 4);
  buffer.write("WAVE", 8);
  buffer.write("fmt ", 12);
  buffer.writeUInt32LE(16, 16);
  buffer.writeUInt16LE(1, 20); // PCM
  buffer.writeUInt16LE(1, 22); // mono
  buffer.writeUInt32LE(sampleRate, 24);
  buffer.writeUInt32LE(sampleRate * 2, 28);
  buffer.writeUInt16LE(2, 32);
  buffer.writeUInt16LE(16, 34);
  buffer.write("data", 36);
  buffer.writeUInt32LE(dataSize, 40);
  for (let i = 0; i < samples.length; i++) {
    const s = Math.max(-1, Math.min(1, samples[i]));
    buffer.writeInt16LE(Math.round(s * 32767), 44 + i * 2);
  }
  return buffer;
}

function buildSignals() {
  if (testBuffers) return testBuffers;
  const sr = 48000;
  const noiseSeconds = 20;
  const noiseN = sr * noiseSeconds;

  const white = new Float32Array(noiseN);
  for (let i = 0; i < noiseN; i++) white[i] = (Math.random() * 2 - 1) * 0.23;

  // Paul Kellet style pinking filter, scaled conservatively to avoid clipping.
  const pink = new Float32Array(noiseN);
  let b0=0,b1=0,b2=0,b3=0,b4=0,b5=0,b6=0;
  for (let i = 0; i < noiseN; i++) {
    const w = Math.random() * 2 - 1;
    b0 = 0.99886*b0 + w*0.0555179;
    b1 = 0.99332*b1 + w*0.0750759;
    b2 = 0.96900*b2 + w*0.1538520;
    b3 = 0.86650*b3 + w*0.3104856;
    b4 = 0.55000*b4 + w*0.5329522;
    b5 = -0.7616*b5 - w*0.0168980;
    const p = b0+b1+b2+b3+b4+b5+b6+w*0.5362;
    b6 = w*0.115926;
    pink[i] = p * 0.055;
  }

  const sweepSeconds = 15;
  const sweepN = sr * sweepSeconds;
  const sweep = new Float32Array(sweepN);
  const f0 = 20, f1 = 20000;
  const L = sweepSeconds / Math.log(f1/f0);
  const K = 2*Math.PI*f0*L;
  for (let i = 0; i < sweepN; i++) {
    const t = i/sr;
    const fade = Math.min(1, t/0.05, (sweepSeconds-t)/0.05);
    sweep[i] = Math.sin(K * (Math.exp(t/L)-1)) * 0.35 * Math.max(0, fade);
  }

  testBuffers = {
    "/pink.wav": makeWav(pink, sr),
    "/white.wav": makeWav(white, sr),
    "/sweep-20-20000.wav": makeWav(sweep, sr)
  };
  return testBuffers;
}

function startTestAudioServer() {
  if (testAudioServer) return;
  const buffers = buildSignals();
  testAudioServer = http.createServer((req, res) => {
    const urlPath = String(req.url || "").split("?")[0];
    const body = buffers[urlPath];
    if (!body) {
      res.writeHead(404, {"Content-Type":"text/plain", "Access-Control-Allow-Origin":"*"});
      res.end("Not found");
      return;
    }
    res.writeHead(200, {
      "Content-Type": "audio/wav",
      "Content-Length": body.length,
      "Cache-Control": "no-store",
      "Access-Control-Allow-Origin": "*"
    });
    res.end(body);
  });
  testAudioServer.on("error", err => console.error("Room EQ test server:", err.message));
  testAudioServer.listen(TEST_AUDIO_PORT, "0.0.0.0");
}

function sameSubnetAddress(deviceIp = "") {
  const target = String(deviceIp).split(".");
  const nets = os.networkInterfaces();
  const candidates = [];
  for (const list of Object.values(nets)) {
    for (const item of list || []) {
      if (item.family === "IPv4" && !item.internal) candidates.push(item.address);
    }
  }
  if (target.length === 4) {
    const prefix = target.slice(0,3).join(".") + ".";
    const match = candidates.find(ip => ip.startsWith(prefix));
    if (match) return match;
  }
  return candidates[0] || "127.0.0.1";
}

ipcMain.handle("test-audio:info", async (_event, deviceIp) => {
  startTestAudioServer();
  const host = sameSubnetAddress(deviceIp);
  const base = `http://${host}:${TEST_AUDIO_PORT}`;
  return {
    ok: host !== "127.0.0.1",
    host,
    port: TEST_AUDIO_PORT,
    urls: {
      pink: `${base}/pink.wav`,
      white: `${base}/white.wav`,
      sweep: `${base}/sweep-20-20000.wav`
    }
  };
});

ipcMain.handle("microphone:permission", async () => {
  if (process.platform !== "darwin") return { ok: true, status: "not-required" };
  try {
    const current = systemPreferences.getMediaAccessStatus("microphone");
    if (current === "granted") return { ok: true, status: current };
    const ok = await systemPreferences.askForMediaAccess("microphone");
    return { ok, status: ok ? "granted" : systemPreferences.getMediaAccessStatus("microphone") };
  } catch (error) {
    return { ok: false, status: "error", error: error.message };
  }
});

function createWindow() {
  const win = new BrowserWindow({
    width: 1600,
    height: 1000,
    minWidth: 1180,
    minHeight: 760,
    backgroundColor: "#07101c",
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, "preload.cjs"),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  if (process.platform === "win32") win.setMenuBarVisibility(false);

  session.defaultSession.setPermissionRequestHandler((_wc, permission, callback) => {
    callback(permission === "media");
  });

  if (!app.isPackaged) win.loadURL("http://localhost:5173");
  else win.loadFile(path.join(__dirname, "../dist/index.html"));
}

app.whenReady().then(() => {
  startTestAudioServer();
  startLocalMediaServer();
  createWindow();
  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});

// ---- Local music library / media server (v3.0.7.31) ----
const fs = require("fs");
const crypto = require("crypto");
const dgram = require("dgram");
const { dialog } = require("electron");
let musicMetadata = null;
try { musicMetadata = require("music-metadata"); } catch {}
const localMediaFiles = new Map();
const localMediaArtwork = new Map();
const radioArtwork = new Map();
// v4.4.1 SMB3/NTLMv2 sessions and HTTP proxy entries. Credentials remain in Electron main only.
const smbClients = new Map();
const smbHostClients = new Map();
const smbMediaFiles = new Map();
let SMB3ClientClass = null;
async function loadSmb3Client(){
  if(SMB3ClientClass) return SMB3ClientClass;
  const mod = await import("smb3-client");
  SMB3ClientClass = mod.Client;
  return SMB3ClientClass;
}
let localMediaServer = null;
let localMediaPort = 17890;
const AUDIO_EXTS = new Set([".mp3",".flac",".wav",".m4a",".aac",".ogg",".opus",".aiff",".aif"]);

function mimeForAudio(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  return ({".mp3":"audio/mpeg",".flac":"audio/flac",".wav":"audio/wav",".m4a":"audio/mp4",".aac":"audio/aac",".ogg":"audio/ogg",".opus":"audio/ogg",".aiff":"audio/aiff",".aif":"audio/aiff"})[ext] || "application/octet-stream";
}
function awaitMaybeSmbStream(client,filePath){ return client.createReadStream(filePath); }
function startLocalMediaServer() {
  if (localMediaServer) return;
  localMediaServer = http.createServer(async (req,res)=>{
    try {
      const u = new URL(req.url, "http://localhost");
      if (u.pathname.startsWith("/cover/")) {
        const id = u.pathname.slice(7);
        const art = localMediaArtwork.get(id);
        if (!art?.data) { res.writeHead(404); return res.end(); }
        res.writeHead(200,{"Content-Type":art.mime||"image/jpeg","Content-Length":art.data.length,"Cache-Control":"no-cache"});
        return res.end(art.data);
      }
      if (u.pathname.startsWith("/radio-cover/")) {
        const id = u.pathname.slice(13);
        const art = radioArtwork.get(id);
        if (!art?.data) { res.writeHead(404); return res.end(); }
        res.writeHead(200,{"Content-Type":art.mime||"image/jpeg","Content-Length":art.data.length,"Cache-Control":"no-cache"});
        return res.end(art.data);
      }
      if (u.pathname.startsWith("/smb-media/")) {
        const id = u.pathname.slice(11); const item = smbMediaFiles.get(id);
        if (!item?.data) { res.writeHead(404); return res.end(); }
        const data=item.data; const total=data.length; const range=req.headers.range;
        res.setHeader("Accept-Ranges","bytes"); res.setHeader("Content-Type",item.mime||"application/octet-stream");
        if(req.method==="HEAD"){res.writeHead(200,{"Content-Length":total});return res.end();}
        if(range){const m=/bytes=(\d*)-(\d*)/.exec(range);let start=Number(m?.[1]||0);let end=m?.[2]?Number(m[2]):total-1;start=Math.max(0,Math.min(start,total-1));end=Math.max(start,Math.min(end,total-1));res.writeHead(206,{"Content-Range":`bytes ${start}-${end}/${total}`,"Content-Length":end-start+1});return res.end(data.subarray(start,end+1));}
        res.writeHead(200,{"Content-Length":total}); return res.end(data);
      }
      if (!u.pathname.startsWith("/media/")) { res.writeHead(404); return res.end(); }
      const id = u.pathname.slice(7);
      const filePath = localMediaFiles.get(id);
      if (!filePath || !fs.existsSync(filePath)) { res.writeHead(404); return res.end(); }
      const stat = fs.statSync(filePath); const total = stat.size;
      const range = req.headers.range;
      res.setHeader("Accept-Ranges","bytes"); res.setHeader("Content-Type",mimeForAudio(filePath));
      if (range) {
        const m = /bytes=(\d*)-(\d*)/.exec(range); let start = Number(m?.[1] || 0); let end = m?.[2] ? Number(m[2]) : total-1;
        start=Math.max(0,Math.min(start,total-1)); end=Math.max(start,Math.min(end,total-1));
        res.writeHead(206,{"Content-Range":`bytes ${start}-${end}/${total}`,"Content-Length":end-start+1});
        fs.createReadStream(filePath,{start,end}).pipe(res);
      } else { res.writeHead(200,{"Content-Length":total}); fs.createReadStream(filePath).pipe(res); }
    } catch { res.writeHead(500); res.end(); }
  });
  localMediaServer.on("error",()=>{});
  localMediaServer.listen(localMediaPort,"0.0.0.0");
}
function routeAddressFor(targetIp) {
  return new Promise(resolve=>{
    const sock=dgram.createSocket("udp4");
    const done=(ip)=>{try{sock.close();}catch{} resolve(ip);};
    sock.once("error",()=>done(null));
    sock.connect(9,String(targetIp||"8.8.8.8"),()=>{ try { done(sock.address().address); } catch { done(null); } });
  });
}
async function scanMusicFolder(root) {
  const tracks=[]; const stack=[root];
  while(stack.length){ const dir=stack.pop(); let entries=[]; try{entries=fs.readdirSync(dir,{withFileTypes:true});}catch{continue;}
    for(const e of entries){ if(e.name.startsWith(".")) continue; const p=path.join(dir,e.name); if(e.isDirectory()){stack.push(p);continue;} if(!AUDIO_EXTS.has(path.extname(e.name).toLowerCase())) continue;
      let common={},format={}; try { if(musicMetadata){ const md=await musicMetadata.parseFile(p,{duration:true,skipCovers:false}); common=md.common||{}; format=md.format||{}; } } catch {}
      const rel=path.relative(root,p); const id=crypto.createHash("sha1").update(p).digest("hex"); localMediaFiles.set(id,p);
      let artwork=""; const pic=common.picture?.[0]; if(pic?.data){ const b=Buffer.from(pic.data); const mime=pic.format||"image/jpeg"; localMediaArtwork.set(id,{data:b,mime}); artwork=`data:${mime};base64,${b.toString("base64")}`; }
      if(!artwork){ for(const n of ["cover.jpg","folder.jpg","Cover.jpg","Folder.jpg","cover.png","folder.png"]){const cp=path.join(path.dirname(p),n); if(fs.existsSync(cp)){try{const b=fs.readFileSync(cp); const mime=n.toLowerCase().endsWith("png")?"image/png":"image/jpeg"; localMediaArtwork.set(id,{data:b,mime}); artwork=`data:${mime};base64,${b.toString("base64")}`;break;}catch{}}} }
      tracks.push({id,path:p,relativePath:rel,folder:path.dirname(rel)==="."?"":path.dirname(rel),title:common.title||path.basename(e.name,path.extname(e.name)),artist:common.artist||common.albumartist||"Unknown Artist",albumArtist:common.albumartist||common.artist||"Unknown Artist",album:common.album||"Unknown Album",track:Number(common.track?.no)||0,disc:Number(common.disk?.no)||0,genre:Array.isArray(common.genre)?common.genre.join(", "):(common.genre||""),year:common.year||"",duration:Number(format.duration)||0,artwork});
    }
  }
  tracks.sort((a,b)=>a.relativePath.localeCompare(b.relativePath,undefined,{numeric:true,sensitivity:"base"})); return tracks;
}
ipcMain.handle("library:chooseFolder", async ()=>{ const r=await dialog.showOpenDialog({properties:["openDirectory"],title:"Choose Music Folder"}); return r.canceled?null:r.filePaths[0]; });
ipcMain.handle("library:scan", async (_e,root)=>{ if(!root||!fs.existsSync(root)) return {ok:false,error:"Folder not found"}; startLocalMediaServer(); const tracks=await scanMusicFolder(root); return {ok:true,root,tracks}; });
ipcMain.handle("library:mediaUrl", async (_e,{id,deviceIp})=>{ startLocalMediaServer(); if(!localMediaFiles.has(id)) return {ok:false,error:"Track is not indexed"}; const ip=await routeAddressFor(deviceIp); if(!ip) return {ok:false,error:"Could not determine the computer LAN address"}; return {ok:true,url:`http://${ip}:${localMediaPort}/media/${id}`,artUrl:localMediaArtwork.has(id)?`http://${ip}:${localMediaPort}/cover/${id}`:""}; });

function xmlEscape(value="") { return String(value).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&apos;"); }
function soapEscape(value="") { return xmlEscape(value); }
function upnpAvTransportAction({ip, action, innerXml, timeout=5000}) {
  return new Promise((resolve)=>{
    const body=`<?xml version="1.0" encoding="utf-8"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:${action} xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">${innerXml}</u:${action}></s:Body></s:Envelope>`;
    const req=http.request({hostname:String(ip||"").trim(),port:49152,path:"/upnp/control/rendertransport1",method:"POST",timeout,headers:{"Content-Type":'text/xml; charset="utf-8"',"SOAPAction":`"urn:schemas-upnp-org:service:AVTransport:1#${action}"`,"Content-Length":Buffer.byteLength(body),"Connection":"close","User-Agent":"airControl/3.0.7.45"},agent:false},res=>{let raw="";res.setEncoding("utf8");res.on("data",c=>raw+=c);res.on("end",()=>resolve({ok:res.statusCode>=200&&res.statusCode<300,status:res.statusCode,raw}));});
    req.on("timeout",()=>req.destroy(new Error(`UPnP ${action} timed out`))); req.on("error",e=>resolve({ok:false,status:0,error:e.message,raw:e.message})); req.end(body);
  });
}
ipcMain.handle("library:upnpPlay", async (_e,{deviceIp,id,title,artist,album,duration}={})=>{
  startLocalMediaServer();
  if(!localMediaFiles.has(id)) return {ok:false,error:"Track is not indexed"};
  const lanIp=await routeAddressFor(deviceIp); if(!lanIp) return {ok:false,error:"Could not determine the computer LAN address"};
  const mediaUrl=`http://${lanIp}:${localMediaPort}/media/${id}`;
  const artUrl=localMediaArtwork.has(id)?`http://${lanIp}:${localMediaPort}/cover/${id}`:"";
  const filePath=localMediaFiles.get(id); const mime=mimeForAudio(filePath);
  const sec=Math.max(0,Math.round(Number(duration)||0)); const h=String(Math.floor(sec/3600)).padStart(2,"0"),m=String(Math.floor((sec%3600)/60)).padStart(2,"0"),ss=String(sec%60).padStart(2,"0");
  const didl=`<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/"><item id="0" parentID="0" restricted="1"><dc:title>${xmlEscape(title||path.basename(filePath))}</dc:title><dc:creator>${xmlEscape(artist||"")}</dc:creator><upnp:artist>${xmlEscape(artist||"")}</upnp:artist><upnp:album>${xmlEscape(album||"")}</upnp:album>${artUrl?`<upnp:albumArtURI>${xmlEscape(artUrl)}</upnp:albumArtURI>`:""}<upnp:class>object.item.audioItem.musicTrack</upnp:class><res protocolInfo="http-get:*:${xmlEscape(mime)}:*" duration="${h}:${m}:${ss}">${xmlEscape(mediaUrl)}</res></item></DIDL-Lite>`;
  const set=await upnpAvTransportAction({ip:deviceIp,action:"SetAVTransportURI",innerXml:`<InstanceID>0</InstanceID><CurrentURI>${soapEscape(mediaUrl)}</CurrentURI><CurrentURIMetaData>${soapEscape(didl)}</CurrentURIMetaData>`});
  if(!set.ok) return {...set,step:"SetAVTransportURI"};
  const play=await upnpAvTransportAction({ip:deviceIp,action:"Play",innerXml:"<InstanceID>0</InstanceID><Speed>1</Speed>"});
  return {...play,step:play.ok?"Play":"Play",url:mediaUrl,artUrl};
});


// ---- Internet Radio UPnP metadata + artwork (v3.0.7.45) ----
function fetchRadioArtwork(url, redirects=0) {
  return new Promise((resolve)=>{
    try {
      const target=new URL(String(url||""));
      const mod=target.protocol==="https:" ? require("https") : http;
      const req=mod.get(target,{timeout:5000,headers:{"User-Agent":"airControl/3.0.7.45","Accept":"image/*"}},res=>{
        if (res.statusCode>=300 && res.statusCode<400 && res.headers.location && redirects<4) {
          res.resume();
          const next=new URL(res.headers.location,target).toString();
          return fetchRadioArtwork(next,redirects+1).then(resolve);
        }
        if (res.statusCode<200 || res.statusCode>=300) { res.resume(); return resolve(null); }
        const chunks=[]; let size=0; const limit=5*1024*1024;
        res.on("data",c=>{ size+=c.length; if(size<=limit) chunks.push(c); });
        res.on("end",()=>{
          if(size>limit) return resolve(null);
          const data=Buffer.concat(chunks); if(!data.length) return resolve(null);
          resolve({data,mime:String(res.headers["content-type"]||"image/jpeg").split(";")[0]});
        });
      });
      req.on("timeout",()=>req.destroy()); req.on("error",()=>resolve(null));
    } catch { resolve(null); }
  });
}
ipcMain.handle("radio:upnpPlay", async (_e,{deviceIp,url,title,artist,album,artUrl}={})=>{
  const streamUrl=String(url||"").trim();
  if(!deviceIp || !streamUrl) return {ok:false,error:"Missing device IP or radio stream URL"};
  startLocalMediaServer();
  const lanIp=await routeAddressFor(deviceIp); if(!lanIp) return {ok:false,error:"Could not determine the computer LAN address"};
  let playerArtUrl="";
  if(artUrl){
    const key=crypto.createHash("sha1").update(String(artUrl)).digest("hex");
    if(!radioArtwork.has(key)) { const art=await fetchRadioArtwork(artUrl); if(art) radioArtwork.set(key,art); }
    if(radioArtwork.has(key)) playerArtUrl=`http://${lanIp}:${localMediaPort}/radio-cover/${key}`;
  }
  const didl=`<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/"><item id="0" parentID="0" restricted="1"><dc:title>${xmlEscape(title||"Internet Radio")}</dc:title><dc:creator>${xmlEscape(artist||"")}</dc:creator><upnp:artist>${xmlEscape(artist||"")}</upnp:artist><upnp:album>${xmlEscape(album||"")}</upnp:album>${playerArtUrl?`<upnp:albumArtURI>${xmlEscape(playerArtUrl)}</upnp:albumArtURI>`:""}<upnp:class>object.item.audioItem.audioBroadcast</upnp:class><res protocolInfo="http-get:*:audio/mpeg:*">${xmlEscape(streamUrl)}</res></item></DIDL-Lite>`;
  const set=await upnpAvTransportAction({ip:deviceIp,action:"SetAVTransportURI",innerXml:`<InstanceID>0</InstanceID><CurrentURI>${soapEscape(streamUrl)}</CurrentURI><CurrentURIMetaData>${soapEscape(didl)}</CurrentURIMetaData>`});
  if(!set.ok) return {...set,step:"SetAVTransportURI"};
  const play=await upnpAvTransportAction({ip:deviceIp,action:"Play",innerXml:"<InstanceID>0</InstanceID><Speed>1</Speed>"});
  return {...play,step:"Play",url:streamUrl,artUrl:playerArtUrl};
});

// v4.1.0 — automatic LAN discovery for airControl devices.
// Uses SSDP/UPnP first, then a lightweight scan of the local /24 for the
// known airCloud/Linkplay control ports. Every candidate is verified by its
// real getStatusEx API before it is returned to the renderer.
function localIpv4Subnets() {
  const out = [];
  for (const list of Object.values(os.networkInterfaces())) {
    for (const a of (list || [])) {
      if (a && a.family === "IPv4" && !a.internal && /^\d+\.\d+\.\d+\.\d+$/.test(a.address)) {
        const p = a.address.split(".");
        out.push({ address:a.address, prefix:`${p[0]}.${p[1]}.${p[2]}` });
      }
    }
  }
  return [...new Map(out.map(x=>[x.prefix,x])).values()];
}

function ssdpDiscover(timeout=1400, onCandidate=null) {
  return new Promise((resolve) => {
    const found = new Set();
    const sockets = [];
    const emit = ip => {
      if (!ip || !/^\d+\.\d+\.\d+\.\d+$/.test(ip) || found.has(ip)) return;
      found.add(ip);
      try { onCandidate?.(ip); } catch {}
    };
    const message = Buffer.from([
      "M-SEARCH * HTTP/1.1",
      "HOST: 239.255.255.250:1900",
      'MAN: "ssdp:discover"',
      "MX: 1",
      "ST: ssdp:all",
      "", ""
    ].join("\r\n"));
    const finish = () => { for (const s of sockets) { try{s.close();}catch{} } resolve([...found]); };
    const nets = localIpv4Subnets();
    if (!nets.length) return resolve([]);
    for (const nic of nets) {
      try {
        const sock = dgram.createSocket("udp4"); sockets.push(sock);
        sock.on("message", (msg, rinfo) => {
          if (rinfo?.address) emit(rinfo.address);
          const m = String(msg||"").match(/^LOCATION:\s*https?:\/\/([^\/:\s]+)/im);
          if (m?.[1]) emit(m[1]);
        });
        sock.on("error", ()=>{});
        sock.bind(0, nic.address, () => {
          try { sock.setMulticastInterface(nic.address); sock.send(message,1900,"239.255.255.250"); } catch {}
        });
      } catch {}
    }
    setTimeout(finish, Math.max(600, Number(timeout)||1400));
  });
}

function tcpOpen(ip, port, timeout=110) {
  return new Promise(resolve => {
    const s = new net.Socket(); let done=false;
    const finish = ok => { if(done)return; done=true; try{s.destroy();}catch{} resolve(ok); };
    s.setTimeout(timeout); s.once("connect",()=>finish(true)); s.once("timeout",()=>finish(false)); s.once("error",()=>finish(false));
    try{s.connect(port,ip);}catch{finish(false);}
  });
}

async function probeDiscoveredIp(ip, timeout=650) {
  const lp = await linkplayAutoProbe({ip, command:"getStatusEx", preferredProtocol:"http", preferredPort:80, timeout});
  if (lp?.ok && lp.data && typeof lp.data === "object") {
    const d=lp.data;
    return {ip, protocol:lp.protocol||"http", port:Number(lp.port)||80, deviceType:"airScope",
      name:d.DeviceName||d.GroupName||d.project||"airScope Linkplay", model:d.hardware||d.project||"Linkplay",
      uuid:d.uuid||d.upnp_uuid||"", hardware:d.hardware||"", project:d.project||""};
  }
  for (const endpoint of [{protocol:"http",port:8000},{protocol:"https",port:8443}]) {
    try {
      const r=await requestDevice({ip,port:endpoint.port,protocol:endpoint.protocol,instruct:"getStatusEx",apiStyle:"aircloud",timeout});
      if(r?.ok && r.data && typeof r.data === "object") {
        const d=r.data;
        return {ip,protocol:endpoint.protocol,port:endpoint.port,deviceType:"airCloud",
          name:d.DevName||d.UserDevName||d.DeviceName||d.ProjectName||"airCloud Device",
          model:d.ProjectName||d.project||"CLOUDIX",uuid:d.uuid||d.UUID||"",hardware:d.hardware||"",project:d.ProjectName||d.project||""};
      }
    } catch {}
  }
  return null;
}

async function discoverAirControlDevices(event) {
  // v4.2.2 Progressive Discovery: emit each verified device immediately.
  // SSDP and fast /24 candidate scan run concurrently; no phase blocks another.
  const found = new Map();
  const probing = new Set();
  const emitDevice = (d, method) => {
    if (!d) return;
    const key=(d.uuid||"").toLowerCase() || `${d.hardware||d.project||d.model||""}|${d.ip}`;
    const item={...d,discoveryMethod:method};
    if (!found.has(key)) {
      found.set(key,item);
      try { event?.sender?.send("device:discovery-device", item); } catch {}
    }
  };
  const probeOne = async (ip, method) => {
    if (!ip || probing.has(ip)) return;
    probing.add(ip);
    try { emitDevice(await probeDiscoveredIp(ip, 600), method); } finally { probing.delete(ip); }
  };

  // SSDP starts now. Every response is probed immediately, without waiting for MX timeout.
  const ssdpPromise = ssdpDiscover(1000, ip => { void probeOne(ip, "SSDP + API"); });

  // Fast candidate pass across /24. We only API-probe hosts exposing a known control port.
  const ips=[];
  for (const nic of localIpv4Subnets()) for(let i=1;i<255;i++) {
    const ip=`${nic.prefix}.${i}`; if(ip!==nic.address) ips.push(ip);
  }
  let cursor=0;
  const worker=async()=>{
    while(cursor<ips.length){
      const ip=ips[cursor++];
      const open=await Promise.all([80,443,8000,8443].map(p=>tcpOpen(ip,p,110)));
      if(open.some(Boolean)) await probeOne(ip,"Linkplay API scan");
    }
  };
  const scanPromise=Promise.all(Array.from({length:Math.min(96,ips.length)},worker));
  await Promise.all([ssdpPromise,scanPromise]);
  // Let probes launched by late SSDP packets finish, but never hold UI for minutes.
  const deadline=Date.now()+1800;
  while(probing.size && Date.now()<deadline) await new Promise(r=>setTimeout(r,40));
  return [...found.values()].sort((a,b)=>a.ip.localeCompare(b.ip,undefined,{numeric:true}));
}
ipcMain.handle("device:discover", async (event)=>({ok:true,devices:await discoverAirControlDevices(event)}));

// Diagnostic endpoint: returns unfiltered SSDP announcements/responses so we
// can compare Simple DLNA, WiiM and Linkplay behavior without guessing.
ipcMain.handle("discovery:ssdpDebug", async ()=>({ok:true,responses:await ssdpResponses(2200)}));

// v4.2.0 — Network Music Sources discovery.
// DLNA/UPnP MediaServers are discovered from SSDP LOCATION descriptions.
// SMB hosts are shown when TCP/445 is reachable; browsing/authentication is a later layer.
function ssdpResponses(timeout=1800) {
  // v4.2.3: some UPnP servers do not answer ST:ssdp:all reliably.
  // Ask explicitly for the common MediaServer/ContentDirectory targets as well,
  // and also listen on multicast port 1900 for NOTIFY advertisements while the
  // active M-SEARCH burst is running.
  return new Promise(resolve => {
    const rows=[]; const seen=new Set(); const sockets=[];
    const targets=[
      "ssdp:all",
      "upnp:rootdevice",
      "urn:schemas-upnp-org:device:MediaServer:1",
      "urn:schemas-upnp-org:device:MediaServer:2",
      "urn:schemas-upnp-org:service:ContentDirectory:1",
      "urn:schemas-upnp-org:service:ContentDirectory:2"
    ];
    const addRow=(msg,rinfo,source="response")=>{
      const raw=String(msg||""); const headers={};
      raw.split(/\r?\n/).slice(1).forEach(line=>{const i=line.indexOf(":");if(i>0)headers[line.slice(0,i).trim().toLowerCase()]=line.slice(i+1).trim()});
      const location=headers.location||"";
      const st=headers.st||headers.nt||"";
      const key=`${rinfo?.address||""}|${location}|${headers.usn||""}|${st}`;
      if(!seen.has(key)){seen.add(key);rows.push({ip:rinfo?.address||"",location,st,server:headers.server||"",usn:headers.usn||"",source,rawStart:raw.split(/\r?\n/)[0]||""})}
    };
    const finish=()=>{for(const x of sockets){try{x.close()}catch{}} resolve(rows)};
    const nets=localIpv4Subnets();
    if(!nets.length) return resolve([]);

    // Active search: one socket per interface, several ST values. Responses are
    // accepted immediately and deduplicated later by LOCATION/USN.
    for(const nic of nets) try {
      const sock=dgram.createSocket({type:"udp4",reuseAddr:true}); sockets.push(sock);
      sock.on("message",(msg,rinfo)=>addRow(msg,rinfo,"M-SEARCH"));
      sock.on("error",()=>{});
      sock.bind(0,nic.address,()=>{
        try { sock.setMulticastInterface(nic.address); } catch {}
        targets.forEach((st,i)=>setTimeout(()=>{
          const message=Buffer.from(["M-SEARCH * HTTP/1.1","HOST: 239.255.255.250:1900",'MAN: "ssdp:discover"',"MX: 1",`ST: ${st}`,"",""] .join("\r\n"));
          try{sock.send(message,1900,"239.255.255.250")}catch{}
        },i*45));
      });
    } catch {}

    // Passive advertisements: useful for servers that announce with NOTIFY but
    // are selective/buggy when replying to ssdp:all.
    try {
      const passive=dgram.createSocket({type:"udp4",reuseAddr:true}); sockets.push(passive);
      passive.on("message",(msg,rinfo)=>addRow(msg,rinfo,"NOTIFY")); passive.on("error",()=>{});
      passive.bind(1900,"0.0.0.0",()=>{
        for(const nic of nets) try{passive.addMembership("239.255.255.250",nic.address)}catch{}
      });
    } catch {}
    setTimeout(finish,Math.max(1200,Number(timeout)||1800));
  });
}
function fetchText(url, timeout=1800) {
  return new Promise(resolve=>{try{const u=new URL(url);const lib=u.protocol==="https:"?https:http;const req=lib.get(u,{rejectUnauthorized:false,timeout},res=>{let body="";res.setEncoding("utf8");res.on("data",c=>{if(body.length<1024*1024)body+=c});res.on("end",()=>resolve({ok:res.statusCode>=200&&res.statusCode<300,status:res.statusCode,body,url}))});req.on("timeout",()=>req.destroy());req.on("error",()=>resolve({ok:false,body:"",url}))}catch{resolve({ok:false,body:"",url})}})
}
const xmlText=(xml,tag)=>{const m=String(xml||"").match(new RegExp(`<(?:(?:\\w+):)?${tag}[^>]*>([\\s\\S]*?)<\\/(?:(?:\\w+):)?${tag}>`,`i`));return m?m[1].replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g,"$1").replace(/&amp;/g,"&").replace(/&lt;/g,"<").replace(/&gt;/g,">").replace(/&quot;/g,'"').trim():""};
function resolveUrl(base,value){try{return new URL(value,base).toString()}catch{return value||""}}
async function discoverNetworkMusicSources(){
  const responses=await ssdpResponses(1100); const byLocation=new Map();
  for(const r of responses) if(r.location&&!byLocation.has(r.location)) byLocation.set(r.location,r);
  const dlna=[];
  await Promise.all([...byLocation].map(async([location,r])=>{
    const x=await fetchText(location); if(!x.ok)return;
    const xml=x.body; const type=xmlText(xml,"deviceType");
    if(!/MediaServer/i.test(type) && !/ContentDirectory/i.test(xml))return;
    const services=[...xml.matchAll(/<service>([\s\S]*?)<\/service>/gi)].map(m=>m[1]);
    const cd=services.find(v=>/ContentDirectory/i.test(xmlText(v,"serviceType")));
    dlna.push({kind:"dlna",ip:r.ip,name:xmlText(xml,"friendlyName")||r.server||r.ip,manufacturer:xmlText(xml,"manufacturer"),model:xmlText(xml,"modelName"),udn:xmlText(xml,"UDN")||r.usn,location,controlUrl:cd?resolveUrl(location,xmlText(cd,"controlURL")):""});
  }));
  const smb=[]; const jobs=[];
  for(const nic of localIpv4Subnets()) for(let i=1;i<255;i++){const ip=`${nic.prefix}.${i}`;if(ip!==nic.address)jobs.push(ip)}
  let cursor=0; const worker=async()=>{while(cursor<jobs.length){const ip=jobs[cursor++];if(await tcpOpen(ip,445,110)){let name="";try{name=(await require("dns").promises.reverse(ip))[0]||""}catch{} smb.push({kind:"smb",ip,name:name||ip})}}};
  await Promise.all(Array.from({length:Math.min(64,jobs.length)},worker));
  dlna.sort((a,b)=>a.name.localeCompare(b.name)); smb.sort((a,b)=>a.ip.localeCompare(b.ip,undefined,{numeric:true}));
  return {dlna,smb};
}
ipcMain.handle("media:discover", async()=>{try{return {ok:true,...await discoverNetworkMusicSources()}}catch(e){return {ok:false,error:e?.message||String(e),dlna:[],smb:[]}}});


// v4.4.4 — SMB Playback Session FIX. Use smb3-client (SMB 2.1/3.x + NTLMv2)
// instead of the legacy NTLMv1-era client. All failures stay inside IPC and are
// returned to the renderer; they must never escape as Electron main exceptions.
function smbKey({host,share,domain,username}) { return `${host}|${share}|${domain||""}|${username||""}`; }
function smbPublicPath(share,relative=""){
  const cleanShare=String(share||"").trim().replace(/^[/\\]+|[/\\]+$/g,"");
  const cleanRel=String(relative||"").replace(/\\/g,"/").replace(/^\/+|\/+$/g,"");
  return cleanRel?`${cleanShare}/${cleanRel}`:cleanShare;
}
async function smbClientFor(args={}) {
  const host=String(args.host||args.ip||"").trim(), share=String(args.share||"").trim().replace(/^[/\\]+|[/\\]+$/g,"");
  if(!host||!share) throw new Error("SMB server and share name are required");
  // smb3-client authenticates with NTLMv2. For a guest share use guest + blank password.
  const cfg={host,share,domain:String(args.domain||""),username:String(args.username||"").trim()||"guest",password:String(args.password||"")};
  const key=smbKey(cfg); let client=smbClients.get(key);
  if(!client){
    const Client=await loadSmb3Client();
    client=new Client({host:cfg.host,port:445,domain:cfg.domain,username:cfg.username,password:cfg.password});
    try { await client.connect(); } catch(e) { try{await client.close()}catch{}; throw e; }
    smbClients.set(key,client);
  }
  return {client,key,cfg};
}

function smbHostKey({host,domain,username}) { return `${host}|${domain||""}|${username||""}`; }
async function smbHostClientFor(args={}) {
  const host=String(args.host||args.ip||"").trim(); if(!host) throw new Error("SMB server is required");
  const cfg={host,domain:String(args.domain||""),username:String(args.username||"").trim()||"guest",password:String(args.password||"")};
  const key=smbHostKey(cfg); let client=smbHostClients.get(key);
  if(!client){const Client=await loadSmb3Client();client=new Client({host:cfg.host,port:445,domain:cfg.domain,username:cfg.username,password:cfg.password});try{await client.connect()}catch(e){try{await client.close()}catch{};throw e}smbHostClients.set(key,client)}
  return {client,cfg};
}
ipcMain.handle("smb:listShares", async (_e,args={})=>{try{const {client,cfg}=await smbHostClientFor(args);const rows=await client.listShares();const shares=(rows||[]).map(x=>({name:String(x?.name||""),comment:String(x?.comment||""),type:x?.type})).filter(x=>x.name&&!/^(IPC\$|ADMIN\$|[A-Z]\$)$/i.test(x.name)).sort((a,b)=>a.name.localeCompare(b.name,undefined,{numeric:true,sensitivity:"base"}));return {ok:true,host:cfg.host,shares}}catch(e){console.warn("SMB listShares failed:",e?.code||"",e?.message||e);return {ok:false,error:smbFriendlyError(e),shares:[]}}});

function smbJoin(a,b){return [String(a||"").replace(/[\\/]+$/,"") ,String(b||"").replace(/^[\\/]+/,"")].filter(Boolean).join("/");}
function smbAudioMime(name){return mimeForAudio(String(name||""));}
function smbFriendlyError(e){
  const code=e?.code||e?.statusName||""; const msg=e?.message||String(e||"SMB connection failed");
  if(code==="EACCES"||/logon|auth|credential|access denied/i.test(msg)) return "SMB authentication failed. Check username, password and domain. For a guest share leave password blank.";
  if(code==="ECONNREFUSED") return "SMB connection refused on TCP 445.";
  if(code==="ENOENT") return "SMB share or folder was not found.";
  return `${code?code+": ":""}${msg}`;
}
ipcMain.handle("smb:browse", async (_e,args={})=>{try{
  const {client,cfg}=await smbClientFor(args); const folder=String(args.path||"").replace(/^[/\\]+|[/\\]+$/g,"");
  const rows=await client.readdir(smbPublicPath(cfg.share,folder),{withFileTypes:true});
  const items=(rows||[]).map(x=>{const name=String(x?.name||x||""); const isDirectory=typeof x?.isDirectory==="function"?x.isDirectory():Boolean(x?.isDirectory); const full=smbJoin(folder,name); return {kind:isDirectory?"container":"file",name,title:name.replace(/\.[^.]+$/,"") ,path:full,size:Number(x?.size)||0,isDirectory,playable:!isDirectory&&AUDIO_EXTS.has(path.extname(name).toLowerCase())};}).filter(x=>x.isDirectory||x.playable).sort((a,b)=>(b.isDirectory-a.isDirectory)||a.name.localeCompare(b.name,undefined,{numeric:true,sensitivity:"base"}));
  // Dirent does not necessarily carry size; fetch stat only for playable files.
  await Promise.all(items.filter(x=>!x.isDirectory).map(async x=>{try{const st=await client.stat(smbPublicPath(cfg.share,x.path));x.size=Number(st?.size)||0}catch{}}));
  return {ok:true,host:cfg.host,share:cfg.share,path:folder,items};
}catch(e){console.warn("SMB browse failed:",e?.code||"",e?.message||e);return {ok:false,error:smbFriendlyError(e),items:[]}}});
// v4.4.8 — SMB Playback OS Bridge FIX.
// smb3-client 0.2.0 is kept for discovery/share enumeration/browse (verified working),
// but the tested guest server rejects its file CREATE/READ with STATUS_FILE_INVALID.
// Playback therefore copies the selected file through the host OS SMB client into
// airControl's temp cache, then uses the already proven HTTP + AVTransport path.
const {spawn}=require("node:child_process");
function runProcess(cmd,args,opts={}){return new Promise((resolve,reject)=>{const cp=spawn(cmd,args,{...opts,stdio:["ignore","pipe","pipe"]});let out="",err="";cp.stdout?.on("data",d=>out+=d);cp.stderr?.on("data",d=>err+=d);cp.on("error",reject);cp.on("close",code=>code===0?resolve({out,err}):reject(new Error(`${cmd} exited ${code}: ${err||out}`)))});}
async function copySmbViaOs(cfg,filePath,cachePath,status){
  const rel=String(filePath||"").replace(/\\/g,"/").replace(/^\/+/,"");
  if(process.platform==="darwin"){
    const mountDir=path.join(app.getPath("temp"),`airControl-smb-${crypto.randomUUID()}`);
    await fs.promises.mkdir(mountDir,{recursive:true});
    const user=encodeURIComponent(cfg.username||"guest");
    const pass=encodeURIComponent(cfg.password||"");
    const share=encodeURIComponent(cfg.share);
    const auth=cfg.password?`${user}:${pass}`:user;
    try{
      status({ok:true,step:"SMB OS MOUNT"});
      await runProcess("/sbin/mount_smbfs",[`//${auth}@${cfg.host}/${share}`,mountDir]);
      const source=path.join(mountDir,...rel.split("/").filter(Boolean));
      status({ok:true,step:"SMB OS COPY",path:rel});
      await fs.promises.copyFile(source,cachePath);
    }finally{
      try{await runProcess("/sbin/umount",[mountDir])}catch{}
      try{await fs.promises.rm(mountDir,{recursive:true,force:true})}catch{}
    }
    return;
  }
  if(process.platform==="win32"){
    const root=`\\\\${cfg.host}\\${cfg.share}`;
    const source=`${root}\\${rel.replace(/\//g,"\\")}`;
    status({ok:true,step:"SMB OS CONNECT"});
    const netArgs=["use",root];
    if(cfg.password) netArgs.push(cfg.password); else netArgs.push("");
    netArgs.push(`/user:${cfg.domain?cfg.domain+"\\":""}${cfg.username||"guest"}`,"/persistent:no");
    try{await runProcess("net.exe",netArgs)}catch(e){if(!/1219|already/i.test(String(e?.message||e)))throw e}
    try{status({ok:true,step:"SMB OS COPY",path:rel});await fs.promises.copyFile(source,cachePath)}finally{try{await runProcess("net.exe",["use",root,"/delete","/y"])}catch{}}
    return;
  }
  throw new Error("SMB playback OS bridge is currently implemented for macOS and Windows");
}
ipcMain.on("smb:play", (event,args={})=>{
  const sender=event.sender; const jobId=crypto.randomUUID();
  const status=(payload)=>{try{if(!sender.isDestroyed())sender.send("smb:play-status",{jobId,...payload})}catch{}};
  void (async()=>{let cachePath="";try{
    const host=String(args.host||args.ip||"").trim(); const share=String(args.share||"").trim().replace(/^[/\\]+|[/\\]+$/g,""); const filePath=String(args.path||"");
    if(!host||!share||!filePath)throw new Error("SMB server, share and file path are required");
    const cfg={host,share,domain:String(args.domain||""),username:String(args.username||"").trim()||"guest",password:String(args.password||"")};
    startLocalMediaServer();
    const id=crypto.createHash("sha1").update(`${host}|${share}|${filePath}|${Date.now()}`).digest("hex"); const ext=path.extname(filePath)||".bin"; const mime=smbAudioMime(filePath);
    const cacheDir=path.join(app.getPath("temp"),"airControl-smb-cache"); await fs.promises.mkdir(cacheDir,{recursive:true}); cachePath=path.join(cacheDir,`${id}${ext}`);
    status({ok:true,step:"SMB OS BRIDGE"}); await copySmbViaOs(cfg,filePath,cachePath,status);
    const st=await fs.promises.stat(cachePath); if(!st.size)throw new Error("SMB file is empty or could not be copied"); localMediaFiles.set(id,cachePath); status({ok:true,step:"CACHE READY",bytes:st.size});
    const lanIp=await routeAddressFor(args.deviceIp); if(!lanIp)throw new Error("Could not determine the computer LAN address"); const mediaUrl=`http://${lanIp}:${localMediaPort}/media/${id}`;
    const title=String(args.title||path.basename(filePath,path.extname(filePath))); const didl=`<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/"><item id="0" parentID="0" restricted="1"><dc:title>${xmlEscape(title)}</dc:title><upnp:class>object.item.audioItem.musicTrack</upnp:class><res protocolInfo="http-get:*:${xmlEscape(mime)}:*">${xmlEscape(mediaUrl)}</res></item></DIDL-Lite>`;
    status({ok:true,step:"AVTransport"}); const set=await upnpAvTransportAction({ip:args.deviceIp,action:"SetAVTransportURI",innerXml:`<InstanceID>0</InstanceID><CurrentURI>${soapEscape(mediaUrl)}</CurrentURI><CurrentURIMetaData>${soapEscape(didl)}</CurrentURIMetaData>`}); if(!set.ok)throw new Error(set.error||"SetAVTransportURI failed");
    const play=await upnpAvTransportAction({ip:args.deviceIp,action:"Play",innerXml:"<InstanceID>0</InstanceID><Speed>1</Speed>"}); if(!play.ok)throw new Error(play.error||"Play failed"); status({ok:true,done:true,step:"PLAYING",url:mediaUrl});
  }catch(e){if(cachePath){try{await fs.promises.unlink(cachePath)}catch{}}console.warn("SMB play failed:",e?.message||e);status({ok:false,done:true,step:"ERROR",error:smbFriendlyError(e)})}})();
});

// v4.3.0 — browse UPnP/DLNA ContentDirectory and play remote resources.
function decodeXmlEntities(value="") { return String(value).replace(/&lt;/g,"<").replace(/&gt;/g,">").replace(/&quot;/g,'"').replace(/&apos;/g,"'").replace(/&amp;/g,"&"); }
function stripXml(value="") { return decodeXmlEntities(String(value).replace(/<[^>]+>/g," ")).replace(/\s+/g," ").trim(); }
function attrValue(tag,name){ const m=String(tag||"").match(new RegExp(`\\b${name}=["']([^"']*)["']`,`i`)); return m?decodeXmlEntities(m[1]):""; }
function didlField(xml,name){ const m=String(xml||"").match(new RegExp(`<(?:(?:\\w+):)?${name}\\b[^>]*>([\\s\\S]*?)<\\/(?:(?:\\w+):)?${name}>`,`i`)); return m?stripXml(m[1]):""; }
function parseDidl(resultXml){
  const out=[]; const src=String(resultXml||"");
  const re=/<(container|item)\b([^>]*)>([\s\S]*?)<\/\1>/gi; let m;
  while((m=re.exec(src))){
    const kind=m[1].toLowerCase(), attrs=m[2], body=m[3];
    const resources=[...body.matchAll(/<res\b([^>]*)>([\s\S]*?)<\/res>/gi)].map(x=>({url:stripXml(x[2]),protocolInfo:attrValue(x[1],"protocolInfo"),duration:attrValue(x[1],"duration"),size:attrValue(x[1],"size")}));
    const audio=resources.find(r=>/audio\//i.test(r.protocolInfo))||resources.find(r=>/^https?:\/\//i.test(r.url))||resources[0]||null;
    out.push({kind,id:attrValue(attrs,"id"),parentId:attrValue(attrs,"parentID"),title:didlField(body,"title")||"Untitled",artist:didlField(body,"artist")||didlField(body,"creator"),album:didlField(body,"album"),artUrl:didlField(body,"albumArtURI"),upnpClass:didlField(body,"class"),childCount:Number(attrValue(attrs,"childCount")||0),resource:audio,resources});
  }
  return out;
}
function contentDirectoryBrowse({controlUrl,objectId="0",start=0,count=200,timeout=6000}){
  return new Promise(resolve=>{try{
    const u=new URL(controlUrl); const lib=u.protocol==="https:"?https:http;
    const body=`<?xml version="1.0" encoding="utf-8"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:Browse xmlns:u="urn:schemas-upnp-org:service:ContentDirectory:1"><ObjectID>${xmlEscape(objectId)}</ObjectID><BrowseFlag>BrowseDirectChildren</BrowseFlag><Filter>*</Filter><StartingIndex>${Number(start)||0}</StartingIndex><RequestedCount>${Number(count)||200}</RequestedCount><SortCriteria></SortCriteria></u:Browse></s:Body></s:Envelope>`;
    const req=lib.request({hostname:u.hostname,port:u.port||(u.protocol==="https:"?443:80),path:`${u.pathname}${u.search}`,method:"POST",timeout,rejectUnauthorized:false,headers:{"Content-Type":'text/xml; charset="utf-8"',"SOAPAction":'"urn:schemas-upnp-org:service:ContentDirectory:1#Browse"',"Content-Length":Buffer.byteLength(body),"Connection":"close","User-Agent":"airControl/4.3.0"}},res=>{let raw="";res.setEncoding("utf8");res.on("data",c=>raw+=c);res.on("end",()=>{if(res.statusCode<200||res.statusCode>=300)return resolve({ok:false,status:res.statusCode,error:`ContentDirectory HTTP ${res.statusCode}`,raw}); const result=decodeXmlEntities(xmlText(raw,"Result")); resolve({ok:true,status:res.statusCode,items:parseDidl(result),numberReturned:Number(xmlText(raw,"NumberReturned")||0),totalMatches:Number(xmlText(raw,"TotalMatches")||0),updateId:xmlText(raw,"UpdateID")});});});
    req.on("timeout",()=>req.destroy(new Error("ContentDirectory Browse timed out"))); req.on("error",e=>resolve({ok:false,error:e.message,items:[]})); req.end(body);
  }catch(e){resolve({ok:false,error:e.message,items:[]})}});
}
ipcMain.handle("media:browse", async (_e,args={})=>{ if(!args.controlUrl)return {ok:false,error:"MediaServer has no ContentDirectory control URL",items:[]}; return contentDirectoryBrowse(args); });
ipcMain.handle("media:upnpPlay", async (_e,{deviceIp,url,title,artist,album,artUrl,protocolInfo,duration}={})=>{
  const mediaUrl=String(url||"").trim(); if(!deviceIp||!mediaUrl)return {ok:false,error:"Missing player IP or media URL"};
  const dur=String(duration||""); const pi=String(protocolInfo||"http-get:*:audio/mpeg:*");
  const didl=`<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/"><item id="0" parentID="0" restricted="1"><dc:title>${xmlEscape(title||"DLNA Track")}</dc:title><dc:creator>${xmlEscape(artist||"")}</dc:creator><upnp:artist>${xmlEscape(artist||"")}</upnp:artist><upnp:album>${xmlEscape(album||"")}</upnp:album>${artUrl?`<upnp:albumArtURI>${xmlEscape(artUrl)}</upnp:albumArtURI>`:""}<upnp:class>object.item.audioItem.musicTrack</upnp:class><res protocolInfo="${xmlEscape(pi)}"${dur?` duration="${xmlEscape(dur)}"`:""}>${xmlEscape(mediaUrl)}</res></item></DIDL-Lite>`;
  const set=await upnpAvTransportAction({ip:deviceIp,action:"SetAVTransportURI",innerXml:`<InstanceID>0</InstanceID><CurrentURI>${soapEscape(mediaUrl)}</CurrentURI><CurrentURIMetaData>${soapEscape(didl)}</CurrentURIMetaData>`}); if(!set.ok)return {...set,step:"SetAVTransportURI"};
  const play=await upnpAvTransportAction({ip:deviceIp,action:"Play",innerXml:"<InstanceID>0</InstanceID><Speed>1</Speed>"}); return {...play,step:"Play",url:mediaUrl,artUrl:artUrl||""};
});
