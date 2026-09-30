export const DEVICE_TYPES = {
  AIRCLOUD: "airCloud",
  AIRSCOPE: "airScope"
};

export function deviceTypeOf(device) {
  return device?.deviceType === DEVICE_TYPES.AIRSCOPE ? DEVICE_TYPES.AIRSCOPE : DEVICE_TYPES.AIRCLOUD;
}

export function apiStyleFor(device) {
  return deviceTypeOf(device) === DEVICE_TYPES.AIRSCOPE ? "linkplay" : "aircloud";
}

export function defaultPortFor(deviceType, protocol="http") {
  if (deviceType === DEVICE_TYPES.AIRSCOPE) return protocol === "https" ? 443 : 80;
  return protocol === "https" ? 8443 : 8000;
}

export function defaultDeviceName(deviceType) {
  return deviceType === DEVICE_TYPES.AIRSCOPE ? "airScope Linkplay" : "A33 Device";
}

export function driverLabel(device) {
  return deviceTypeOf(device) === DEVICE_TYPES.AIRSCOPE ? "airScope · Linkplay" : "airCloud · CLOUDIX A33";
}

export function translateCommand(device, command) {
  const raw = String(command || "");
  if (deviceTypeOf(device) !== DEVICE_TYPES.AIRSCOPE) return raw;

  // The Linkplay HTTP API intentionally reuses many setPlayerCmd commands.
  // Translate only syntax/value differences here so the React UI can stay shared.
  if (raw.startsWith("setPlayerCmd:switchmode:")) {
    const value = raw.slice("setPlayerCmd:switchmode:".length);
    const map = {
      "Network": "wifi",
      "Bluetooth": "bluetooth",
      "AUX In": "line-in",
      "LineIn": "line-in",
      "USB Disk": "udisk",
      "USBDisk": "udisk",
      "Optical In": "optical",
      "OpticalIn": "optical",
      "RCA In": "line-in",
      "RCAIn": "line-in",
      "RCA 2 In": "line-in2",
      "PHONO In": "line-in",
      "Phono In": "line-in",
      "USBDAC": "PCUSB",
      "USB DAC": "PCUSB"
    };
    return `setPlayerCmd:switchmode:${map[value] || value}`;
  }

  // Shared USB UI -> native Linkplay local-storage commands.
  // Linkplay/Arylic firmware exposes USB files through getLocalPlayList and
  // starts an item by its zero-based local-list index.
  if (raw === "getUsbSongList") return "getLocalPlayList";
  if (raw.startsWith("selectUsbTracks:")) {
    return `setPlayerCmd:playLocalList:${raw.slice("selectUsbTracks:".length)}`;
  }
  if (raw === "playFromUsbDisk") return "setPlayerCmd:switchmode:udisk";

  // A33 uses setplay, while Linkplay documents seek.
  if (raw.startsWith("setPlayerCmd:setplay:")) {
    return `setPlayerCmd:seek:${raw.slice("setPlayerCmd:setplay:".length)}`;
  }

  // A33-specific relative volume syntax -> Linkplay documented syntax.
  if (raw === "setPlayerCmd:RemoteVol++") return "setPlayerCmd:vol++";
  if (raw === "setPlayerCmd:RemoteVol--") return "setPlayerCmd:vol--";

  return raw;
}

function hexToText(value) {
  const s = String(value || "").trim();
  if (!s || !/^(?:[0-9a-fA-F]{2})+$/.test(s)) return s;
  try {
    const bytes = new Uint8Array(s.match(/.{2}/g).map(x => parseInt(x,16)));
    return new TextDecoder("utf-8", {fatal:false}).decode(bytes).replace(/\0/g, "").trim();
  } catch { return s; }
}

