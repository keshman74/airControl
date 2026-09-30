"use strict";

const net = require("net");

const MAGIC = Buffer.from([0x18, 0x96, 0x18, 0x20]);
const GAP_MS = 220; // Arylic specifies at least 200 ms between commands.

function frame(command) {
  const payload = Buffer.from(command, "utf8");
  const result = Buffer.alloc(20 + payload.length);
  MAGIC.copy(result);
  result.writeUInt32LE(payload.length, 4);
  let checksum = 0;
  for (const byte of payload) checksum = (checksum + byte) >>> 0;
  result.writeUInt32LE(checksum, 8);
  payload.copy(result, 20);
  return result;
}

class A31Session {
  constructor(ip, port, onEvent = () => {}) {
    this.ip = ip;
    this.port = port;
    this.onEvent = onEvent;
    this.socket = null;
    this.connecting = false;
    this.input = Buffer.alloc(0);
    this.queue = [];
    this.pending = null;
    this.lastSent = 0;
    this.pumpTimer = null;
    this.connectTimer = null;
    this.closing = false;
  }

  request({command, timeout = 1100, expectReply = true}) {
    return new Promise(resolve => {
      if (/^MCU\+VOL\+\d{3}$/.test(command)) {
        const keep = [];
        for (const old of this.queue) {
          if (/^MCU\+VOL\+\d{3}$/.test(old.command)) {
            old.resolve({ok:true,coalesced:true,payloads:[],command:old.command});
          } else keep.push(old);
        }
        this.queue = keep;
      }
      this.queue.push({command, timeout, expectReply, resolve});
      this.pump();
    });
  }

  connect() {
    if (this.socket || this.connecting || this.closing) return;
    this.connecting = true;
    let connected = false;
    const socket = net.createConnection({host:this.ip, port:this.port});
    this.socket = socket;
    socket.setNoDelay(true);
    socket.setKeepAlive(true, 30000);
    this.connectTimer = setTimeout(() => socket.destroy(new Error("A31 TCP connect timeout")), 1500);
    socket.on("connect", () => {
      connected = true;
      clearTimeout(this.connectTimer);
      this.connecting = false;
      this.pump();
    });
    socket.on("data", chunk => this.receive(chunk));
    socket.on("error", () => {}); // close handles pending work once.
    socket.on("close", () => {
      clearTimeout(this.connectTimer);
      if (this.socket !== socket) return;
      this.socket = null;
      this.connecting = false;
      this.input = Buffer.alloc(0);
      if (this.pending) this.finish(false, "A31 TCP disconnected");
      if (!connected && this.queue.length) {
        const item = this.queue.shift();
        item.resolve({ok:false,error:"A31 TCP connection failed",payloads:[],command:item.command});
      }
      if (this.queue.length && !this.closing) {
        this.pumpTimer = setTimeout(() => {this.pumpTimer=null;this.pump();}, 1000);
      }
    });
  }

  receive(chunk) {
    this.input = Buffer.concat([this.input, chunk]);
    if (this.input.length > 128 * 1024) this.input = this.input.subarray(-3);
    while (this.input.length >= 20) {
      const at = this.input.indexOf(MAGIC);
      if (at < 0) { this.input = this.input.subarray(-3); return; }
      if (at) this.input = this.input.subarray(at);
      if (this.input.length < 20) return;
      const size = this.input.readUInt32LE(4);
      if (size > 64 * 1024) { this.input = this.input.subarray(1); continue; }
      if (this.input.length < 20 + size) return;
      const expectedChecksum = this.input.readUInt32LE(8);
      const bytes = this.input.subarray(20, 20 + size);
      this.input = this.input.subarray(20 + size);
      let sum = 0;
      for (const byte of bytes) sum = (sum + byte) >>> 0;
      if (sum !== expectedChecksum) continue;
      const payload = bytes.toString("utf8");
      if (this.pending?.expectReply) this.pending.payloads.push(payload);
      this.onEvent({ip:this.ip, payload});
    }
  }

  finish(ok, error = "") {
    const item = this.pending;
    if (!item) return;
    this.pending = null;
    if (item.timer) clearTimeout(item.timer);
    item.resolve({ok, error, payloads:item.payloads, command:item.command});
    this.pump();
  }

  pump() {
    if (this.pending || !this.queue.length) return;
    if (!this.socket || this.socket.destroyed) { this.connect(); return; }
    if (this.connecting) return;
    const remaining = GAP_MS - (Date.now() - this.lastSent);
    if (remaining > 0) {
      if (!this.pumpTimer) this.pumpTimer = setTimeout(() => {
        this.pumpTimer = null;
        this.pump();
      }, remaining);
      return;
    }
    const item = this.queue.shift();
    this.pending = {...item, payloads:[], timer:null};
    this.lastSent = Date.now();
    this.socket.write(frame(item.command), err => {
      if (err) { this.finish(false, err.message); return; }
      if (!item.expectReply) this.pending.timer = setTimeout(() => this.finish(true), 100);
    });
    if (item.expectReply) {
      this.pending.timer = setTimeout(() => this.finish(true), Math.max(250, Number(item.timeout) || 1100));
    }
  }

  close() {
    this.closing = true;
    if (this.pumpTimer) clearTimeout(this.pumpTimer);
    if (this.connectTimer) clearTimeout(this.connectTimer);
    if (this.socket) this.socket.destroy();
    if (this.pending) this.finish(false, "Session closed");
    for (const item of this.queue.splice(0)) item.resolve({ok:false,error:"Session closed",payloads:[]});
  }
}

module.exports = {A31Session, frame};
