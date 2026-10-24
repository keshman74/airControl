import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const moduleSource = fs.readFileSync(path.join(here, "../src/services/deviceDrivers.js"), "utf8");
const { parseLinkplayStatus } = await import(
  "data:text/javascript;base64," + Buffer.from(moduleSource).toString("base64")
);
const ip = "192.168.0.21";
const raw = `https://${ip}/data/AirplayArtWorkData.jpeg`;
const oldGood = "data:image/jpeg;base64,b2xkLWNvdmVy";
const nextGood = "data:image/jpeg;base64,bmV3LWNvdmVy";
const player = {mode:"1", status:"play", Title:"556C747261", Artist:"4269636570", Album:"476173"};

const transient = parseLinkplayStatus({}, player,
  {ip, source:"AirPlay", track:{title:"Ultra", artist:"Bicep", art:oldGood}},
  {metaData:{title:"Ultra", albumArtURI:raw}}, {art:raw});
assert.equal(transient.track.art, oldGood,
  "transient fetch miss must retain the last resolved AirPlay cover");

const firstLoadMiss = parseLinkplayStatus({}, player,
  {ip, source:"AirPlay", track:{title:"Ultra", art:raw}},
  {metaData:{title:"Ultra", albumArtURI:raw}}, {art:raw});
assert.equal(firstLoadMiss.track.art, "",
  "a raw local self-signed URL must never reach Chromium");

const changedTrack = parseLinkplayStatus({}, {...player, Title:"4E657874"},
  {ip, source:"AirPlay", track:{title:"Ultra", art:oldGood}},
  {metaData:{title:"Next", albumArtURI:raw}}, {art:raw});
assert.equal(changedTrack.track.art, "",
  "a new track with unresolved artwork must not show the previous cover");

const successful = parseLinkplayStatus({}, player,
  {ip, source:"AirPlay", track:{title:"Ultra", art:oldGood}},
  {metaData:{title:"Ultra", albumArtURI:nextGood}}, {});
assert.equal(successful.track.art, nextGood,
  "a successfully resolved data URL must replace the old cover");


const a31Relative = "/data/airplay_f67a80954965fd2f79a144f41d4bbe38.jpg";
const a31Absolute = `http://${ip}${a31Relative}`;
const relativeMiss = parseLinkplayStatus({}, player,
  {ip, source:"AirPlay", track:{title:"Ultra", art:oldGood}},
  {metaData:{title:"Ultra", albumArtURI:a31Relative}}, {art:a31Relative});
assert.equal(relativeMiss.track.art, oldGood,
  "transient A31 relative artwork failure must retain the last good image");

const relativeFirstMiss = parseLinkplayStatus({}, player,
  {ip, source:"AirPlay", track:{title:"Ultra", art:a31Relative}},
  {metaData:{title:"Ultra", albumArtURI:a31Relative}}, {art:a31Relative});
assert.equal(relativeFirstMiss.track.art, "",
  "raw relative A31 artwork must never reach Chromium");

const absoluteFirstMiss = parseLinkplayStatus({}, player,
  {ip, source:"AirPlay", track:{title:"Ultra", art:a31Absolute}},
  {metaData:{title:"Ultra", albumArtURI:a31Absolute}}, {art:a31Absolute});
assert.equal(absoluteFirstMiss.track.art, "",
  "raw absolute A31 artwork URL must never reach Chromium");

console.log("AirPlay artwork stability regression passed.");