const LINKPLAY_MODE_SOURCE = {
  "0": "Network",
  "1": "AirPlay",
  "2": "DLNA",
  "10": "Network",
  "11": "USB Disk",
  "20": "Network",
  "31": "Spotify",
  "40": "AUX In",
  "41": "Bluetooth",
  "43": "Optical In",
  "47": "RCA 2 In",
  "51": "USB DAC",
  "99": "Multiroom"
};

export function parseLinkplayStatus(metadata={}, player={}, previous={}, metaInfo={}, upnpInfo={}) {
  const vol = Number(player?.vol);
  const curMs = Number(player?.curpos);
  const totalMs = Number(player?.totlen);
  const mode = String(player?.mode ?? "");
  const source = LINKPLAY_MODE_SOURCE[mode] || previous.source || "Network";
  const status = String(player?.status || "").toLowerCase();
  const ip = metadata?.eth2 || metadata?.apcli0 || previous.ip || "—";
  const networkMode = metadata?.eth2 ? "Ethernet" : (metadata?.apcli0 ? "Wi-Fi" : (previous.networkMode || "—"));

  const rich = metaInfo?.metaData && typeof metaInfo.metaData === "object" ? metaInfo.metaData : (metaInfo || {});
  const upnp = upnpInfo && typeof upnpInfo === "object" ? upnpInfo : {};
  const playerTitle = hexToText(player?.Title);
  const richTitle = String(rich?.title || "").trim();
  const upnpTitle = String(upnp?.title || "").trim();
  // A31 getPlayerStatus is the authoritative source for USB identity. UPnP
  // metadata can lag by one playlist item, which made the footer show N-1.
  const hardware = String(metadata?.hardware || previous.hardware || "").toUpperCase();
  const project = String(metadata?.project || previous.project || "").toUpperCase();
  const isA31 = hardware === "A31" || project.includes("UP2STREAM_PRO_V4");
  const title = isA31
    ? (playerTitle || richTitle || upnpTitle || previous.track?.title || "Nothing playing")
    : (richTitle || upnpTitle || playerTitle || previous.track?.title || "Nothing playing");
  const previousTitle = String(previous.track?.title || "").trim();
  const titleChanged = Boolean(title && previousTitle && title !== previousTitle);
  const sameTrackForArtwork = !richTitle || !playerTitle || richTitle.trim().toLowerCase() === playerTitle.trim().toLowerCase();
  const richArtwork = sameTrackForArtwork ? String(rich?.albumArtURI || rich?.["albumArtURI "] || "").trim() : "";
  const upnpArtwork = String(upnp?.art || "").trim();
  const liveUrl = String(player?.uri || player?.url || rich?.url || upnp?.url || "").trim();
  const playerArtist = hexToText(player?.Artist);
  const playerAlbum = hexToText(player?.Album);
  const artist = isA31
    ? (playerArtist || String(rich?.artist || "").trim() || String(upnp?.artist || "").trim() || (titleChanged ? "" : (previous.track?.artist || "")))
    : (String(rich?.artist || "").trim() || String(upnp?.artist || "").trim() || playerArtist || (titleChanged ? "" : (previous.track?.artist || "")));
  const album = isA31
    ? (playerAlbum || String(rich?.album || "").trim() || String(upnp?.album || "").trim() || (titleChanged ? "" : (previous.track?.album || "")))
    : (String(rich?.album || "").trim() || String(upnp?.album || "").trim() || playerAlbum || (titleChanged ? "" : (previous.track?.album || "")));
  // v4.4.15: for Network/Internet Radio, AVTransport GetPositionInfo is the
  // authoritative artwork source. It survives an airControl restart and is
  // exactly what the player advertises to other controllers. Empty polling
  // values do not erase the last valid cover while the media identity is stable.
  const networkPlayback = source === "Network" || source === "DLNA";
  const art = networkPlayback
    ? (upnpArtwork || richArtwork || (titleChanged ? "" : (previous.track?.art || "")))
    : (richArtwork || upnpArtwork || (titleChanged ? "" : (previous.track?.art || "")));

  return {
    name: metadata?.DeviceName || metadata?.GroupName || previous.name || "airScope Linkplay",
    model: metadata?.hardware || metadata?.project || previous.model || "Linkplay",
    version: metadata?.firmware || previous.version || "—",
    hardware: metadata?.hardware || previous.hardware || "—",
    project: metadata?.project || previous.project || "—",
    uuid: metadata?.uuid || previous.uuid || "",
    volume: Number.isFinite(vol) ? vol : (previous.volume ?? 0),
    maxVolume: 100,
    muted: String(player?.mute ?? "0") === "1",
    source,
    multiroom: String(metadata?.group || "0") === "0" ? "free" : "grouped",
    // Native Linkplay WMRM state. master_ip is authoritative for Slave role;
    // master_uuid is retained separately for diagnostics/identity.
    host: metadata?.master_ip || "0",
    masterIp: metadata?.master_ip || "",
    masterUuid: metadata?.master_uuid || "",
    networkMode,
    tcpIp: ip,
    wlanMac: metadata?.STA_MAC || previous.wlanMac || "—",
    ethMac: (metadata?.ETH_MAC && metadata.ETH_MAC !== "00:00:00:00:00:00") ? metadata.ETH_MAC : (metadata?.MAC || previous.ethMac || "—"),
    bleName: previous.bleName || "—",
    features: previous.features || [],
    track: {
      title,
      artist,
      album,
      art,
      progress: Number.isFinite(curMs) ? Math.max(0, curMs / 1000) : (Number(upnp?.progress) || previous.track?.progress || 0),
      total: Number.isFinite(totalMs) ? Math.max(0, totalMs / 1000) : (Number(upnp?.total) || previous.track?.total || 0),
      playState: status || previous.track?.playState || "",
      streamSource: source,
      service: source,
      url: liveUrl || previous.track?.url || "",
      id: String(player?.plicurr ?? previous.track?.id ?? ""),
      context: previous.track?.context || ""
    },
    rawStatus: {metadata, player},
    lastSeen: Date.now(),
    online: true
  };
}

export function sourcesForDevice(device) {
  if (deviceTypeOf(device) !== DEVICE_TYPES.AIRSCOPE) return null;
  return [
    {label:"Network", value:"Network"},
    {label:"Bluetooth", value:"Bluetooth"},
    {label:"AUX In", value:"AUX In"},
    {label:"USB Disk", value:"USB Disk"},
    {label:"Optical In", value:"OpticalIn"},
    {label:"RCA 2 In", value:"RCA 2 In"},
    {label:"USB DAC", value:"USBDAC"}
  ];
}

export function capabilitiesFor(device) {
  if (deviceTypeOf(device) === DEVICE_TYPES.AIRSCOPE) {
    const hardware = String(device?.hardware || device?.model || "").toUpperCase();
    const project = String(device?.project || "").toUpperCase();
    // A31 uses the verified MCU TCP/8899 tone path. A98/WiiM-class hardware
    // exposes a documented 10-band EQ over the regular Linkplay HTTP API.
    // A97 stays disabled until its own EQ path is verified on real hardware.
    const verifiedA31Eq = hardware === "A31" || project.includes("UP2STREAM_PRO_V4");
    const documentedWiiMEq = hardware.includes("AMLOGIC") || project.includes("WIIM");
    return {
      status:true, player:true, volume:true, source:true, internetRadio:true,
      presets:true, usb:true, bluetooth:true, multiroom:true,
      eq:verifiedA31Eq || documentedWiiMEq, roomEq:false, network:true,
      tcpLiveStatus:false, uart:false
    };
  }
  return {
    status:true, player:true, volume:true, source:true, internetRadio:true,
    presets:true, usb:true, bluetooth:true, multiroom:true,
    eq:true, roomEq:true, network:true,
    tcpLiveStatus:false, uart:false
  };
}
