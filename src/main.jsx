import React, { useEffect, useMemo, useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import {
  Activity, Bluetooth, ChevronLeft, ChevronRight, CircleUserRound, Disc3, Folder, Gauge, HardDrive,
  Home, Layers3, Link2, Network, Pause, Play, Plus, Radio, RefreshCw, Search, Settings,
  SlidersHorizontal, Speaker, Volume2, VolumeX, Wifi, X
} from "lucide-react";
import "./styles.css";
import packageJson from "../package.json";
import { countRadioClick, findRadioAlternatives, searchRadioStations, topRadioStations } from "./services/radioBrowser.js";
import {
  DEVICE_TYPES, apiStyleFor, capabilitiesFor, defaultDeviceName, defaultPortFor,
  deviceTypeOf, driverLabel, parseLinkplayStatus, sourcesForDevice, translateCommand
} from "./services/deviceDrivers.js";
import platFormaGeometryXml from "./platForma-geometry-v1.xml?raw";

const STORAGE_KEY = "airCloudCTRL.devices.v02";
const SELECTED_KEY = "airCloudCTRL.selected.v02";
const RADIO_FAVORITES_KEY = "airCloudCTRL.radioFavorites.v034";
const RADIO_NOW_PLAYING_KEY = "airCloudCTRL.radioNowPlayingByDevice.v041";
const RADIO_COMPAT_KEY = "airCloudCTRL.radioCompatibility.v0342";
const RADIO_BROWSER_STATE_KEY = "airCloudCTRL.radioBrowserState.v0343";
const RADIO_PAGE_SIZE = 50;
const THEME_KEY = "airCloudCTRL.theme.v1";
const INTERFACE_STYLE_KEY = "airControl.interfaceStyle.v1";
const APP_VERSION = packageJson.version;
const multiroomDiagnosticSignatures = new Map();

function isA33Device(device) {
  if (!device) return false;
  if (deviceTypeOf(device) !== DEVICE_TYPES.AIRCLOUD) return false;
  const project = String(device.project || device.model || "").toLowerCase();
  return project.includes("cl-bopro") || project.includes("a33") || project.includes("acs2");
}

function isA33DirectHttpRadio(device) {
  if (!isA33Device(device) || device.online !== true) return false;
  const source = normalizeSource(device.source);
  const service = String(device?.track?.service || "").trim().toLowerCase();
  return source === "Network" && service === "http_music";
}

const FIRST_REAL_DEVICE = {
  id: "cs8-audio",
  name: "CS-8 Audio",
  model: "CS-8",
  ip: "192.168.0.12",
  protocol: "http",
  port: 8000,
  mock: false,
  deviceType: DEVICE_TYPES.AIRCLOUD,
  online: false,
  volume: 0,
  maxVolume: 100,
  muted: false,
  source: "Network",
  version: "—",
  multiroom: "free",
  networkMode: "—",
  features: [],
  track: null
};

const SOURCES = [
  {label:"Network", value:"Network"},
  {label:"Bluetooth", value:"Bluetooth"},
  {label:"AUX In", value:"AUX In"},
  {label:"USB Disk", value:"USB Disk"},
  {label:"Optical In", value:"OpticalIn"},
  {label:"HDMI ARC", value:"HDMIARC"},
  {label:"RCA In", value:"RCAIn"},
  {label:"RCA 2 In", value:"RCA2 In"},
  {label:"Phono In", value:"PHONO In"}
];

const API_COMMANDS = [
  ["getStatusEx","Device","Get device information"],
  ["wlanGetConnectState","Network","Get Wi-Fi connection state"],
  ["getScanAPs","Network","Scan access points"],
  ["connectToAP:wifiName:wifiPassword","Network","Connect to Wi-Fi"],
  ["getPlayerStatus","Playback","Get playback status"],
  ["setPlayerCmd:play:<URL>","Playback","Play audio URL"],
  ["setPlayerCmd:playlist:songid","Playback","Play playlist song"],
  ["setPlayerCmd:pause","Playback","Pause"],
  ["setPlayerCmd:resume","Playback","Resume"],
  ["setPlayerCmd:onepause","Playback","Toggle pause/play"],
  ["setPlayerCmd:prev","Playback","Previous"],
  ["setPlayerCmd:next","Playback","Next"],
  ["setPlayerCmd:getplay:seconds","Playback","Get playback position"],
  ["setPlayerCmd:setplay:seconds","Playback","Set playback position"],
  ["setPlayerCmd:stop","Playback","Stop"],
  ["setPlayerCmd:vol:value","Volume","Set volume"],
  ["setPlayerCmd:RemoteVol++","Volume","Increase volume"],
  ["setPlayerCmd:RemoteVol--","Volume","Decrease volume"],
  ["setPlayerCmd:mute:mute","Volume","Mute / unmute"],
  ["setPlayerCmd:maximumVolume:maximumVolume","Volume","Set maximum volume"],
  ["setChannel:channel","Playback","Stereo / left / right"],
  ["setPlayerCmd:prompttone:prompt_tone","Device","Prompt tone status"],
  ["setPlayerCmd:loopmode:loopmode","Playback","Set loop mode"],
  ["reboot","Device","Reboot"],
  ["factory","Device","Factory reset"],
  ["shutdown","Device","Shutdown"],
  ["setPlayerCmd:devicename:devicename","Device","Change device name"],
  ["playFromUsbDisk","USB","Play from USB"],
  ["getUsbSongList","USB","Get USB tracks"],
  ["selectUsbTracks:usbSongNum","USB","Select USB track"],
  ["setPlayerCmd:switchmode:switchmode","Source","Switch playback source"],
  ["setDiscoveryBluetooth:dismode","Bluetooth","Bluetooth discovery mode"],
  ["resetBluetoothPairing","Bluetooth","Reset Bluetooth pairing"],
  ["clearBluetoothPairingList","Bluetooth","Clear Bluetooth pairing list"],
  ["getBluetoothName","Bluetooth","Get Bluetooth name"],
  ["modifyBluetoothName:bleName","Bluetooth","Change Bluetooth name"],
  ["multiroom:setHost","Multiroom","Set as host"],
  ["multiroom:setSlave:host_ip","Multiroom","Set as slave"],
  ["multiroom:disconnectSlave","Multiroom","Release slave"],
  ["multiroom:breakUp","Multiroom","Leave / break multiroom"],
  ["multiroom:getInformation","Multiroom","Get multiroom information"],
  ["downloadPromptSound:audioFileName","Prompt","Download prompt sound"],
  ["playPromptSound:audioName:volume","Prompt","Play prompt sound"],
  ["viewServerPromptSound","Prompt","List server prompt sounds"],
  ["viewDevicePromptSound","Prompt","List device prompt sounds"],
  ["deleteSpecifiedAudio:audioPath","Prompt","Delete prompt sound"],
  ["setNetIPSwitchState:switch","Network","Static IP switch"],
  ["setStaticIP:staticIPInfo","Network","Set static IP"],
  ["getEqType","EQ","Get EQ mode"],
  ["eqEnable:eqSwitch","EQ","Enable / select EQ"],
  ["setEqHighAndLowFrequencies:info","EQ","Bass / treble"],
  ["setPresetEq:presetInfo","EQ","Set preset EQ"],
  ["setParameterEq:parametInfo","EQ","Set parameter EQ"],
  ["getEqInfo:eqType","EQ","Get EQ information"],
  ["addCustomEqInfo:addEqInfo","EQ","Add custom EQ"],
  ["delCustomEqInfo:delEqInfo","EQ","Delete custom EQ"]
];

function loadDevices() {
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || "null");
    if (Array.isArray(saved) && saved.length) {
      // v4.4.19: persisted zones are history, not proof that a device is
      // currently reachable. Discovery/getStatusEx must explicitly promote
      // them back to Online after each application start.
      return saved.map(d => d?.mock ? d : {...d, online:false});
    }
  } catch {}
  return [FIRST_REAL_DEVICE];
}

function formatTime(sec=0) {
  const n = Math.max(0, Number(sec) || 0);
  const m = Math.floor(n/60), s = Math.floor(n%60);
  return `${String(m).padStart(2,"0")}:${String(s).padStart(2,"0")}`;
}

function numberOr(value, fallback=0) {
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

function decodeMaybeHex(value) {
  const raw = String(value || "").trim();
  if (!raw || !/^(?:[0-9a-fA-F]{2})+$/.test(raw)) return raw;
  try {
    const bytes = new Uint8Array(raw.match(/.{2}/g).map(x => parseInt(x, 16)));
    return new TextDecoder("utf-8", {fatal:false}).decode(bytes).replace(/\0/g, "").trim();
  } catch { return raw; }
}

function repairUtf8Mojibake(value) {
  const raw = String(value || "");
  if (!/[ÃÂÐÑ]/.test(raw)) return raw;
  try {
    const bytes = Uint8Array.from([...raw].map(ch => ch.charCodeAt(0) & 0xff));
    const fixed = new TextDecoder("utf-8", {fatal:true}).decode(bytes);
    return fixed || raw;
  } catch { return raw; }
}

function isPlaying(state="") {
  return ["plays","play","playing","1"].includes(String(state).toLowerCase());
}

const SOURCE_ALIASES = {
  "Network": "Network",
  "Bluetooth": "Bluetooth",
  "AUX In": "AUX In",
  "LineIn": "AUX In",
  "USB Disk": "USB Disk",
  "USBDisk": "USB Disk",
  "Optical In": "Optical In",
  "OpticalIn": "Optical In",
  "HDMI ARC": "HDMI ARC",
  "HDMIARC": "HDMI ARC",
  "RCA In": "RCA In",
  "RCAIn": "RCA In",
  "RCA 2 In": "RCA 2 In",
  "PHONO In": "Phono In",
  "Phono In": "Phono In"
};

function normalizeSource(value) {
  const raw = String(value || "").trim();
  return SOURCE_ALIASES[raw] || raw;
}

function reportedSource(info, previousSource) {
  for (const candidate of [info?.DevModel, info?.DevMode, info?.StreamSource]) {
    const normalized = normalizeSource(candidate);
    if (SOURCES.some(s => normalizeSource(s.label) === normalized || normalizeSource(s.value) === normalized)) {
      return normalized;
    }
  }
  return normalizeSource(previousSource) || "—";
}

function parseStatus(info, previous={}, player={}) {
  const alt = info?.AllMate && typeof info.AllMate === "object" ? info.AllMate : (info?.AltMate && typeof info.AltMate === "object" ? info.AltMate : {});
  const volume = numberOr(info?.DevVolumeL, previous.volume ?? 0);
  const maxVolume = numberOr(info?.DevVolumeMax, previous.maxVolume ?? 100);

  // A33 can expose playback metadata in getStatusEx/AllMate and, on some
  // firmware, additional transport state through getPlayerStatus. Treat a new
  // title or stream URL as a new media identity so stale finite-track timing and
  // artwork cannot leak into Internet Radio playback.
  const cleanMeta = (value) => {
    const v = String(value || "").trim();
    return /^(unknown|null|http_music)$/i.test(v) ? "" : v;
  };
  const playerTitle = cleanMeta(decodeMaybeHex(player?.Title));
  const altTitle = cleanMeta(repairUtf8Mojibake(alt.TrackTitle));
  const altArtist = cleanMeta(repairUtf8Mojibake(alt.TrackArtist));
  const altAlbum = cleanMeta(repairUtf8Mojibake(alt.TrackAlbum));
  const altArt = cleanMeta(alt.TrackImage);
  const liveUrl = String(alt.TrackUrl || player?.uri || player?.url || info?.TuneinId || "").trim();
  const a33ServiceValues = [alt?.MateType, info?.StreamMediaName, player?.PlaySource]
    .map(v => String(v || "").trim().toLowerCase());
  const a33Radio = a33ServiceValues.some(v => ["http_music", "tunein", "vtuner", "v_tuner"].includes(v));
  const a33RadioService = a33ServiceValues.find(v => ["tunein", "vtuner", "v_tuner", "http_music"].includes(v)) || "";
  const liveTitle = altTitle || playerTitle;
  const previousTitle = String(previous.track?.title || "").trim();
  const previousUrl = String(previous.track?.url || "").trim();
  const titleChanged = Boolean(liveTitle && previousTitle && liveTitle !== previousTitle);
  const urlChanged = Boolean(liveUrl && previousUrl && liveUrl !== previousUrl);
  const identityChanged = titleChanged || urlChanged;
  // Native A33 Internet Radio often reports no ICY metadata at all. In that
  // case do not recycle the previous song title: expose a stable radio identity
  // and the live URL instead. Radio Browser stations started by airCloudCTRL
  // are overlaid later by buildRadioTrackOverride().
  const radioFallbackTitle = a33RadioService === "tunein" ? "TuneIn Radio" : (a33RadioService === "vtuner" || a33RadioService === "v_tuner" ? "vTuner Radio" : "Internet Radio");
  const title = liveTitle || (a33Radio ? radioFallbackTitle : (identityChanged ? "Nothing playing" : (previousTitle || "Nothing playing")));
  const artist = altArtist || cleanMeta(decodeMaybeHex(player?.Artist)) || (a33Radio ? "" : (identityChanged ? "" : (previous.track?.artist || "")));
  const album = altAlbum || cleanMeta(decodeMaybeHex(player?.Album)) || (a33Radio ? "" : (identityChanged ? "" : (previous.track?.album || "")));
  const art = altArt || (a33Radio ? "" : (identityChanged ? "" : (previous.track?.art || "")));

  const hasAltProgress = alt.Progress !== undefined && alt.Progress !== null && String(alt.Progress) !== "";
  const hasAltTotal = alt.TotalTime !== undefined && alt.TotalTime !== null && String(alt.TotalTime) !== "";
  const playerCurMs = Number(player?.curpos);
  const playerTotalMs = Number(player?.totlen);
  const progress = hasAltProgress
    ? numberOr(alt.Progress, 0)
    : (Number.isFinite(playerCurMs) ? Math.max(0, playerCurMs / 1000) : (identityChanged ? 0 : (previous.track?.progress ?? 0)));
  const total = hasAltTotal
    ? numberOr(alt.TotalTime, 0)
    : (Number.isFinite(playerTotalMs) ? Math.max(0, playerTotalMs / 1000) : (identityChanged ? 0 : (previous.track?.total ?? 0)));
  const playState = info?.PlayState || alt?.PlayState || player?.PlayStatus || player?.status || previous.track?.playState || "";

  return {
    name: info?.UserDevName || info?.DevName || previous.name || "A33 Device",
    model: info?.ProjectName || previous.model || "A33",
    version: info?.VERSION || info?.NEW_VERSION || previous.version || "—",
    volume,
    maxVolume,
    muted: String(info?.VolumeState || player?.mute || "").toLowerCase() === "mute" || String(player?.mute || "0") === "1",
    source: reportedSource(info, previous.source),
    multiroom: info?.MultiroomStatus || previous.multiroom || "free",
    host: info?.Host || previous.host || "0",
    networkMode: info?.NetworkMode || previous.networkMode || "—",
    tcpIp: info?.TCPIP || previous.tcpIp || previous.ip || "—",
    wlanMac: info?.Wlan0Mac || previous.wlanMac || "—",
    ethMac: info?.Eth0Mac || previous.ethMac || "—",
    bleName: info?.BleName || previous.bleName || "—",
    features: Array.isArray(info?.DevFunction) ? info.DevFunction : (previous.features || []),
    eqType: info?.EqType || previous.eqType || "—",
    eqEnable: info?.EqEnable || previous.eqEnable || "—",
    track: { title, artist, album, art, progress, total, playState, streamSource: info?.StreamSource || "", service: alt.MateType || info?.StreamMediaName || player?.PlaySource || "", url: liveUrl || (identityChanged ? "" : (previous.track?.url || "")), id: String(alt.TrackId || ""), context: alt.TrackContext || "" },
    rawStatus: {status:info, player},
    lastSeen: Date.now(),
    online: true
  };
}

function linkplayTransportFor(device) {
  if (deviceTypeOf(device) !== DEVICE_TYPES.AIRSCOPE) return null;
  const hardware = String(device?.hardware || device?.model || "").toUpperCase();
  const project = String(device?.project || "").toUpperCase();
  // Hardware-verified rule (2026-09-26): A31 uses HTTP; A97/A98 use HTTPS.
  if (hardware === "A31" || project.includes("UP2STREAM_PRO_V4")) return {protocol:"http", port:80};
  if (hardware.includes("ALLWINNER-R328") || hardware.includes("AMLOGIC") || project.includes("UP2STREAM_HDDAC") || project.includes("WIIM")) return {protocol:"https", port:443};
  return null;
}

async function api(device, instruct) {
  if (!window.airCloud?.request) throw new Error("Desktop bridge unavailable");
  const forced = linkplayTransportFor(device);
  const protocol = forced?.protocol || device.protocol || "http";
  const port = forced?.port || Number(device.port) || defaultPortFor(deviceTypeOf(device), protocol);
  return window.airCloud.request({
    ip: device.ip, instruct, apiStyle: apiStyleFor(device), protocol, port
  });
}

function App() {
  const [devices, setDevices] = useState(loadDevices);
  const [selectedId, setSelectedId] = useState(() => localStorage.getItem(SELECTED_KEY) || loadDevices()[0]?.id);
  const [tab, setTab] = useState("Overview");
  const [navSection, setNavSection] = useState("Device");
  const deviceTabs = ["Overview","Player","Internet Radio","Library","USB","Source"];
  const settingTabs = ["EQ","Network","Bluetooth","Multiroom","System"];
  const navigateTo = (target) => {
    setNavSection(settingTabs.includes(target) ? "Setting" : "Device");
    setTab(target);
  };
  const [mode, setMode] = useState("User Mode");
  const [theme, setTheme] = useState(() => localStorage.getItem(THEME_KEY) || "dark");
  const [interfaceStyle, setInterfaceStyle] = useState(() => localStorage.getItem(INTERFACE_STYLE_KEY) || "standard");
  const [query, setQuery] = useState("");
  const [showAdd, setShowAdd] = useState(false);
  const [toast, setToast] = useState("");
  const [adding, setAdding] = useState({name:"", ip:"192.168.0.", port:"8000", protocol:"http", deviceType:DEVICE_TYPES.AIRCLOUD, mock:false});
  const [lastResponse, setLastResponse] = useState(null);
  const [refreshing, setRefreshing] = useState(false);
  const [discovering, setDiscovering] = useState(false);
  const [localPlaybackByDevice, setLocalPlaybackByDevice] = useState({});
  // v4.4.0: DLNA queues are owned by airControl just like Local Library queues.
  const [dlnaPlaybackByDevice, setDlnaPlaybackByDevice] = useState({});
  const [localPlaybackTick, setLocalPlaybackTick] = useState(0);
  const toastTimer = useRef(null);
  const volumePending = useRef({});
  const localAutoAdvancePending = useRef({});
  const [radioNowPlayingByDevice, setRadioNowPlayingByDevice] = useState(()=>{
    try {
      const saved = JSON.parse(localStorage.getItem(RADIO_NOW_PLAYING_KEY) || "{}");
      return saved && typeof saved === "object" && !Array.isArray(saved) ? saved : {};
    } catch { return {}; }
  });

  const device = devices.find(d => d.id === selectedId) || devices[0];

  useEffect(() => {
    localStorage.setItem(THEME_KEY, theme);
    document.documentElement.dataset.theme = theme;
  }, [theme]);

  useEffect(() => {
    localStorage.setItem(INTERFACE_STYLE_KEY, interfaceStyle);
  }, [interfaceStyle]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(devices));
  }, [devices]);

  useEffect(() => {
    if (selectedId) localStorage.setItem(SELECTED_KEY, selectedId);
  }, [selectedId]);

  useEffect(()=>{
    localStorage.setItem(RADIO_NOW_PLAYING_KEY, JSON.stringify(radioNowPlayingByDevice));
  },[radioNowPlayingByDevice]);

  const radioNowPlaying = device?.id ? (radioNowPlayingByDevice[device.id] || null) : null;
  const setRadioNowPlaying = (station) => {
    if (!device?.id) return;
    setRadioNowPlayingByDevice(current => {
      const next = {...current};
      if (station) {
        const baseline = device?.track || {};
        next[device.id] = {
          ...station,
          // v4.4.22: A33/ACS2 firmware can report only Network + http_music
          // after a restart, with no Title/Artist/Picture even from getMetaInfo.
          // Mark stations that airControl itself started so they can be restored
          // only after the device is verified Online and still reports http_music.
          _airControlOwned: true,
          _a33Remembered: isA33Device(device),
          _startedAt: station._startedAt || Date.now(),
          // A33 often keeps returning the metadata/timing of the track that was
          // playing before airCloudCTRL started an external radio URL. Keep that
          // media identity as a baseline so stale native metadata cannot evict the
          // Radio Browser overlay a few seconds later.
          _baselineTrack: station._baselineTrack || {
            title: String(baseline.title || "").trim(),
            artist: String(baseline.artist || "").trim(),
            album: String(baseline.album || "").trim(),
            url: String(baseline.url || "").trim(),
            id: String(baseline.id || "").trim(),
            total: numberOr(baseline.total, 0)
          }
        };
      } else delete next[device.id];
      return next;
    });
  };

  const radioTrackOverride = useMemo(()=>buildRadioTrackOverride(device, radioNowPlaying),[radioNowPlaying, device?.source, device?.track]);
  const localPlayback = device?.id ? (localPlaybackByDevice[device.id] || null) : null;
  // Library owns descriptive metadata, but Linkplay owns transport timing.
  // On real A31 HTTP playback getPlayerStatus reports curpos/totlen correctly
  // (mode 10), even while Title/Artist/Album remain stale from the prior USB item.
  const linkplayLocalTiming = localPlayback && deviceTypeOf(device) === DEVICE_TYPES.AIRSCOPE;
  const nativeLocalProgress = Number(device?.track?.progress);
  const nativeLocalTotal = Number(device?.track?.total);
  const libraryDuration = Number(localPlayback?.track?.duration) || 0;
  const fallbackLocalProgress = localPlayback ? Math.min(libraryDuration, Math.max(0,(Date.now()-localPlayback.startedAt)/1000)) : 0;
  const localTrackOverride = localPlayback ? {
    _tick: localPlaybackTick,
    title: localPlayback.track.title,
    artist: localPlayback.track.artist,
    album: localPlayback.track.album,
    art: localPlayback.track.artwork || "",
    total: linkplayLocalTiming && Number.isFinite(nativeLocalTotal) && nativeLocalTotal > 0 ? nativeLocalTotal : libraryDuration,
    progress: linkplayLocalTiming && Number.isFinite(nativeLocalProgress) && nativeLocalProgress >= 0 ? nativeLocalProgress : fallbackLocalProgress,
    playState: device?.track?.playState || "play",
    service: "This Device",
    url: localPlayback.url || "",
    id: localPlayback.track.id,
    context: "airControl Local Library"
  } : null;
  const dlnaPlayback = device?.id ? (dlnaPlaybackByDevice[device.id] || null) : null;
  const dlnaTrackOverride = dlnaPlayback ? {
    title: dlnaPlayback.track.title || "Untitled",
    artist: dlnaPlayback.track.artist || "",
    album: dlnaPlayback.track.album || "",
    art: dlnaPlayback.track.artUrl || "",
    total: Number(device?.track?.total) || dlnaPlayback.durationSeconds || 0,
    progress: Number(device?.track?.progress) || 0,
    playState: device?.track?.playState || "play",
    service: "UPnP / DLNA",
    url: dlnaPlayback.track?.resource?.url || "",
    id: dlnaPlayback.track?.id || "",
    context: dlnaPlayback.serverName || "DLNA MediaServer"
  } : null;
  const effectiveTrackOverride = localTrackOverride || dlnaTrackOverride || radioTrackOverride;

  // Keep the local-library progress bar moving even when the device only reports
  // coarse HTTP-stream timing. The tick only runs while a local-library track is active.
  useEffect(()=>{
    if (!localPlayback) return;
    const timer=setInterval(()=>setLocalPlaybackTick(v=>v+1),500);
    return ()=>clearInterval(timer);
  },[device?.id, Boolean(localPlayback)]);

  // Radio Browser metadata is a local overlay. A33 is special: after we start a
  // radio URL it can keep reporting the *previous* native track (including its
  // finite duration) for a long time. Therefore A33 must not drop our station
  // merely because total/url differ. We only clear it when the source leaves
  // Network or when the device reports a genuinely new native media identity
  // compared with the snapshot taken when the station was started.
  useEffect(()=>{
    if (!device?.id || !radioNowPlaying) return;

    // A33 native TuneIn/vTuner must immediately take ownership back from a
    // Radio Browser overlay. A direct stream started by airCloudCTRL is
    // reported by the firmware as http_music, while the native services are
    // reported explicitly as tunein / vtuner. This distinction lets us keep
    // our station metadata for airCloudCTRL radio without masking a station
    // selected later in the manufacturer's app.
    if (deviceTypeOf(device) === DEVICE_TYPES.AIRCLOUD) {
      const nativeService = String(device?.track?.service || "").trim().toLowerCase();
      if (["tunein", "vtuner", "v_tuner"].includes(nativeService)) {
        setRadioNowPlaying(null);
        return;
      }
    }

    const age = Date.now() - Number(radioNowPlaying._startedAt || 0);
    if (age < 5000) return;
    const source = normalizeSource(device?.source);
    const movedSource = Boolean(source && source !== "—" && source !== "Network");
    if (movedSource) {
      setRadioNowPlaying(null);
      return;
    }

    const live = device?.track || {};
    const baseline = radioNowPlaying?._baselineTrack || {};
    const identity = t => [
      String(t?.id || "").trim(),
      String(t?.url || "").trim(),
      String(t?.title || "").trim(),
      String(t?.artist || "").trim(),
      String(t?.album || "").trim()
    ].join("|");

    if (deviceTypeOf(device) === DEVICE_TYPES.AIRCLOUD) {
      // A33 rule: when airCloudCTRL started a Radio Browser stream, our station
      // metadata is authoritative. The firmware may report unrelated/stale URLs,
      // "Unknown" metadata, or changing counters, so none of those are allowed
      // to evict the overlay. Only a real native media item with meaningful
      // metadata can take ownership back while the source remains Network.
      const meaningful = v => {
        const x = String(v || "").trim();
        return Boolean(x && !/^(unknown|null|nothing playing|internet radio|http_music)$/i.test(x));
      };
      const service = String(live?.service || "").toLowerCase();
      const nativeMusicMetadata = meaningful(live?.title) || meaningful(live?.artist) || meaningful(live?.album) || meaningful(live?.art);
      const stillNativeRadio = ["http_music", "tunein", "vtuner", "v_tuner"].includes(service);
      if (nativeMusicMetadata && !stillNativeRadio) setRadioNowPlaying(null);
      return;
    }

    // v4.4.13: Older Linkplay can keep stale finite timing/URI values while
    // Internet Radio is already playing. Those values must not evict the
    // renderer-only Radio Browser overlay (that caused the ~5 s cover blink).
    // A real source change above still releases ownership. No player command
    // is sent here.
    return;
  },[device?.id, device?.source, device?.track, radioNowPlaying]);

  const notify = (msg) => {
    setToast(msg);
    clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setToast(""), 2600);
  };

  const patchDevice = (id, patch) => {
    setDevices(ds => ds.map(d => d.id === id ? {...d, ...patch} : d));
  };

  const refreshStatus = async (target=device, {silent=true}={}) => {
    if (!target || target.mock) return;
    if (!silent) setRefreshing(true);
    try {
      const r = await api(target, "getStatusEx");
      if (!r?.ok) throw new Error(r?.raw || `HTTP ${r?.status || "error"}`);
      const info = r.data && typeof r.data === "object" ? r.data : {};
      // v4.4.26: compact Multiroom-only Terminal diagnostic. Log only when
      // the relevant raw status fields change for a device. This is read-only.
      try {
        const payload = {
          name: target.name, ip: target.ip, hardware: info?.hardware || target.hardware || "", project: info?.project || target.project || "",
          group: info?.group, master_uuid: info?.master_uuid, slave: info?.slave,
          MultiroomStatus: info?.MultiroomStatus, Host: info?.Host, Device: info?.Device,
          GroupName: info?.GroupName, uuid: info?.uuid
        };
        const sig = JSON.stringify(payload);
        if (multiroomDiagnosticSignatures.get(target.id) !== sig) {
          multiroomDiagnosticSignatures.set(target.id, sig);
          window.airCloud?.logMultiroomDiagnostic?.(payload);
        }
      } catch {}
      let playerInfo = null;
      let metaInfo = null;
      let upnpInfo = null;
      if (deviceTypeOf(target) === DEVICE_TYPES.AIRSCOPE) {
        const pr = await api(target, "getPlayerStatus");
        if (pr?.ok && pr.data && typeof pr.data === "object") playerInfo = pr.data;

        // A98/Amlogic WiiM normally provides albumArtURI via getMetaInfo.
        // A31 and A97/ALLWINNER-R328 may not. Try HTTP metadata where supported,
        // then use standard Linkplay UPnP AVTransport metadata as a cover-art fallback.
        const knownHardware = String(info?.hardware || target.hardware || "").toUpperCase();
        if (knownHardware !== "A31") {
          const mr = await api(target, "getMetaInfo");
          if (mr?.ok && mr.data && typeof mr.data === "object") metaInfo = mr.data;
        }
        // v4.4.15: standard AVTransport metadata is the shared source of truth
        // for Linkplay artwork while Network/Internet Radio is active. This is
        // read-only and also restores covers for stations that were already
        // playing before airControl started.
        let rich = metaInfo?.metaData && typeof metaInfo.metaData === "object" ? metaInfo.metaData : (metaInfo || {});

        // v4.4.21: A98/WiiM exposes Internet Radio artwork through getMetaInfo,
        // while A31/A97 commonly expose it through UPnP. Feed getMetaInfo art
        // through the exact same Electron resolver before parseLinkplayStatus.
        // This turns a reachable image into a data: URL and, for stale
        // /radio-cover URLs left by an older airControl process, recovers the
        // public station favicon by saved station/title lookup. Read-only only.
        const metaOriginalArt = String(rich?.albumArtURI || rich?.["albumArtURI "] || "").trim();
        if (metaOriginalArt && window.airCloud?.resolveArtworkUrl) {
          let resolvedMetaArt = "";
          const rr = await window.airCloud.resolveArtworkUrl({url:metaOriginalArt, timeout:5000});
          if (rr?.ok && rr.dataUrl) resolvedMetaArt = rr.dataUrl;
          if (!resolvedMetaArt && /\/radio-cover\//i.test(metaOriginalArt)) {
            const saved = radioNowPlayingByDevice[target.id];
            let candidate = String(saved?.favicon || "").trim();
            const metaTitle = String(rich?.title || "").trim();
            if (!candidate && metaTitle) {
              try {
                const matches = await searchRadioStations({name:metaTitle, limit:8});
                const exact = matches.find(x => String(x?.name||"").trim().toLowerCase() === metaTitle.toLowerCase());
                candidate = String((exact || matches[0])?.favicon || "").trim();
              } catch {}
            }
            if (candidate) {
              const fr = await window.airCloud.resolveArtworkUrl({url:candidate, timeout:5000});
              resolvedMetaArt = (fr?.ok && fr.dataUrl) ? fr.dataUrl : candidate;
            }
          }
          if (resolvedMetaArt) {
            rich = {...rich, albumArtURI:resolvedMetaArt, originalAlbumArtURI:metaOriginalArt};
            metaInfo = metaInfo?.metaData && typeof metaInfo.metaData === "object"
              ? {...metaInfo, metaData:rich}
              : rich;
          }
        }
        const hasArtwork = Boolean(String(rich?.albumArtURI || rich?.["albumArtURI "] || "").trim());
        const isA98 = knownHardware === "A98" || String(info?.project || target.project || "").toUpperCase().includes("A98");
        // v4.4.18: A98/WiiM Home can expose metadata through getMetaInfo but lose
        // radio artwork after an app restart. Always read AVTransport as a second,
        // read-only source on A98 so we can compare the two paths directly.
        const shouldReadUpnp = isA98 || normalizeSource(target.source) === "Network" || !hasArtwork;
        if (shouldReadUpnp && window.airCloud?.getLinkplayUpnpMetadata) {
          const ur = await window.airCloud.getLinkplayUpnpMetadata({ip:target.ip});
          if (ur?.ok && ur.data && typeof ur.data === "object") upnpInfo = ur.data;
        }

        // v4.4.17: resolve Linkplay artwork through Electron main. External
        // TuneIn/Google URLs can fail when loaded directly by the renderer, and
        // old /radio-cover URLs may point at a cache from the previous process.
        if (upnpInfo?.art && window.airCloud?.resolveArtworkUrl) {
          const originalArt = String(upnpInfo.art || "").trim();
          const rr = await window.airCloud.resolveArtworkUrl({url:originalArt, timeout:5000});
          if (rr?.ok && rr.dataUrl) {
            upnpInfo = {...upnpInfo, art:rr.dataUrl, originalArt};
          } else if (/\/radio-cover\//i.test(originalArt)) {
            // If the old local cache died with the previous app process, first
            // recover the persisted Radio Browser favicon; otherwise perform a
            // title-only Radio Browser lookup as a last UI-only fallback.
            const saved = radioNowPlayingByDevice[target.id];
            let candidate = String(saved?.favicon || "").trim();
            if (!candidate && upnpInfo.title) {
              try {
                const matches = await searchRadioStations({name:upnpInfo.title, limit:8});
                const exact = matches.find(x => String(x?.name||"").trim().toLowerCase() === String(upnpInfo.title||"").trim().toLowerCase());
                candidate = String((exact || matches[0])?.favicon || "").trim();
              } catch {}
            }
            if (candidate) {
              const fr = await window.airCloud.resolveArtworkUrl({url:candidate, timeout:5000});
              upnpInfo = {...upnpInfo, art:(fr?.ok && fr.dataUrl) ? fr.dataUrl : candidate, originalArt};
            }
          }
        }
      } else {
        // Some A33 firmware exposes radio transport state through getPlayerStatus
        // even when getStatusEx lacks PlayState. This call is optional and failure
        // must not mark the device offline.
        try {
          const pr = await api(target, "getPlayerStatus");
          if (pr?.ok && pr.data && typeof pr.data === "object") playerInfo = pr.data;
        } catch {}

        // v4.4.20 diagnostic only: read the same metadata sources that are used
        // by Linkplay, but DO NOT feed them into A33 parsing yet. This lets us
        // see whether A33 firmware actually exposes current radio metadata.
        try {
          const mr = await api(target, "getMetaInfo");
          if (mr?.ok && mr.data && typeof mr.data === "object") metaInfo = mr.data;
        } catch {}
        try {
          if (window.airCloud?.getLinkplayUpnpMetadata) {
            const ur = await window.airCloud.getLinkplayUpnpMetadata({ip:target.ip, timeout:2500});
            if (ur?.ok && ur.data && typeof ur.data === "object") upnpInfo = ur.data;
          }
        } catch {}
      }
      setDevices(ds => ds.map(d => {
        if (d.id !== target.id) return d;
        const parsed = deviceTypeOf(target) === DEVICE_TYPES.AIRSCOPE
          ? {...parseLinkplayStatus(info, playerInfo || {}, d, metaInfo || {}, upnpInfo || {}), online:true}
          : {...parseStatus(info, d, playerInfo || {}), online:true};
        // v4.4.12: a Radio Browser station started by airControl keeps its
        // original public favicon in renderer state.  Older Linkplay devices
        // may expose an albumArtURI that points back to airControl's temporary
        // /radio-cover cache; after an app restart that in-memory cache no
        // longer exists.  Restore the UI artwork from the saved station without
        // sending any command to the player.
        const savedRadio = radioNowPlayingByDevice[d.id];
        const allowSavedRadioArt = !savedRadio?._a33Remembered || isA33DirectHttpRadio({...d, ...parsed, online:true});
        if (savedRadio?.favicon && allowSavedRadioArt && ["Network", "DLNA"].includes(normalizeSource(parsed.source))) {
          const currentTitle = String(parsed.track?.title || "").trim().toLowerCase();
          const stationTitle = String(savedRadio.name || "").trim().toLowerCase();
          const art = String(parsed.track?.art || "").trim();
          const staleLocalCover = /\/radio-cover\//i.test(art);
          if (!art || staleLocalCover || !currentTitle || currentTitle === stationTitle) {
            parsed.track = {...(parsed.track || {}), art:savedRadio.favicon};
          }
        }
        // v4.4.25: verbose DEVICE PIPELINE diagnostics removed; polling behavior is unchanged.

        const pending = volumePending.current[d.id];
        if (pending) {
          const reported = Number(parsed.volume);
          if (reported === Number(pending.target)) {
            delete volumePending.current[d.id];
            parsed.volume = Number(pending.target);
          } else if (Date.now() < pending.expires) {
            // Keep the user's final slider position while the A33 is still
            // reporting an older intermediate value.
            parsed.volume = d.volume;
          } else {
            delete volumePending.current[d.id];
          }
        }
        return {...d, ...parsed};
      }));
      if (!silent) notify("Status updated");
      return r;
    } catch (e) {
      patchDevice(target.id, {online:false});
      if (!silent) notify(`Connection error: ${e.message}`);
      return null;
    } finally {
      if (!silent) setRefreshing(false);
    }
  };

  useEffect(() => {
    if (!device || device.mock || !device.online) return;
    let cancelled = false;
    const tick = async () => {
      if (!cancelled) await refreshStatus(device, {silent:true});
    };
    tick();
    const id = setInterval(tick, 2000);
    return () => { cancelled = true; clearInterval(id); };
    // Intentionally restart polling only when connection identity changes.
  }, [device?.id, device?.ip, device?.port, device?.protocol, device?.mock]);

  // v4.4.12: Zone Cards represent every device, not only the selected one.
  // Keep non-selected online zones fresh as well.  Previously only `device`
  // was polled every 2 seconds; selecting another card caused its first fresh
  // status read, which is why artwork appeared only after clicking through
  // zones.  Background polling is read-only and never changes playback.
  useEffect(() => {
    let cancelled = false;
    const tick = async () => {
      const targets = devices.filter(d => !d.mock && d.online && d.id !== selectedId);
      for (const target of targets) {
        if (cancelled) break;
        await refreshStatus(target, {silent:true});
      }
    };
    const id = setInterval(tick, 5000);
    return () => { cancelled = true; clearInterval(id); };
  }, [selectedId, devices.map(d=>`${d.id}:${d.ip}:${d.port}:${d.protocol}:${d.online}`).join("|")]);

  // Refresh immediately whenever the user enters another top-level tab.
  // This keeps volume, mute, source, EQ mode and other status-backed controls
  // in sync before the next regular 2 s polling tick. EQ itself also reads
  // getEqInfo on mount, so its editor sliders are redrawn from the device.
  useEffect(() => {
    if (!device || device.mock) return;
    refreshStatus(device, {silent:true});
  }, [tab, device?.id]);

  const releaseLocalLibraryOwnership = (deviceId=device?.id) => {
    if (!deviceId) return;
    setLocalPlaybackByDevice(current => {
      if (!current[deviceId]) return current;
      const next = {...current};
      delete next[deviceId];
      return next;
    });
    delete localAutoAdvancePending.current[deviceId];
  };

  const run = async (instruct, {quiet=false}={}) => {
    if (!device) return {ok:false};
    try {
      // A source selected in airControl explicitly ends Local Library ownership
      // before the device reply arrives. This prevents stale Library metadata from
      // surviving on USB/Bluetooth/AUX/Optical/etc.
      if (/^setPlayerCmd:switchmode:/i.test(String(instruct || ""))) {
        releaseLocalLibraryOwnership(device.id);
      }
      if (device.mock) {
        const result = {ok:true, mock:true, instruct, data:"OK"};
        setLastResponse(result);
        if (!quiet) notify(`Mock → ${instruct}`);
        return result;
      }
      const deviceCommand = translateCommand(device, instruct);
      const result = await api(device, deviceCommand);
      setLastResponse({...result, requestedCommand:instruct, sentCommand:deviceCommand});
      if (!result?.ok) throw new Error(result?.raw || "Device returned an error");
      if (instruct === "getStatusEx" && result.data && typeof result.data === "object" && deviceTypeOf(device) === DEVICE_TYPES.AIRCLOUD) {
        patchDevice(device.id, {...parseStatus(result.data, device), online:true});
        setTimeout(() => refreshStatus(device, {silent:true}), 80);
      } else {
        setTimeout(() => refreshStatus(device, {silent:true}), 220);
      }
      if (!quiet) notify("Command sent");
      return result;
    } catch (e) {
      setLastResponse({ok:false, error:e.message, instruct});
      patchDevice(device.id, {online:false});
      if (!quiet) notify(`Error: ${e.message}`);
      return {ok:false, error:e.message};
    }
  };

  const startLocalLibraryTrack = async (track, queue=[], index=0) => {
    if (!track || !device?.id) return {ok:false,error:"No track selected"};
    const m = await window.airCloud?.getLocalMediaUrl?.({id:track.id,deviceIp:device.ip});
    if (!m?.ok) return {ok:false,error:m?.error||"Could not publish this track"};
    let r;
    if (deviceTypeOf(device) === DEVICE_TYPES.AIRSCOPE && window.airCloud?.playLocalTrackUpnp) {
      r = await window.airCloud.playLocalTrackUpnp({deviceIp:device.ip,id:track.id,title:track.title,artist:track.artist,album:track.album,duration:track.duration});
    } else {
      r = await run(`setPlayerCmd:play:${m.url}`,{quiet:true});
    }
    if (!r?.ok) return r;
    setRadioNowPlaying(null);
    setDlnaPlaybackByDevice(cur=>{const next={...cur};delete next[device.id];return next});
    // Remember the native media identity that existed immediately before airControl
    // starts its own HTTP stream. A31/A97 can keep reporting that old identity while
    // our stream is playing, so it must not be mistaken for a user takeover.
    const baseline = {
      title:String(device?.track?.title || "").trim(),
      id:String(device?.track?.id || "").trim(),
      url:String(device?.track?.url || "").trim(),
      total:Number(device?.track?.total) || 0
    };
    setLocalPlaybackByDevice(cur=>({...cur,[device.id]:{track,queue,index,url:m.url,startedAt:Date.now(),baseline}}));
    return {ok:true};
  };

  // While airControl owns a local Library queue, keep that queue authoritative for
  // Network playback. Older A31 firmware may report a synthetic/empty native
  // identity for our UPnP HTTP item; treating that as an external takeover used to
  // delete the queue a few seconds after playback started. That made both Next and
  // automatic advance fall back to the device-native transport, which has no queue.
  // A real source change still releases Library ownership immediately.
  // v3.0.7.40: do not evict the Library queue from polled source labels.
  // A31 can report transient/stale source values during UPnP HTTP playback.
  // Keeping ownership here makes both UI Next/Previous and timed auto-advance
  // deterministic. Starting another Library item simply replaces this state.

  // v4.0.2: release the local Library overlay when the device has really moved
  // to another source/URI. A31 can briefly report stale values after SetAVTransportURI,
  // so ignore polling during a short grace period. After that, an explicit non-Network
  // source or an explicit player URI different from airControl's published local URL
  // means another controller/source owns playback and native metadata must be shown.
  useEffect(()=>{
    if (!device?.id || !localPlayback) return;
    if (Date.now() - Number(localPlayback.startedAt || 0) < 3000) return;

    const source = String(device?.source || "").trim().toLowerCase();
    const rawPlayer = device?.rawStatus?.player || {};
    const nativeUri = String(rawPlayer?.uri || rawPlayer?.url || "").trim();
    const localUri = String(localPlayback.url || "").trim();
    const normalizeUri = (value) => {
      try { return decodeURIComponent(String(value || "")).replace(/\/+$/, ""); }
      catch { return String(value || "").replace(/\/+$/, ""); }
    };

    const sourceTakenOver = Boolean(source && source !== "network" && source !== "dlna");
    const uriTakenOver = Boolean(nativeUri && localUri && normalizeUri(nativeUri) !== normalizeUri(localUri));

    // Network is not a playback owner: Library, Qobuz, TIDAL, Spotify, TuneIn,
    // DLNA, etc. can all be reported as Network. Detect native services explicitly
    // so a track selected later in WiiM Home immediately takes metadata ownership.
    const nativeService = String(device?.track?.service || rawPlayer?.PlaySource || "").trim().toLowerCase();
    const externalNetworkService = /^(qobuz|tidal|spotify|amazon|amazon_music|deezer|tunein|vtuner|v_tuner|airplay|chromecast)$/i.test(nativeService);

    // Also inspect the raw device source fields. Some old A31 firmware leaves the
    // normalized source stale while DevModel/DevMode has already changed to USB,
    // Bluetooth or an input.
    const rawStatus = device?.rawStatus?.status || {};
    const rawSource = normalizeSource(rawStatus?.DevModel || rawStatus?.DevMode || rawStatus?.StreamSource || "");
    const rawSourceTakenOver = Boolean(rawSource && rawSource !== "Network" && rawSource !== "DLNA");

    if (!sourceTakenOver && !rawSourceTakenOver && !uriTakenOver && !externalNetworkService) return;

    setLocalPlaybackByDevice(current => {
      if (!current[device.id]) return current;
      const next = {...current};
      delete next[device.id];
      return next;
    });
    delete localAutoAdvancePending.current[device.id];
  }, [device?.id, device?.source, device?.track?.service, device?.rawStatus?.status?.DevModel, device?.rawStatus?.status?.DevMode, device?.rawStatus?.status?.StreamSource, device?.rawStatus?.player?.PlaySource, device?.rawStatus?.player?.uri, device?.rawStatus?.player?.url, localPlayback?.url, localPlayback?.startedAt]);

  const localQueueStep = async (delta) => {
    const state = localPlaybackByDevice[device?.id];
    if (!state?.queue?.length) return run(delta>0?"setPlayerCmd:next":"setPlayerCmd:prev");
    const next = state.index + delta;
    if (next < 0 || next >= state.queue.length) return {ok:false,error:"End of queue"};
    return startLocalLibraryTrack(state.queue[next], state.queue, next);
  };

  const dlnaDurationSeconds = (value) => {
    if (typeof value === "number") return value;
    const m=String(value||"").match(/^(\d+):(\d+):(\d+(?:\.\d+)?)$/);
    return m ? Number(m[1])*3600+Number(m[2])*60+Number(m[3]) : 0;
  };

  const startDlnaQueueTrack = async (track, queue=[], index=0, serverName="DLNA MediaServer") => {
    if (!track?.resource?.url || !device?.id) return {ok:false,error:"No playable DLNA resource"};
    const r=await window.airCloud?.playDlnaTrackUpnp?.({deviceIp:device.ip,url:track.resource.url,title:track.title,artist:track.artist,album:track.album,artUrl:track.artUrl,protocolInfo:track.resource.protocolInfo,duration:track.resource.duration});
    if (!r?.ok) return r || {ok:false,error:"DLNA playback unavailable"};
    releaseLocalLibraryOwnership(device.id);
    setRadioNowPlaying(null);
    setDlnaPlaybackByDevice(cur=>({...cur,[device.id]:{track,queue,index,serverName,startedAt:Date.now(),durationSeconds:dlnaDurationSeconds(track.resource.duration)}}));
    return {ok:true};
  };

  const activeQueueStep = async (delta) => {
    const ds=dlnaPlaybackByDevice[device?.id];
    if (ds?.queue?.length) {
      const next=ds.index+delta;
      if(next<0||next>=ds.queue.length)return {ok:false,error:"End of queue"};
      return startDlnaQueueTrack(ds.queue[next],ds.queue,next,ds.serverName);
    }
    return localQueueStep(delta);
  };

  // v4.4.0 DLNA auto-next: use real Linkplay progress when available and a
  // metadata-duration timer as fallback. Only one transition is allowed per item.
  const dlnaAutoAdvancePending = useRef({});
  useEffect(()=>{
    const id=device?.id, state=id?dlnaPlaybackByDevice[id]:null;
    if(!id||!state?.queue?.length||state.index>=state.queue.length-1)return;
    if(Date.now()-Number(state.startedAt||0)<2500)return;
    const progress=Number(device?.track?.progress)||0, total=Number(device?.track?.total)||state.durationSeconds||0;
    if(!total||progress<Math.max(0,total-2.5))return;
    const key=`${state.index}:${state.startedAt}`; if(dlnaAutoAdvancePending.current[id]===key)return;
    dlnaAutoAdvancePending.current[id]=key;
    startDlnaQueueTrack(state.queue[state.index+1],state.queue,state.index+1,state.serverName)
      .finally(()=>setTimeout(()=>{if(dlnaAutoAdvancePending.current[id]===key)delete dlnaAutoAdvancePending.current[id]},1500));
  },[device?.id,device?.track?.progress,device?.track?.total,dlnaPlaybackByDevice]);

  useEffect(()=>{
    const id=device?.id, state=id?dlnaPlaybackByDevice[id]:null;
    if(!id||!state?.durationSeconds||state.index>=state.queue.length-1)return;
    const remaining=Math.max(300,state.durationSeconds*1000-(Date.now()-state.startedAt)+500);
    const timer=setTimeout(()=>startDlnaQueueTrack(state.queue[state.index+1],state.queue,state.index+1,state.serverName),remaining);
    return()=>clearTimeout(timer);
  },[device?.id,dlnaPlaybackByDevice]);

  useEffect(()=>{
    const state = device?.id ? localPlaybackByDevice[device.id] : null;
    const duration = Number(state?.track?.duration)||0;
    if (!state || !duration || state.index >= state.queue.length-1) return;
    const remaining = Math.max(250, duration*1000 - (Date.now()-state.startedAt) + 350);
    const timer = setTimeout(()=>{ startLocalLibraryTrack(state.queue[state.index+1],state.queue,state.index+1); }, remaining);
    return ()=>clearTimeout(timer);
  },[device?.id, localPlaybackByDevice]);

  // v3.0.7.41: A31 local Library auto-advance is driven primarily by the
  // device's real polled progress. The metadata duration timer above remains a
  // fallback, but some files/devices do not fire that timer at the exact end.
  // getPlayerStatus gives curpos/totlen reliably on A31, so when the player is
  // within the final polling window we advance the airControl queue ourselves.
  useEffect(()=>{
    const id=device?.id;
    const state=id ? localPlaybackByDevice[id] : null;
    if (!id || !state?.queue?.length || state.index >= state.queue.length-1) return;
    if (Date.now() - Number(state.startedAt||0) < 2500) return;
    const progress=Number(device?.track?.progress)||0;
    const total=Number(device?.track?.total)||0;
    if (!total || progress < Math.max(0,total-2.5)) return;
    const key=`${state.index}:${state.startedAt}`;
    if (localAutoAdvancePending.current[id]===key) return;
    localAutoAdvancePending.current[id]=key;
    startLocalLibraryTrack(state.queue[state.index+1],state.queue,state.index+1)
      .finally(()=>{ setTimeout(()=>{ if(localAutoAdvancePending.current[id]===key) delete localAutoAdvancePending.current[id]; },1500); });
  },[device?.id, device?.track?.progress, device?.track?.total, localPlaybackByDevice]);

  const setVolumeForDevice = async (targetDevice, v) => {
    if (!targetDevice) return {ok:false};
    const volume = Math.max(0, Math.min(targetDevice.maxVolume || 100, Math.round(Number(v))));
    volumePending.current[targetDevice.id] = {target: volume, expires: Date.now() + 5000};
    patchDevice(targetDevice.id, {volume});
    try {
      if (targetDevice.mock) return {ok:true,mock:true};
      const command = translateCommand(targetDevice, `setPlayerCmd:vol:${volume}`);
      const result = await api(targetDevice, command);
      if (!result?.ok) throw new Error(result?.raw || "Device returned an error");
      setTimeout(() => refreshStatus(targetDevice, {silent:true}), 250);
      setTimeout(() => refreshStatus(targetDevice, {silent:true}), 900);
      return result;
    } catch (e) {
      delete volumePending.current[targetDevice.id];
      setTimeout(() => refreshStatus(targetDevice, {silent:true}), 150);
      return {ok:false,error:e.message};
    }
  };

  const setVolume = async (v) => {
    const volume = Math.max(0, Math.min(device.maxVolume || 100, Math.round(Number(v))));
    // Remember the final user-selected target. Polling may continue, but it is
    // not allowed to redraw stale volume values until the device confirms this target.
    volumePending.current[device.id] = {target: volume, expires: Date.now() + 5000};
    patchDevice(device.id, {volume});
    const result = await run(`setPlayerCmd:vol:${volume}`, {quiet:true});
    if (!result?.ok) {
      delete volumePending.current[device.id];
      setTimeout(() => refreshStatus(device, {silent:true}), 150);
    } else {
      setTimeout(() => refreshStatus(device, {silent:true}), 250);
      setTimeout(() => refreshStatus(device, {silent:true}), 900);
      setTimeout(() => refreshStatus(device, {silent:true}), 1800);
    }
    return result;
  };

  const setSeek = async (seconds) => {
    const s = Math.max(0, Math.round(Number(seconds) || 0));
    patchDevice(device.id, {track:{...(device.track || {}), progress:s}});
    await run(`setPlayerCmd:setplay:${s}`, {quiet:true});
  };

  const mergeDiscoveredDevice = (f) => {
    if (!f?.ip) return;
    setDevices(current => {
      const next=[...current];
      const same=next.findIndex(d => (!d.mock && d.ip===f.ip) || (f.uuid && d.uuid && String(d.uuid).toLowerCase()===String(f.uuid).toLowerCase()));
      if(same>=0) next[same]={...next[same],...f,online:true};
      else next.push({id:crypto.randomUUID(),name:f.name||defaultDeviceName(f.deviceType),model:f.model||"—",ip:f.ip,protocol:f.protocol,port:Number(f.port),deviceType:f.deviceType,uuid:f.uuid||"",hardware:f.hardware||"",project:f.project||"",mock:false,online:true,volume:0,maxVolume:100,muted:false,source:"Network",version:"—",multiroom:"free",features:[],track:null});
      return next;
    });
  };

  useEffect(()=>{
    if(!window.airCloud?.onDiscoveredDevice) return;
    return window.airCloud.onDiscoveredDevice(device => mergeDiscoveredDevice(device));
  },[]);

  const discoverDevices = async ({silent=false}={}) => {
    if (discovering || !window.airCloud?.discoverDevices) return;
    setDiscovering(true);
    try {
      const result = await window.airCloud.discoverDevices();
      const found = Array.isArray(result?.devices) ? result.devices : [];
      let added = 0, updated = 0;
      setDevices(current => {
        const next = [...current];
        for (const f of found) {
          const same = next.findIndex(d =>
            (!d.mock && d.ip === f.ip) ||
            (f.uuid && d.uuid && String(d.uuid).toLowerCase() === String(f.uuid).toLowerCase())
          );
          if (same >= 0) {
            next[same] = {...next[same], ...f, online:true};
            updated++;
          } else {
            next.push({
              id:crypto.randomUUID(), name:f.name || defaultDeviceName(f.deviceType), model:f.model || "—",
              ip:f.ip, protocol:f.protocol, port:Number(f.port), deviceType:f.deviceType,
              uuid:f.uuid || "", hardware:f.hardware || "", project:f.project || "",
              mock:false, online:true, volume:0, maxVolume:100, muted:false, source:"Network",
              version:"—", multiroom:"free", features:[], track:null
            });
            added++;
          }
        }
        return next;
      });
      if (!silent || added) notify(found.length ? `Discovery: ${found.length} found · ${added} new` : "No devices found");
    } catch (e) {
      if (!silent) notify(`Discovery error: ${e.message}`);
    } finally { setDiscovering(false); }
  };

  // Automatic discovery once after startup. Saved devices remain intact; matching
  // UUIDs/IPs are refreshed and newly verified devices are appended.
  useEffect(()=>{
    const timer=setTimeout(()=>discoverDevices({silent:true}),900);
    return ()=>clearTimeout(timer);
  },[]);

  const addDevice = async () => {
    if (!adding.ip.trim()) return notify("Enter device IP");
    const id = crypto.randomUUID();
    const d = {
      id,
      name: adding.name || defaultDeviceName(adding.deviceType),
      model: adding.deviceType === DEVICE_TYPES.AIRSCOPE ? "Linkplay" : "A33",
      ip: adding.ip.trim(),
      protocol: adding.protocol,
      port: Number(adding.port) || defaultPortFor(adding.deviceType, adding.protocol),
      deviceType: adding.deviceType,
      mock: Boolean(adding.mock),
      online: Boolean(adding.mock),
      volume: 0,
      maxVolume: 100,
      muted: false,
      source: "Network",
      version: "—",
      multiroom: "free",
      features: [],
      track: null
    };

    // Probe before adding. This avoids relying on React state having committed the
    // new device while the very first status request is running. It also lets the
    // Linkplay adapter populate the device from the real A31 response immediately.
    if (!d.mock) {
      try {
        // Linkplay generations differ by transport: older A31 devices commonly
        // answer over HTTP/80, while newer A97/A98/WiiM firmware exposes the same
        // /httpapi.asp?command= API over HTTPS/443 with a self-signed certificate.
        // Probe the user's selected endpoint first, then automatically try the
        // other Linkplay transport so Add Device does not require chip knowledge.
        let statusResult;
        let linkplayEndpoint = null;
        if (deviceTypeOf(d) === DEVICE_TYPES.AIRSCOPE) {
          if (window.airCloud?.autoProbeLinkplay) {
            statusResult = await window.airCloud.autoProbeLinkplay({
              ip:d.ip,
              command:"getStatusEx",
              preferredProtocol:d.protocol,
              preferredPort:d.port
            });
            if (statusResult?.ok) {
              linkplayEndpoint = {
                protocol: statusResult.protocol || d.protocol,
                port: Number(statusResult.port) || defaultPortFor(DEVICE_TYPES.AIRSCOPE, statusResult.protocol || d.protocol)
              };
            }
          } else if (window.airCloud?.probeLinkplay) {
            // Backward-compatible fallback if an older preload is still present.
            const selectedProtocol = d.protocol === "https" ? "https" : "http";
            const selectedPort = Number(d.port) || defaultPortFor(DEVICE_TYPES.AIRSCOPE, selectedProtocol);
            const candidates = [
              {protocol:selectedProtocol, port:selectedPort},
              {protocol:"https", port:443},
              {protocol:"http", port:80}
            ].filter((v,i,a)=>a.findIndex(x=>x.protocol===v.protocol && x.port===v.port)===i);
            let lastProbe = null;
            for (const endpoint of candidates) {
              const probe = await window.airCloud.probeLinkplay({
                ip:d.ip, command:"getStatusEx", protocol:endpoint.protocol, port:endpoint.port
              });
              lastProbe = probe;
              if (probe?.ok && probe.data && typeof probe.data === "object") {
                statusResult = probe;
                linkplayEndpoint = endpoint;
                break;
              }
            }
            if (!statusResult) statusResult = lastProbe;
          } else {
            throw new Error("Linkplay IPC bridge is not available. Replace electron/preload.cjs from this patch.");
          }
        } else {
          statusResult = await api(d, "getStatusEx");
        }
        if (!statusResult?.ok || !statusResult.data || typeof statusResult.data !== "object") {
          throw new Error(statusResult?.error || statusResult?.raw || `HTTP ${statusResult?.status || "error"}`);
        }

        let ready = d;
        if (deviceTypeOf(d) === DEVICE_TYPES.AIRSCOPE) {
          const endpoint = linkplayEndpoint || {protocol:d.protocol, port:d.port};
          const playerResult = window.airCloud?.autoProbeLinkplay
            ? await window.airCloud.autoProbeLinkplay({
                ip:d.ip,
                command:"getPlayerStatus",
                preferredProtocol:endpoint.protocol,
                preferredPort:endpoint.port
              })
            : (window.airCloud?.probeLinkplay
              ? await window.airCloud.probeLinkplay({
                  ip:d.ip,
                  command:"getPlayerStatus",
                  protocol:endpoint.protocol,
                  port:endpoint.port
                })
              : await api({...d, protocol:endpoint.protocol, port:endpoint.port}, "getPlayerStatus"));
          const player = playerResult?.ok && playerResult.data && typeof playerResult.data === "object"
            ? playerResult.data : {};
          ready = {
            ...d,
            protocol:endpoint.protocol,
            port:Number(endpoint.port),
            ...parseLinkplayStatus(statusResult.data, player, d),
            online:true
          };
        } else {
          ready = {...d, ...parseStatus(statusResult.data, d), online:true};
        }

        setDevices(ds => [...ds, ready]);
        setSelectedId(id);
        setShowAdd(false);
        notify(deviceTypeOf(d) === DEVICE_TYPES.AIRSCOPE
          ? `Connected: ${ready.name} · ${ready.hardware || ready.model}`
          : "Device connected");
      } catch (e) {
        setLastResponse({ok:false, error:e.message, instruct:"getStatusEx", device:d.ip});
        notify(`Connection error: ${e.message}`);
      }
      return;
    }

    setDevices(ds => [...ds, d]);
    setSelectedId(id);
    setShowAdd(false);
    notify("Demo device added");
  };

  const removeCurrent = () => {
    if (!device || devices.length <= 1) return notify("Keep at least one device");
    const removedId = device.id;
    const remaining = devices.filter(d => d.id !== removedId);
    const next = remaining[0];
    // v4.4.19: remove synchronously from persistent storage as well. Do not
    // leave a window where a restart can resurrect a zone from localStorage.
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(remaining)); } catch {}
    setRadioNowPlayingByDevice(current => {
      if (!current[removedId]) return current;
      const copy = {...current}; delete copy[removedId]; return copy;
    });
    setDevices(remaining);
    setSelectedId(next?.id);
    setTab("Overview");
  };

  // v4.4.51 — Devices uses the same Master → Slave topology presentation as Multiroom.
  // A slave is attached to the real master reported by masterIp/masterUuid; it is no longer
  // rendered as a separate top-level card while that master is present.
  const appNormUuid=v=>String(v||"").replace(/^uuid:/i,"").replace(/[^0-9a-f]/gi,"").toUpperCase();
  const appMasterFor=d=>{
    if(!d || (!d.masterIp&&!d.masterUuid)) return null;
    return devices.find(x=>x.id!==d.id&&((d.masterIp&&x.ip===d.masterIp)||(appNormUuid(d.masterUuid)&&appNormUuid(x.uuid)===appNormUuid(d.masterUuid))))||null;
  };
  const appMembersFor=master=>devices.filter(d=>appMasterFor(d)?.id===master.id);
  const deviceGroups=devices.filter(d=>!appMasterFor(d)).map(master=>({master,members:appMembersFor(master)}));
  const qDevice=query.trim().toLowerCase();
  const filteredGroups=deviceGroups.filter(g=>!qDevice||[g.master,...g.members].some(d=>`${d.name} ${d.ip} ${d.model}`.toLowerCase().includes(qDevice)));
  const onlineCount = devices.filter(d => d.online).length;

  if (!device) return <div className="bootError">No devices configured.</div>;

  if (interfaceStyle === "salvador") return (
    <SalvadorStyle
      devices={devices}
      device={device}
      selectedId={selectedId}
      setSelectedId={setSelectedId}
      setInterfaceStyle={setInterfaceStyle}
      run={run}
      setVolume={setVolume}
      trackOverride={effectiveTrackOverride}
      onPrevious={()=>activeQueueStep(-1)}
      onNext={()=>activeQueueStep(1)}
      openLibrary={()=>{setInterfaceStyle("standard");setNavSection("Device");setTab("Library")}}
      openTab={(nextTab)=>{setInterfaceStyle("standard");setNavSection("Device");setTab(nextTab)}}
      requestDevice={api}
      refreshAll={async()=>{await Promise.all(devices.filter(d=>d.online&&!d.mock).map(d=>refreshStatus(d,{silent:true})))}}
    />
  );

  return (
    <div className="app" data-theme={theme}>
      <header className="topbar">
        <div className="brand">
          <div className="brandIcon"><Speaker size={25}/></div>
          <div className="brandText"><div className="brandTitleRow"><div className="brandName">airControl</div><div className="brandVersion">v{APP_VERSION}</div></div><div className="brandSub">Multi-platform Audio Device Control</div><div className="brandCredit">Created by FilmoScope Lab LLC</div></div>
        </div>
        <div className="topActions">
          <button className="salvadorSwitch" onClick={()=>setInterfaceStyle("salvador")} title="Open platForma" aria-label="Open platForma">
            <img src="./platForma-icon.png" alt=""/><span>platForma</span>
          </button>
          <div className="segmented">
            <button className={mode==="User Mode"?"active":""} onClick={()=>setMode("User Mode")}>User Mode</button>
            <button className={mode==="Installer Mode"?"active":""} onClick={()=>setMode("Installer Mode")}>Installer Mode</button>
          </div>
          <div className="divider"/>
          <div className="themeSwitch" aria-label="Color theme">
            <button className={theme==="dark"?"active":""} onClick={()=>setTheme("dark")} title="Dark theme">Dark</button>
            <button className={theme==="light"?"active":""} onClick={()=>setTheme("light")} title="Light theme">Light</button>
          </div>
          <div className="divider"/>
          <button className="iconBtn" title="Refresh status" onClick={()=>refreshStatus(device,{silent:false})}><RefreshCw size={19} className={refreshing?"spin":""}/></button>
          <button className="iconBtn"><CircleUserRound size={20}/></button>
        </div>
      </header>

      <div className="layout">
        <aside className="sidebar">
          {[[Speaker,"Device"],[Settings,"Setting"],[Home,"Rooms"],[Layers3,"Multiroom"],[Disc3,"Presets"]].map(([I,label]) => {
            const enabled = label === "Device" || label === "Setting";
            return <button key={label} onClick={()=>{
              if (!enabled) return;
              setNavSection(label);
              setTab(label === "Device" ? "Overview" : "EQ");
            }} className={`sideItem ${navSection===label?"selected":""} ${!enabled?"disabled":""}`}><I size={19}/><span>{label}</span></button>
          })}
          <div className="sideBottom">
            <div><span className="onlineDot"/> {onlineCount} device{onlineCount===1?"":"s"} online</div>
            <small>Live status via getStatusEx</small>
          </div>
        </aside>

        <main className="content">
          <section className="deviceColumn">
            <div className="sectionHead">
              <h1>Devices</h1>
              <div style={{display:"flex",gap:8}}><button className="ghostBtn" onClick={()=>discoverDevices()} disabled={discovering}><RefreshCw size={17} className={discovering?"spin":""}/> {discovering?"Searching…":"Find Devices"}</button><button className="primaryBtn" onClick={()=>setShowAdd(true)}><Plus size={17}/> Add Device</button></div>
            </div>
            <div className="search"><Search size={17}/><input placeholder="Search devices..." value={query} onChange={e=>setQuery(e.target.value)}/></div>
            <div className="deviceList">
              {filteredGroups.map(({master:d,members}) => {
                const localState = localPlaybackByDevice[d.id];
                const dlnaState = dlnaPlaybackByDevice[d.id];
                const radioState = radioNowPlayingByDevice[d.id];
                const cardTrack = localState ? {
                  title: localState.track?.title, artist: localState.track?.artist, album: localState.track?.album, art: localState.track?.artwork, service: "This Device"
                } : dlnaState ? {
                  title: dlnaState.track?.title, artist: dlnaState.track?.artist, album: dlnaState.track?.album, art: dlnaState.track?.artUrl, service: "UPnP / DLNA"
                } : radioState ? buildRadioTrackOverride(d, radioState) : (d.track || {});
                const hasTrack = Boolean(cardTrack?.title && cardTrack.title !== "Nothing playing");
                const grouped=members.length>0;
                const groupSelected=d.id===selectedId||members.some(m=>m.id===selectedId);
                const openZone=zone=>{setSelectedId(zone.id);setNavSection("Device");setTab("Overview")};
                const memberRow=zone=><div key={zone.id} className={`deviceGroupMember ${zone.id===selectedId?"selected":""}`} role="button" tabIndex={0} onClick={e=>{e.stopPropagation();openZone(zone)}} onKeyDown={e=>{if(e.key==="Enter"){e.stopPropagation();openZone(zone)}}}>
                  <div className="deviceGroupMemberHead"><div><strong>{zone.name}</strong><span>SLAVE · {deviceTypeOf(zone)}</span></div><div className="zoneCardActions">
                    {deviceTypeOf(zone)===DEVICE_TYPES.AIRSCOPE&&<button className="zoneLinkBtn on" title={`Multiroom for ${zone.name}`} onClick={e=>{e.stopPropagation();setSelectedId(zone.id);setNavSection("Setting");setTab("Multiroom")}}><Link2 size={14}/></button>}
                    <button className="zoneSettingsBtn" title={`Settings for ${zone.name}`} onClick={e=>{e.stopPropagation();setSelectedId(zone.id);setNavSection("Setting");setTab("EQ")}}><Settings size={15}/></button>
                  </div></div>
                  <div className="zoneVolume" onClick={e=>e.stopPropagation()} onPointerDown={e=>e.stopPropagation()}><Volume2 size={15}/><VolumeSlider device={zone} setVolume={v=>setVolumeForDevice(zone,v)} className="range zoneRange" disabled={!zone.online}/><strong>{zone.volume ?? 0}%</strong></div>
                </div>;
                return <div key={d.id} className={`deviceCard zoneCard deviceGroupCard ${groupSelected?"selected":""} ${grouped?"grouped":""}`}>
                  <div role="button" tabIndex={0} onClick={()=>openZone(d)} onKeyDown={e=>{if(e.key==="Enter")openZone(d)}}>
                    <div className="zoneCardTop">
                      <div className="zoneIdentity"><strong>{d.name}{grouped?` +${members.length}`:""}</strong><div><span className="zoneType">{deviceTypeOf(d)}</span><span className={d.online?"status online":"status"}><i/> {grouped?"Multiroom master":(d.online?"Online":"Offline")}</span></div></div>
                      <div className="zoneCardActions">
                        {deviceTypeOf(d)===DEVICE_TYPES.AIRSCOPE&&<button className={`zoneLinkBtn ${grouped?"on":""}`} title={`Multiroom for ${d.name}`} onClick={e=>{e.stopPropagation();setSelectedId(d.id);setNavSection("Setting");setTab("Multiroom")}}><Link2 size={16}/></button>}
                        <button className="zoneSettingsBtn" title={`Settings for ${d.name}`} onClick={e=>{e.stopPropagation();setSelectedId(d.id);setNavSection("Setting");setTab("EQ")}}><Settings size={16}/></button>
                      </div>
                    </div>
                    <div className="zoneNowPlaying"><Artwork track={cardTrack} device={d}/><div className="zoneTrackText"><b>{hasTrack ? cardTrack.title : "Nothing playing"}</b><span>{hasTrack ? (cardTrack.artist || "Unknown artist") : (d.source || "—")}</span><small>{hasTrack ? (cardTrack.album || cardTrack.service || d.source || "") : ""}</small></div></div>
                    <div className="zoneVolume" onClick={e=>e.stopPropagation()} onPointerDown={e=>e.stopPropagation()}><Volume2 size={15}/><VolumeSlider device={d} setVolume={v=>setVolumeForDevice(d,v)} className="range zoneRange" disabled={!d.online}/><strong>{d.volume ?? 0}%</strong></div>
                  </div>
                  {grouped&&<div className="deviceGroupMembers">{members.map(memberRow)}</div>}
                </div>;
              })}
            </div>
          </section>

          <section className="workspace">
            <div className="deviceHeaderSticky">
              <div className="deviceHero">
                <div className="heroDevice"><Speaker size={42}/></div>
                <div className="heroInfo">
                  <div className="heroTitle">{device.name} {device.mock ? <span className="liveBadge demo">DEMO</span> : (device.online && String(device?.track?.playState || "").toLowerCase() === "play" ? <span className="liveBadge">LIVE</span> : null)}</div>
                  <div className="heroMeta">{device.model} <span>•</span> {driverLabel(device)} <span>•</span> {device.ip}:{device.port}</div>
                  <div className="heroStatus"><span className={device.online?"onlineDot":"offlineDot"}/>{device.online?"Online":"Offline"} <span>•</span> {device.version}</div>
                </div>
                <div className="heroStates">
                  <div><Wifi size={20}/><b>Network</b><span>{device.networkMode || "—"}</span></div>
                  <div><Radio size={20}/><b>Source</b><span>{device.source || "—"}</span></div>
                  <div><Network size={20}/><b>Multiroom</b><span>{device.multiroom || "—"}</span></div>
                </div>
              </div>

              <div className="tabs">
                {(navSection === "Setting" ? settingTabs : deviceTabs).map(t =>
                  <button key={t} className={tab===t?"active":""} onClick={()=>navigateTo(t)}>{t}</button>
                )}
              </div>
            </div>

            {tab==="Overview" && <Overview device={device} setVolume={setVolume} setSeek={setSeek} run={run} setTab={navigateTo} refresh={()=>refreshStatus(device,{silent:false})} trackOverride={effectiveTrackOverride} />}
            {tab==="Player" && <Player device={device} run={run} setVolume={setVolume} setSeek={setSeek} radioNowPlaying={radioNowPlaying} setRadioNowPlaying={setRadioNowPlaying} localTrackOverride={localTrackOverride || dlnaTrackOverride} onPrevious={()=>activeQueueStep(-1)} onNext={()=>activeQueueStep(1)} view="player"/>} 
            {tab==="Internet Radio" && <Player device={device} run={run} setVolume={setVolume} setSeek={setSeek} radioNowPlaying={radioNowPlaying} setRadioNowPlaying={setRadioNowPlaying} localTrackOverride={localTrackOverride || dlnaTrackOverride} onPrevious={()=>activeQueueStep(-1)} onNext={()=>activeQueueStep(1)} view="radio"/>}
            {tab==="Library" && <LocalMusicLibrary device={device} run={run} onPlayTrack={startLocalLibraryTrack} playback={localPlayback} onPlayDlna={startDlnaQueueTrack} dlnaPlayback={dlnaPlayback}/>} 
            {tab==="Source" && <Source device={device} run={run}/>} 
            {tab==="Volume" && <Volume device={device} setVolume={setVolume} run={run}/>} 
            {tab==="EQ" && (capabilitiesFor(device).eq
              ? (deviceTypeOf(device)===DEVICE_TYPES.AIRSCOPE ? <LinkplayEQ device={device} run={run} setVolume={setVolume}/> : <EQ device={device} run={run} setVolume={setVolume}/>)
              : <UnsupportedFeature title="EQ" device={device} note="A31 native tone EQ and A98/WiiM 10-band HTTP EQ are enabled. A97 remains disabled until its native control path is verified on real hardware."/>)} 
            {tab==="Network" && <NetworkPanel device={device} run={run}/>} 
            {tab==="Bluetooth" && (deviceTypeOf(device)===DEVICE_TYPES.AIRCLOUD ? <BluetoothPanel device={device} run={run}/> : <UnsupportedFeature title="Bluetooth settings" device={device} note="Bluetooth playback is available through Source; pairing/settings mapping will be added after basic driver verification."/>)} 
            {tab==="Multiroom" && <MultiroomPanel device={device} devices={devices} refreshAll={async()=>{await Promise.all(devices.filter(d=>d.online&&!d.mock).map(d=>refreshStatus(d,{silent:true})))}} requestDevice={api}/>} 
            {tab==="USB" && <USBPanel device={device} run={run}/>} 
            {tab==="System" && <SystemPanel device={device} run={run} removeCurrent={removeCurrent}/>} 

            {mode==="Installer Mode" && (
              <section className="installer">
                <div className="panelTitle"><div><h2>API Console</h2><p>Direct device command access. airCloud and Linkplay syntax are routed by the selected driver.</p></div><Activity size={20}/></div>
                <div className="consoleRow">
                  <select id="cmdSelect" defaultValue="getStatusEx">{API_COMMANDS.map(([cmd,g,desc])=><option key={cmd} value={cmd}>[{g}] {cmd} — {desc}</option>)}</select>
                  <button className="primaryBtn" onClick={()=>run(document.getElementById("cmdSelect").value)}>SEND</button>
                </div>
                <pre className="console">{lastResponse ? JSON.stringify(lastResponse,null,2) : "// response will appear here"}</pre>
                <div className="apiGrid">{API_COMMANDS.map(([cmd,g])=><div className="apiChip" key={cmd}><span>{g}</span><code>{cmd}</code></div>)}</div>
              </section>
            )}
          </section>
        </main>
      </div>

      <GlobalPlayerBar
        device={device}
        run={run}
        setVolume={setVolume}
        setSeek={setSeek}
        trackOverride={effectiveTrackOverride}
        onPrevious={()=>activeQueueStep(-1)}
        onNext={()=>activeQueueStep(1)}
      />

      {showAdd && <div className="modalBackdrop"><div className="modal">
        <div className="modalHead"><h2>Add Device</h2><button className="iconBtn" onClick={()=>setShowAdd(false)}><X size={18}/></button></div>
        <div className="deviceTypePicker">
          <button className={adding.deviceType===DEVICE_TYPES.AIRCLOUD?"selected":""} onClick={()=>setAdding({...adding,deviceType:DEVICE_TYPES.AIRCLOUD,port:String(defaultPortFor(DEVICE_TYPES.AIRCLOUD,adding.protocol))})}><b>airCloud</b><span>CLOUDIX A33</span></button>
          <button className={adding.deviceType===DEVICE_TYPES.AIRSCOPE?"selected":""} onClick={()=>setAdding({...adding,deviceType:DEVICE_TYPES.AIRSCOPE,port:String(defaultPortFor(DEVICE_TYPES.AIRSCOPE,adding.protocol))})}><b>airScope</b><span>Linkplay A31 / A97 / A98</span></button>
        </div>
        <label>Device name<input value={adding.name} onChange={e=>setAdding({...adding,name:e.target.value})} placeholder="CS-8 Audio"/></label>
        <label>IP address<input value={adding.ip} onChange={e=>setAdding({...adding,ip:e.target.value})} placeholder="192.168.0.12"/></label>
        <div className="twoCol"><label>Protocol<select value={adding.protocol} onChange={e=>setAdding({...adding,protocol:e.target.value,port:String(defaultPortFor(adding.deviceType,e.target.value))})}><option value="http">http</option><option value="https">https</option></select></label><label>Port<input value={adding.port} onChange={e=>setAdding({...adding,port:e.target.value})}/></label></div>
        <label className="check"><input type="checkbox" checked={adding.mock} onChange={e=>setAdding({...adding,mock:e.target.checked})}/> Demo / mock mode</label>
        <div className="modalActions"><button className="ghostBtn" onClick={()=>setShowAdd(false)}>Cancel</button><button className="primaryBtn" onClick={addDevice}>Add Device</button></div>
      </div></div>}
      {toast && <div className="toast">{toast}</div>}
    </div>
  );
}


function GlobalPlayerBar({device,run,setVolume,setSeek,trackOverride=null,onPrevious,onNext}) {
  const [volumeOpen,setVolumeOpen] = useState(false);
  const volumeRef = useRef(null);
  const track = trackOverride || device.track || {};
  const playing = isPlaying(track.playState);
  const total = Math.max(0, numberOr(track.total));
  const progress = Math.max(0, numberOr(track.progress));
  const live = total <= 0;
  const title = track.title || (normalizeSource(device.source)==="Network" ? "Live audio" : "Nothing playing");
  const artist = track.artist || track.service || device.source || "—";

  useEffect(()=>setVolumeOpen(false),[device.id]);
  useEffect(()=>{
    if (!volumeOpen) return;
    const close = (event) => {
      if (volumeRef.current && !volumeRef.current.contains(event.target)) setVolumeOpen(false);
    };
    document.addEventListener("pointerdown", close);
    return ()=>document.removeEventListener("pointerdown", close);
  },[volumeOpen]);

  return <footer className="globalPlayerBar">
    <div className="globalTrack">
      <Artwork track={track} device={device}/>
      <div className="globalTrackText">
        <strong>{title}</strong>
        <span>{artist}</span>
      </div>
    </div>

    <div className="globalTransport">
      <button onClick={()=>onPrevious?onPrevious():run("setPlayerCmd:prev")} title="Previous" aria-label="Previous">◀</button>
      <button className="globalPlay" onClick={()=>run("setPlayerCmd:onepause")} title={playing?"Pause":"Play"} aria-label={playing?"Pause":"Play"}>
        {playing?<Pause size={20}/>:<Play size={20}/>} 
      </button>
      <button onClick={()=>onNext?onNext():run("setPlayerCmd:next")} title="Next" aria-label="Next">▶</button>
    </div>

    <div className="globalProgress">
      <span>{live?"Live":formatTime(progress)}</span>
      <input
        type="range"
        min="0"
        max={Math.max(1,total)}
        value={Math.min(progress,Math.max(1,total))}
        disabled={live}
        onChange={e=>setSeek(e.target.value)}
        aria-label="Playback position"
      />
      {!live && <span>{formatTime(total)}</span>}
    </div>

    <div className="globalZone">
      <div className="zoneName"><Speaker size={16}/><span>{device.name}</span></div>
      <div className="footerVolumeAnchor" ref={volumeRef}>
        {volumeOpen && <div className="footerVolumePopover">
          <VolumeSlider device={device} setVolume={setVolume} className="footerVerticalRange" showValue/>
          <button
            className={`footerMuteBtn ${device.muted?"muted":""}`}
            onClick={()=>run(`setPlayerCmd:mute:${device.muted?0:1}`, {quiet:true})}
          >
            {device.muted?<VolumeX size={16}/>:<Volume2 size={16}/>} {device.muted?"Unmute":"Mute"}
          </button>
        </div>}
        <button
          className={`footerSpeakerBtn ${device.muted?"muted":""}`}
          onClick={()=>setVolumeOpen(v=>!v)}
          title={`Volume · ${device.name}`}
          aria-label={`Open volume for ${device.name}`}
        >
          {device.muted?<VolumeX size={21}/>:<Volume2 size={21}/>} 
        </button>
        <strong>{device.volume ?? 0}</strong>
      </div>
    </div>
  </footer>;
}

function UnsupportedFeature({title,device,note}){
  return <div className="single"><Panel><PanelTitle title={title} sub={`${driverLabel(device)} driver`}/><div className="unsupportedFeature"><h3>Driver mapping pending</h3><p>{note}</p><small>Core v0.4.1 test scope: Status · Player · Volume · Mute · Source · Internet Radio.</small></div></Panel></div>
}

function Panel({children, className=""}){return <div className={`panel ${className}`}>{children}</div>}
function PanelTitle({icon, title, sub, action}){return <div className="panelTitle"><div><h2>{title}</h2>{sub&&<p>{sub}</p>}</div><div className="panelTitleAction">{action}{icon}</div></div>}

function normalizeArtworkUrl(url, device) {
  const raw = String(url || "").trim();
  if (!raw || raw === "null") return "";
  if (/^https?:\/\//i.test(raw) || raw.startsWith("data:")) return raw;
  if (raw.startsWith("//")) return `${device?.protocol || "http"}:${raw}`;
  if (raw.startsWith("/")) return `${device?.protocol || "http"}://${device?.ip}:${device?.port || 8000}${raw}`;
  return raw;
}

function buildRadioTrackOverride(device, station) {
  // Radio Browser playback is sent with UPnP SetAVTransportURI, so older Linkplay
  // commonly reports mode 2 / DLNA rather than Network. Treat both as network
  // radio ownership; otherwise persisted station artwork disappears after restart.
  if (!station || !["Network", "DLNA"].includes(normalizeSource(device?.source))) return null;

  // v4.4.22 A33 remembered-radio rule. The ACS2 API documents getMetaInfo, but
  // real CL-BOPro firmware returns no radio metadata/artwork for direct http_music.
  // Never show a remembered A33 station merely because it exists in localStorage:
  // the zone must first be verified Online and must still report Network/http_music.
  // Native TuneIn/vTuner or any source change therefore releases this overlay.
  if (station._a33Remembered && !isA33DirectHttpRadio(device)) return null;
  const base = device?.track || {};

  // v4.4.12: Radio Browser metadata/artwork is a renderer-only overlay for
  // every device family. Older Linkplay firmware can keep reporting a stale
  // finite `total` from the item that played before the live radio stream.
  // The old 5-second guard therefore removed only the airControl artwork even
  // though the station kept playing and WiiM Home still retained its cover.
  // Do not expire the overlay from timing data; the ownership effect clears it
  // when playback/source genuinely changes. No command is sent to the player.

  const subtitle = [station.country, station.language].filter(Boolean).join(" · ");
  return {
    ...base,
    title: station.name || "Internet Radio",
    artist: subtitle || "Internet Radio",
    album: station.tags ? station.tags.split(",").slice(0,4).join(" · ") : "",
    // Prefer the Radio Browser favicon for a station started in this session,
    // but never mask artwork recovered from the player's UPnP metadata. If the
    // saved station has no favicon (common after reconnect/restart), the same
    // device.track artwork is used by Player, Overview and Zone Cards.
    art: station.favicon || base.art || "",
    service: "Internet Radio",
    url: station.url || ""
  };
}

function Artwork({track, device, big=false}) {
  const [failed,setFailed] = useState(false);
  const [retry,setRetry] = useState(0);
  const art = normalizeArtworkUrl(track?.art, device);
  useEffect(()=>{ setFailed(false); setRetry(0); },[art]);
  useEffect(()=>{
    if (!failed || !art) return;
    const timer=setTimeout(()=>{ setFailed(false); setRetry(v=>v+1); },1500);
    return ()=>clearTimeout(timer);
  },[failed, art]);
  if (art && !failed) return <div className={`albumArt ${big?"big":""}`}><img key={`${art}|${retry}`} src={art} alt="Album cover" onError={()=>setFailed(true)}/></div>;
  return <div className={`albumArt ${big?"big":""}`}><Disc3 size={big?72:42}/></div>;
}

function NowPlaying({device, run, setSeek, big=false, trackOverride=null, onPrevious=null, onNext=null}) {
  const track = trackOverride || device.track || {};
  const total = Math.max(0, numberOr(track.total));
  const progress = Math.min(total || numberOr(track.progress), numberOr(track.progress));
  const playing = isPlaying(track.playState);
  const pct = total ? Math.min(100, (progress/total)*100) : 0;
  const hasMetadata = Boolean(track.title && track.title !== "Nothing playing");
  const artist = track.artist || (hasMetadata ? "Unknown artist" : device.source || "—");
  const album = track.album || (hasMetadata ? "Unknown album" : "");
  return <div className={big?"playerBig nowPlayingBig":""}>
    <div className={big?"track bigTrack nowPlayingHero":"track"}>
      <Artwork track={track} device={device} big={big}/>
      <div className="trackInfo">
        {big && <div className="nowPlayingEyebrow">NOW PLAYING <span>{device.source || "—"}</span></div>}
        <strong>{track.title || "Nothing playing"}</strong>
        <span>{artist}</span>
        <small>{album}</small>
        {big && <div className="metaBadges"><span>{device.source || "—"}</span>{track.service && <span>{String(track.service).toUpperCase()==="QOBUZ"?"Qobuz":track.service}</span>}</div>}
        {!big && track.service && <div className="metaBadges compact"><span>{device.source || "—"}</span><span>{track.service}</span></div>}
      </div>
    </div>
    {big ? <div className="seekBlock"><input className="range seekRange" type="range" min="0" max={Math.max(1,total)} value={Math.min(progress,Math.max(1,total))} onChange={e=>setSeek(e.target.value)}/><div className="time"><span>{formatTime(progress)}</span><span>{formatTime(total)}</span></div></div> : <><div className="progress"><span style={{width:`${pct}%`}}/></div><div className="time"><span>{formatTime(progress)}</span><span>{formatTime(total)}</span></div></>}
    <div className="transport">
      <button onClick={()=>onPrevious?onPrevious():run("setPlayerCmd:prev")} title="Previous">◀</button>
      <button className="play" onClick={()=>run("setPlayerCmd:onepause")} title={playing?"Pause":"Play"}>{playing?<Pause size={21}/>:<Play size={21}/>}</button>
      <button onClick={()=>onNext?onNext():run("setPlayerCmd:next")} title="Next">▶</button>
      {!big && <button onClick={()=>run("setPlayerCmd:loopmode:2")}>↻</button>}
    </div>
  </div>;
}

function VolumeSlider({device, setVolume, className="range", showValue=false, disabled=false}) {
  const [localValue, setLocalValue] = useState(device.volume ?? 0);
  const dragging = useRef(false);
  const committedValue = useRef(device.volume ?? 0);

  useEffect(() => {
    if (!dragging.current) {
      const next = Number(device.volume ?? 0);
      committedValue.current = next;
      setLocalValue(next);
    }
  }, [device.volume, device.id]);

  const change = (e) => {
    // While dragging, only move the UI. Do not send HTTP commands yet.
    setLocalValue(Number(e.target.value));
  };

  const start = () => {
    dragging.current = true;
  };

  const finish = (e) => {
    const value = Number(e?.currentTarget?.value ?? localValue);
    dragging.current = false;
    setLocalValue(value);
    if (value !== committedValue.current) {
      committedValue.current = value;
      setVolume(value);
    }
  };

  return <div className="volumeSliderWrap">
    <input
      className={className}
      type="range"
      min="0"
      max={device.maxVolume || 100}
      value={localValue}
      disabled={disabled}
      onChange={change}
      onPointerDown={start}
      onPointerUp={finish}
      onPointerCancel={finish}
      onKeyDown={start}
      onKeyUp={finish}
      onBlur={(e) => { if (dragging.current) finish(e); }}
    />
    {showValue && <span className="sliderValue">{localValue}%</span>}
  </div>;
}

function parsePlatFormaGeometry(xmlText){
  const doc=new DOMParser().parseFromString(xmlText,"application/xml");
  const view=doc.querySelector("viewBox");
  const width=Number(view?.getAttribute("width"))||1382, height=Number(view?.getAttribute("height"))||1138;
  const nodes={}; doc.querySelectorAll("node").forEach(n=>nodes[n.getAttribute("id")]=[Number(n.getAttribute("x")),Number(n.getAttribute("y"))]);
  const regions={}; doc.querySelectorAll("region").forEach(r=>regions[r.getAttribute("id")]=(r.getAttribute("nodes")||"").trim().split(/\s+/));
  return {width,height,nodes,regions};
}
const PLATFORMA_GEOMETRY=parsePlatFormaGeometry(platFormaGeometryXml);
const PLATFORMA_VIEWBOX={width:PLATFORMA_GEOMETRY.width,height:PLATFORMA_GEOMETRY.height};
const PLATFORMA_NODES=PLATFORMA_GEOMETRY.nodes;
const PLATFORMA_REGIONS=PLATFORMA_GEOMETRY.regions;
function platFormaBoundsAtY(regionName, y){
  const pts=PLATFORMA_REGIONS[regionName].map(k=>PLATFORMA_NODES[k]);
  const xs=[];
  for(let i=0;i<pts.length;i++){
    const [x1,y1]=pts[i], [x2,y2]=pts[(i+1)%pts.length];
    if(y1===y2){ if(y===y1) xs.push(x1,x2); continue; }
    if(y>=Math.min(y1,y2) && y<=Math.max(y1,y2)) xs.push(x1+(y-y1)*(x2-x1)/(y2-y1));
  }
  xs.sort((a,b)=>a-b);
  return xs.length>=2 ? [xs[0],xs[xs.length-1]] : null;
}
function platFormaRect(regionName,y,widthRatio=.72,inset=12){
  const b=platFormaBoundsAtY(regionName,y); if(!b) return {};
  const avail=Math.max(0,b[1]-b[0]-inset*2), w=avail*widthRatio;
  // platForma rule: every side button is centered on the longitudinal axis
  // halfway between the two long region boundaries at this exact Y.
  const centerX=(b[0]+b[1])/2;
  const x=centerX-w/2;
  return {left:`${x/PLATFORMA_VIEWBOX.width*100}%`,top:`${y/PLATFORMA_VIEWBOX.height*100}%`,width:`${w/PLATFORMA_VIEWBOX.width*100}%`};
}
function platFormaCenteredRect(regionName,y,widthRatio=.82,inset=24){
  const b=platFormaBoundsAtY(regionName,y); if(!b) return {};
  const avail=Math.max(0,b[1]-b[0]-inset*2), w=avail*widthRatio;
  const centerX=(b[0]+b[1])/2;
  return {left:`${(centerX-w/2)/PLATFORMA_VIEWBOX.width*100}%`,top:`${y/PLATFORMA_VIEWBOX.height*100}%`,width:`${w/PLATFORMA_VIEWBOX.width*100}%`};
}
function platFormaPlayerRect(y,widthRatio=.82,inset=24){
  const b=platFormaBoundsAtY("player",y); if(!b) return {};
  // platForma rule: the Player uses the vertical bisector dropped from center_top.
  // Its X never follows an independently inferred container/flex center.
  const axisX=PLATFORMA_NODES.center_top[0];
  const halfAvail=Math.max(0,Math.min(axisX-b[0],b[1]-axisX)-inset);
  const w=halfAvail*2*widthRatio;
  return {left:`${(axisX-w/2)/PLATFORMA_VIEWBOX.width*100}%`,top:`${y/PLATFORMA_VIEWBOX.height*100}%`,width:`${w/PLATFORMA_VIEWBOX.width*100}%`};
}
function platFormaArtworkRect(topY, desiredSize=150, inset=30){
  // v4.4.36 strict platForma artwork rule:
  // artwork is a square geometry-bound object whose CENTER X is always the
  // exact Player bisector. Its size is limited by the narrowest triangle width
  // across the complete artwork vertical band, with a symmetric safety inset.
  const axisX=PLATFORMA_PLAYER_AXIS.x;
  const topBounds=platFormaBoundsAtY("player",topY);
  if(!topBounds) return {};
  const topHalf=Math.max(0,Math.min(axisX-topBounds[0],topBounds[1]-axisX)-inset);
  let size=Math.min(desiredSize,topHalf*2);
  // The player triangle widens downward, but keep the calculation generic so
  // later XML adjustments cannot make the lower edge collide with artwork.
  for(let i=0;i<4;i++){
    const bottomY=topY+size;
    const bottomBounds=platFormaBoundsAtY("player",bottomY);
    if(!bottomBounds) break;
    const bottomHalf=Math.max(0,Math.min(axisX-bottomBounds[0],bottomBounds[1]-axisX)-inset);
    size=Math.min(size,bottomHalf*2);
  }
  size=Math.max(0,size);
  return {
    left:`${(axisX-size/2)/PLATFORMA_VIEWBOX.width*100}%`,
    top:`${topY/PLATFORMA_VIEWBOX.height*100}%`,
    width:`${size/PLATFORMA_VIEWBOX.width*100}%`,
    height:`${size/PLATFORMA_VIEWBOX.height*100}%`
  };
}
function platFormaArtworkCenteredBetween(apexY, playCenterY, desiredSize=190, inset=30){
  // v4.4.38 strict rule: artwork CENTER is exactly halfway on the XML player
  // bisector between center_top and the Play button center.
  const centerY=(apexY+playCenterY)/2;
  let size=desiredSize;
  for(let i=0;i<5;i++){
    const topY=centerY-size/2, bottomY=centerY+size/2;
    const tb=platFormaBoundsAtY("player",topY), bb=platFormaBoundsAtY("player",bottomY);
    if(!tb || !bb) break;
    const axisX=PLATFORMA_PLAYER_AXIS.x;
    const half=Math.max(0,Math.min(axisX-tb[0],tb[1]-axisX,axisX-bb[0],bb[1]-axisX)-inset);
    size=Math.min(size,half*2);
  }
  size=Math.max(0,size);
  const axisX=PLATFORMA_PLAYER_AXIS.x;
  return {
    left:`${(axisX-size/2)/PLATFORMA_VIEWBOX.width*100}%`,
    top:`${(centerY-size/2)/PLATFORMA_VIEWBOX.height*100}%`,
    width:`${size/PLATFORMA_VIEWBOX.width*100}%`,
    height:`${size/PLATFORMA_VIEWBOX.height*100}%`
  };
}
function platFormaCenterPoint(regionName,y){
  const b=platFormaBoundsAtY(regionName,y); if(!b) return null;
  return {x:(b[0]+b[1])/2,y};
}
function platFormaPlayerAxis(){
  const apex=PLATFORMA_NODES.center_top;
  const left=PLATFORMA_NODES.inner_left, right=PLATFORMA_NODES.inner_right;
  const baseMidX=(left[0]+right[0])/2;
  const baseY=(left[1]+right[1])/2;
  return {apexX:apex[0],apexY:apex[1],x:baseMidX,baseY};
}
const PLATFORMA_PLAYER_AXIS=platFormaPlayerAxis();
function platFormaBox(regionName,pad=18){
  const pts=PLATFORMA_REGIONS[regionName].map(k=>PLATFORMA_NODES[k]);
  const xs=pts.map(p=>p[0]), ys=pts.map(p=>p[1]);
  const l=Math.min(...xs)+pad,r=Math.max(...xs)-pad,t=Math.min(...ys)+pad,b=Math.max(...ys)-pad;
  return {left:`${l/PLATFORMA_VIEWBOX.width*100}%`,top:`${t/PLATFORMA_VIEWBOX.height*100}%`,width:`${(r-l)/PLATFORMA_VIEWBOX.width*100}%`,height:`${(b-t)/PLATFORMA_VIEWBOX.height*100}%`};
}

function SalvadorStyle({devices,device,selectedId,setSelectedId,setInterfaceStyle,run,setVolume,trackOverride,onPrevious,onNext,openLibrary,openTab,requestDevice,refreshAll}) {
  const [sourceMode,setSourceMode] = useState("library");
  const [libraryMode,setLibraryMode] = useState("Internet Radio");
  const [contextTab,setContextTab] = useState("Popular");
  const [contextRows,setContextRows] = useState([]);
  const [contextLoading,setContextLoading] = useState(false);
  const [radioPath,setRadioPath] = useState([]);
  const [radioLevel,setRadioLevel] = useState("stations");
  const [radioQuery,setRadioQuery] = useState("");
  const [groupPicker,setGroupPicker] = useState(null);
  const [groupBusy,setGroupBusy] = useState(false);
  const [groupMessage,setGroupMessage] = useState("");
  const radioBack=()=>{ setRadioPath(p=>p.slice(0,-1)); setRadioLevel("stations"); };
  const isNativeLinkplay=d=>deviceTypeOf(d)===DEVICE_TYPES.AIRSCOPE&&Boolean(linkplayTransportFor(d));
  const groupUuid=d=>{
    const raw=String(d?.uuid||"").replace(/^uuid:/i,"").replace(/[^0-9a-f]/gi,"").toUpperCase();
    if(raw.length===32)return `${raw.slice(0,8)}-${raw.slice(8,12)}-${raw.slice(12,16)}-${raw.slice(16,20)}-${raw.slice(20)}`;
    return String(d?.uuid||"").replace(/^uuid:/i,"");
  };
  const normUuid=v=>String(v||"").replace(/^uuid:/i,"").replace(/[^0-9a-f]/gi,"").toUpperCase();
  const slaveOf=(d,master)=>Boolean(master&&((d?.masterIp&&d.masterIp===master.ip)||(normUuid(d?.masterUuid)&&normUuid(d.masterUuid)===normUuid(master.uuid))));
  const masterFor=d=>{
    if(!d)return null;
    if(d.masterIp||d.masterUuid)return devices.find(x=>x.id!==d.id&&((d.masterIp&&x.ip===d.masterIp)||(normUuid(d.masterUuid)&&normUuid(x.uuid)===normUuid(d.masterUuid))))||d;
    return devices.find(x=>x.id===d.id&&devices.some(y=>y.id!==x.id&&slaveOf(y,x)))||d;
  };
  const groupCount=d=>{const master=masterFor(d);return master?devices.filter(x=>x.id!==master.id&&slaveOf(x,master)).length:0};
  const grouped=d=>Boolean((d?.masterIp||d?.masterUuid)||groupCount(d)>0);
  const openGroupPicker=async(e,d)=>{e.preventDefault();e.stopPropagation();setSelectedId(d.id);setGroupMessage("");await refreshAll?.();setGroupPicker(d.id);};
  const toggleGroupMember=async(master,member)=>{
    if(groupBusy||!master||!member||!requestDevice)return;
    setGroupBusy(true);setGroupMessage("");
    try{
      const command=slaveOf(member,master)?"multiroom:LeaveGroup":`multiroom:JoinGroup:IP=${master.ip}:uuid=${groupUuid(master)}`;
      const r=await requestDevice(member,command);
      if(!r?.ok)throw new Error(r?.raw||r?.error||"Device rejected command");
      await new Promise(resolve=>setTimeout(resolve,800));
      await refreshAll?.();
    }catch(e){setGroupMessage(e?.message||String(e));}
    finally{setGroupBusy(false);}
  };

  const track = trackOverride || device?.track || {};
  useEffect(()=>{
    let cancelled=false;
    if(sourceMode!=="library"){ setContextRows([]); return ()=>{cancelled=true}; }
    if(libraryMode==="Internet Radio"){
      setContextLoading(true);
      topRadioStations(40,0).then(rows=>{ if(!cancelled) setContextRows(Array.isArray(rows)?rows:[]); })
        .catch(()=>{ if(!cancelled) setContextRows([]); })
        .finally(()=>{ if(!cancelled) setContextLoading(false); });
    } else {
      setContextRows([]);
      setContextLoading(false);
    }
    return ()=>{cancelled=true};
  },[sourceMode,libraryMode]);

  const playing = isPlaying(track.playState);
  const title = track.title || "Nothing playing";
  const artist = track.artist || "";
  const album = track.album || "";
  const progress = Math.max(0, Number(track.progress) || 0);
  const total = Math.max(0, Number(track.total) || 0);
  // Salvador v4.4.29: a stream with no finite duration is presented as LIVE, not as a broken seek timeline.
  const isLiveStream = total <= 0;
  const sourceItems = sourcesForDevice(device) || SOURCES;
  const fmt = sec => {
    const n=Math.max(0,Math.floor(Number(sec)||0));
    return `${Math.floor(n/60)}:${String(n%60).padStart(2,"0")}`;
  };
  const metaLine=(text,className="")=>{
    const value=String(text||"").trim();
    const scroll=value.split(/\s+/).filter(Boolean).length>5;
    return <div className={`platMetaLine ${className} ${scroll?"scroll":"static"}`}><span>{value||"—"}</span></div>;
  };
  // v4.4.37: ZONES and SOURCES are horizontally aligned to the XML center_top node.
  const headingY=PLATFORMA_NODES.center_top[1];
  const zonesHeading=platFormaCenteredRect("zones",headingY,.78,18);
  const sourcesHeading=platFormaCenteredRect("sources",headingY,.78,18);
  const libraryItems=["Internet Radio","This Device","USB","DLNA","SMB"];
  // v4.4.40 strict paired-row rule: Zones and Library/Inputs MUST consume
  // the same XML-coordinate Y slots. Missing items leave their slot empty.
  const sideYSlots=[300,358,416,474,532];
  // v4.4.52 platForma: device identities may move between the fixed XML slots,
  // but the button geometry itself NEVER moves.  Render each real Master first,
  // immediately followed by its Slaves, then free/unresolved zones.
  const platFormaZoneOrder=(()=>{
    const used=new Set();
    const ordered=[];
    const masters=devices.filter(m=>devices.some(d=>d.id!==m.id&&slaveOf(d,m)));
    for(const master of masters){
      if(!used.has(master.id)){ordered.push(master);used.add(master.id);}
      for(const member of devices.filter(d=>d.id!==master.id&&slaveOf(d,master))){
        if(!used.has(member.id)){ordered.push(member);used.add(member.id);}
      }
    }
    for(const d of devices){if(!used.has(d.id)){ordered.push(d);used.add(d.id);}}
    return ordered;
  })();
  const inputItems=sourceItems.slice(0,6);
  const lowerTabs={
    "Internet Radio":["Favorites","Search","Popular"],
    "This Device":["Artists","Albums","Folders","All Tracks"],
    USB:["Folders","Tracks"],
    DLNA:["Servers","Browse","Queue"],
    SMB:["Discovery","Shares","Browse"]
  };
  const lowerMenu=lowerTabs[libraryMode]||[];
  const openLibraryMode=(mode)=>{
    setRadioPath([]);
    setRadioLevel("stations");
    setLibraryMode(mode);
    const first=(lowerTabs[mode]||[])[0];
    if(first) setContextTab(first);
  };
  const openExistingBrowser=()=>{
    const tab=libraryMode==="Internet Radio"?"Internet Radio":libraryMode==="USB"?"USB":"Library";
    openTab?.(tab);
  };
  return <div className="salvadorRoot">
    <div className="salvadorTop">
      <div><b>airControl</b><span>v{APP_VERSION}</span><small>platForma — geometry XML v1</small></div>
      <button onClick={()=>setInterfaceStyle("standard")}>Standard Style</button>
    </div>
    <div className="salvadorStage geometryV1">
      <img className="salvadorSkeleton" src="./platForma-icon.png" alt="platForma brand geometry"/>
      <section className="salvadorZones" aria-label="Zones">
        <h2 style={zonesHeading}>Zones</h2>
        <div className="salvadorZoneList">{platFormaZoneOrder.slice(0,sideYSlots.length).map((d,i)=>{ const y=sideYSlots[i]; const count=groupCount(d); const actualMaster=masterFor(d); const isSlave=Boolean(actualMaster&&actualMaster.id!==d.id&&slaveOf(d,actualMaster)); return <button style={platFormaRect("zones",y,.72,18)} key={d.id} className={`${d.id===selectedId?"active":""} ${grouped(d)?"grouped":""} ${isSlave?"groupSlave":""}`} type="button" onClick={(e)=>{e.preventDefault();e.stopPropagation();setSelectedId(d.id)}}>
          <span className="zoneGlyph">{["⌂","◌","◇","□","△"][i%5]}</span><span className="zoneLabel"><b>{isSlave?"↳ ":""}{d.name}{!isSlave&&count>0?` +${count}`:""}</b><small>{isSlave?`SLAVE · ${actualMaster.name}`:count>0?`MASTER · ${count} slave${count===1?"":"s"}`:(d.online?"Online":"Offline")} · {deviceTypeOf(d)}</small></span>
          {isNativeLinkplay(d)&&<span className={`zoneGroupButton ${grouped(d)?"on":""}`} role="button" tabIndex="0" title="Multiroom" onClick={(e)=>openGroupPicker(e,d)}><Link2 size={14}/></span>}
        </button>})}</div>
      </section>
      <section className="salvadorPlayer" aria-label="Player">
        <div className="salvadorArtwork" style={platFormaArtworkRect(300,150,30)}><Artwork track={track} device={device}/></div>
        <div className="salvadorTransport" style={platFormaPlayerRect(500,.72,26)}><button onClick={onPrevious}>◀</button><button className="main" onClick={()=>run("setPlayerCmd:onepause")}>{playing?"Ⅱ":"▶"}</button><button onClick={onNext}>▶</button></div>
        <div className="salvadorMeta" style={platFormaPlayerRect(585,.88,28)}>{metaLine(artist,"artist")}{metaLine(title,"title")}{metaLine(album,"album")}</div>
        <div className={`salvadorProgress ${isLiveStream?"live":""}`} style={platFormaPlayerRect(690,.78,32)}>{isLiveStream ? <div className="salvadorLive"><span className="liveDot"/>LIVE</div> : <><input type="range" min="0" max={Math.max(1,total)} value={Math.min(progress,Math.max(1,total))} onChange={e=>run(`setPlayerCmd:setplay:${Math.round(Number(e.target.value)||0)}`,{quiet:true})}/><div><span>{fmt(progress)}</span><span>{fmt(total)}</span></div></>}</div>
      </section>
      <section className="salvadorSources" aria-label={sourceMode==="library"?"Library":"Inputs"}>
        <h2 className="sourceModeToggle" style={sourcesHeading}
            onClick={()=>setSourceMode(m=>m==="library"?"input":"library")}
            title="Switch Library / Inputs">{sourceMode==="library"?"Library":"Inputs"}</h2>
        {sourceMode==="library"
          ? <div className="salvadorSourceList frameless">{sideYSlots.map((y,i)=>{
              const label=libraryItems[i]; if(!label) return null;
              return <button style={platFormaRect("sources",y,.72,18)} key={label}
                className={libraryMode===label?"active":""} onClick={()=>openLibraryMode(label)}>{label}</button>
            })}</div>
          : <div className="salvadorSourceList frameless">{sideYSlots.map((y,i)=>{
              const src=inputItems[i]; if(!src) return null;
              const active=normalizeSource(device?.source)===normalizeSource(src.value)||normalizeSource(device?.source)===normalizeSource(src.label);
              return <button style={platFormaRect("sources",y,.72,18)} key={src.value}
                className={active?"active":""} onClick={()=>run(`setPlayerCmd:switchmode:${src.value}`)}>{src.label}</button>
            })}</div>}
      </section>
      <section className="salvadorLower browserOpen" style={platFormaBox("bottom",32)}>
        <div className="platLowerTopline">
          <b className="platLowerMode">{sourceMode==="library"?libraryMode:"Inputs"}</b>
          <div className="platLowerTabs">
            {sourceMode==="library" ? lowerMenu.map(item=><button key={item} className={contextTab===item?"active":""} onClick={()=>setContextTab(item)}>{item}</button>) : <span>Device inputs</span>}
          </div>
          <button className="platLowerOpen" onClick={openExistingBrowser}>Open</button>
        </div>
        <div className="platLowerList" role="list">
          {sourceMode==="library" && libraryMode==="Internet Radio" && radioPath.length>0 &&
            <div className="radioBreadcrumb">
              <button onClick={radioBack}>‹ Back</button>
              <span>{radioPath.map(x=>x.name).join(" / ")}</span>
            </div>}

          {sourceMode==="library" && libraryMode==="Internet Radio" && radioLevel==="station" && radioPath.length
            ? <div className="radioStationDetail">
                <b>{radioPath[radioPath.length-1].name}</b>
                <small>{radioPath[radioPath.length-1].row?.country || ""}{radioPath[radioPath.length-1].row?.tags ? " · "+radioPath[radioPath.length-1].row.tags : ""}</small>
                <button onClick={()=>playRadioStation?.(radioPath[radioPath.length-1].row)}>Play station</button>
              </div>
            : sourceMode!=="library" ? <div className="platLowerEmpty">Select an input in SOURCES</div> :
           libraryMode==="Internet Radio" ? (contextLoading ? <div className="platLowerEmpty">Loading stations…</div> :
             contextRows.length ? contextRows.map((station,i)=><button className="platLowerRow" key={station.stationuuid||station.url||i} onClick={openExistingBrowser}>
               <span>{station.name||"Unnamed station"}</span><small>{[station.country,station.tags].filter(Boolean).join(" · ")}</small>
             </button>) : <div className="platLowerEmpty">Open Radio browser to search stations</div>) :
           <div className="platLowerEmpty">Open {libraryMode} browser to load content</div>}
        </div>
        <div className="platLowerStatus">
          <div className="platLowerZone"><span>Selected zone</span><b>{device.name}</b><small>{device.online?"Online":"Offline"} · {device.source||"—"}</small></div>
          <div className="salvadorVolume"><Volume2 size={18}/><input type="range" min="0" max={device.maxVolume||100} value={device.volume??0} onChange={e=>setVolume(e.target.value)}/><b>{device.volume??0}%</b></div>
        </div>
      </section>
      {groupPicker&&(()=>{const opened=devices.find(d=>d.id===groupPicker);const master=masterFor(opened);if(!master)return null;const members=devices.filter(d=>d.online&&d.id!==master.id&&isNativeLinkplay(d));return <div className="platGroupBackdrop" onClick={()=>!groupBusy&&setGroupPicker(null)}><div className="platGroupDialog" onClick={e=>e.stopPropagation()}><button className="platGroupClose" onClick={()=>setGroupPicker(null)}>×</button><div className="platGroupTitle"><b>{master.name}{groupCount(master)>0?` +${groupCount(master)}`:""}</b><span>play in sync</span></div><div className="platGroupRows"><div className="platGroupRow master"><span>◉</span><b>{master.name}<small>MASTER</small></b><i>✓</i></div>{members.map(m=>{const linked=slaveOf(m,master);return <button key={m.id} className={`platGroupRow ${linked?"linked":""}`} disabled={groupBusy||(grouped(m)&&!linked)} onClick={()=>toggleGroupMember(master,m)}><span>▣</span><b>{m.name}<small>{linked?"SLAVE":"FREE"}</small></b><i>{linked?"✓":"○"}</i></button>})}</div>{groupMessage&&<div className="platGroupError">{groupMessage}</div>}<button className="platGroupDone" disabled={groupBusy} onClick={()=>setGroupPicker(null)}>{groupBusy?"Working…":"Done"}</button></div></div>})()}
    </div>
  </div>;
}

function Overview({device,setVolume,setSeek,run,setTab,refresh,trackOverride=null}){
  return <div className="overview">
    <div className="topPanels">
      <Panel className="nowPlaying">
        <PanelTitle title="Now Playing" icon={<Disc3 size={19}/>} action={<button className="miniRefresh" onClick={refresh}><RefreshCw size={15}/> Live</button>} />
        <NowPlaying device={device} run={run} setSeek={setSeek} trackOverride={trackOverride}/>
      </Panel>
      <Panel className="quick">
        <PanelTitle title="Quick Controls" />
        <div className="quickGrid">
          <button onClick={()=>run("setPlayerCmd:onepause")}>{isPlaying(device.track?.playState)?<Pause size={24}/>:<Play size={24}/>}<span>Play / Pause</span></button>
          <button onClick={()=>run("setPlayerCmd:next")}><ChevronRight size={25}/><span>Next</span></button>
          <button onClick={()=>run("setPlayerCmd:prev")}><ChevronRight className="rotate180" size={25}/><span>Previous</span></button>
          <button onClick={()=>setTab("Source")}><Radio size={21}/><span>Source</span><small>{device.source}</small></button>
          <button onClick={()=>setTab("Volume")}><Gauge size={21}/><span>Volume</span><small>{device.volume}%</small></button>
          <button onClick={()=>run(`setPlayerCmd:mute:${device.muted?0:1}`)}><span className="volIcon">{device.muted?"🔇":"🔊"}</span><span>{device.muted?"Unmute":"Mute"}</span></button>
        </div>
      </Panel>
    </div>
    <div className="metricGrid">
      <Panel><div className="metric"><Radio/><div><span>Current Source</span><strong>{device.source}</strong><small>{device.track?.streamSource || ""}</small></div><ChevronRight size={17}/></div></Panel>
      <Panel><div className="metric"><Gauge/><div><span>Volume</span><strong>{device.volume}% {device.muted&&<em>Muted</em>}</strong><VolumeSlider device={device} setVolume={setVolume}/></div></div></Panel>
      <Panel><div className="metric"><Wifi/><div><span>Network</span><strong>{device.networkMode || "—"} <em>{device.online?"Connected":"Offline"}</em></strong><small>{device.tcpIp || device.ip}</small></div><ChevronRight size={17}/></div></Panel>
      <Panel><div className="metric"><Network/><div><span>Multiroom</span><strong>{device.multiroom || "—"}</strong><small>{device.host && device.host!=="0" ? `Host: ${device.host}` : "Not in group"}</small></div><ChevronRight size={17}/></div></Panel>
    </div>
    <div className="featureGrid">
      {[["EQ","Custom EQ, presets and parametric settings",SlidersHorizontal,"EQ"],["Bluetooth","Pairing, device list and settings",Bluetooth,"Bluetooth"],["Network","Wi-Fi, static IP and advanced settings",Wifi,"Network"],["USB","Browse files and USB playback settings",HardDrive,"USB"],["System","Device info, firmware and lifecycle",Settings,"System"],["Diagnostics","Raw status and API information",Activity,"System"]].map(([t,s,I,target])=><button key={t} onClick={()=>setTab(target)} className="feature"><I/><div><b>{t}</b><span>{s}</span></div><ChevronRight size={17}/></button>)}
    </div>
  </div>
}

function Player({device,run,setVolume,setSeek,radioNowPlaying,setRadioNowPlaying,localTrackOverride=null,onPrevious=null,onNext=null,view="player"}){
  const initialRadioBrowserState = useMemo(()=>{
    try {
      const saved = JSON.parse(localStorage.getItem(RADIO_BROWSER_STATE_KEY) || "null");
      return saved && typeof saved === "object" ? saved : {};
    } catch { return {}; }
  },[]);
  const [radioQuery,setRadioQuery] = useState(initialRadioBrowserState.query || "");
  const [radioCountry,setRadioCountry] = useState(initialRadioBrowserState.country || "");
  const [radioTag,setRadioTag] = useState(initialRadioBrowserState.tag || "");
  const [radioStations,setRadioStations] = useState(Array.isArray(initialRadioBrowserState.stations) ? initialRadioBrowserState.stations : []);
  const [radioLoading,setRadioLoading] = useState(false);
  const [radioError,setRadioError] = useState(initialRadioBrowserState.error || "");
  const [radioTitle,setRadioTitle] = useState(initialRadioBrowserState.title || "Popular stations");
  const [playingRadioId,setPlayingRadioId] = useState("");
  const [radioPlayingBusy,setRadioPlayingBusy] = useState("");
  const [radioHasMore,setRadioHasMore] = useState(initialRadioBrowserState.hasMore ?? true);
  const [radioMode,setRadioMode] = useState(initialRadioBrowserState.mode || "popular");
  const [radioCompatibility,setRadioCompatibility] = useState(()=>{
    try {
      const saved = JSON.parse(localStorage.getItem(RADIO_COMPAT_KEY) || "{}");
      return saved && typeof saved === "object" && !Array.isArray(saved) ? saved : {};
    } catch { return {}; }
  });
  const [favorites,setFavorites] = useState(()=>{
    try {
      const saved = JSON.parse(localStorage.getItem(RADIO_FAVORITES_KEY) || "[]");
      return Array.isArray(saved) ? saved : [];
    } catch { return []; }
  });

  useEffect(()=>{
    localStorage.setItem(RADIO_FAVORITES_KEY, JSON.stringify(favorites));
  },[favorites]);

  useEffect(()=>{
    localStorage.setItem(RADIO_COMPAT_KEY, JSON.stringify(radioCompatibility));
  },[radioCompatibility]);

  useEffect(()=>{
    localStorage.setItem(RADIO_BROWSER_STATE_KEY, JSON.stringify({
      query:radioQuery, country:radioCountry, tag:radioTag, stations:radioStations,
      title:radioTitle, mode:radioMode, hasMore:radioHasMore, error:radioError
    }));
  },[radioQuery,radioCountry,radioTag,radioStations,radioTitle,radioMode,radioHasMore,radioError]);

  // Radio Browser metadata is a fallback overlay only while that live stream is
  // still active. Native-app playback always wins.
  const radioTrackOverride = useMemo(()=>buildRadioTrackOverride(device, radioNowPlaying),[radioNowPlaying, device.source, device.track]);

  const mergeStations = (current, incoming) => {
    const seen = new Set(current.map(st => st.id || st.url));
    return [...current, ...incoming.filter(st => {
      const key = st.id || st.url;
      if (!key || seen.has(key)) return false;
      seen.add(key);
      return true;
    })];
  };

  const loadPopular = async ({append=false}={}) => {
    setRadioLoading(true); setRadioError(""); setRadioTitle("Popular stations"); setRadioMode("popular");
    try {
      const offset = append ? radioStations.length : 0;
      const list = await topRadioStations(RADIO_PAGE_SIZE, offset);
      setRadioStations(current => append ? mergeStations(current,list) : list);
      setRadioHasMore(list.length === RADIO_PAGE_SIZE);
    }
    catch(e){ setRadioError(e.message || "Could not load Internet Radio"); }
    finally { setRadioLoading(false); }
  };

  useEffect(()=>{ if (!radioStations.length) loadPopular(); },[]);

  // v3.0.7.43: keep Internet Radio row/preset highlighting synchronized with
  // the station that airControl actually considers active. This mirrors the
  // Library fix: the highlight follows current playback state instead of the
  // first row that was clicked.
  useEffect(()=>{
    setPlayingRadioId(radioNowPlaying ? (radioNowPlaying.id || radioNowPlaying.url || "") : "");
  },[radioNowPlaying]);

  const searchRadio = async ({append=false}={}) => {
    const hasFilters = radioQuery.trim() || radioCountry.trim() || radioTag.trim();
    if (!hasFilters) return loadPopular({append});
    setRadioLoading(true); setRadioError(""); setRadioTitle("Search results"); setRadioMode("search");
    try {
      const offset = append ? radioStations.length : 0;
      const list = await searchRadioStations({name:radioQuery,country:radioCountry,tag:radioTag,limit:RADIO_PAGE_SIZE,offset});
      setRadioStations(current => append ? mergeStations(current,list) : list);
      setRadioHasMore(list.length === RADIO_PAGE_SIZE);
      if (!append && !list.length) setRadioError("No stations found. Try a shorter name, another country or genre.");
    } catch(e){ setRadioError(e.message || "Radio search failed"); }
    finally { setRadioLoading(false); }
  };

  const loadMoreRadio = () => radioMode === "popular" ? loadPopular({append:true}) : searchRadio({append:true});

  const compatibilityKey = station => {
    const stationKey = station?.id || station?.url || "";
    return stationKey ? `${device.id}::${stationKey}` : "";
  };
  const markCompatibility = (station, state, extra={}) => {
    const key = compatibilityKey(station);
    if (!key) return;
    setRadioCompatibility(current => ({...current,[key]:{state,at:Date.now(),...extra}}));
  };

  const playbackState = statusResult => {
    const info = statusResult?.data && typeof statusResult.data === "object" ? statusResult.data : {};
    const state = String(info?.PlayState || info?.status || "").trim().toLowerCase();
    if (!state) return "unknown";
    if (/pause|stop|idle|none/.test(state) || state === "0") return "stopped";
    if (/play/.test(state) || state === "1") return "playing";
    return "unknown";
  };

  const tryRadioUrl = async streamUrl => {
    const result = await run(`setPlayerCmd:play:${streamUrl}`, {quiet:true});
    const reply = String(result?.raw || "").trim();
    if (!result?.ok || /^(FAIL|ERROR)$/i.test(reply) || /INVALID URL/i.test(reply)) {
      return {ok:false, reply:reply || result?.error || "Rejected"};
    }
    // A network player may return OK before a stream has actually opened.  Give
    // it a moment, then ask getStatusEx.  If PlayState is available it becomes
    // our compatibility check.  Unknown firmware values are kept as accepted
    // rather than incorrectly rejecting a stream that may in fact be audible.
    await new Promise(r=>setTimeout(r,1250));
    const status = await run(deviceTypeOf(device)===DEVICE_TYPES.AIRSCOPE ? "getPlayerStatus" : "getStatusEx", {quiet:true});
    const state = playbackState(status);
    return {ok:state !== "stopped", verified:state === "playing", reply, state};
  };

  const playStation = async (station) => {
    if (!station?.url) return;
    const stationKey = station.id || station.url || "";
    setRadioPlayingBusy(stationKey);
    setRadioError("");
    try {
      await run("setPlayerCmd:switchmode:Network", {quiet:true});
      await new Promise(r=>setTimeout(r,140));

      // Reset the transport before probing. This prevents a previously-playing
      // station from making a dead replacement URL look successful in the reported state.
      await run("setPlayerCmd:pause", {quiet:true});
      await new Promise(r=>setTimeout(r,180));

      let alternatives = [];
      try { alternatives = await findRadioAlternatives(station, 16); } catch { alternatives = []; }

      const urlCandidates = [];
      const addCandidate = (url, sourceStation=station) => {
        url = String(url || "").trim();
        if (!url || urlCandidates.some(c=>c.url===url)) return;
        urlCandidates.push({url, sourceStation});
      };
      addCandidate(station.url, station);
      addCandidate(station.originalUrl, station);
      alternatives.forEach(alt=>{ addCandidate(alt.url,alt); addCandidate(alt.originalUrl,alt); });

      let accepted = null;
      let verified = false;
      let lastReply = "";
      for (const candidate of urlCandidates.slice(0,12)) {
        const result = await tryRadioUrl(candidate.url);
        lastReply = result.reply || lastReply;
        if (result.ok) {
          accepted = candidate;
          verified = Boolean(result.verified);
          break;
        }
      }

      if (!accepted) {
        markCompatibility(station,"failed",{reason:lastReply || "No compatible stream URL"});
        throw new Error(lastReply || "No compatible stream URL was found for this device");
      }

      const selected = {...station, url:accepted.url, resolvedFrom:accepted.sourceStation?.id || station.id};

      // v3.0.7.44: A31/AirScope radio uses the same proven UPnP DIDL-Lite
      // metadata path as Local Library, including a LAN-proxied station logo.
      if (deviceTypeOf(device) === DEVICE_TYPES.AIRSCOPE && window.airCloud?.playRadioStationUpnp) {
        const subtitle = [selected.country, selected.language].filter(Boolean).join(" · ") || "Internet Radio";
        const album = selected.tags ? selected.tags.split(",").slice(0,4).join(" · ") : "Internet Radio";
        const upnp = await window.airCloud.playRadioStationUpnp({
          deviceIp: device.ip,
          url: accepted.url,
          title: selected.name || "Internet Radio",
          artist: subtitle,
          album,
          artUrl: selected.favicon || ""
        });
        if (!upnp?.ok) throw new Error(upnp?.error || upnp?.raw || `UPnP ${upnp?.step || "radio play"} failed`);
      }
      setPlayingRadioId(stationKey);
      setRadioNowPlaying(selected);
      // v4.4.27: Player is a child component and does not own App.setDevices.
      // setRadioNowPlaying(selected) above is the renderer-safe immediate artwork path;
      // device polling will update the canonical device track independently.
      markCompatibility(station, verified ? "verified" : "accepted", {url:accepted.url});
      countRadioClick(accepted.sourceStation?.id || station.id);
    } catch(e) {
      setRadioError(`Could not play ${station.name}: ${e.message}`);
    } finally {
      setRadioPlayingBusy("");
    }
  };

  const toggleFavorite = (station) => {
    const key = station.id || station.url;
    setFavorites(current => {
      const exists = current.some(s => (s.id || s.url) === key);
      if (exists) return current.filter(s => (s.id || s.url) !== key);
      return [...current, station].slice(-24);
    });
  };

  const favoriteKeys = useMemo(()=>new Set(favorites.map(s=>s.id || s.url)),[favorites]);
  const presets = favorites.slice(0,10);

  return <div className="single">
    {view === "player" && <>
    <Panel className="playerPanel">
      <PanelTitle title="Player" sub={`${driverLabel(device)} · live title, artist, album and playback status`}/>
      <NowPlaying device={device} run={run} setSeek={setSeek} big trackOverride={localTrackOverride || radioTrackOverride} onPrevious={localTrackOverride?onPrevious:null} onNext={localTrackOverride?onNext:null}/>
      <div className="playerPlaybackSettings">
        <div className="playerPlaybackSettingsTitle">Playback settings</div>
        <div className="playerPlaybackSettingsGrid">
          <label>Loop mode<select onChange={e=>run(`setPlayerCmd:loopmode:${e.target.value}`)}><option value="3">List not looping</option><option value="1">Single loop</option><option value="2">List loop</option><option value="4">Random list loop</option><option value="5">Random list not looping</option></select></label>
          <label>Channel<select onChange={e=>run(`setChannel:${e.target.value}`)}><option value="rl">Stereo</option><option value="ll">Left</option><option value="rr">Right</option></select></label>
        </div>
      </div>
    </Panel>

    <Panel>
      <PanelTitle title="Quick radio presets" sub="Save Internet Radio stations with ★ and recall the first ten here"/>
      <div className="radioPresets">
        {Array.from({length:10},(_,i)=>{
          const station=presets[i];
          return station
            ? <div key={station.id||station.url} className={playingRadioId===(station.id||station.url)?"radioPreset active":"radioPreset"} title={station.name}>
                <button className="radioPresetPlay" onClick={()=>playStation(station)}>
                  <span className="presetNo">{i+1}</span><RadioLogo station={station}/><b>{station.name}</b>
                </button>
                <button className="presetRemove" title="Remove preset" onClick={()=>{if(window.confirm(`Remove preset “${station.name}”?`)) toggleFavorite(station)}}><X size={13}/></button>
              </div>
            : <div key={`empty-${i}`} className="radioPreset empty"><span className="presetNo">{i+1}</span><Radio size={18}/><b>Empty preset</b></div>;
        })}
      </div>
    </Panel>

    <Panel>
      <PanelTitle title="Devices presets" sub="Native player preset buttons 1–10"/>
      <div className="devicePresetGrid">
        {Array.from({length:10},(_,i)=><button key={i+1} onClick={()=>run(`setPlayerCmd:playPreset:${i+1}`)}><span>{i+1}</span><b>Preset {i+1}</b></button>)}
      </div>
    </Panel>
    </>}

    {view === "radio" && <Panel className="internetRadioPanel">
      <PanelTitle title="Internet Radio" sub={`Radio Browser directory · direct stream playback on ${driverLabel(device)}`} action={<button className="miniRefresh" onClick={()=>loadPopular()} disabled={radioLoading}><RefreshCw size={14} className={radioLoading?"spin":""}/> Popular</button>}/>
      <div className="internetRadioPresetsBlock">
        <div className="radioSectionHead"><b>Quick radio presets</b><span>Shared with Player · first ten favorites</span></div>
        <div className="radioPresets">
          {Array.from({length:10},(_,i)=>{
            const station=presets[i];
            return station
              ? <div key={station.id||station.url} className={playingRadioId===(station.id||station.url)?"radioPreset active":"radioPreset"} title={station.name}>
                  <button className="radioPresetPlay" onClick={()=>playStation(station)}>
                    <span className="presetNo">{i+1}</span><RadioLogo station={station}/><b>{station.name}</b>
                  </button>
                  <button className="presetRemove" title="Remove preset" onClick={()=>{if(window.confirm(`Remove preset “${station.name}”?`)) toggleFavorite(station)}}><X size={13}/></button>
                </div>
              : <div key={`radio-empty-${i}`} className="radioPreset empty"><span className="presetNo">{i+1}</span><Radio size={18}/><b>Empty preset</b></div>;
          })}
        </div>
      </div>
      <div className="radioSearchGrid">
        <label>Station name<input value={radioQuery} onChange={e=>setRadioQuery(e.target.value)} onKeyDown={e=>{if(e.key==="Enter")searchRadio()}} placeholder="Jazz, BBC, Radio..."/></label>
        <label>Country<input value={radioCountry} onChange={e=>setRadioCountry(e.target.value)} onKeyDown={e=>{if(e.key==="Enter")searchRadio()}} placeholder="Ukraine, Germany..."/></label>
        <label>Genre / tag<input value={radioTag} onChange={e=>setRadioTag(e.target.value)} onKeyDown={e=>{if(e.key==="Enter")searchRadio()}} placeholder="jazz, rock, news..."/></label>
        <button className="primaryBtn radioSearchBtn" onClick={searchRadio} disabled={radioLoading}><Search size={16}/>{radioLoading?"Searching...":"Search"}</button>
      </div>
      <div className="radioSectionHead"><b>{radioTitle}</b><span>{radioStations.length} station{radioStations.length===1?"":"s"}</span></div>
      {radioError && <div className="radioError">{radioError}</div>}
      {radioLoading && !radioStations.length ? <div className="radioEmpty">Loading Internet Radio directory…</div> :
        <div className="radioStationList">
          {radioStations.map(station=>{
            const key=station.id||station.url;
            const compatKey=compatibilityKey(station);
            const fav=favoriteKeys.has(key);
            const busy=radioPlayingBusy===key;
            const active=playingRadioId===key;
            return <div className={active?"radioStation active":"radioStation"} key={key}>
              <RadioLogo station={station}/>
              <div className="radioStationInfo">
                <b>{station.name}</b>
                <span>{[station.country,station.language].filter(Boolean).join(" · ") || "Internet Radio"}</span>
                <small>{station.tags ? station.tags.split(",").slice(0,4).join(" · ") : "No genre tags"}</small>
              </div>
              <RadioCompatibilityBadge station={station} record={radioCompatibility[compatKey]} device={device}/>
              <div className="radioTech">
                <span>{station.codec || "STREAM"}</span>
                {station.bitrate>0 && <small>{station.bitrate} kbps</small>}
                {station.hls && <small className="radioWarn">HLS</small>}
              </div>
              <button className={fav?"radioFav active":"radioFav"} onClick={()=>toggleFavorite(station)} title={fav?"Remove from presets":"Add to presets"}>{fav?"★":"☆"}</button>
              <button className="radioPlayBtn" onClick={()=>playStation(station)} disabled={busy}>{busy?<RefreshCw size={15} className="spin"/>:<Play size={15}/>}<span>{active?"Playing":"Play"}</span></button>
            </div>;
          })}
          {!radioLoading && !radioStations.length && !radioError && <div className="radioEmpty">No stations to show.</div>}
        </div>}
      {radioStations.length>0 && radioHasMore && <button className="radioLoadMore" onClick={loadMoreRadio} disabled={radioLoading}>{radioLoading?<RefreshCw size={14} className="spin"/>:<Plus size={14}/>} {radioLoading?"Loading…":"Load 50 more"}</button>}
      <div className="radioFootnote">airCloudCTRL remembers radio-stream compatibility separately for each device. A green badge means this exact player reported a playing state; amber means the URL was accepted but the status was not conclusive; failed URLs are remembered and alternative Radio Browser records are tried automatically.</div>
    </Panel>}

  </div>;
}

function RadioCompatibilityBadge({station,record,device}){
  const label = deviceTypeOf(device) === DEVICE_TYPES.AIRSCOPE ? "Linkplay" : "A33";
  if (record?.state === "verified") return <div className="radioCompat verified" title="This station has played successfully on this device">● {label} verified</div>;
  if (record?.state === "accepted") return <div className="radioCompat accepted" title="The device accepted the URL, but playback status was not conclusive">● {label} accepted</div>;
  if (record?.state === "failed") return <div className="radioCompat failed" title="Previous playback attempts failed on this device">× Failed</div>;
  if (station?.lastCheckOk) return <div className="radioCompat directory" title="Radio Browser reports this stream as healthy">● Directory OK</div>;
  return <div className="radioCompat untested" title="Not tested on this device yet">○ Untested</div>;
}

function RadioLogo({station}){
  const [failed,setFailed]=useState(false);
  useEffect(()=>setFailed(false),[station?.favicon]);
  if (station?.favicon && !failed) return <div className="radioLogo"><img src={station.favicon} alt="" onError={()=>setFailed(true)}/></div>;
  return <div className="radioLogo fallback"><Radio size={18}/></div>;
}
function Source({device,run}){const deviceSources=sourcesForDevice(device)||SOURCES; return <div className="single"><Panel><PanelTitle title="Source" sub="Select the active playback input"/><div className="sourceGrid">{deviceSources.map(s=>{const active=normalizeSource(device.source)===normalizeSource(s.value)||normalizeSource(device.source)===normalizeSource(s.label);return <button className={active?"source selected":"source"} key={s.value} onClick={()=>run(`setPlayerCmd:switchmode:${s.value}`)}><Radio size={21}/><div><b>{s.label}</b><span>{active?"Active":"Available when supported"}</span></div></button>})}</div></Panel></div>}
function Volume({device,setVolume,run}){return <div className="single"><Panel><PanelTitle title="Volume" sub="Master level, mute and safety limit"/><div className="volumeBig"><Gauge size={40}/><strong>{device.volume}</strong><span>/ {device.maxVolume||100}</span></div><VolumeSlider device={device} setVolume={setVolume} className="range huge" showValue/><div className="volumeActions"><button onClick={()=>run("setPlayerCmd:RemoteVol--")}>−</button><button onClick={()=>run(`setPlayerCmd:mute:${device.muted?0:1}`)}>{device.muted?"Unmute":"Mute"}</button><button onClick={()=>run("setPlayerCmd:RemoteVol++")}>+</button></div>{deviceTypeOf(device)===DEVICE_TYPES.AIRCLOUD && <label>Maximum volume<input type="number" min="10" max="100" defaultValue={device.maxVolume||100} onBlur={e=>run(`setPlayerCmd:maximumVolume:${e.target.value}`)}/></label>}</Panel></div>}
const GRAPHIC_BANDS = [32,64,125,250,500,1000,2000,4000,8000,16000];
const EQ_MODES = [
  ["0000","Off"],
  ["0001","Bass / Treble"],
  ["0010","Graphic EQ"],
  ["0011","Bass/Treble + Graphic"],
  ["0100","Parametric EQ"],
  ["0101","Parametric + Bass/Treble"]
];
const FILTERS = ["PK","LS","HS","LP","HP","OFF"];

function eqPayload(result){
  if (!result?.ok) return null;
  if (result.data && typeof result.data === "object") return result.data;
  if (typeof result.raw === "string") {
    try { return JSON.parse(result.raw); } catch {}
  }
  return null;
}


const ROOM_FREQS = [20,25,31.5,40,50,63,80,100,125,160,200,250,315,400,500,630,800,1000,1250,1600,2000,2500,3150,4000,5000,6300,8000,10000,12500,16000,20000];

function median(values=[]) {
  const a = values.filter(Number.isFinite).slice().sort((x,y)=>x-y);
  if (!a.length) return 0;
  const m = Math.floor(a.length/2);
  return a.length % 2 ? a[m] : (a[m-1]+a[m])/2;
}

function smoothRoomCurve(curve=[]) {
  // Log-frequency Gaussian smoothing, close to 1/6-octave visual/analysis smoothing.
  const sigmaOct = 0.18;
  return curve.map(point=>{
    let wsum=0, vsum=0;
    for (const other of curve) {
      const d = Math.log2(other.f/point.f);
      if (Math.abs(d) > 0.60) continue;
      const w = Math.exp(-0.5*(d/sigmaOct)*(d/sigmaOct));
      if (Number.isFinite(other.db)) { wsum += w; vsum += w*other.db; }
    }
    return {f:point.f,db:wsum ? vsum/wsum : point.db};
  });
}

function peqMagnitudeDb(freq, fc, q, gainDb, sampleRate=48000) {
  // RBJ peaking-EQ magnitude, matching a conventional digital PK filter closely enough
  // for a preview. The CS-8 remains the final authority after a re-measurement.
  if (!Number.isFinite(freq) || !Number.isFinite(fc) || !Number.isFinite(q) || !Number.isFinite(gainDb) || q<=0) return 0;
  const A = Math.pow(10,gainDb/40);
  const w0 = 2*Math.PI*Math.min(fc,sampleRate*0.45)/sampleRate;
  const alpha = Math.sin(w0)/(2*q);
  let b0=1+alpha*A, b1=-2*Math.cos(w0), b2=1-alpha*A;
  let a0=1+alpha/A, a1=-2*Math.cos(w0), a2=1-alpha/A;
  b0/=a0; b1/=a0; b2/=a0; a1/=a0; a2/=a0;
  const w = 2*Math.PI*Math.min(freq,sampleRate*0.45)/sampleRate;
  const c1=Math.cos(w), s1=Math.sin(w), c2=Math.cos(2*w), s2=Math.sin(2*w);
  const nr=b0+b1*c1+b2*c2, ni=-(b1*s1+b2*s2);
  const dr=1+a1*c1+a2*c2, di=-(a1*s1+a2*s2);
  const den=dr*dr+di*di;
  if (den<=0) return 0;
  const mag2=(nr*nr+ni*ni)/den;
  return mag2>0 ? 10*Math.log10(mag2) : 0;
}

function RoomEqMeasurement({device,run,setVolume,onLoadPeq}) {
  const [signal,setSignal] = useState("pink");
  const [signalState,setSignalState] = useState("stopped");
  const [signalUrl,setSignalUrl] = useState("");
  const [mics,setMics] = useState([]);
  const [micId,setMicId] = useState("");
  const [micActive,setMicActive] = useState(false);
  const [inputDb,setInputDb] = useState(-100);
  const [liveCurve,setLiveCurve] = useState([]);
  const [measured,setMeasured] = useState([]);
  const [measuring,setMeasuring] = useState(false);
  const [measureProgress,setMeasureProgress] = useState(0);
  const [target,setTarget] = useState("house");
  const [suggestion,setSuggestion] = useState([]);
  const [smoothedCurve,setSmoothedCurve] = useState([]);
  const [normalizedCurve,setNormalizedCurve] = useState([]);
  const [curveMode,setCurveMode] = useState("normalized");
  const [predictedCurve,setPredictedCurve] = useState([]);
  const [status,setStatus] = useState("Room EQ is ready. Pink noise is recommended for the first measurement.");
  const streamRef = useRef(null);
  const audioRef = useRef(null);
  const rafRef = useRef(null);
  const liveCurveRef = useRef([]);
  const micMeterFillRef = useRef(null);

  const targetDb = (f) => {
    if (target === "flat") return 0;
    // Gentle house curve: +4 dB at 20 Hz, 0 dB around 1 kHz, -2 dB at 20 kHz.
    if (f <= 1000) return 4 * Math.max(0, Math.min(1, Math.log10(1000/f) / Math.log10(1000/20)));
    return -2 * Math.max(0, Math.min(1, Math.log10(f/1000) / Math.log10(20000/1000)));
  };

  const stopMic = () => {
    if (rafRef.current) cancelAnimationFrame(rafRef.current);
    rafRef.current = null;
    if (streamRef.current) streamRef.current.getTracks().forEach(t=>t.stop());
    streamRef.current = null;
    if (audioRef.current) audioRef.current.close().catch(()=>{});
    audioRef.current = null;
    setMicActive(false);
    setInputDb(-100);
  };

  useEffect(()=>()=>stopMic(),[]);

  const refreshMics = async () => {
    try {
      if (window.airCloud?.requestMicrophonePermission) await window.airCloud.requestMicrophonePermission();
      const temp = await navigator.mediaDevices.getUserMedia({audio:true});
      const list = await navigator.mediaDevices.enumerateDevices();
      temp.getTracks().forEach(t=>t.stop());
      const inputs = list.filter(d=>d.kind === "audioinput");
      setMics(inputs);
      if (!micId && inputs[0]) setMicId(inputs[0].deviceId);
      setStatus(inputs.length ? `Microphones found: ${inputs.length}.` : "No microphone input was found.");
    } catch (e) {
      setStatus(`Microphone access failed: ${e.message}`);
    }
  };

  const startMic = async () => {
    try {
      stopMic();
      if (window.airCloud?.requestMicrophonePermission) await window.airCloud.requestMicrophonePermission();
      const constraints = {audio:{
        deviceId: micId ? {exact:micId} : undefined,
        autoGainControl:false, echoCancellation:false, noiseSuppression:false,
        channelCount:1
      }};
      const stream = await navigator.mediaDevices.getUserMedia(constraints);
      const Ctx = window.AudioContext || window.webkitAudioContext;
      const ctx = new Ctx();
      const source = ctx.createMediaStreamSource(stream);
      const analyser = ctx.createAnalyser();
      analyser.fftSize = 8192;
      analyser.smoothingTimeConstant = 0.72;
      analyser.minDecibels = -110;
      analyser.maxDecibels = -10;
      source.connect(analyser);
      streamRef.current = stream;
      audioRef.current = ctx;
      setMicActive(true);
      setStatus("Microphone is active. Keep the microphone at the listening position.");

      const td = new Float32Array(analyser.fftSize);
      const fd = new Float32Array(analyser.frequencyBinCount);
      const draw = () => {
        analyser.getFloatTimeDomainData(td);
        let sum=0;
        for (let i=0;i<td.length;i++) sum += td[i]*td[i];
        const rms = Math.sqrt(sum/td.length);
        const nextInputDb = rms>0 ? Math.max(-100,20*Math.log10(rms)) : -100;
        setInputDb(nextInputDb);
        // Update the meter fill directly on every audio animation frame.
        // Using transform instead of animated width avoids an Electron/Chromium
        // repaint issue where the numeric dBFS value updated but the bar did not
        // repaint until another UI event (for example mouse movement) occurred.
        const meterLevel = Math.max(0,Math.min(1,(nextInputDb+60)/60));
        if (micMeterFillRef.current) {
          micMeterFillRef.current.style.transform = `scaleX(${meterLevel})`;
        }

        analyser.getFloatFrequencyData(fd);
        const binHz = ctx.sampleRate/analyser.fftSize;
        let curve = ROOM_FREQS.map(f=>{
          const lo = Math.max(1,Math.floor((f/Math.pow(2,1/12))/binHz));
          const hi = Math.min(fd.length-1,Math.ceil((f*Math.pow(2,1/12))/binHz));
          let total=0,count=0;
          for (let b=lo;b<=hi;b++) if (Number.isFinite(fd[b])) { total += fd[b]; count++; }
          let db = count ? total/count : -110;
          if (signal === "pink") db += 3.0103*Math.log2(f/1000);
          return {f,db};
        });
        const refs = curve.filter(x=>x.f>=500 && x.f<=2000).map(x=>x.db);
        const ref = median(refs);
        // Keep the full relative measurement. Do not hard-clip the data here;
        // the graph chooses its own dynamic dB range in v0.3.1.
        curve = curve.map(x=>({f:x.f,db:x.db-ref}));
        liveCurveRef.current = curve;
        setLiveCurve(curve);
        rafRef.current = requestAnimationFrame(draw);
      };
      draw();
      return true;
    } catch (e) {
      setMicActive(false);
      setStatus(`Could not start microphone: ${e.message}`);
      return false;
    }
  };

  const startSignal = async (kind=signal) => {
    try {
      if (!window.airCloud?.getTestAudioInfo) throw new Error("Desktop test-audio bridge is unavailable. Restart Electron after installing the patch.");
      const info = await window.airCloud.getTestAudioInfo(device.ip);
      const url = info?.urls?.[kind];
      if (!url) throw new Error("Could not create the test signal URL.");
      setSignalUrl(url);
      setSignalState("starting");
      const r = await run(`setPlayerCmd:play:${url}`,{quiet:true});
      const reply = String(r?.raw || "").trim();
      const upperReply = reply.toUpperCase();
      if (!r?.ok || upperReply === "FAIL" || upperReply === "ERROR" || upperReply.includes("INVALID URL")) throw new Error(reply || "Player rejected the URL");
      setSignalState("playing");
      setStatus(`Player accepted test signal: ${reply || "OK"}. ${kind === "pink" ? "Pink noise" : kind === "white" ? "White noise" : "20 Hz–20 kHz sweep"} → ${device.name}. Test server: ${info.host}:${info.port}`);
    } catch (e) {
      setSignalState("stopped");
      setStatus(`Test playback failed: ${e.message}`);
    }
  };

  const stopSignal = async () => {
    await run("setPlayerCmd:stop",{quiet:true});
    setSignalState("stopped");
    setStatus("Test signal stopped.");
  };

  const measure = async () => {
    if (signal === "sweep") {
      setStatus("Sweep is available as a test signal. Auto EQ measurement currently uses pink or white noise.");
      return;
    }
    if (!micActive) {
      const ok = await startMic();
      if (!ok) return;
      await new Promise(r=>setTimeout(r,800));
    }
    if (signalState !== "playing") {
      await startSignal(signal);
      await new Promise(r=>setTimeout(r,1200));
    }
    setMeasuring(true); setMeasureProgress(0); setSuggestion([]); setPredictedCurve([]); setSmoothedCurve([]); setNormalizedCurve([]);
    const accum = ROOM_FREQS.map(()=>0), counts = ROOM_FREQS.map(()=>0);
    const samples = 50;
    for (let n=0;n<samples;n++) {
      await new Promise(r=>setTimeout(r,100));
      const c = liveCurveRef.current;
      c.forEach((x,i)=>{ if (Number.isFinite(x?.db)) {accum[i]+=x.db; counts[i]++;} });
      setMeasureProgress(Math.round(((n+1)/samples)*100));
    }
    const result = ROOM_FREQS.map((f,i)=>({f,db:counts[i]?accum[i]/counts[i]:0}));
    setMeasured(result);
    setMeasuring(false);
    setCurveMode("raw");
    setStatus("Measurement captured with unclipped relative RTA data. Use Raw / Smoothed / Normalized to inspect processing, then press Calculate correction.");
  };

  const calculateSuggestion = () => {
    if (!measured.length) { setStatus("Make a measurement first."); return; }

    const smoothed = smoothRoomCurve(measured);
    setSmoothedCurve(smoothed);
    // The microphone/RTA measurement is relative, so align the broad 250 Hz–4 kHz
    // response to the selected target before asking PEQ to fix tonal shape.
    const anchorErrors = smoothed.filter(x=>x.f>=250 && x.f<=4000).map(x=>x.db-targetDb(x.f));
    const offset = median(anchorErrors);
    const normalized = smoothed.map(x=>({f:x.f,db:x.db-offset}));
    setNormalizedCurve(normalized);
    setCurveMode("normalized");

    const weights = normalized.map(x=>{
      // Bass/low-mid is important but do not let extreme edge bins consume every filter.
      if (x.f < 31.5 || x.f > 16000) return 0.30;
      if (x.f < 80 || x.f > 10000) return 0.65;
      return 1.0;
    });
    let residual = normalized.map(x=>targetDb(x.f)-x.db);
    const chosen=[];
    const qChoices=[0.7,1.0,1.4,2.0,2.8];
    const centers=ROOM_FREQS.filter(f=>f>=31.5 && f<=16000);
    const rms = arr => Math.sqrt(arr.reduce((s,v,i)=>s+weights[i]*v*v,0)/Math.max(0.001,weights.reduce((a,b)=>a+b,0)));

    for (let step=0; step<10; step++) {
      const before=rms(residual);
      let best=null;
      for (const fc of centers) {
        if (chosen.some(b=>Math.abs(Math.log2(fc/b.fc))<0.42)) continue;
        const idx=normalized.reduce((bestIdx,p,i)=>Math.abs(Math.log2(p.f/fc))<Math.abs(Math.log2(normalized[bestIdx].f/fc))?i:bestIdx,0);
        const wanted=residual[idx];
        // Strong cuts are useful for peaks. Boosts are intentionally modest, and very
        // deep nulls are not chased because they are usually cancellation, not EQ-able loss.
        if (wanted>0 && normalized[idx].db < targetDb(fc)-7) continue;
        const gain=Math.max(-9,Math.min(3,wanted));
        if (Math.abs(gain)<1.0) continue;
        for (const q of qChoices) {
          const response=normalized.map(p=>peqMagnitudeDb(p.f,fc,q,gain));
          const next=residual.map((v,i)=>v-response[i]);
          const after=rms(next);
          const improvement=before-after;
          if (!best || improvement>best.improvement) best={fc,q,gain,response,next,improvement,after};
        }
      }
      if (!best || best.improvement < 0.18) break;
      chosen.push(best);
      residual=best.next;
    }

    const active=chosen.sort((a,b)=>a.fc-b.fc).map((b,i)=>({
      Index:String(i), Filter:"PK", Freq:String(Math.round(b.fc)), Q:String(Math.round(b.q*10)/10), Gain:String(Math.round(b.gain*10)/10), fc:b.fc
    }));
    const bands=active.map(({fc,...b})=>b);
    while (bands.length<10) bands.push({Index:String(bands.length),Filter:"OFF",Freq:"1000",Q:"1",Gain:"0"});

    const predicted=normalized.map(p=>{
      const eqDb=chosen.reduce((sum,b)=>sum+peqMagnitudeDb(p.f,b.fc,b.q,b.gain),0);
      return {f:p.f,db:p.db+eqDb};
    });
    setSuggestion(bands);
    setPredictedCurve(predicted);
    const beforeRms=rms(normalized.map(x=>targetDb(x.f)-x.db));
    const afterRms=rms(predicted.map(x=>targetDb(x.f)-x.db));
    setStatus(`Auto EQ preview calculated: ${chosen.length} active filters. Weighted target error ${beforeRms.toFixed(1)} → ${afterRms.toFixed(1)} dB. Nothing has been sent to the device.`);
  };

  const rawGraphCurve = measured.length ? measured : liveCurve;
  const graphCurve = curveMode === "smoothed" && smoothedCurve.length ? smoothedCurve
    : curveMode === "normalized" && normalizedCurve.length ? normalizedCurve
    : rawGraphCurve;
  const graphLabel = curveMode === "smoothed" ? "Smoothed (1/6 octave)"
    : curveMode === "normalized" ? "Normalized for Auto EQ"
    : measured.length ? "Raw captured / relative" : "Live RTA / relative";
  const xOf = f => 28 + (Math.log10(f/20)/Math.log10(20000/20))*744;

  // Dynamic vertical scale: data is never clipped to the old +12 / -18 dB window.
  // Use a 6 dB grid and leave one grid step of headroom around all visible curves.
  const visibleDb = [
    ...graphCurve.map(x=>x.db),
    ...ROOM_FREQS.map(f=>targetDb(f)),
    ...(predictedCurve.length && curveMode === "normalized" ? predictedCurve.map(x=>x.db) : [])
  ].filter(Number.isFinite);
  const dataMin = visibleDb.length ? Math.min(...visibleDb) : -18;
  const dataMax = visibleDb.length ? Math.max(...visibleDb) : 12;
  let yMin = Math.floor((dataMin-3)/6)*6;
  let yMax = Math.ceil((dataMax+3)/6)*6;
  if (yMax-yMin < 30) {
    const mid=(yMin+yMax)/2;
    yMin=Math.floor((mid-15)/6)*6;
    yMax=Math.ceil((mid+15)/6)*6;
  }
  // Guard against a single bad FFT frame making the graph unusable, without changing stored data.
  yMin=Math.max(-72,yMin); yMax=Math.min(36,yMax);
  if (yMax<=yMin) { yMin=-18; yMax=12; }
  const yTicks=[];
  for (let db=yMax; db>=yMin-0.01; db-=6) yTicks.push(db);
  const yOf = db => 154 - ((db-yMin)/(yMax-yMin))*126;
  const points = graphCurve.map(x=>`${xOf(x.f).toFixed(1)},${yOf(x.db).toFixed(1)}`).join(" ");
  const targetPoints = ROOM_FREQS.map(f=>`${xOf(f).toFixed(1)},${yOf(targetDb(f)).toFixed(1)}`).join(" ");
  const predictedPoints = curveMode === "normalized" ? predictedCurve.map(x=>`${xOf(x.f).toFixed(1)},${yOf(x.db).toFixed(1)}`).join(" ") : "";
  const levelClass = inputDb > -6 ? "hot" : inputDb > -35 ? "good" : "low";
  const meterLevel = Math.max(0,Math.min(1,(inputDb+60)/60));

  return <div className="roomEq">
    <div className="roomEqIntro">
      <div><b>Room Measurement & Auto EQ</b><span>Test signal → player → speakers → room → microphone → smoothed response → PEQ preview</span></div>
      <div className="roomEqBadge">v0.3.2.1 BETA</div>
    </div>

    <div className="roomEqGrid">
      <section className="roomCard">
        <h4>1 · Test signal</h4>
        <div className="signalChoices">
          {[["pink","Pink noise"],["white","White noise"],["sweep","Sweep 20–20k"]].map(([v,l])=><button key={v} className={signal===v?"active":""} onClick={()=>setSignal(v)}>{l}</button>)}
        </div>
        <div className="actions roomActions"><button className="primaryBtn" onClick={()=>startSignal(signal)} disabled={signalState==="starting"}>{signalState==="starting"?"Starting…":"Send to player"}</button><button className="ghostBtn" onClick={stopSignal}>Stop</button></div>
        <div className="roomTestVolume">
          <div className="roomTestVolumeHead"><span>Test volume</span><strong>{device.volume ?? 0}%</strong></div>
          <VolumeSlider device={device} setVolume={setVolume} className="range" showValue/>
          <div className="roomVolumeHint">Adjust here while watching the microphone meter. Aim for the test signal to sit clearly above the room noise floor without approaching clipping.</div>
        </div>
        {signalUrl && <div className="roomSmall">URL: {signalUrl}</div>}
        <div className="roomSmall">Pink noise is recommended for RTA/Auto EQ. Sweep remains available for listening/tests; impulse-response deconvolution will come later.</div>
      </section>

      <section className="roomCard">
        <h4>2 · Microphone</h4>
        <div className="micRow"><select value={micId} onChange={e=>setMicId(e.target.value)}><option value="">Default microphone</option>{mics.map((m,i)=><option key={m.deviceId} value={m.deviceId}>{m.label || `Audio input ${i+1}`}</option>)}</select><button className="ghostBtn" onClick={refreshMics}>Find mics</button></div>
        <div className="micMeter"><div ref={micMeterFillRef} className={`micMeterFill ${levelClass}`} style={{transform:`scaleX(${meterLevel})`}}/><span>{inputDb<=-99?"—":`${inputDb.toFixed(1)} dBFS`}</span></div>
        <div className="micMeterScale"><span>−60</span><span>−35</span><span>−10</span><span>0 dBFS</span></div>
        <div className="micMeterMeaning"><span>Noise floor</span><span>Good measurement range</span><span>Clipping</span></div>
        <div className="actions roomActions"><button className="primaryBtn" onClick={micActive?stopMic:startMic}>{micActive?"Stop microphone":"Start microphone"}</button></div>
        <div className="roomSmall">The blue live RTA remains visible even with the test signal stopped so you can see the ambient noise shape. Raise the test level until the meter is typically about 15–20 dB above the quiet-room reading, while keeping peaks safely below 0 dBFS. A calibrated USB measurement microphone is preferred.</div>
      </section>
    </div>

    <section className="roomCard roomGraphCard">
      <div className="roomGraphHead"><div><h4>3 · Frequency response</h4><span>{graphLabel}</span></div><div className="roomGraphControls"><div className="curveModeSwitch">{[["raw","Raw"],["smoothed","Smoothed"],["normalized","Normalized"]].map(([v,l])=><button key={v} className={curveMode===v?"active":""} disabled={v!=="raw" && !(v==="smoothed"?smoothedCurve.length:normalizedCurve.length)} onClick={()=>setCurveMode(v)}>{l}</button>)}</div><div className="targetSelect"><label>Target<select value={target} onChange={e=>{setTarget(e.target.value);setSuggestion([]);setSmoothedCurve([]);setNormalizedCurve([]);setPredictedCurve([]);setCurveMode("raw")}}><option value="house">House curve</option><option value="flat">Flat</option></select></label></div></div></div>
      <svg className="roomGraph" viewBox="0 0 800 180" preserveAspectRatio="none">
        {yTicks.map(db=><g key={db}><line x1="28" x2="772" y1={yOf(db)} y2={yOf(db)} className="gridLine"/><text x="2" y={yOf(db)+3}>{db>0?`+${db}`:db}</text></g>)}
        {[20,100,1000,10000,20000].map(f=><g key={f}><line x1={xOf(f)} x2={xOf(f)} y1="24" y2="154" className="gridLine"/><text x={xOf(f)-12} y="172">{f>=1000?`${f/1000}k`:f}</text></g>)}
        <polyline points={targetPoints} className="targetCurve"/>
        {points && <polyline points={points} className="measureCurve"/>}
        {predictedPoints && <polyline points={predictedPoints} className="predictedCurve"/>}
      </svg>
      <div className="graphLegend"><span><i className="legendMeasure"/>{graphLabel}</span><span><i className="legendTarget"/>Target</span>{predictedPoints && <span><i className="legendPredicted"/>Predicted after EQ</span>}</div>
      <div className="measureBar"><button className="primaryBtn" onClick={measure} disabled={measuring}>{measuring?`Measuring… ${measureProgress}%`:"Measure 5 seconds"}</button><button className="ghostBtn" onClick={()=>{setMeasured([]);setSuggestion([]);setSmoothedCurve([]);setNormalizedCurve([]);setPredictedCurve([]);setCurveMode("raw")}}>Clear</button><span className="graphRange">Graph range: {yMin}…{yMax} dB · no data clipping</span></div>
    </section>

    <section className="roomCard">
      <div className="roomGraphHead"><div><h4>4 · PEQ correction preview</h4><span>Smoothed, level-normalized, peak-aware 10-band fit; never sent automatically.</span></div><button className="ghostBtn" onClick={calculateSuggestion}>Calculate correction</button></div>
      {suggestion.length ? <>
        <div className="roomSuggestion"><table><thead><tr><th>#</th><th>Filter</th><th>Freq</th><th>Q</th><th>Gain</th></tr></thead><tbody>{suggestion.map((b,i)=><tr key={i} className={b.Filter==="OFF"?"peqOff":""}><td>{i+1}</td><td>{b.Filter}</td><td>{b.Filter==="OFF"?"—":`${b.Freq} Hz`}</td><td>{b.Filter==="OFF"?"—":b.Q}</td><td>{b.Filter==="OFF"?"—":`${Number(b.Gain)>0?"+":""}${b.Gain} dB`}</td></tr>)}</tbody></table></div>
        <div className="actions"><button className="primaryBtn" onClick={()=>onLoadPeq(suggestion)}>Load into Parametric EQ</button></div>
      </> : <div className="roomEmpty">Capture a measurement, then calculate a correction. Deep nulls are not chased; boost is limited to +3 dB and cut to −9 dB.</div>}
    </section>

    <div className="roomStatus">{status}</div>
    <div className="roomWarning"><b>Measurement note.</b> v0.3.2.1 keeps the live blue RTA visible as an ambient-noise reference even when no test signal is playing. The microphone meter is a dBFS input-level meter, not SPL. v0.3.2 keeps the captured relative RTA data unclipped. Raw shows the unsmoothed relative response, Smoothed applies approximately 1/6-octave smoothing, and Normalized aligns the broad 250 Hz–4 kHz level to the selected target before Auto EQ. The green curve is a mathematical prediction, not a substitute for re-measuring the room. This is not a calibrated SPL or THD/harmonic-distortion measurement.</div>
  </div>;
}


const WIIM_EQ_NATIVE_FLAT = 50;
const WIIM_EQ_NATIVE_PER_DB = 5;
const WIIM_PEQ_PLUGIN = "http://moddevices.com/plugins/caps/EqNp";
const WIIM_PEQ_LETTERS = "abcdefghij".split("");
const WIIM_PEQ_MODE_OPTIONS = [
  {value:-1,label:"Off"},
  {value:0,label:"Low Shelf"},
  {value:1,label:"Peak"},
  {value:2,label:"High Shelf"}
];
const WIIM_PEQ_DEFAULT_FREQS = [30,62.5,125,250,500,1000,2000,4000,8000,16000];
const clampPeq = (value,min,max,fallback) => {
  const n=Number(value);
  return Number.isFinite(n)?Math.max(min,Math.min(max,n)):fallback;
};
const emptyPeqBands = () => WIIM_PEQ_LETTERS.map((letter,i)=>({
  letter,
  mode:1,
  frequency:WIIM_PEQ_DEFAULT_FREQS[i],
  q:0.25,
  gain:0
}));

const nativeEqToDb = value => (Number(value) - WIIM_EQ_NATIVE_FLAT) / WIIM_EQ_NATIVE_PER_DB;
const formatEqDb = value => {
  const db=nativeEqToDb(value);
  const rounded=Math.abs(db)<0.0001 ? 0 : db;
  return `${rounded>0?"+":""}${rounded.toFixed(1)} dB`;
};

const WIIM_EQ_BANDS = [
  {index:0,param_name:"band31hz",label:"31 Hz"},
  {index:1,param_name:"band63hz",label:"63 Hz"},
  {index:2,param_name:"band125hz",label:"125 Hz"},
  {index:3,param_name:"band250hz",label:"250 Hz"},
  {index:4,param_name:"band500hz",label:"500 Hz"},
  {index:5,param_name:"band1khz",label:"1 kHz"},
  {index:6,param_name:"band2khz",label:"2 kHz"},
  {index:7,param_name:"band4khz",label:"4 kHz"},
  {index:8,param_name:"band8khz",label:"8 kHz"},
  {index:9,param_name:"band16khz",label:"16 kHz"}
];

function isWiiMHttpEqDevice(device) {
  const hardware=String(device?.hardware || device?.model || "").toUpperCase();
  const project=String(device?.project || "").toUpperCase();
  return hardware.includes("AMLOGIC") || project.includes("WIIM");
}


const PEQ_GRAPH_MIN_FREQ = 10;
const PEQ_GRAPH_MAX_FREQ = 22000;
const PEQ_GRAPH_MIN_DB = -12;
const PEQ_GRAPH_MAX_DB = 12;

function peqFilterResponseDb(type, freq, fc, q, gainDb, sampleRate=48000) {
  const t=String(type||"OFF").toUpperCase();
  if (t==="OFF" || !Number.isFinite(Number(fc)) || Number(fc)<=0) return 0;
  const f=Math.max(1,Math.min(sampleRate/2-1,Number(freq)||1));
  const f0=Math.max(1,Math.min(sampleRate/2-1,Number(fc)||1000));
  const Q=Math.max(0.01,Number(q)||0.707);
  const g=Math.max(-24,Math.min(24,Number(gainDb)||0));
  const A=Math.pow(10,g/40);
  const w0=2*Math.PI*f0/sampleRate;
  const cw=Math.cos(w0), sw=Math.sin(w0);
  let b0=1,b1=0,b2=0,a0=1,a1=0,a2=0;
  if (t==="PK" || t==="PEAK" || t==="1") {
    const alpha=sw/(2*Q);
    b0=1+alpha*A;b1=-2*cw;b2=1-alpha*A;
    a0=1+alpha/A;a1=-2*cw;a2=1-alpha/A;
  } else if (t==="LS" || t==="LOW SHELF" || t==="0") {
    const S=Math.max(0.1,Math.min(2,Q));
    const alpha=sw/2*Math.sqrt((A+1/A)*(1/S-1)+2);
    const beta=2*Math.sqrt(A)*alpha;
    b0=A*((A+1)-(A-1)*cw+beta);b1=2*A*((A-1)-(A+1)*cw);b2=A*((A+1)-(A-1)*cw-beta);
    a0=(A+1)+(A-1)*cw+beta;a1=-2*((A-1)+(A+1)*cw);a2=(A+1)+(A-1)*cw-beta;
  } else if (t==="HS" || t==="HIGH SHELF" || t==="2") {
    const S=Math.max(0.1,Math.min(2,Q));
    const alpha=sw/2*Math.sqrt((A+1/A)*(1/S-1)+2);
    const beta=2*Math.sqrt(A)*alpha;
    b0=A*((A+1)+(A-1)*cw+beta);b1=-2*A*((A-1)+(A+1)*cw);b2=A*((A+1)+(A-1)*cw-beta);
    a0=(A+1)-(A-1)*cw+beta;a1=2*((A-1)-(A+1)*cw);a2=(A+1)-(A-1)*cw-beta;
  } else if (t==="LP") {
    const alpha=sw/(2*Q);
    b0=(1-cw)/2;b1=1-cw;b2=(1-cw)/2;a0=1+alpha;a1=-2*cw;a2=1-alpha;
  } else if (t==="HP") {
    const alpha=sw/(2*Q);
    b0=(1+cw)/2;b1=-(1+cw);b2=(1+cw)/2;a0=1+alpha;a1=-2*cw;a2=1-alpha;
  } else return 0;
  const w=2*Math.PI*f/sampleRate;
  const c1=Math.cos(w),s1=Math.sin(w),c2=Math.cos(2*w),s2=Math.sin(2*w);
  const nr=b0+b1*c1+b2*c2, ni=-(b1*s1+b2*s2);
  const dr=a0+a1*c1+a2*c2, di=-(a1*s1+a2*s2);
  const den=dr*dr+di*di;
  if (!Number.isFinite(den) || den<=1e-18) return 0;
  const re=(nr*dr+ni*di)/den, im=(ni*dr-nr*di)/den;
  const mag=Math.sqrt(re*re+im*im);
  return Number.isFinite(mag) && mag>1e-12 ? 20*Math.log10(mag) : -48;
}

function UnifiedPeqEditor({bands,onChange,filterOptions,onApplyBand,applyingKey="",frequencyMin=10,frequencyMax=22000,qMin=0.01,qMax=24,title="Parametric EQ"}) {
  const [selected,setSelected]=useState(0);
  const dragRef=useRef(null);
  const normalized=bands.map((b,i)=>({
    id:b.id ?? i,
    label:b.label ?? String(i+1),
    filter:b.filter ?? "OFF",
    frequency:Math.max(frequencyMin,Math.min(frequencyMax,Number(b.frequency)||1000)),
    q:Math.max(qMin,Math.min(qMax,Number(b.q)||0.25)),
    gain:Math.max(-12,Math.min(12,Number(b.gain)||0))
  }));
  const W=980,H=350,L=62,R=22,T=22,B=42,plotW=W-L-R,plotH=H-T-B;
  const xFor=f=>L+(Math.log10(Math.max(PEQ_GRAPH_MIN_FREQ,Math.min(PEQ_GRAPH_MAX_FREQ,f)))-Math.log10(PEQ_GRAPH_MIN_FREQ))/(Math.log10(PEQ_GRAPH_MAX_FREQ)-Math.log10(PEQ_GRAPH_MIN_FREQ))*plotW;
  const freqForX=x=>Math.pow(10,Math.log10(PEQ_GRAPH_MIN_FREQ)+Math.max(0,Math.min(1,(x-L)/plotW))*(Math.log10(PEQ_GRAPH_MAX_FREQ)-Math.log10(PEQ_GRAPH_MIN_FREQ)));
  const yFor=db=>T+(PEQ_GRAPH_MAX_DB-Math.max(PEQ_GRAPH_MIN_DB,Math.min(PEQ_GRAPH_MAX_DB,db)))/(PEQ_GRAPH_MAX_DB-PEQ_GRAPH_MIN_DB)*plotH;
  const dbForY=y=>PEQ_GRAPH_MAX_DB-Math.max(0,Math.min(1,(y-T)/plotH))*(PEQ_GRAPH_MAX_DB-PEQ_GRAPH_MIN_DB);
  const curve=useMemo(()=>Array.from({length:260},(_,i)=>{
    const f=Math.pow(10,Math.log10(PEQ_GRAPH_MIN_FREQ)+i/259*(Math.log10(PEQ_GRAPH_MAX_FREQ)-Math.log10(PEQ_GRAPH_MIN_FREQ)));
    const db=normalized.reduce((sum,b)=>sum+peqFilterResponseDb(b.filter,f,b.frequency,b.q,b.gain),0);
    return [xFor(f),yFor(Math.max(-12,Math.min(12,db)))];
  }),[JSON.stringify(normalized)]);
  const path=curve.map((p,i)=>`${i?'L':'M'}${p[0].toFixed(2)},${p[1].toFixed(2)}`).join(' ');
  const freqTicks=[10,20,50,100,200,500,1000,2000,5000,10000,20000];
  const dbTicks=[12,6,0,-6,-12];
  const graphPoint=(i)=>normalized[i] ? {x:xFor(normalized[i].frequency),y:yFor(normalized[i].gain)} : {x:0,y:0};
  const movePoint=(e,i)=>{
    const rect=e.currentTarget.ownerSVGElement?.getBoundingClientRect?.() || e.currentTarget.getBoundingClientRect();
    if(!rect?.width||!rect?.height)return;
    const sx=W/rect.width, sy=H/rect.height;
    const x=(e.clientX-rect.left)*sx, y=(e.clientY-rect.top)*sy;
    const f=Math.max(frequencyMin,Math.min(frequencyMax,freqForX(x)));
    const g=Math.max(-12,Math.min(12,dbForY(y)));
    onChange(i,"frequency",Number((f<100?f.toFixed(1):Math.round(f)).toString()));
    onChange(i,"gain",Number(g.toFixed(1)));
  };
  return <div className="unifiedPeq">
    <div className="unifiedPeqTitle"><div><b>{title}</b><span>Drag a numbered point: horizontal = frequency, vertical = gain. Q changes the width of the curve.</span></div></div>
    <div className="peqCurveShell">
      <svg className="peqCurve" viewBox={`0 0 ${W} ${H}`} role="img" aria-label="Parametric EQ response curve">
        <rect x={L} y={T} width={plotW} height={plotH} rx="10" className="peqCurveBg"/>
        {freqTicks.map(f=><g key={f}><line x1={xFor(f)} x2={xFor(f)} y1={T} y2={T+plotH} className="peqGridLine"/><text x={xFor(f)} y={H-15} textAnchor="middle" className="peqAxisText">{f>=1000?`${f/1000}k`:f}</text></g>)}
        {dbTicks.map(db=><g key={db}><line x1={L} x2={L+plotW} y1={yFor(db)} y2={yFor(db)} className={db===0?"peqZeroLine":"peqGridLine"}/><text x={L-10} y={yFor(db)+4} textAnchor="end" className="peqAxisText">{db>0?`+${db}`:db} dB</text></g>)}
        <path d={path} className="peqResponsePath"/>
        {normalized.map((b,i)=>{
          if(String(b.filter).toUpperCase()==="OFF" || Number(b.filter)===-1)return null;
          const p=graphPoint(i); return <g key={b.id} transform={`translate(${p.x} ${p.y})`} className={selected===i?"peqNode selected":"peqNode"}
            onPointerDown={e=>{e.preventDefault();setSelected(i);dragRef.current=i;e.currentTarget.setPointerCapture?.(e.pointerId);movePoint(e,i);}}
            onPointerMove={e=>{if(dragRef.current===i)movePoint(e,i);}}
            onPointerUp={e=>{if(dragRef.current===i)movePoint(e,i);dragRef.current=null;e.currentTarget.releasePointerCapture?.(e.pointerId);}}
            onPointerCancel={()=>{dragRef.current=null;}}>
            <circle r="13"/><text textAnchor="middle" dy="4">{i+1}</text></g>;
        })}
      </svg>
    </div>
    <div className="unifiedPeqTableWrap"><table className="unifiedPeqTable"><thead><tr><th>#</th><th>Filter</th><th>Freq</th><th>Gain</th><th>Q</th>{onApplyBand&&<th></th>}</tr></thead><tbody>
      {normalized.map((b,i)=><tr key={b.id} className={selected===i?"selected":""} onClick={()=>setSelected(i)}>
        <td><button type="button" className="peqBandBadge" onClick={()=>setSelected(i)}>{i+1}</button></td>
        <td><select value={b.filter} onChange={e=>onChange(i,"filter",filterOptions.find(o=>String(o.value)===e.target.value)?.value ?? e.target.value)}>{filterOptions.map(o=><option key={String(o.value)} value={o.value}>{o.label}</option>)}</select></td>
        <td><div className="peqInlineNumber"><input type="number" min={frequencyMin} max={frequencyMax} step="0.5" value={b.frequency} onChange={e=>onChange(i,"frequency",e.target.value)}/><span>Hz</span></div></td>
        <td><div className="peqInlineNumber"><input type="number" min="-12" max="12" step="0.1" value={b.gain} onChange={e=>onChange(i,"gain",e.target.value)}/><span>dB</span></div></td>
        <td><input className="peqQInput" type="number" min={qMin} max={qMax} step="0.01" value={b.q} onChange={e=>onChange(i,"q",e.target.value)}/></td>
        {onApplyBand&&<td><button className="ghostBtn peqApplyBand" onClick={e=>{e.stopPropagation();onApplyBand(i);}} disabled={applyingKey!==""}>{applyingKey===String(b.id)?"Applying…":"Apply"}</button></td>}
      </tr>)}
    </tbody></table></div>
  </div>;
}

function WiiMEqualizer({device,run,setVolume}) {
  const DEFAULT_PRESETS=["Flat","Acoustic","Bass Booster","Bass Reducer","Classical","Dance","Deep","Electronic","Hip-Hop","Jazz","Latin","Loudness","Lounge","Piano","Pop","R&B","Rock","Small Speakers","Spoken Word","Treble Booster","Treble Reducer","Vocal Booster"];
  const [view,setView]=useState("graphic");
  const [eqOn,setEqOn]=useState(false);
  const [name,setName]=useState("—");
  const [sourceName,setSourceName]=useState("—");
  const [channelMode,setChannelMode]=useState("—");
  const [bands,setBands]=useState(WIIM_EQ_BANDS.map(b=>({...b,value:50})));
  const [presets,setPresets]=useState(DEFAULT_PRESETS);
  const [loading,setLoading]=useState(false);
  const [saving,setSaving]=useState("");
  const [message,setMessage]=useState("");
  const [peqProbe,setPeqProbe]=useState(null);
  const [peqLoading,setPeqLoading]=useState(false);
  const [peqBands,setPeqBands]=useState(emptyPeqBands);
  const [peqOn,setPeqOn]=useState(false);
  const [peqSource,setPeqSource]=useState("wifi");
  const [peqChannelMode,setPeqChannelMode]=useState("Stereo");
  const [peqName,setPeqName]=useState("");
  const [peqSaving,setPeqSaving]=useState("");
  const mounted=useRef(true);
  const draggingRef=useRef(false);
  const busyRef=useRef(false);
  const writeTimer=useRef(null);
  const queuedBand=useRef(null);
  const peqWriteTimers=useRef(new Map());
  const peqPendingBands=useRef(new Map());
  const peqWriteChain=useRef(Promise.resolve());
  const peqReadbackTimer=useRef(null);

  useEffect(()=>()=>{
    mounted.current=false;
    if(writeTimer.current)clearTimeout(writeTimer.current);
    peqWriteTimers.current.forEach(timer=>clearTimeout(timer));
    peqWriteTimers.current.clear();
    peqPendingBands.current.clear();
    if(peqReadbackTimer.current)clearTimeout(peqReadbackTimer.current);
  },[]);

  const parseBandPayload=(r)=>{
    const data=r?.data;
    if (data && typeof data==="object" && !Array.isArray(data)) return data;
    try { return JSON.parse(String(r?.raw || data || "")); } catch { return null; }
  };

  const applyBandPayload=(payload)=>{
    if (!payload || typeof payload!=="object") return false;
    if (typeof payload.EQStat==="string") setEqOn(payload.EQStat.toLowerCase()==="on");
    if (payload.Name!=null) setName(String(payload.Name));
    if (payload.source_name!=null) setSourceName(String(payload.source_name));
    if (payload.channelMode!=null) setChannelMode(String(payload.channelMode));
    if (Array.isArray(payload.EQBand)) {
      const byIndex=new Map(payload.EQBand.map(x=>[Number(x?.index),x]));
      setBands(WIIM_EQ_BANDS.map(def=>{
        const item=byIndex.get(def.index) || payload.EQBand.find(x=>String(x?.param_name||"")===def.param_name) || {};
        const v=Math.max(0,Math.min(99,Math.round(Number(item.value))));
        return {...def,value:Number.isFinite(v)?v:50};
      }));
    }
    return true;
  };

  const readEq=async({silent=false}={})=>{
    if (!silent) {setLoading(true);setMessage("");}
    try {
      const r=await run("EQGetBand",{quiet:true});
      const payload=parseBandPayload(r);
      if (!r?.ok || !payload) throw new Error(r?.error || r?.raw || "Invalid EQGetBand response");
      if (mounted.current) applyBandPayload(payload);
      if (!silent && mounted.current) setMessage("A98/WiiM EQ read from the device.");
      return payload;
    } catch(e) {
      if (!silent && mounted.current) setMessage(`EQ read failed: ${e.message}`);
      return null;
    } finally { if (!silent && mounted.current) setLoading(false); }
  };

  const readPresets=async()=>{
    const r=await run("EQGetList",{quiet:true});
    let list=r?.data;
    if (!Array.isArray(list)) { try { list=JSON.parse(String(r?.raw || "")); } catch {} }
    if (Array.isArray(list) && list.length) setPresets(list.map(String));
  };

  useEffect(()=>{
    let cancelled=false;
    (async()=>{await readEq();if(!cancelled)await readPresets();})();
    const id=setInterval(()=>{
      if (!cancelled && !busyRef.current && !draggingRef.current) readEq({silent:true});
    },1600);
    return()=>{cancelled=true;clearInterval(id);};
  },[device.id,device.ip,device.port,device.protocol]);

  const setPower=async(on)=>{
    busyRef.current=true;setSaving("power");setMessage("");
    const r=await run(on?"EQOn":"EQOff",{quiet:true});
    if (r?.ok) {setEqOn(on);setMessage(`Equalizer ${on?"enabled":"disabled"}.`);setTimeout(()=>readEq({silent:true}),250);}
    else setMessage(`Could not ${on?"enable":"disable"} EQ${r?.raw?`: ${r.raw}`:"."}`);
    busyRef.current=false;setSaving("");
  };

  const setPreset=async(preset)=>{
    busyRef.current=true;setSaving(`preset-${preset}`);setMessage("");
    const r=await run(`EQLoad:${preset}`,{quiet:true});
    if (r?.ok) {setName(preset);setMessage(`Preset “${preset}” loaded.`);setTimeout(()=>readEq({silent:true}),300);}
    else setMessage(`Could not load preset “${preset}”.`);
    busyRef.current=false;setSaving("");
  };

  const sendBand=async(index,value)=>{
    const def=WIIM_EQ_BANDS[index];
    if (!def) return;
    const n=Math.max(0,Math.min(99,Math.round(Number(value)||0)));
    busyRef.current=true;
    const payload={EQBand:[{index:def.index,param_name:def.param_name,value:n}]};
    const r=await run(`EQSetBand:${JSON.stringify(payload)}`,{quiet:true});
    busyRef.current=false;
    if (!r?.ok && mounted.current) setMessage(`Could not set ${def.label}${r?.raw?`: ${r.raw}`:"."}`);
  };

  const queueBandWrite=(index,value)=>{
    queuedBand.current={index,value};
    if (writeTimer.current) clearTimeout(writeTimer.current);
    writeTimer.current=setTimeout(async()=>{
      const q=queuedBand.current;queuedBand.current=null;writeTimer.current=null;
      if(q) await sendBand(q.index,q.value);
    },420);
  };

  const updateBand=(index,value)=>{
    const n=Math.max(0,Math.min(99,Math.round(Number(value)||0)));
    setBands(prev=>prev.map((b,i)=>i===index?{...b,value:n}:b));
    queueBandWrite(index,n);
  };

  const flatAll=async()=>{
    if (writeTimer.current) {clearTimeout(writeTimer.current);writeTimer.current=null;queuedBand.current=null;}
    const next=WIIM_EQ_BANDS.map(b=>({...b,value:50}));
    setBands(next);busyRef.current=true;setSaving("flat");setMessage("");
    const payload={EQBand:next.map(({index,param_name,value})=>({index,param_name,value}))};
    const r=await run(`EQSetBand:${JSON.stringify(payload)}`,{quiet:true});
    if (r?.ok) setMessage("All 10 bands set to native flat value 50.");
    else setMessage(`Could not flatten EQ${r?.raw?`: ${r.raw}`:"."}`);
    busyRef.current=false;setSaving("");
    setTimeout(()=>readEq({silent:true}),300);
  };

  const nativeLabel=v=>formatEqDb(v);

  const applyPeqPayload=(payload)=>{
    if (!payload || typeof payload!=="object") return false;
    if (typeof payload.EQStat==="string") setPeqOn(payload.EQStat.toLowerCase()==="on");
    if (payload.source_name) setPeqSource(String(payload.source_name));
    if (payload.channelMode) setPeqChannelMode(String(payload.channelMode));
    if (payload.Name!=null) setPeqName(String(payload.Name));
    const arr=Array.isArray(payload.EQBand)?payload.EQBand:[];
    if (!arr.length) return false;
    const map=new Map(arr.map(x=>[String(x?.param_name||""),Number(x?.value)]));
    setPeqBands(WIIM_PEQ_LETTERS.map((letter,i)=>({
      letter,
      mode:Math.round(clampPeq(map.get(`${letter}_mode`),-1,2,1)),
      frequency:clampPeq(map.get(`${letter}_freq`),10,22000,WIIM_PEQ_DEFAULT_FREQS[i]),
      q:clampPeq(map.get(`${letter}_q`),0.01,24,0.25),
      gain:clampPeq(map.get(`${letter}_gain`),-12,12,0)
    })));
    return true;
  };

  const readPeq=async({silent=false}={})=>{
    if (!silent) {setPeqLoading(true);setMessage("");}
    try {
      let r;
      if (peqSource && peqSource!=="—") {
        const request={source_name:peqSource,pluginURI:WIIM_PEQ_PLUGIN};
        r=await run(`EQGetLV2SourceBandEx:${JSON.stringify(request)}`,{quiet:true});
      }
      let payload=parseBandPayload(r);
      if (!r?.ok || !payload || !Array.isArray(payload.EQBand)) {
        r=await run(`EQGetLV2BandEx:${WIIM_PEQ_PLUGIN}`,{quiet:true});
        payload=parseBandPayload(r);
      }
      if (!r?.ok || !payload) throw new Error(r?.error || r?.raw || "No PEQ response");
      const ok=applyPeqPayload(payload);
      setPeqProbe(payload);
      if (!silent) setMessage(ok?"Parametric EQ read from A98/WiiM.":"PEQ endpoint responded, but no EqNp band data was found.");
      return payload;
    } catch(e) {
      if (!silent) {setPeqProbe({error:e.message});setMessage(`PEQ read failed: ${e.message}`);}
      return null;
    } finally {if (!silent)setPeqLoading(false);}
  };

  const probePeq=()=>readPeq();

  const makePeqPayload=(b)=>({
    source_name:peqSource || "wifi",
    pluginURI:WIIM_PEQ_PLUGIN,
    channelMode:peqChannelMode || "Stereo",
    EQBand:[
      {param_name:`${b.letter}_mode`,value:Math.round(clampPeq(b.mode,-1,2,1))},
      {param_name:`${b.letter}_freq`,value:clampPeq(b.frequency,10,22000,1000)},
      {param_name:`${b.letter}_q`,value:clampPeq(b.q,0.01,24,0.25)},
      {param_name:`${b.letter}_gain`,value:clampPeq(b.gain,-12,12,0)}
    ]
  });

  const sendPeqBandSnapshot=async(i,b,{announce=false}={})=>{
    if(!b)return;
    const payload=makePeqPayload(b);
    if(mounted.current)setPeqSaving(b.letter);
    try{
      const r=await run(`EQSetLV2SourceBand:${JSON.stringify(payload)}`,{quiet:true});
      if(!r?.ok)throw new Error(r?.error || r?.raw || "device write error");
      if(announce && mounted.current)setMessage(`PEQ band ${b.letter.toUpperCase()} written.`);
      if(peqReadbackTimer.current)clearTimeout(peqReadbackTimer.current);
      peqReadbackTimer.current=setTimeout(()=>{
        peqReadbackTimer.current=null;
        if(mounted.current)readPeq({silent:true});
      },650);
    }catch(e){
      if(mounted.current)setMessage(`Could not write PEQ band ${b.letter.toUpperCase()}: ${e.message}`);
    }finally{
      if(mounted.current)setPeqSaving("");
    }
  };

  const queuePeqBandWrite=(i,b)=>{
    peqPendingBands.current.set(i,{...b});
    const prevTimer=peqWriteTimers.current.get(i);
    if(prevTimer)clearTimeout(prevTimer);
    const timer=setTimeout(()=>{
      peqWriteTimers.current.delete(i);
      const snapshot=peqPendingBands.current.get(i);
      peqPendingBands.current.delete(i);
      if(!snapshot)return;
      // Serialize writes so fast drags never overlap HTTP/LV2 commands.
      peqWriteChain.current=peqWriteChain.current.then(()=>sendPeqBandSnapshot(i,snapshot)).catch(()=>{});
    },360);
    peqWriteTimers.current.set(i,timer);
  };

  const updatePeqBand=(i,key,value)=>{
    setPeqBands(prev=>{
      const next=prev.map((b,n)=>n===i?{...b,[key]:value}:b);
      const changed=next[i];
      if(changed)queuePeqBandWrite(i,changed);
      return next;
    });
  };

  const flushPeqTimers=()=>{
    peqWriteTimers.current.forEach(timer=>clearTimeout(timer));
    peqWriteTimers.current.clear();
    peqPendingBands.current.clear();
    if(peqReadbackTimer.current){clearTimeout(peqReadbackTimer.current);peqReadbackTimer.current=null;}
  };

  const writeAllPeqBands=async(nextBands,{messageText="All PEQ bands written."}={})=>{
    flushPeqTimers();
    setPeqSaving("all");setMessage("");
    try{
      // Keep the proven per-band LV2 write path, but serialize all ten bands.
      for(let i=0;i<nextBands.length;i++){
        const b=nextBands[i];
        const payload=makePeqPayload(b);
        const r=await run(`EQSetLV2SourceBand:${JSON.stringify(payload)}`,{quiet:true});
        if(!r?.ok)throw new Error(r?.error || r?.raw || `band ${b.letter.toUpperCase()} write failed`);
        await new Promise(resolve=>setTimeout(resolve,90));
      }
      if(mounted.current){setPeqBands(nextBands);setMessage(messageText);}
      setTimeout(()=>readPeq({silent:true}),450);
    }catch(e){
      if(mounted.current)setMessage(`Could not write all PEQ bands: ${e.message}`);
    }finally{if(mounted.current)setPeqSaving("");}
  };

  const resetPeqToZero=async()=>{
    const next=peqBands.map(b=>({...b,gain:0}));
    setPeqBands(next);
    await writeAllPeqBands(next,{messageText:"Parametric EQ gain reset to 0 dB on all 10 bands."});
  };

  const applyAllPeq=async()=>{
    const next=peqBands.map(b=>({...b}));
    await writeAllPeqBands(next,{messageText:"All 10 Parametric EQ bands applied."});
  };

  const loadRoomPeq=(roomBands=[])=>{
    const modeFor=filter=>{
      const f=String(filter||"OFF").toUpperCase();
      if(f==="PK")return 1;
      if(f==="LS")return 0;
      if(f==="HS")return 2;
      return -1;
    };
    const next=WIIM_PEQ_LETTERS.map((letter,i)=>{
      const src=roomBands[i]||{};
      return {
        letter,
        mode:modeFor(src.Filter),
        frequency:clampPeq(src.Freq,10,22000,WIIM_PEQ_DEFAULT_FREQS[i]),
        q:clampPeq(src.Q,0.01,24,0.25),
        gain:clampPeq(src.Gain,-12,12,0)
      };
    });
    flushPeqTimers();
    setPeqBands(next);
    setView("parametric");
    setMessage("Room EQ suggestion loaded into the A98/WiiM Parametric EQ editor. Review the curve, then press Apply all PEQ when ready.");
  };

  const setPeqPower=async(on)=>{
    setPeqSaving("power");setMessage("");
    try{
      const payload={source_name:peqSource || "wifi",pluginURI:WIIM_PEQ_PLUGIN};
      const cmd=on?`EQChangeSourceFX:${JSON.stringify(payload)}`:`EQSourceOff:${JSON.stringify(payload)}`;
      const r=await run(cmd,{quiet:true});
      if(!r?.ok)throw new Error(r?.error || r?.raw || "device response error");
      setPeqOn(on);setMessage(`Parametric EQ ${on?"enabled":"disabled"} for ${peqSource||"current source"}.`);
      setTimeout(()=>readPeq({silent:true}),300);
    }catch(e){setMessage(`Could not ${on?"enable":"disable"} Parametric EQ: ${e.message}`);}
    finally{setPeqSaving("");}
  };

  return <div className="single"><Panel>
    <PanelTitle title="Equalizer" sub={`A98 / WiiM · 10-band HTTP EQ + LV2 Parametric EQ · ${device.hardware || device.model || "Linkplay"}`} action={<button className="miniRefresh" onClick={()=>{readEq();readPresets();if(view==="parametric")readPeq({silent:true});}} disabled={loading}><RefreshCw size={15} className={loading?"spin":""}/> Read EQ</button>}/>

    <div className="wiimEqSummary">
      <div><span>EQ state</span><b>{eqOn?"ON":"OFF"}</b><small>EQGetBand / EQOn / EQOff</small></div>
      <div><span>Current preset</span><b>{name || "—"}</b><small>{sourceName!=="—"?`Source: ${sourceName}`:"Current source EQ"}</small></div>
      <div><span>Channel mode</span><b>{channelMode}</b><small>Reported by EQGetBand</small></div>
    </div>

    <div className="eqTabs">
      <button className={view==="graphic"?"active":""} onClick={()=>setView("graphic")}>Graphic EQ</button>
      <button className={view==="parametric"?"active":""} onClick={()=>setView("parametric")}>Parametric EQ</button>
      <button className={view==="room"?"active":""} onClick={()=>setView("room")}>Room EQ</button>
    </div>

    {message && <div className="eqMessage">{message}</div>}

    {view==="graphic" && <>
      <section className="wiimEqSection">
        <div className="a31SectionHead"><div><b>Equalizer power</b><span>Uses the documented WiiM HTTP API.</span></div></div>
        <div className="a31ToggleRow wiimPowerButtons"><button className={eqOn?"active":""} onClick={()=>setPower(true)} disabled={saving!==""}>ON</button><button className={!eqOn?"active":""} onClick={()=>setPower(false)} disabled={saving!==""}>OFF</button></div>
      </section>

      <section className="wiimEqSection">
        <div className="a31SectionHead"><div><b>10-band graphic equalizer</b><span>Displayed in dB; commands remain native 0…99 with 50 = 0 dB. Changes are throttled to about 0.4 s.</span></div><button className="ghostBtn" onClick={flatAll} disabled={saving!==""}>Set Flat</button></div>
        <div className="wiimEqGraph">
          {bands.map((b,i)=><div className="wiimEqBand" key={b.param_name}>
            <b>{nativeLabel(b.value)}</b>
            <input type="range" min="0" max="99" step="1" value={b.value}
              onPointerDown={()=>{draggingRef.current=true;}}
              onChange={e=>updateBand(i,e.target.value)}
              onPointerUp={e=>{draggingRef.current=false;queueBandWrite(i,e.currentTarget.value);}}
              onPointerCancel={()=>{draggingRef.current=false;}}
              disabled={saving!==""}/>
            <span>{b.label}</span>
            <small className="wiimNativeValue">native {b.value}</small>
          </div>)}
        </div>
        <div className="eqScaleNote">Display conversion: native 50 = 0.0 dB and 5 native steps = 1 dB (0.2 dB/step), matching the legacy Eq10HP decimal-gain representation. Device writes still use the proven native 0–99 values.</div>
      </section>

      <section className="wiimEqSection">
        <div className="a31SectionHead"><div><b>EQ presets</b><span>Read from EQGetList; EQLoad loads the selected preset.</span></div><button className="ghostBtn" onClick={readPresets}>Refresh presets</button></div>
        <div className="wiimPresetGrid">
          {presets.map(p=><button key={p} className={name===p?"active":""} onClick={()=>setPreset(p)} disabled={saving!==""}><span>{p}</span></button>)}
        </div>
      </section>
    </>}

    {view==="parametric" && <section className="wiimEqSection">
      <div className="a31SectionHead"><div><b>10-band Parametric EQ</b><span>Native WiiM LV2 EqNp: Mode · Frequency · Q · Gain. Live write is enabled; Bands A–J are editable, while K/L reported by firmware are reserved and intentionally ignored.</span></div><button className="ghostBtn" onClick={probePeq} disabled={peqLoading||peqSaving!==""}>{peqLoading?"Reading…":"Read PEQ"}</button></div>

      <div className="wiimPeqMeta">
        <div><span>PEQ state</span><b>{peqOn?"ON":"OFF"}</b></div>
        <div><span>Source</span><b>{peqSource||"—"}</b></div>
        <div><span>Channel</span><b>{peqChannelMode||"—"}</b></div>
        <div><span>Preset</span><b>{peqName||"Custom / unnamed"}</b></div>
      </div>
      <div className="a31ToggleRow wiimPowerButtons"><button className={peqOn?"active":""} onClick={()=>setPeqPower(true)} disabled={peqSaving!==""}>PEQ ON</button><button className={!peqOn?"active":""} onClick={()=>setPeqPower(false)} disabled={peqSaving!==""}>PEQ OFF</button></div>

      <div className="eqEditorHead wiimPeqActions">
        <div className="eqScaleNote">Reset keeps Frequency / Q / Filter type and sets Gain to 0 dB on all ten bands.</div>
        <div className="actions"><button className="ghostBtn" onClick={resetPeqToZero} disabled={peqSaving!==""}>{peqSaving==="all"?"Writing…":"Reset PEQ to 0"}</button><button className="primaryBtn" onClick={applyAllPeq} disabled={peqSaving!==""}>Apply all PEQ</button></div>
      </div>

      <UnifiedPeqEditor
        title="A98 / WiiM Parametric EQ"
        bands={peqBands.map(b=>({id:b.letter,label:b.letter.toUpperCase(),filter:b.mode,frequency:b.frequency,q:b.q,gain:b.gain}))}
        filterOptions={WIIM_PEQ_MODE_OPTIONS}
        frequencyMin={10} frequencyMax={22000} qMin={0.01} qMax={24}
        onChange={(i,key,value)=>updatePeqBand(i,key==="filter"?"mode":key,key==="filter"?Number(value):value)}
      />
      <div className="eqScaleNote">Confirmed EqNp ranges used here: mode −1 Off / 0 Low Shelf / 1 Peak / 2 High Shelf; frequency 10–22000 Hz; Q 0.01–24; gain −12…+12 dB. Changes are written automatically after a 360 ms debounce, serialized one band at a time, then read back after the edit settles.</div>
      <details className="wiimPeqRaw"><summary>Raw PEQ response</summary>{peqProbe ? <pre className="wiimPeqProbe">{typeof peqProbe==="string"?peqProbe:JSON.stringify(peqProbe,null,2)}</pre> : <div className="eqScaleNote">Press Read PEQ to load the current EqNp structure.</div>}</details>
    </section>}

    {view==="room" && <RoomEqMeasurement device={device} run={run} setVolume={setVolume} onLoadPeq={loadRoomPeq}/>}

    <div className="linkplayEqNote"><b>A98/WiiM HTTP controls.</b> Graphic EQ keeps the verified native 0–99 transport. Parametric EQ uses WiiM LV2 <code>EqNp</code> with <code>EQGetLV2BandEx</code>/<code>EQGetLV2SourceBandEx</code> and per-source <code>EQSetLV2SourceBand</code>. Room EQ uses the shared desktop measurement/Auto EQ engine and loads its result into this same EqNp editor. The A31 MCU/8899 implementation remains isolated and unchanged.</div>
  </Panel></div>;
}

function LinkplayEQ({device,run,setVolume}) {
  if (isWiiMHttpEqDevice(device)) return <WiiMEqualizer device={device} run={run} setVolume={setVolume}/>;
  const DEFAULT_PRESETS = [
    {index:0,name:"Flat"},
    {index:1,name:"Classical"},
    {index:2,name:"Pop"},
    {index:3,name:"Jazz"},
    {index:4,name:"Rock"},
    {index:5,name:"Vocal"}
  ];
  const [tone,setTone] = useState({bass:5,mid:0,treble:5,balance:0,preset:"—"});
  const [presets,setPresets] = useState(DEFAULT_PRESETS);
  const [advanced,setAdvanced] = useState({virtualBass:null,virtualBassIntensity:50,intensityKnown:false,maxVolume:100});
  const [loading,setLoading] = useState(false);
  const [saving,setSaving] = useState("");
  const [message,setMessage] = useState("");
  const mounted = useRef(true);
  const busyRef = useRef(false);
  const draggingRef = useRef("");

  useEffect(()=>()=>{ mounted.current=false; },[]);

  const mcu = async (command, expectReply=true, timeout=450) => {
    if (!window.airCloud?.linkplayMcuRequest) return {ok:false,error:"Desktop MCU bridge unavailable",payloads:[]};
    return window.airCloud.linkplayMcuRequest({ip:device.ip,port:8899,command,expectReply,timeout});
  };

  const rakoit = (command,expectReply=true,timeout=450) => mcu(`MCU+PAS+RAKOIT:${command}&`,expectReply,timeout);

  const parseValue = (payloads, regex) => {
    for (const item of payloads || []) {
      const match=String(item).match(regex);
      if (match) return Number(match[1]);
    }
    return null;
  };

  const readToneValues = async () => {
    const result=await mcu("MCU+PAS+EQGet&",true);
    return {
      result,
      bass:parseValue(result?.payloads,/EQ:bass:([+-]?\d+)/i),
      treble:parseValue(result?.payloads,/EQ:treble:([+-]?\d+)/i)
    };
  };

  const readBalanceValue = async () => {
    const result=await rakoit("BAL",true);
    return {
      result,
      balance:parseValue(result?.payloads,/RAKOIT:BAL:([+-]?\d+)/i)
    };
  };

  const readMidValue = async () => {
    const result=await rakoit("MID",true);
    return {
      result,
      mid:parseValue(result?.payloads,/(?:RAKOIT:)?MID:([+-]?\d+)/i)
    };
  };

  const parsePresetList = (payloads=[]) => {
    for (const item of payloads) {
      const text=String(item);
      const match=text.match(/(?:RAKOIT:)?PEQ:([^&\r\n]+)/i);
      if (!match) continue;
      const list=match[1].split(",").map(part=>{
        const m=part.trim().match(/^(\d+)@(.+)$/);
        return m ? {index:Number(m[1]),name:m[2].trim()} : null;
      }).filter(Boolean);
      if (list.length) return list;
    }
    return [];
  };

  const readPresetList = async () => {
    const result=await rakoit("PEQ",true,550);
    const list=parsePresetList(result?.payloads);
    if (list.length && mounted.current) setPresets(list);
    return list;
  };

  const readPresetState = async () => {
    // On this A31 / UP2STREAM_PRO_V4 the native app updates the MCU EQS value
    // immediately, while the legacy HTTP getEqualizer value can lag behind.
    // Read EQS first so changes made on another controller appear in airCloudCTRL.
    let idx=null;
    try {
      const result=await rakoit("EQS",true,550);
      idx=parseValue(result?.payloads,/(?:RAKOIT:)?EQS:([+-]?\d+)/i);
    } catch (_) {}
    if (!Number.isFinite(idx)) {
      try {
        const httpResult=await run("getEqualizer",{quiet:true});
        const raw=String(httpResult?.data ?? httpResult?.raw ?? "").trim();
        if (/^-?\d+$/.test(raw)) idx=Number(raw);
      } catch (_) {}
    }
    return idx;
  };

  const readVirtualBass = async () => {
    const result=await rakoit("VBS",true,550);
    const state=parseValue(result?.payloads,/(?:RAKOIT:)?VBS:([01])(?:&|$)/i);
    return {result,state};
  };

  const readMaxVolume = async () => {
    const result=await rakoit("MXV",true,550);
    const value=parseValue(result?.payloads,/(?:RAKOIT:)?MXV:(\d+)/i);
    return {result,value};
  };

  const refreshAdvanced = async ({quiet=false}={}) => {
    // Keep these reads serialized too: only one client/request should use A31 MCU/8899 at a time.
    let idx=null, vbState=null, maxValue=null;
    try { idx=await readPresetState(); } catch (_) {}
    try { const vb=await readVirtualBass(); vbState=vb?.state; } catch (_) {}
    try { const maxv=await readMaxVolume(); maxValue=maxv?.value; } catch (_) {}
    if (!mounted.current) return;
    setTone(prev=>({...prev,preset:Number.isFinite(idx)?String(idx):prev.preset}));
    setAdvanced(prev=>({
      ...prev,
      virtualBass:Number.isFinite(vbState)?Boolean(vbState):prev.virtualBass,
      maxVolume:Number.isFinite(maxValue)?maxValue:prev.maxVolume
    }));
    if (!quiet) setMessage("Advanced A31 audio settings refreshed.");
  };

  const loadEq = async () => {
    setLoading(true); setMessage("");
    try {
      // A31 MCU/8899 is effectively single-client. Keep the verified tone/balance
      // reads serialized. Advanced queries are then read after those values.
      const toneRead=await readToneValues();
      const midRead=await readMidValue();
      const balanceRead=await readBalanceValue();
      const {bass,treble}=toneRead;
      const {mid}=midRead;
      const {balance}=balanceRead;
      let preset=await readPresetState();
      await readPresetList();
      const vb=await readVirtualBass();
      const maxv=await readMaxVolume();
      if (mounted.current) {
        setTone(prev=>({
          bass:Number.isFinite(bass)?bass:prev.bass,
          mid:Number.isFinite(mid)?mid:prev.mid,
          treble:Number.isFinite(treble)?treble:prev.treble,
          balance:Number.isFinite(balance)?balance:prev.balance,
          preset:Number.isFinite(preset)?String(preset):prev.preset
        }));
        setAdvanced(prev=>({
          ...prev,
          virtualBass:Number.isFinite(vb.state)?Boolean(vb.state):prev.virtualBass,
          maxVolume:Number.isFinite(maxv.value)?maxv.value:prev.maxVolume
        }));
      }
      const missing=[];
      if (!Number.isFinite(bass)) missing.push("Bass");
      if (!Number.isFinite(mid)) missing.push("Mid");
      if (!Number.isFinite(treble)) missing.push("Treble");
      if (!Number.isFinite(balance)) missing.push("Balance");
      if (mounted.current) setMessage(missing.length ? `Read completed, but ${missing.join(", ")} did not answer.` : "A31 audio/EQ values read from the device.");
    } catch (e) {
      if (mounted.current) setMessage(`EQ read failed: ${e.message}`);
    } finally { if (mounted.current) setLoading(false); }
  };

  useEffect(()=>{ mounted.current=true; loadEq(); },[device.id,device.ip]);

  // Keep A31 tone controls synchronized with changes made from the native app.
  // One MCU request at a time: A31/8899 is effectively single-client.
  useEffect(()=>{
    let cancelled=false;
    let timer=null;
    let cycle=0;

    const schedule=(delay=1000)=>{
      if (!cancelled) timer=setTimeout(syncFromDevice,delay);
    };

    const syncFromDevice=async()=>{
      if (cancelled) return;
      if (busyRef.current || draggingRef.current) { schedule(350); return; }
      busyRef.current=true;
      try {
        const toneRead=await readToneValues();
        if (cancelled || !mounted.current || draggingRef.current) return;
        const {bass,treble}=toneRead;
        if (Number.isFinite(bass) || Number.isFinite(treble)) {
          setTone(prev=>({
            ...prev,
            bass:Number.isFinite(bass)?bass:prev.bass,
            treble:Number.isFinite(treble)?treble:prev.treble
          }));
        }

        const midRead=await readMidValue();
        if (!cancelled && mounted.current && !draggingRef.current && Number.isFinite(midRead.mid)) {
          setTone(prev=>({...prev,mid:midRead.mid}));
        }

        cycle += 1;
        if (cycle % 3 === 0 && !cancelled && !draggingRef.current) {
          const balanceRead=await readBalanceValue();
          const {balance}=balanceRead;
          if (!cancelled && mounted.current && Number.isFinite(balance)) setTone(prev=>({...prev,balance}));
        }
        if (cycle % 4 === 0 && !cancelled) {
          const idx=await readPresetState();
          if (!cancelled && mounted.current && Number.isFinite(idx)) setTone(prev=>({...prev,preset:String(idx)}));
        }
        if (cycle % 6 === 0 && !cancelled) {
          const vb=await readVirtualBass();
          if (!cancelled && mounted.current && Number.isFinite(vb.state)) setAdvanced(prev=>({...prev,virtualBass:Boolean(vb.state)}));
        }
        if (cycle % 8 === 0 && !cancelled) {
          const maxv=await readMaxVolume();
          if (!cancelled && mounted.current && Number.isFinite(maxv.value)) setAdvanced(prev=>({...prev,maxVolume:maxv.value}));
        }
      } catch (_) {
        // Background sync is silent. Manual Read EQ reports errors.
      } finally {
        busyRef.current=false;
        schedule(700);
      }
    };

    schedule(150);
    return()=>{cancelled=true;if(timer)clearTimeout(timer);};
  },[device.id,device.ip]);

  const pause=(ms)=>new Promise(resolve=>setTimeout(resolve,ms));

  const writeTone = async (kind,value) => {
    const n=Math.max(0,Math.min(10,Math.round(Number(value)||0)));
    setTone(prev=>({...prev,[kind]:n}));
    busyRef.current=true;
    setSaving(kind); setMessage("");
    try {
      const result=await mcu(`MCU+PAS+EQSet:${kind}:${n}&`,false);
      if (!result?.ok) throw new Error(result?.error || "device write error");
      await pause(180);
      const verify=await readToneValues();
      const actual=kind==="bass" ? verify.bass : verify.treble;
      if (mounted.current) {
        setTone(prev=>({
          ...prev,
          bass:Number.isFinite(verify.bass)?verify.bass:prev.bass,
          treble:Number.isFinite(verify.treble)?verify.treble:prev.treble
        }));
        if (Number.isFinite(actual)) {
          setMessage(actual===n
            ? `${kind === "bass" ? "Bass" : "Treble"} = ${n} confirmed by A31.`
            : `${kind === "bass" ? "Bass" : "Treble"}: requested ${n}, device reports ${actual}.`);
        } else setMessage(`${kind === "bass" ? "Bass" : "Treble"} write sent, but A31 did not return a verification value.`);
      }
    } catch (e) {
      if (mounted.current) setMessage(`Could not set ${kind}: ${e.message}`);
    } finally { busyRef.current=false; if (mounted.current) setSaving(""); }
  };

  const writeMid = async (value) => {
    const n=Math.max(-5,Math.min(5,Math.round(Number(value)||0)));
    setTone(prev=>({...prev,mid:n}));
    busyRef.current=true;
    setSaving("mid"); setMessage("");
    try {
      const result=await rakoit(`MID:${n}`,false);
      if (!result?.ok) throw new Error(result?.error || "device write error");
      await pause(180);
      const verify=await readMidValue();
      const actual=Number.isFinite(verify.mid)?verify.mid:n;
      if (mounted.current) {
        setTone(prev=>({...prev,mid:actual}));
        setMessage(Number.isFinite(verify.mid)
          ? (verify.mid===n ? `Mid = ${n} confirmed by A31.` : `Mid: requested ${n}, device reports ${verify.mid}.`)
          : `Mid ${n} command sent.`);
      }
    } catch (e) {
      if (mounted.current) setMessage(`Could not set Mid: ${e.message}`);
    } finally { busyRef.current=false; if (mounted.current) setSaving(""); }
  };

  const writeBalance = async (value) => {
    const n=Math.max(-100,Math.min(100,Math.round(Number(value)||0)));
    setTone(prev=>({...prev,balance:n}));
    busyRef.current=true;
    setSaving("balance"); setMessage("");
    try {
      const result=await rakoit(`BAL:${n}`,false);
      if (!result?.ok) throw new Error(result?.error || "device write error");
      await pause(180);
      const verify=await readBalanceValue();
      if (mounted.current) {
        if (Number.isFinite(verify.balance)) setTone(prev=>({...prev,balance:verify.balance}));
        setMessage(Number.isFinite(verify.balance)
          ? (verify.balance===n ? `Balance = ${n} confirmed by A31.` : `Balance: requested ${n}, device reports ${verify.balance}.`)
          : "Balance write sent, but A31 did not return a verification value.");
      }
    } catch (e) {
      if (mounted.current) setMessage(`Could not set Balance: ${e.message}`);
    } finally { busyRef.current=false; if (mounted.current) setSaving(""); }
  };

  const setPreset = async (index) => {
    const n=Math.max(0,Math.round(Number(index)||0));
    busyRef.current=true; setSaving(`preset-${n}`); setMessage("");
    try {
      const result=await rakoit(`EQS:${n}`,false);
      if (!result?.ok) throw new Error(result?.error || "device write error");
      await pause(230);
      const actual=await readPresetState();
      if (mounted.current) {
        if (Number.isFinite(actual)) setTone(prev=>({...prev,preset:String(actual)}));
        setMessage(actual===n ? `EQ preset ${n} selected and confirmed by A31.` : `Preset ${n} sent${Number.isFinite(actual)?`, device reports ${actual}`:"; no readback"}.`);
      }
    } catch (e) {
      if (mounted.current) setMessage(`Could not select EQ preset: ${e.message}`);
    } finally { busyRef.current=false; if (mounted.current) setSaving(""); }
  };

  const setVirtualBass = async (enabled) => {
    const en=enabled?1:0;
    busyRef.current=true; setSaving("vb"); setMessage("");
    try {
      const result=await rakoit(`VBS:${en}`,false);
      if (!result?.ok) throw new Error(result?.error || "device write error");
      await pause(200);
      const verify=await readVirtualBass();
      if (mounted.current) {
        const actual=Number.isFinite(verify.state)?Boolean(verify.state):Boolean(en);
        setAdvanced(prev=>({...prev,virtualBass:actual}));
        setMessage(Number.isFinite(verify.state) ? `Virtual Bass ${actual?"ON":"OFF"} confirmed by A31.` : `Virtual Bass ${en?"ON":"OFF"} command sent.`);
      }
    } catch (e) {
      if (mounted.current) setMessage(`Could not set Virtual Bass: ${e.message}`);
    } finally { busyRef.current=false; if (mounted.current) setSaving(""); }
  };

  const setVirtualBassIntensity = async (value) => {
    const n=Math.max(1,Math.min(100,Math.round(Number(value)||1)));
    setAdvanced(prev=>({...prev,virtualBassIntensity:n,intensityKnown:true}));
    busyRef.current=true; setSaving("vbi"); setMessage("");
    try {
      // Verified from the native macOS app on this A31 revision.
      // The device accepts VBI:n (1…100), but VBI& does not return a value,
      // so there is intentionally no readback/polling for this control.
      const result=await rakoit(`VBI:${n}`,false);
      if (!result?.ok) throw new Error(result?.error || "device write error");
      if (mounted.current) {
        setAdvanced(prev=>({...prev,virtualBassIntensity:n,intensityKnown:true}));
        setMessage(`Virtual Bass Intensity ${n} sent to A31 (write-only on this firmware).`);
      }
    } catch (e) {
      if (mounted.current) setMessage(`Could not set Virtual Bass Intensity: ${e.message}`);
    } finally { busyRef.current=false; if (mounted.current) setSaving(""); }
  };

  const setMaxVolume = async (value) => {
    const n=Math.max(30,Math.min(100,Math.round(Number(value)||100)));
    setAdvanced(prev=>({...prev,maxVolume:n}));
    busyRef.current=true; setSaving("maxVolume"); setMessage("");
    try {
      const result=await rakoit(`MXV:${n}`,false);
      if (!result?.ok) throw new Error(result?.error || "device write error");
      await pause(200);
      const verify=await readMaxVolume();
      const actual=Number.isFinite(verify.value)?verify.value:n;
      if (mounted.current) {
        setAdvanced(prev=>({...prev,maxVolume:actual}));
        setMessage(Number.isFinite(verify.value) ? `Maximum volume = ${actual} confirmed by A31.` : `Maximum volume ${n} command sent.`);
      }
    } catch (e) {
      if (mounted.current) setMessage(`Could not set maximum volume: ${e.message}`);
    } finally { busyRef.current=false; if (mounted.current) setSaving(""); }
  };

  const toneLabel=(n)=> Number(n)===5 ? "0" : (Number(n)>5 ? `+${Number(n)-5}` : String(Number(n)-5));
  const balanceSide=(n)=> Number(n)===0 ? "Centre" : (Number(n)<0 ? `Left ${Math.abs(Number(n))}` : `Right ${Number(n)}`);
  const currentPreset=Number(tone.preset);

  return <div className="single"><Panel>
    <PanelTitle title="Equalizer" sub={`Linkplay A31 · MCU TCP/8899 · ${device.project || device.model || "A31"}`} action={<button className="miniRefresh" onClick={loadEq} disabled={loading}><RefreshCw size={15} className={loading?"spin":""}/> Read EQ</button>}/>
    <div className="linkplayEqSummary">
      <div><span>Standard EQ preset</span><b>{Number.isFinite(currentPreset) ? (presets.find(p=>p.index===currentPreset)?.name || `Preset ${currentPreset}`) : tone.preset}</b><small>Named EQ groups with device readback.</small></div>
      <div><span>MCU tone control</span><b>Verified A31</b><small>Bass/Treble are shown as −5…+5; Mid uses native −5…+5.</small></div>
      <div><span>Balance</span><b>{balanceSide(tone.balance)}</b><small>Range −100…+100, centre = 0.</small></div>
    </div>

    {message && <div className="eqMessage">{message}</div>}

    <section className="a31AudioSection">
      <div className="a31SectionHead"><div><b>EQ presets</b><span>Flat / Classical / Pop / Jazz / Rock / Vocal; device list is used when available.</span></div><button className="ghostBtn" onClick={async()=>{busyRef.current=true;try{await readPresetList();const idx=await readPresetState();if(Number.isFinite(idx))setTone(p=>({...p,preset:String(idx)}));}finally{busyRef.current=false;}}}>Refresh presets</button></div>
      <div className="a31PresetGrid">
        {presets.map(p=><button key={p.index} className={Number(tone.preset)===p.index?"active":""} onClick={()=>setPreset(p.index)} disabled={saving===`preset-${p.index}`}><span>{p.name}</span><small>#{p.index}</small></button>)}
      </div>
    </section>

    <div className="linkplayEqControls">
      <div className="linkplayEqControl">
        <div className="linkplayEqHead"><div><b>Treble</b><span>MCU tone</span></div><strong>{toneLabel(tone.treble)}</strong></div>
        <input type="range" min="0" max="10" step="1" value={tone.treble}
          onPointerDown={()=>{draggingRef.current="treble";}}
          onChange={e=>setTone(p=>({...p,treble:Number(e.target.value)}))}
          onPointerUp={e=>{draggingRef.current="";writeTone("treble",e.currentTarget.value);}}
          onPointerCancel={()=>{draggingRef.current="";}}
          onKeyUp={e=>{ if (["ArrowLeft","ArrowRight","ArrowUp","ArrowDown","Home","End"].includes(e.key)) writeTone("treble",e.currentTarget.value); }}
          disabled={saving==="treble"}/>
        <div className="linkplayEqScale"><span>−5</span><span>0</span><span>+5</span></div>
        <div className="actions"><button className="ghostBtn" onClick={()=>writeTone("treble",tone.treble)} disabled={saving==="treble"}>{saving==="treble"?"Applying…":"Apply Treble"}</button></div>
      </div>

      <div className="linkplayEqControl">
        <div className="linkplayEqHead"><div><b>Mid</b><span>Native A31 MID</span></div><strong>{tone.mid>0?`+${tone.mid}`:tone.mid}</strong></div>
        <input type="range" min="-5" max="5" step="1" value={tone.mid}
          onPointerDown={()=>{draggingRef.current="mid";}}
          onChange={e=>setTone(p=>({...p,mid:Number(e.target.value)}))}
          onPointerUp={e=>{draggingRef.current="";writeMid(e.currentTarget.value);}}
          onPointerCancel={()=>{draggingRef.current="";}}
          onKeyUp={e=>{ if (["ArrowLeft","ArrowRight","ArrowUp","ArrowDown","Home","End"].includes(e.key)) writeMid(e.currentTarget.value); }}
          disabled={saving==="mid"}/>
        <div className="linkplayEqScale"><span>−5</span><span>0</span><span>+5</span></div>
        <div className="actions"><button className="ghostBtn" onClick={()=>writeMid(tone.mid)} disabled={saving==="mid"}>{saving==="mid"?"Applying…":"Apply Mid"}</button></div>
      </div>

      <div className="linkplayEqControl">
        <div className="linkplayEqHead"><div><b>Bass</b><span>MCU tone</span></div><strong>{toneLabel(tone.bass)}</strong></div>
        <input type="range" min="0" max="10" step="1" value={tone.bass}
          onPointerDown={()=>{draggingRef.current="bass";}}
          onChange={e=>setTone(p=>({...p,bass:Number(e.target.value)}))}
          onPointerUp={e=>{draggingRef.current="";writeTone("bass",e.currentTarget.value);}}
          onPointerCancel={()=>{draggingRef.current="";}}
          onKeyUp={e=>{ if (["ArrowLeft","ArrowRight","ArrowUp","ArrowDown","Home","End"].includes(e.key)) writeTone("bass",e.currentTarget.value); }}
          disabled={saving==="bass"}/>
        <div className="linkplayEqScale"><span>−5</span><span>0</span><span>+5</span></div>
        <div className="actions"><button className="ghostBtn" onClick={()=>writeTone("bass",tone.bass)} disabled={saving==="bass"}>{saving==="bass"?"Applying…":"Apply Bass"}</button></div>
      </div>

      <div className="linkplayEqControl balanceControl">
        <div className="linkplayEqHead"><div><b>Balance</b><span>Left / Right</span></div><strong>{balanceSide(tone.balance)}</strong></div>
        <input type="range" min="-100" max="100" step="1" value={tone.balance}
          onPointerDown={()=>{draggingRef.current="balance";}}
          onChange={e=>setTone(p=>({...p,balance:Number(e.target.value)}))}
          onPointerUp={e=>{draggingRef.current="";writeBalance(e.currentTarget.value);}}
          onPointerCancel={()=>{draggingRef.current="";}}
          onKeyUp={e=>{ if (["ArrowLeft","ArrowRight","ArrowUp","ArrowDown","Home","End"].includes(e.key)) writeBalance(e.currentTarget.value); }}
          disabled={saving==="balance"}/>
        <div className="linkplayEqScale"><span>L 100</span><span>Centre</span><span>R 100</span></div>
        <div className="actions"><button className="ghostBtn" onClick={()=>writeBalance(0)} disabled={saving==="balance"}>Centre balance</button></div>
      </div>
    </div>

    <section className="a31AudioSection">
      <div className="a31SectionHead"><div><b>Virtual Bass</b><span>Direct A31 MCU passthrough controls.</span></div><button className="ghostBtn" onClick={()=>refreshAdvanced()} disabled={saving!==""}>Read advanced</button></div>
      <div className="a31AdvancedGrid">
        <div className="a31AdvancedCard">
          <div className="a31CardTitle"><div><b>Virtual Bass</b><span>On / Off</span></div><strong>{advanced.virtualBass===null?"—":advanced.virtualBass?"ON":"OFF"}</strong></div>
          <div className="a31ToggleRow"><button className={advanced.virtualBass===true?"active":""} onClick={()=>setVirtualBass(true)} disabled={saving==="vb"}>ON</button><button className={advanced.virtualBass===false?"active":""} onClick={()=>setVirtualBass(false)} disabled={saving==="vb"}>OFF</button></div>
        </div>
        <div className="a31AdvancedCard">
          <div className="a31CardTitle"><div><b>Virtual Bass Intensity</b><span>Native A31 VBI · write-only</span></div><strong>{advanced.virtualBassIntensity}</strong></div>
          <input type="range" min="1" max="100" step="1" value={advanced.virtualBassIntensity}
            onPointerDown={()=>{draggingRef.current="vbi";}}
            onChange={e=>setAdvanced(p=>({...p,virtualBassIntensity:Number(e.target.value),intensityKnown:true}))}
            onPointerUp={e=>{draggingRef.current="";setVirtualBassIntensity(e.currentTarget.value);}}
            onPointerCancel={()=>{draggingRef.current="";}}
            onKeyUp={e=>{ if (["ArrowLeft","ArrowRight","ArrowUp","ArrowDown","Home","End"].includes(e.key)) setVirtualBassIntensity(e.currentTarget.value); }}
            disabled={saving==="vbi"}/>
          <div className="linkplayEqScale"><span>1</span><span>50</span><span>100</span></div>
          <small className="a31WriteOnlyHint">{advanced.intensityKnown ? "Value sent/edited in airCloudCTRL." : "Device does not report the current VBI value."}</small>
        </div>
        <div className="a31AdvancedCard">
          <div className="a31CardTitle"><div><b>Maximum volume</b><span>Device safety limit</span></div><strong>{advanced.maxVolume}</strong></div>
          <input type="range" min="30" max="100" step="1" value={advanced.maxVolume} onChange={e=>setAdvanced(p=>({...p,maxVolume:Number(e.target.value)}))} onPointerUp={e=>setMaxVolume(e.currentTarget.value)} disabled={saving==="maxVolume"}/>
          <div className="linkplayEqScale"><span>30</span><span>65</span><span>100</span></div>
        </div>
      </div>
    </section>

    <div className="linkplayEqNote"><b>A31 native controls.</b> Bass, Treble, Mid and Balance use the real MCU/8899 path. Mid is read with <code>MID</code> and written with <code>MID:n</code> (−5…+5). EQ presets are read from <code>PEQ</code> and tracked live with <code>EQS</code>. Virtual Bass uses <code>VBS</code>. Virtual Bass Intensity uses the native-app command <code>VBI:n</code> with range 1…100; this firmware does not return a value for <code>VBI&amp;</code>, so Intensity is write-only and is not polled. Maximum Volume uses <code>MXV</code> (30…100). A98/WiiM uses a separate documented HTTP EQ implementation; A97 remains isolated until verified.</div>
  </Panel></div>;
}

function EQ({device,run,setVolume}){
  const [view,setView] = useState("graphic");
  const [tone,setTone] = useState({Bass:"0",Treble:"0"});
  const [graphic,setGraphic] = useState({Custom:"0",Name:"Flat",EqBand:Array(10).fill("0")});
  const [parametric,setParametric] = useState({Custom:"0",Name:"Parametric",EqBand:[]});
  const [loading,setLoading] = useState(false);
  const [saving,setSaving] = useState("");
  const [message,setMessage] = useState("");

  const loadEq = async () => {
    setLoading(true); setMessage("");
    try {
      const [r1,r2,r3] = await Promise.all([
        run("getEqInfo:1",{quiet:true}),
        run("getEqInfo:2",{quiet:true}),
        run("getEqInfo:3",{quiet:true})
      ]);
      const t=eqPayload(r1), g=eqPayload(r2), p=eqPayload(r3);
      if (t) setTone({Bass:String(t.Bass ?? "0"),Treble:String(t.Treble ?? "0")});
      if (g) setGraphic({Custom:String(g.Custom ?? "0"),Name:g.Name || "Flat",EqBand:Array.from({length:10},(_,i)=>String(g.EqBand?.[i] ?? "0"))});
      if (p) setParametric({Custom:String(p.Custom ?? "0"),Name:p.Name || "Parametric",EqBand:Array.from({length:10},(_,i)=>({
        Index:String(p.EqBand?.[i]?.Index ?? i), Filter:p.EqBand?.[i]?.Filter || "OFF", Freq:String(p.EqBand?.[i]?.Freq ?? 1000), Q:String(p.EqBand?.[i]?.Q ?? 1), Gain:String(p.EqBand?.[i]?.Gain ?? 0)
      }))});
      if (!t && !g && !p) setMessage("EQ data could not be read from the device.");
    } finally { setLoading(false); }
  };

  useEffect(()=>{ loadEq(); },[device.id,device.ip,device.port]);

  // Refresh immediately when switching between the four EQ sub-tabs.
  // getStatusEx keeps status-backed controls (mode, volume, mute, etc.) current,
  // while the selected hardware EQ editor is re-read from the matching getEqInfo slot.
  useEffect(()=>{
    let cancelled=false;
    const refreshEqView=async()=>{
      setLoading(true);
      try {
        const statusPromise=run("getStatusEx",{quiet:true});
        let eqPromise=null;
        if (view==="tone") eqPromise=run("getEqInfo:1",{quiet:true});
        else if (view==="graphic") eqPromise=run("getEqInfo:2",{quiet:true});
        else if (view==="parametric") eqPromise=run("getEqInfo:3",{quiet:true});

        const [statusResult,eqResult]=await Promise.all([statusPromise,eqPromise || Promise.resolve(null)]);
        if (cancelled || !eqResult) return;
        const payload=eqPayload(eqResult);
        if (!payload) return;

        if (view==="tone") {
          setTone({Bass:String(payload.Bass ?? "0"),Treble:String(payload.Treble ?? "0")});
        } else if (view==="graphic") {
          setGraphic({Custom:String(payload.Custom ?? "0"),Name:payload.Name || "Flat",EqBand:Array.from({length:10},(_,i)=>String(payload.EqBand?.[i] ?? "0"))});
        } else if (view==="parametric") {
          setParametric({Custom:String(payload.Custom ?? "0"),Name:payload.Name || "Parametric",EqBand:Array.from({length:10},(_,i)=>({
            Index:String(payload.EqBand?.[i]?.Index ?? i), Filter:payload.EqBand?.[i]?.Filter || "OFF", Freq:String(payload.EqBand?.[i]?.Freq ?? 1000), Q:String(payload.EqBand?.[i]?.Q ?? 1), Gain:String(payload.EqBand?.[i]?.Gain ?? 0)
          }))});
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    refreshEqView();
    return ()=>{cancelled=true;};
  },[view,device.id]);

  useEffect(()=>{
    const mode=device.eqEnable;
    if (mode==="0001") setView("tone");
    else if (mode==="0100" || mode==="0101") setView("parametric");
    else if (mode==="0010" || mode==="0011") setView("graphic");
  },[device.eqEnable]);

  const changeMode = async (value) => {
    setSaving("mode"); setMessage("");
    const r=await run(`eqEnable:${value}`,{quiet:true});
    setSaving("");
    setMessage(r?.ok ? `EQ mode changed to ${EQ_MODES.find(x=>x[0]===value)?.[1] || value}.` : "Could not change EQ mode.");
  };

  const updateTone = (key,value) => {
    const n=Math.max(-5,Math.min(5,Number(value)||0));
    setTone(t=>({...t,[key]:String(n)}));
  };
  const applyTone = async () => {
    setSaving("tone"); setMessage("");
    const payload={
      Bass:String(Math.max(-5,Math.min(5,Number(tone.Bass)||0))),
      Treble:String(Math.max(-5,Math.min(5,Number(tone.Treble)||0)))
    };
    const r=await run(`setEqHighAndLowFrequencies:${JSON.stringify(payload)}`,{quiet:true});
    setSaving("");
    setMessage(r?.ok ? "Bass / Treble saved to the device." : `Bass / Treble write failed${r?.raw?`: ${r.raw}`:"."}`);
    if (r?.ok) setTimeout(loadEq,250);
  };

  const updateGraphicBand = (i,value) => setGraphic(g=>({...g,EqBand:g.EqBand.map((v,n)=>n===i?String(value):v)}));
  const applyGraphic = async () => {
    setSaving("graphic"); setMessage("");
    const payload={Custom:"1",Name:graphic.Name || "airCloudGraphic",EqBand:graphic.EqBand.map(v=>String(Math.max(-12,Math.min(12,Number(v)||0))))};
    const r=await run(`setPresetEq:${JSON.stringify(payload)}`,{quiet:true});
    setSaving("");
    setMessage(r?.ok ? "Graphic EQ saved to the device." : `Graphic EQ write failed${r?.raw?`: ${r.raw}`:"."}`);
    if (r?.ok) setTimeout(loadEq,250);
  };
  const flatGraphic = () => setGraphic(g=>({...g,Name:"Flat",EqBand:Array(10).fill("0")}));

  const updatePeq = (i,key,value) => setParametric(p=>({...p,EqBand:p.EqBand.map((b,n)=>n===i?{...b,[key]:value}:b)}));
  const applyParametric = async () => {
    setSaving("peq"); setMessage("");
    const bands=parametric.EqBand.map((b,i)=>({
      Index:String(i), Filter:FILTERS.includes(b.Filter)?b.Filter:"OFF",
      Freq:String(Math.max(20,Math.min(24000,Number(b.Freq)||20))),
      Q:String(Math.max(0,Math.min(30,Number(b.Q)||0))),
      Gain:String(Math.max(-12,Math.min(12,Number(b.Gain)||0)))
    }));
    const payload={Custom:"1",Name:parametric.Name || "airCloudPEQ",EqBand:bands};
    const r=await run(`setParameterEq:${JSON.stringify(payload)}`,{quiet:true});
    setSaving("");
    setMessage(r?.ok ? "Parametric EQ saved to the device." : `Parametric EQ write failed${r?.raw?`: ${r.raw}`:"."}`);
    if (r?.ok) setTimeout(loadEq,250);
  };

  const resetParametricToZero = async () => {
    const next={...parametric,Name:parametric.Name || "airCloudPEQ",EqBand:parametric.EqBand.map(b=>({...b,Gain:"0"}))};
    setParametric(next);
    setSaving("peq-reset"); setMessage("");
    const bands=next.EqBand.map((b,i)=>({
      Index:String(i), Filter:FILTERS.includes(b.Filter)?b.Filter:"OFF",
      Freq:String(Math.max(20,Math.min(24000,Number(b.Freq)||20))),
      Q:String(Math.max(0,Math.min(30,Number(b.Q)||0))),
      Gain:"0"
    }));
    const payload={Custom:"1",Name:next.Name,EqBand:bands};
    const r=await run(`setParameterEq:${JSON.stringify(payload)}`,{quiet:true});
    setSaving("");
    setMessage(r?.ok ? "Parametric EQ gain reset to 0 dB on all 10 bands." : `Parametric EQ reset failed${r?.raw?`: ${r.raw}`:"."}`);
    if (r?.ok) setTimeout(loadEq,250);
  };

  return <div className="single"><Panel>
    <PanelTitle title="Equalizer" sub={`Real device EQ · EqType ${device.eqType || "—"} · EqEnable ${device.eqEnable || "—"}`} action={<button className="miniRefresh" onClick={loadEq} disabled={loading}><RefreshCw size={15} className={loading?"spin":""}/> Read EQ</button>}/>

    <div className="eqModeBar">
      <label>Active EQ mode<select value={device.eqEnable && device.eqEnable!=="—"?device.eqEnable:"0010"} onChange={e=>changeMode(e.target.value)} disabled={saving==="mode"}>{EQ_MODES.map(([v,l])=><option key={v} value={v}>{l} ({v})</option>)}</select></label>
      <div className="eqStatusPills"><span>Support: {device.eqType || "—"}</span><span>Active: {device.eqEnable || "—"}</span></div>
    </div>

    <div className="eqTabs">
      <button className={view==="tone"?"active":""} onClick={()=>setView("tone")}>Bass / Treble</button>
      <button className={view==="graphic"?"active":""} onClick={()=>setView("graphic")}>Graphic EQ</button>
      <button className={view==="parametric"?"active":""} onClick={()=>setView("parametric")}>Parametric EQ</button>
      <button className={view==="room"?"active":""} onClick={()=>setView("room")}>Room EQ</button>
    </div>

    {message && <div className="eqMessage">{message}</div>}

    {view==="tone" && <div className="toneEditor">
      <div className="toneControls">
        {[['Bass','Bass'],['Treble','Treble']].map(([key,label])=><div className="toneControl" key={key}>
          <div className="toneControlHead"><span>{label}</span><strong>{Number(tone[key]||0)>0?`+${tone[key]}`:tone[key]} dB</strong></div>
          <input type="range" min="-5" max="5" step="1" value={tone[key]||"0"} onChange={e=>updateTone(key,e.target.value)}/>
          <div className="toneScale"><span>−5</span><span>0</span><span>+5</span></div>
          <input className="toneNumber" type="number" min="-5" max="5" step="1" value={tone[key]||"0"} onChange={e=>updateTone(key,e.target.value)}/>
        </div>)}
      </div>
      <div className="toneFooter">
        <div className="eqScaleNote">Range −5…+5 dB · values are sent together with <code>setEqHighAndLowFrequencies</code>. Verified on CS-8 firmware 2.35.0023.32.</div>
        <button className="primaryBtn" onClick={applyTone} disabled={saving==="tone"}>{saving==="tone"?"Saving…":"Apply Bass / Treble"}</button>
      </div>
    </div>}

    {view==="graphic" && <>
      <div className="eqEditorHead">
        <label>Preset name<input value={graphic.Name} onChange={e=>setGraphic(g=>({...g,Name:e.target.value}))}/></label>
        <div className="actions"><button className="ghostBtn" onClick={flatGraphic}>Set Flat</button><button className="primaryBtn" onClick={applyGraphic} disabled={saving==="graphic"}>{saving==="graphic"?"Saving…":"Apply Graphic EQ"}</button></div>
      </div>
      <div className="eqGraph realEqGraph">{GRAPHIC_BANDS.map((b,i)=><div className="eqBand" key={b}><b>{Number(graphic.EqBand[i]||0).toFixed(0)} dB</b><input type="range" min="-12" max="12" step="1" value={graphic.EqBand[i]||"0"} onChange={e=>updateGraphicBand(i,e.target.value)}/><span>{b>=1000?`${b/1000}k`:b} Hz</span></div>)}</div>
      <div className="eqScaleNote">Range −12…+12 dB · all 10 bands are sent together with <code>setPresetEq</code>.</div>
    </>}

    {view==="parametric" && <>
      <div className="eqEditorHead">
        <label>PEQ name<input value={parametric.Name} onChange={e=>setParametric(p=>({...p,Name:e.target.value}))}/></label>
        <div className="actions"><button className="ghostBtn" onClick={resetParametricToZero} disabled={saving!==""}>{saving==="peq-reset"?"Resetting…":"Reset PEQ to 0"}</button><button className="primaryBtn" onClick={applyParametric} disabled={saving!==""}>{saving==="peq"?"Saving…":"Apply Parametric EQ"}</button></div>
      </div>
      <UnifiedPeqEditor
        title="A33 Parametric EQ"
        bands={parametric.EqBand.map((b,i)=>({id:i,label:String(i+1),filter:b.Filter,frequency:b.Freq,q:b.Q,gain:b.Gain}))}
        filterOptions={FILTERS.map(f=>({value:f,label:f}))}
        frequencyMin={20} frequencyMax={24000} qMin={0.01} qMax={30}
        onChange={(i,key,value)=>updatePeq(i,key==="filter"?"Filter":key==="frequency"?"Freq":key==="gain"?"Gain":"Q",value)}
      />
      <div className="eqScaleNote">Filters: PK / LS / HS / LP / HP / OFF · 20–24000 Hz · Q 0–30 · Gain −12…+12 dB.</div>
    </>}

    {view==="room" && <RoomEqMeasurement device={device} run={run} setVolume={setVolume} onLoadPeq={(bands)=>{setParametric({Custom:"1",Name:"RoomEQ Preview",EqBand:bands});setView("parametric");setMessage("Room EQ suggestion loaded into the Parametric EQ editor. Review it and press Apply only when ready.");}}/>}
  </Panel></div>
}
function NetworkPanel({device,run}){
  const currentIp = String(device?.tcpIp || device?.ip || "").trim();
  const parts = currentIp.split(".");
  const guessedGateway = parts.length===4 ? `${parts[0]}.${parts[1]}.${parts[2]}.1` : "192.168.0.1";
  const isA31 = /^A31(?:$|[^0-9])/i.test(String(device?.hardware || device?.model || "").trim());
  const [cfg,setCfg] = useState({
    WStaticIp: currentIp,
    WStaticNetmask:"255.255.255.0",
    WStaticGateway:guessedGateway,
    WStaticDns:guessedGateway,
    EStaticIp:currentIp,
    EStaticNetmask:"255.255.255.0",
    EStaticGateway:guessedGateway,
    EStaticDns:guessedGateway
  });
  const [busy,setBusy] = useState(false);
  const [a31Net,setA31Net] = useState({loaded:false,wifi:null,eth:null});
  const set = (key,value)=>setCfg(v=>({...v,[key]:value}));
  const validIp = value => { const a=String(value||"").split("."); return a.length===4 && a.every(x=>/^\d+$/.test(x) && Number(x)>=0 && Number(x)<=255); };

  const readA31Static = async () => {
    if (!isA31) return;
    const r = await run("getStaticIP", {quiet:true});
    if (!r?.ok || !r.data || typeof r.data!=="object") return;
    const d=r.data;
    setA31Net({loaded:true,wifi:String(d.wifi ?? ""),eth:String(d.eth ?? "")});
    setCfg(v=>({
      ...v,
      WStaticIp:d.wifi_static_ip || v.WStaticIp || currentIp,
      WStaticNetmask:d.wifi_static_mask || v.WStaticNetmask,
      WStaticGateway:d.wifi_static_gateway || v.WStaticGateway,
      WStaticDns:d.wifi_static_dns1 || v.WStaticDns
    }));
  };
  useEffect(()=>{ readA31Static(); },[device?.id,isA31]);

  const applyStatic = async mode => {
    const prefix = mode==="wifi" ? "W" : "E";
    const keys = [`${prefix}StaticIp`,`${prefix}StaticNetmask`,`${prefix}StaticGateway`,`${prefix}StaticDns`];
    if (!keys.every(k=>validIp(cfg[k]))) { alert("Check IP address, subnet mask, gateway and DNS."); return; }
    if (isA31 && mode==="ethernet" && a31Net.eth==="-1") return;
    if (!confirm(`Apply static ${mode==="wifi"?"Wi-Fi":"Ethernet"} IP ${cfg[`${prefix}StaticIp`]}? The device may temporarily disconnect.`)) return;
    setBusy(true);
    try {
      if (isA31) {
        // Verified on A31 4.6.415156 (2026-09-16): DHCP -> Static uses JSON setStaticIP.
        // The device may change IP before the HTTP response reaches airControl, so a
        // timeout/connection reset after sending is expected and must not be treated as failure.
        // getStaticIP reports wifi=0 for Static, wifi=1 for DHCP, eth=-1 when Ethernet is unavailable.
        const type=mode==="wifi"?"wifi":"eth";
        const staticInfo={
          type,
          ip:cfg[`${prefix}StaticIp`],
          mask:cfg[`${prefix}StaticNetmask`],
          gateway:cfg[`${prefix}StaticGateway`],
          dns:[{service:cfg[`${prefix}StaticDns`]}]
        };
        const saved=await run(`setStaticIP:${JSON.stringify(staticInfo)}`, {quiet:true});
        if (saved?.ok && String(saved.data||"").toLowerCase().includes("unknown command")) {
          alert("The A31 did not accept the static IP command.");
          return;
        }
        // Do not wait for confirmation from the old address: A31 drops that connection
        // as soon as the new static address is applied.
        alert(`Static IP command sent to A31. Reconnect airControl to ${cfg[`${prefix}StaticIp`]}.`);
        return;
      }
      // Preserve the existing A33/newer-chip implementation unchanged.
      const info = JSON.stringify(cfg);
      const saved = await run(`setStaticIP:${info}`, {quiet:true});
      if (!saved?.ok) { alert("The device did not accept the static IP parameters."); return; }
      const enabled = await run(`setNetIPSwitchState:${mode==="wifi"?"W_Enable":"E_Enable"}`, {quiet:true});
      if (!enabled?.ok) alert("Static IP parameters were saved, but enabling static mode was not confirmed.");
    } finally { setBusy(false); }
  };
  const dhcp = async mode => {
    if (isA31 && mode==="ethernet" && a31Net.eth==="-1") return;
    if (!confirm(`Enable DHCP for ${mode==="wifi"?"Wi-Fi":"Ethernet"}? The device IP may change.`)) return;
    setBusy(true);
    try {
      if (isA31) {
        const type=mode==="wifi"?"wifi":"eth";
        const r=await run(`setDhcp:${type}`, {quiet:true});
        if (!r?.ok || String(r.data||"").toLowerCase().includes("unknown command")) alert("The A31 did not accept the DHCP command.");
        return;
      }
      await run("setNetIPSwitchState:Disable", {quiet:true});
    } finally { setBusy(false); }
  };
  const iface = (kind,label) => {
    const mode=kind==="W"?"wifi":"ethernet";
    const unavailable=isA31 && mode==="ethernet" && a31Net.eth==="-1";
    const status=isA31 && mode==="wifi" && a31Net.loaded ? (a31Net.wifi==="0"?"Static":a31Net.wifi==="1"?"DHCP":a31Net.wifi==="-1"?"Unavailable":"Unknown") : null;
    return <div className={`staticIpCard${unavailable?" disabled":""}`}>
      <div className="staticIpHead"><div><b>{label}</b><span>{unavailable?"Not available on this device":status?`Current mode: ${status}`:"Static IPv4 configuration"}</span></div></div>
      <div className="staticIpGrid">
        <label>IP address<input disabled={unavailable} value={cfg[`${kind}StaticIp`]} onChange={e=>set(`${kind}StaticIp`,e.target.value)} placeholder="192.168.0.50"/></label>
        <label>Subnet mask<input disabled={unavailable} value={cfg[`${kind}StaticNetmask`]} onChange={e=>set(`${kind}StaticNetmask`,e.target.value)} placeholder="255.255.255.0"/></label>
        <label>Gateway<input disabled={unavailable} value={cfg[`${kind}StaticGateway`]} onChange={e=>set(`${kind}StaticGateway`,e.target.value)} placeholder="192.168.0.1"/></label>
        <label>DNS<input disabled={unavailable} value={cfg[`${kind}StaticDns`]} onChange={e=>set(`${kind}StaticDns`,e.target.value)} placeholder="192.168.0.1"/></label>
      </div>
      <div className="actions"><button className="ghostBtn" disabled={busy||unavailable} onClick={()=>dhcp(mode)}>Use DHCP</button><button className="primaryBtn" disabled={busy||unavailable} onClick={()=>applyStatic(mode)}>Apply Static IP</button></div>
    </div>;
  };
  return <div className="single"><Panel><PanelTitle title="Network" sub="Network state and static IPv4 settings for all supported device chips"/><div className="networkStatus"><Wifi size={34}/><div><b>{device.networkMode || "Network"}</b><span>{device.online?"Connected":"Offline"} · {device.tcpIp || device.ip}</span></div><button className="ghostBtn" onClick={()=>run("wlanGetConnectState")}>Wi-Fi state</button></div><div className="infoGrid"><div><span>Control endpoint</span><b>{device.protocol}://{device.ip}:{device.port}</b></div><div><span>WLAN MAC</span><b>{device.wlanMac || "—"}</b></div><div><span>Ethernet MAC</span><b>{device.ethMac || "—"}</b></div><div><span>Chip / hardware</span><b>{device.hardware || device.model || "—"}</b></div></div><div className="actions"><button className="ghostBtn" onClick={()=>run("getScanAPs")}>Scan Wi-Fi</button>{isA31&&<button className="ghostBtn" disabled={busy} onClick={readA31Static}>Read IP mode</button>}</div></Panel><Panel><PanelTitle title="Static IP" sub={isA31?"A31 legacy Linkplay network API · verified Static/DHCP switching":"Configure Wi-Fi or Ethernet. Static parameters are saved before static mode is enabled."}/><div className="staticIpColumns">{iface("W","Wi-Fi (wlan0)")}{iface("E","Ethernet (eth0)")}</div><div className="networkWarning">Changing IP can disconnect airControl from the device. If the address changes, update the device IP in airControl before reconnecting.</div></Panel></div>
}
function BluetoothPanel({device,run}){return <div className="single"><Panel><PanelTitle title="Bluetooth" sub="Discovery, pairing and device name"/><div className="networkStatus"><Bluetooth size={34}/><div><b>{device.bleName || "Bluetooth"}</b><span>{device.features?.includes("Bluetooth")?"Supported by device":"Feature status unknown"}</span></div><button className="toggle" onClick={()=>run("setDiscoveryBluetooth:Open")}>Discoverable</button></div><div className="actions"><button className="ghostBtn" onClick={()=>run("getBluetoothName")}>Read name</button><button className="ghostBtn" onClick={()=>run("resetBluetoothPairing")}>Reset pairing</button><button className="ghostBtn" onClick={()=>run("clearBluetoothPairingList")}>Clear list</button></div><label>Bluetooth name<input defaultValue={device.bleName && device.bleName!=="—"?device.bleName:"airCloud-Audio"} onBlur={e=>run(`modifyBluetoothName:${e.target.value}`)}/></label></Panel></div>}
function MultiroomPanel({device,devices,refreshAll,requestDevice}){
  const [busy,setBusy]=useState(false);
  const [message,setMessage]=useState("");
  const online=(devices||[]).filter(d=>d.online&&!d.mock);
  const isAirCloud=d=>deviceTypeOf(d)===DEVICE_TYPES.AIRCLOUD;
  const isLinkplay=d=>deviceTypeOf(d)===DEVICE_TYPES.AIRSCOPE;
  const linkplayNative=d=>isLinkplay(d)&&Boolean(linkplayTransportFor(d));
  const normUuid=v=>String(v||"").replace(/^uuid:/i,"").replace(/[^0-9a-f]/gi,"").toUpperCase();
  const slaveOf=(d,master)=>Boolean(master&&d&&d.id!==master.id&&((d.masterIp&&d.masterIp===master.ip)||(normUuid(d.masterUuid)&&normUuid(d.masterUuid)===normUuid(master.uuid))));
  const masterFor=d=>{
    if(!d)return null;
    if(isLinkplay(d)&&(d.masterIp||d.masterUuid))return online.find(x=>x.id!==d.id&&((d.masterIp&&x.ip===d.masterIp)||(normUuid(d.masterUuid)&&normUuid(x.uuid)===normUuid(d.masterUuid))))||null;
    if(isLinkplay(d)&&online.some(x=>slaveOf(x,d)))return d;
    if(isAirCloud(d)){
      const h=String(d.host||"0");
      if(h&&h!=="0"&&h!==d.ip)return online.find(x=>x.ip===h)||null;
      const m=String(d.multiroom||"free").toLowerCase();
      if(m.includes("master")||m.includes("host")||(h&&h!=="0"))return d;
    }
    return null;
  };
  const roleOf=d=>{const m=masterFor(d);if(!m)return "Free";return m.id===d.id?"Master":"Slave"};
  const membersFor=master=>online.filter(x=>x.id!==master.id&&(isLinkplay(master)?slaveOf(x,master):(isAirCloud(x)&&String(x.host||"")===master.ip)));
  const masters=online.filter(d=>roleOf(d)==="Master");
  const groupedIds=new Set(masters.flatMap(m=>[m.id,...membersFor(m).map(x=>x.id)]));
  const free=online.filter(d=>!groupedIds.has(d.id)&&roleOf(d)==="Free");
  const orphans=online.filter(d=>roleOf(d)==="Slave"&&!groupedIds.has(d.id));
  const selectedMaster=masterFor(device);
  // v4.4.52 Standard Style: keep the working row-level Add to group controls.
  // If the selected zone is already grouped, additions target its real master.
  // If it is free, the selected compatible zone itself becomes the proposed master.
  const addTargetMaster=selectedMaster || (device && roleOf(device)==="Free" && (linkplayNative(device)||isAirCloud(device)) ? device : null);
  const refresh=async()=>{setBusy(true);setMessage("");try{await refreshAll?.()}finally{setBusy(false)}};
  const groupUuid=d=>{const raw=normUuid(d?.uuid);if(raw.length===32)return `${raw.slice(0,8)}-${raw.slice(8,12)}-${raw.slice(12,16)}-${raw.slice(16,20)}-${raw.slice(20)}`;return String(d?.uuid||"").replace(/^uuid:/i,"")};
  const send=async(target,command)=>{const r=await requestDevice(target,command);if(!r?.ok)throw new Error(r?.raw||r?.error||"Device rejected command");return r};
  const addToMaster=async(master,slave)=>{
    const nativeLinkplay=linkplayNative(master)&&linkplayNative(slave), nativeA33=isAirCloud(master)&&isAirCloud(slave);
    if(!nativeLinkplay&&!nativeA33){setMessage("Native grouping is enabled only within the verified Linkplay A31/A97/A98 family or within A33/airCloud.");return}
    if(nativeLinkplay&&!groupUuid(master)){setMessage(`${master.name}: UUID is not available yet. Refresh device status first.`);return}
    if(!confirm(`Add ${slave.name} to ${master.name}?`))return;
    setBusy(true);setMessage("");try{if(nativeLinkplay)await send(slave,`multiroom:JoinGroup:IP=${master.ip}:uuid=${groupUuid(master)}`);else{await send(master,"multiroom:setHost");await send(slave,`multiroom:setSlave:${master.ip}`)}await new Promise(r=>setTimeout(r,900));await refreshAll?.();setMessage(`${slave.name} joined ${master.name}.`)}catch(e){setMessage(`Grouping failed: ${e.message}`)}finally{setBusy(false)}
  };
  const leave=async(target)=>{const linkplay=linkplayNative(target);if(!linkplay&&!isAirCloud(target)){setMessage("This device does not have a verified native ungroup command.");return}const role=roleOf(target);const cmd=linkplay?"multiroom:LeaveGroup":(role==="Slave"?"multiroom:disconnectSlave":"multiroom:breakUp");if(!confirm(`${role==="Slave"?"Remove":"Break up group for"} ${target.name}?`))return;setBusy(true);setMessage("");try{await send(target,cmd);await new Promise(r=>setTimeout(r,700));await refreshAll?.();setMessage(`${target.name}: group updated.`)}catch(e){setMessage(`Ungroup failed: ${e.message}`)}finally{setBusy(false)}};
  const renderMember=(d,master,isMaster=false)=><div className={`multiroomMember ${d.id===device.id?"selected":""}`} key={d.id}><div className="multiroomZoneIdentity"><b>{d.name}</b><span>{deviceTypeOf(d)} · {d.hardware||d.project||d.model||"—"}</span></div><strong>{isMaster?"MASTER":"SLAVE"}</strong><small>{isMaster?`Group master · ${d.ip}`:`Linked to ${master.name} · ${master.ip}`}</small><div className="multiroomActions">{!isMaster&&<button className="ghostBtn" disabled={busy} onClick={()=>leave(d)}>Remove</button>}{isMaster&&<button className="ghostBtn" disabled={busy} onClick={()=>leave(d)}>Ungroup</button>}</div></div>;
  return <div className="single"><Panel><PanelTitle title="Multiroom" sub="Native grouping · groups are shown as Master + member zones"/>
    <div className="multiHero"><Network size={38}/><div><strong>{selectedMaster?`${selectedMaster.name} +${membersFor(selectedMaster).length}`:"Free"}</strong><span>{selectedMaster?`${device.name} belongs to this group`:"Selected zone is not in a group"}</span></div><button className="ghostBtn" disabled={busy} onClick={refresh}>{busy?"Working…":"Refresh all"}</button></div>
    <div className="multiroomGroups">{masters.map(master=>{const members=membersFor(master);return <section className={`multiroomGroupCard ${selectedMaster?.id===master.id?"selected":""}`} key={master.id}><div className="multiroomGroupHead"><div><b>{master.name} +{members.length}</b><span>Play in sync</span></div><small>{members.length+1} zones</small></div>{renderMember(master,master,true)}{members.map(m=>renderMember(m,master,false))}<div className="multiroomGroupAdd">{free.filter(d=>(linkplayNative(master)&&linkplayNative(d))||(isAirCloud(master)&&isAirCloud(d))).map(d=><button key={d.id} className="ghostBtn" disabled={busy} onClick={()=>addToMaster(master,d)}>+ {d.name}</button>)}</div></section>})}
    {free.length>0&&<section className="multiroomFreeCard"><div className="multiroomGroupHead"><div><b>Free zones</b><span>Not in a group</span></div><small>{free.length}</small></div>{free.map(d=>{const canAdd=Boolean(addTargetMaster&&d.id!==addTargetMaster.id&&((linkplayNative(addTargetMaster)&&linkplayNative(d))||(isAirCloud(addTargetMaster)&&isAirCloud(d))));return <div className={`multiroomMember ${d.id===device.id?"selected":""}`} key={d.id}><div className="multiroomZoneIdentity"><b>{d.name}</b><span>{deviceTypeOf(d)} · {d.hardware||d.project||d.model||"—"}</span></div><strong>FREE</strong><small>{d.ip}</small><div className="multiroomActions">{canAdd&&<button className="ghostBtn" disabled={busy} onClick={()=>addToMaster(addTargetMaster,d)}>Add to group</button>}</div></div>})}</section>}
    {orphans.length>0&&<section className="multiroomFreeCard"><div className="multiroomGroupHead"><div><b>Waiting for master</b><span>Slave reports a master that is not currently resolved</span></div></div>{orphans.map(d=><div className="multiroomMember" key={d.id}><div className="multiroomZoneIdentity"><b>{d.name}</b><span>{deviceTypeOf(d)}</span></div><strong>SLAVE</strong><small>Master {d.masterIp||d.masterUuid||"unknown"}</small><div/></div>)}</section>}
    </div>{!online.length&&<div className="roomEmpty">No Online zones discovered.</div>}{message&&<div className="multiroomMessage">{message}</div>}
    <div className="linkplayEqNote"><b>Verified Linkplay native multiroom:</b> A31/A97/A98 use <code>multiroom:JoinGroup:IP=...:uuid=...</code> and <code>multiroom:LeaveGroup</code>. Transport is fixed by chip: A31 HTTP; A97/A98 HTTPS.</div>
  </Panel></div>
}

function LocalMusicLibrary({device,run,onPlayTrack,playback,onPlayDlna,dlnaPlayback}) {
  const [librarySource,setLibrarySource]=useState("local");
  const [networkSources,setNetworkSources]=useState({dlna:[],smb:[]});
  const [networkLoading,setNetworkLoading]=useState(false);
  const [networkError,setNetworkError]=useState("");
  const [dlnaServer,setDlnaServer]=useState(null); const [dlnaStack,setDlnaStack]=useState([]); const [dlnaItems,setDlnaItems]=useState([]); const [dlnaLoading,setDlnaLoading]=useState(false);
  const [smbServer,setSmbServer]=useState(null); const [smbCfg,setSmbCfg]=useState({share:"",domain:"",username:"",password:""}); const [smbShares,setSmbShares]=useState([]); const [smbPath,setSmbPath]=useState(""); const [smbItems,setSmbItems]=useState([]); const [smbLoading,setSmbLoading]=useState(false);
  const discoverNetworkSources=async()=>{setNetworkLoading(true);setNetworkError("");try{const r=await window.airCloud?.discoverMediaServers?.();if(!r?.ok)throw new Error(r?.error||"Network discovery failed");setNetworkSources({dlna:r.dlna||[],smb:r.smb||[]})}catch(e){setNetworkError(e?.message||String(e))}finally{setNetworkLoading(false)}};
  const browseDlna=async(server,objectId="0",title=server?.name||"Media Server",push=true)=>{setDlnaLoading(true);setNetworkError("");try{const r=await window.airCloud?.browseMediaServer?.({controlUrl:server.controlUrl,objectId});if(!r?.ok)throw new Error(r?.error||"DLNA Browse failed");setDlnaServer(server);setDlnaItems(r.items||[]);if(push)setDlnaStack(v=>[...v,{id:objectId,title}]);}catch(e){setNetworkError(e?.message||String(e))}finally{setDlnaLoading(false)}};
  const dlnaBack=async()=>{if(dlnaStack.length<=1){setDlnaServer(null);setDlnaItems([]);setDlnaStack([]);return}const next=dlnaStack.slice(0,-1);const p=next[next.length-1];setDlnaStack(next);await browseDlna(dlnaServer,p.id,p.title,false)};
  const playDlna=async(item)=>{if(!item?.resource?.url)return;setNetworkError("");try{const queue=dlnaItems.filter(x=>x.kind!=="container"&&x?.resource?.url);const index=Math.max(0,queue.findIndex(x=>x.id===item.id&&x.resource.url===item.resource.url));const r=onPlayDlna?await onPlayDlna(item,queue,index,dlnaServer?.name||"DLNA MediaServer"):await window.airCloud?.playDlnaTrackUpnp?.({deviceIp:device.ip,url:item.resource.url,title:item.title,artist:item.artist,album:item.album,artUrl:item.artUrl,protocolInfo:item.resource.protocolInfo,duration:item.resource.duration});if(!r?.ok)throw new Error(r?.error||`Playback failed at ${r?.step||"UPnP"}`)}catch(e){setNetworkError(e?.message||String(e))}};
  const listSmbShares=async(server=smbServer)=>{if(!server)return;setSmbLoading(true);setNetworkError("");try{const r=await window.airCloud?.listSmbShares?.({host:server.ip,domain:smbCfg.domain,username:smbCfg.username,password:smbCfg.password});if(!r?.ok)throw new Error(r?.error||"SMB share discovery failed");setSmbServer(server);setSmbShares(r.shares||[]);setSmbItems([]);setSmbPath("")}catch(e){setNetworkError(e?.message||String(e))}finally{setSmbLoading(false)}};
  const chooseSmbServer=async(server)=>{setSmbServer(server);setSmbShares([]);setSmbItems([]);setSmbPath("");setSmbCfg(v=>({...v,share:""}));await listSmbShares(server)};
  const openSmbShare=async(share)=>{setSmbCfg(v=>({...v,share:share.name}));setSmbLoading(true);setNetworkError("");try{const r=await window.airCloud?.browseSmb?.({host:smbServer.ip,share:share.name,domain:smbCfg.domain,username:smbCfg.username,password:smbCfg.password,path:""});if(!r?.ok)throw new Error(r?.error||"SMB Browse failed");setSmbPath("");setSmbItems(r.items||[])}catch(e){setNetworkError(e?.message||String(e))}finally{setSmbLoading(false)}};
  const browseSmb=async(server=smbServer,targetPath="")=>{if(!server)return;setSmbLoading(true);setNetworkError("");try{const r=await window.airCloud?.browseSmb?.({host:server.ip,share:smbCfg.share,domain:smbCfg.domain,username:smbCfg.username,password:smbCfg.password,path:targetPath});if(!r?.ok)throw new Error(r?.error||"SMB Browse failed");setSmbServer(server);setSmbPath(r.path||"");setSmbItems(r.items||[])}catch(e){setNetworkError(e?.message||String(e))}finally{setSmbLoading(false)}};
  const smbBack=()=>{if(!smbPath){setSmbServer(null);setSmbItems([]);return}const parts=smbPath.split(/[\\/]/).filter(Boolean);parts.pop();browseSmb(smbServer,parts.join("\\"))};
  const playSmb=async(item)=>{setNetworkError("");try{const r=await window.airCloud?.playSmbTrack?.({host:smbServer.ip,share:smbCfg.share,domain:smbCfg.domain,username:smbCfg.username,password:smbCfg.password,path:item.path,size:item.size,title:item.title,deviceIp:device.ip});if(!r?.ok)throw new Error(r?.error||`SMB playback failed at ${r?.step||"SMB"}`)}catch(e){setNetworkError(e?.message||String(e))}};
  useEffect(()=>{
    const off=window.airCloud?.onSmbPlaybackStatus?.((st)=>{
      if(st?.ok===false)setNetworkError(`SMB ${st.step||"ERROR"}: ${st.error||"Playback failed"}`);
      else if(st?.done)setNetworkError("");
    });
    return ()=>{try{off?.()}catch{}};
  },[]);
  useEffect(()=>{discoverNetworkSources()},[]);
  const key="airCloudCTRL.localLibrary.v2";
  const legacyKey="airCloudCTRL.localLibrary.v1";
  const initialRoots=()=>{try{const v=JSON.parse(localStorage.getItem(key)||"null");if(Array.isArray(v?.roots))return v.roots;}catch{} try{const v=JSON.parse(localStorage.getItem(legacyKey)||"{}");return v.root?[v.root]:[]}catch{return []}};
  const [roots,setRoots]=useState(initialRoots);
  const [rootStatus,setRootStatus]=useState({});
  const [tracks,setTracks]=useState([]); const [loading,setLoading]=useState(false); const [error,setError]=useState("");
  const [view,setView]=useState("albums"); const [query,setQuery]=useState(""); const [selected,setSelected]=useState(null); const [manage,setManage]=useState(false);
  useEffect(()=>{localStorage.setItem(key,JSON.stringify({roots}))},[roots]);
  const scanRoots=async list=>{ if(!window.airCloud?.scanMusicFolder)return; setLoading(true);setError("");const all=[];const status={};for(const folder of list){try{const r=await window.airCloud.scanMusicFolder(folder);if(!r?.ok)throw new Error(r?.error||"Scan failed");status[folder]="online";(r.tracks||[]).forEach(t=>all.push({...t,libraryRoot:folder}));}catch(e){status[folder]="offline";}} const seen=new Set();const merged=all.filter(t=>!seen.has(t.id)&&seen.add(t.id));setTracks(merged);setRootStatus(status);setLoading(false);};
  useEffect(()=>{if(roots.length)scanRoots(roots)},[]);
  const choose=async()=>{const f=await window.airCloud?.chooseMusicFolder?.();if(!f)return;const normalized=String(f);const next=roots.includes(normalized)?roots:[...roots,normalized];if(!roots.includes(normalized))setRoots(next);await scanRoots(next)};
  const removeRoot=async folder=>{if(!window.confirm(`Remove “${folder}” from the airControl library?\n\nNo music files will be deleted.`))return;const next=roots.filter(r=>r!==folder);setRoots(next);await scanRoots(next)};
  const play=async (track,queue,index)=>{setError("");const r=onPlayTrack?await onPlayTrack(track,queue,index):{ok:false,error:"Local playback controller unavailable"};if(!r?.ok)setError(r?.error||"Device did not accept the local media URL");else setSelected(track.id)};
  const filtered=useMemo(()=>{const q=query.trim().toLowerCase();return q?tracks.filter(t=>[t.title,t.artist,t.album,t.folder,t.libraryRoot].some(v=>String(v||"").toLowerCase().includes(q))):tracks},[tracks,query]);
  const albums=useMemo(()=>{const m=new Map();filtered.forEach(t=>{const k=`${t.albumArtist}|||${t.album}`;if(!m.has(k))m.set(k,{key:k,artist:t.albumArtist,album:t.album,year:t.year,artwork:t.artwork,tracks:[]});m.get(k).tracks.push(t)});return [...m.values()].sort((a,b)=>`${a.artist} ${a.album}`.localeCompare(`${b.artist} ${b.album}`))},[filtered]);
  const artists=useMemo(()=>{const m=new Map();filtered.forEach(t=>{const a=t.albumArtist||t.artist||"Unknown Artist";if(!m.has(a))m.set(a,[]);m.get(a).push(t)});return [...m.entries()].sort((a,b)=>a[0].localeCompare(b[0]))},[filtered]);
  const folders=useMemo(()=>{const m=new Map();filtered.forEach(t=>{const rootName=(t.libraryRoot||"Music").split(/[\\/]/).filter(Boolean).pop()||"Music";const f=t.folder?`${rootName} / ${t.folder}`:rootName;if(!m.has(f))m.set(f,[]);m.get(f).push(t)});return [...m.entries()].sort((a,b)=>a[0].localeCompare(b[0]))},[filtered]);
  const duration=s=>{s=Math.max(0,Math.round(Number(s)||0));return `${Math.floor(s/60)}:${String(s%60).padStart(2,"0")}`};
  const TrackRows=({items})=>{const queue=[...items].sort((a,b)=>(a.disc-b.disc)||(a.track-b.track)||a.title.localeCompare(b.title));return <div className="localTrackList">{queue.map((t,i)=><button key={t.id} className={`localTrack ${playback?.track?.id===t.id?"active":""}`} onClick={()=>play(t,queue,i)}><span className="localTrackNo">{t.track||i+1}</span><span className="localTrackText"><b>{t.title}</b><small>{t.artist} · {t.album}</small></span><span>{duration(t.duration)}</span><Play size={15}/></button>)}</div>};
  return <div className="single localLibraryPage"><Panel><PanelTitle title="Music Library" sub="Local music, UPnP / DLNA and SMB servers" action={<button className="ghostBtn" onClick={discoverNetworkSources} disabled={networkLoading}><RefreshCw size={15} className={networkLoading?"spin":""}/> Discover Network</button>}/>
    <div className="networkLibraryTabs">{[["local","This Device"],["dlna",`UPnP / DLNA (${networkSources.dlna.length})`],["smb",`SMB (${networkSources.smb.length})`]].map(([v,l])=><button key={v} className={librarySource===v?"active":""} onClick={()=>setLibrarySource(v)}>{l}</button>)}</div>
    {networkError&&<div className="usbError">{networkError}</div>}
    {librarySource==="dlna"&&(!dlnaServer?<div className="networkServerGrid">{networkLoading&&!networkSources.dlna.length?<div className="usbEmpty">Searching for UPnP / DLNA MediaServers…</div>:networkSources.dlna.length?networkSources.dlna.map(x=><button className="networkServerCard networkServerButton" key={x.udn||x.location} onClick={()=>browseDlna(x)}><Network size={26}/><div><b>{x.name}</b><span>{x.model||"UPnP / DLNA MediaServer"}</span><small>{x.ip}{x.manufacturer?` · ${x.manufacturer}`:""}</small></div></button>):<div className="usbEmpty">No UPnP / DLNA MediaServers found. Press Discover Network to search again.</div>}</div>:<div className="dlnaBrowser"><div className="dlnaBrowserHead"><button className="ghostBtn" onClick={dlnaBack}>← Back</button><div><b>{dlnaStack.map(x=>x.title).join(" / ")}</b><small>{dlnaServer.name} · {dlnaServer.ip}</small></div></div>{dlnaLoading?<div className="usbEmpty">Loading DLNA folder…</div>:dlnaItems.length?<div className="dlnaItemList">{dlnaItems.map((x,i)=><button key={`${x.kind}-${x.id}-${i}`} className={`dlnaItem ${dlnaPlayback?.track?.id===x.id&&dlnaPlayback?.track?.resource?.url===x.resource?.url?"active":""}`} onClick={()=>x.kind==="container"?browseDlna(dlnaServer,x.id,x.title):playDlna(x)}>{x.artUrl?<img src={x.artUrl}/>:<div className="dlnaItemIcon">{x.kind==="container"?<Folder size={22}/>:<Disc3 size={22}/>}</div>}<span><b>{x.title}</b><small>{x.kind==="container"?(x.childCount?`${x.childCount} items`:"Folder"):[x.artist,x.album].filter(Boolean).join(" · ")||"Audio track"}</small></span><em>{x.kind==="container"?"›":<Play size={16}/>}</em></button>)}</div>:<div className="usbEmpty">This DLNA folder is empty.</div>}</div>)}
    {librarySource==="smb"&&(!smbServer?<div className="networkServerGrid">{networkLoading&&!networkSources.smb.length?<div className="usbEmpty">Searching for SMB servers…</div>:networkSources.smb.length?networkSources.smb.map(x=><button className="networkServerCard networkServerButton" key={x.ip} onClick={()=>chooseSmbServer(x)}><HardDrive size={26}/><div><b>{x.name}</b><span>SMB server</span><small>{x.ip} · TCP 445</small></div></button>):<div className="usbEmpty">No SMB servers found.</div>}</div>:<div className="dlnaBrowser"><div className="dlnaBrowserHead"><button className="ghostBtn" onClick={smbBack}>← Back</button><div><b>{smbServer.name} / {smbCfg.share}{smbPath?` / ${smbPath}`:""}</b><small>{smbServer.ip} · SMB2/3</small></div></div>{!smbItems.length&&!smbLoading?<div className="smbConnect"><label>Domain<input value={smbCfg.domain} onChange={e=>setSmbCfg(v=>({...v,domain:e.target.value}))} placeholder="optional"/></label><label>Username<input value={smbCfg.username} onChange={e=>setSmbCfg(v=>({...v,username:e.target.value}))} placeholder="guest or user"/></label><label>Password<input type="password" value={smbCfg.password} onChange={e=>setSmbCfg(v=>({...v,password:e.target.value}))}/></label><button className="ghostBtn" onClick={()=>listSmbShares(smbServer)}>Refresh Shares</button>{smbShares.length?<div className="dlnaItemList">{smbShares.map(sh=><button key={sh.name} className="dlnaItem" onClick={()=>openSmbShare(sh)}><div className="dlnaItemIcon"><Folder size={22}/></div><span><b>{sh.name}</b><small>{sh.comment||"SMB shared folder"}</small></span><em>›</em></button>)}</div>:<><label>Share (manual fallback)<input value={smbCfg.share} onChange={e=>setSmbCfg(v=>({...v,share:e.target.value}))} placeholder="Music"/></label><button className="primaryBtn" disabled={!smbCfg.share} onClick={()=>browseSmb(smbServer,"")}>Open Share</button><small>No shares were enumerated. You can still enter a share name manually.</small></>}</div>:smbLoading?<div className="usbEmpty">Loading SMB shares / folder…</div>:<div className="dlnaItemList">{smbItems.map((x,i)=><button key={`${x.path}-${i}`} className="dlnaItem" onClick={()=>x.isDirectory?browseSmb(smbServer,x.path):playSmb(x)}><div className="dlnaItemIcon">{x.isDirectory?<Folder size={22}/>:<Disc3 size={22}/>}</div><span><b>{x.title||x.name}</b><small>{x.isDirectory?"Folder":`${Math.max(0,Math.round((x.size||0)/1024/1024))} MB · SMB audio`}</small></span><em>{x.isDirectory?"›":<Play size={16}/>}</em></button>)}</div>}</div>)}
    {librarySource==="local"&&<><div className="libraryActions localLibraryActions"><button className="ghostBtn" onClick={()=>setManage(v=>!v)}>Manage Folders</button><button className="primaryBtn" onClick={choose}><Folder size={16}/> Add Music Folder</button></div>
    <div className="libraryStatus"><div><b>{roots.length?`${roots.length} music folder${roots.length===1?"":"s"}`:"No music folder selected"}</b><small>{loading?"Scanning music…":`${tracks.length} tracks · ${albums.length} albums · ${artists.length} artists`}</small></div>{roots.length>0&&<button className="ghostBtn" onClick={()=>scanRoots(roots)} disabled={loading}><RefreshCw size={15} className={loading?"spin":""}/> Rescan All</button>}</div>
    {manage&&<div className="libraryRoots">{roots.length?roots.map(root=><div className="libraryRoot" key={root}><span className={`libraryRootDot ${rootStatus[root]==="offline"?"offline":""}`}/><div><b>{root}</b><small>{rootStatus[root]==="offline"?"Offline / unavailable":"Available"}</small></div><button className="dangerBtn" onClick={()=>removeRoot(root)}>Remove</button></div>):<div className="usbEmpty">No folders attached to this library.</div>}</div>}
    <div className="libraryToolbar"><div className="usbViewTabs">{[["artists","Artists"],["albums","Albums"],["folders","Folders"],["tracks","All Tracks"]].map(([v,l])=><button key={v} className={view===v?"active":""} onClick={()=>setView(v)}>{l}</button>)}</div><div className="search librarySearch"><Search size={16}/><input value={query} onChange={e=>setQuery(e.target.value)} placeholder="Search library…"/></div></div>
    {error&&<div className="usbError">{error}</div>}{!roots.length&&!loading&&<div className="usbEmpty">Choose one or more music folders on this Mac or Windows PC. Adding another folder keeps the folders already attached.</div>}
    {playback?.track&&<div className="libraryQueue"><div><b>Playing now</b><span>{playback.track.title} · {playback.track.artist}</span></div><div><b>Up Next</b><span>{playback.queue?.[playback.index+1]?.title || "End of queue"}</span></div></div>}
    {view==="albums"&&<div className="albumGrid">{albums.map(a=><div className="albumCard" key={a.key}><button onClick={()=>setSelected(selected===a.key?null:a.key)}>{a.artwork?<img src={a.artwork}/>:<div className="albumPlaceholder"><Disc3 size={38}/></div>}<b>{a.album}</b><span>{a.artist}{a.year?` · ${a.year}`:""}</span></button>{selected===a.key&&<TrackRows items={[...a.tracks]}/>}</div>)}</div>}
    {view==="artists"&&<div className="libraryGroups">{artists.map(([name,items])=><details key={name}><summary><CircleUserRound size={18}/><b>{name}</b><span>{items.length} tracks</span></summary><TrackRows items={[...items]}/></details>)}</div>}
    {view==="folders"&&<div className="libraryGroups">{folders.map(([name,items])=><details key={name}><summary><Folder size={18}/><b>{name}</b><span>{items.length} tracks</span></summary><TrackRows items={[...items]}/></details>)}</div>}
    {view==="tracks"&&<TrackRows items={[...filtered]}/>}
    </>}
  </Panel></div>;
}

function USBPanel({device,run}) {
  const [tracks,setTracks] = useState([]);
  const [rawCount,setRawCount] = useState(0);
  const [hiddenCount,setHiddenCount] = useState(0);
  const [loading,setLoading] = useState(false);
  const [error,setError] = useState("");
  const [viewMode,setViewMode] = useState("folders");
  const [folderPath,setFolderPath] = useState("");

  const cleanUsbPath = (path="") => String(path)
    .replace(/^\/media\/sda\d+\/?/i, "")
    .replace(/^\/udisk\/?/i, "")
    .replace(/^\/+/, "");
  const basename = (path="") => cleanUsbPath(path).split("/").filter(Boolean).pop() || path || "Unknown track";
  const dirname = (path="") => {
    const parts = cleanUsbPath(path).split("/").filter(Boolean);
    parts.pop();
    return parts.length ? parts.join(" / ") : "USB root";
  };
  const isMacMetadata = (path="") => basename(path).startsWith("._");
  const usbTime = (seconds=0) => {
    const n = Math.max(0, Math.floor(Number(seconds) || 0));
    const h = Math.floor(n/3600), m = Math.floor((n%3600)/60), s = n%60;
    return h > 0 ? `${String(h).padStart(2,"0")}:${String(m).padStart(2,"0")}:${String(s).padStart(2,"0")}` : `${String(m).padStart(2,"0")}:${String(s).padStart(2,"0")}`;
  };

  const refreshUsb = async () => {
    setLoading(true); setError("");
    const r = await run("getUsbSongList", {quiet:true});
    if (!r?.ok || !r?.data || typeof r.data !== "object") {
      setTracks([]); setRawCount(0); setHiddenCount(0);
      setError(r?.error || r?.raw || "USB track list is unavailable");
      setLoading(false); return;
    }
    const data = r.data;
    const decodeHexText = (value="") => {
      const raw = String(value || "").trim();
      if (!raw || !/^(?:[0-9a-fA-F]{2})+$/.test(raw)) return raw;
      try {
        const bytes = new Uint8Array(raw.match(/.{2}/g).map(x=>parseInt(x,16)));
        return new TextDecoder("utf-8",{fatal:false}).decode(bytes).replace(/\0/g,"").trim();
      } catch { return raw; }
    };
    let entries = [];
    if (deviceTypeOf(device) === DEVICE_TYPES.AIRSCOPE && Array.isArray(data.locallist || data.Locallist)) {
      const list = data.locallist || data.Locallist;
      entries = list.map((item,index) => {
        const path = decodeHexText(item?.file ?? item?.File ?? "");
        return {index, path, name:basename(path), folder:dirname(path)};
      }).filter(t=>t.path);
    } else {
      entries = Object.entries(data)
        .filter(([key,value]) => /^\d+$/.test(key) && typeof value === "string")
        .map(([key,path]) => ({index:Number(key), path, name:basename(path), folder:dirname(path)}))
        .sort((a,b)=>a.index-b.index);
    }
    const playable = entries.filter(t => !isMacMetadata(t.path));
    setRawCount(Number(data.SongAmount ?? data.num ?? data.Num) || entries.length);
    setHiddenCount(entries.length - playable.length);
    setTracks(playable);
    setLoading(false);
  };

  useEffect(()=>{ refreshUsb(); }, [device?.id]);

  const playTrack = async (track) => {
    setError("");
    if (normalizeSource(device?.source) !== "USB Disk") {
      const sw = await run("setPlayerCmd:switchmode:USB Disk", {quiet:true});
      if (!sw?.ok) { setError("Could not switch the device to USB Disk."); return; }
      await new Promise(resolve => setTimeout(resolve, 250));
    }
    // A31 local playlist uses 1-based item numbers. The UI/library keeps
    // zero-based indexes, so convert exactly once at the command boundary.
    // (playLocalList:0 is tolerated as the first item by some firmware, which
    // previously hid this off-by-one bug at the start of the list.)
    const isA31 = String(device?.hardware || "").toUpperCase() === "A31" || String(device?.project || "").toUpperCase().includes("UP2STREAM_PRO_V4");
    const deviceIndex = isA31 ? track.index + 1 : track.index;
    const r = await run(`selectUsbTracks:${deviceIndex}`, {quiet:true});
    if (!r?.ok) setError(r?.error || "Could not start this USB track.");
  };

  const normalizedFolderPath = cleanUsbPath(folderPath).replace(/\/$/, "");
  const folderEntries = useMemo(() => {
    const prefix = normalizedFolderPath ? `${normalizedFolderPath}/` : "";
    const folders = new Set();
    const files = [];
    for (const track of tracks) {
      const clean = cleanUsbPath(track.path);
      if (!clean.startsWith(prefix)) continue;
      const rest = clean.slice(prefix.length);
      if (!rest) continue;
      const slash = rest.indexOf("/");
      if (slash >= 0) folders.add(rest.slice(0, slash));
      else files.push(track);
    }
    return { folders:[...folders].sort((a,b)=>a.localeCompare(b)), files };
  }, [tracks, normalizedFolderPath]);
  const folderCrumbs = normalizedFolderPath ? normalizedFolderPath.split("/").filter(Boolean) : [];
  const goFolderUp = () => {
    if (!normalizedFolderPath) return;
    const parts = normalizedFolderPath.split("/").filter(Boolean); parts.pop();
    setFolderPath(parts.join("/"));
  };

  // A31 reports plicurr as a 1-based playlist position, while our track.index
  // is zero-based. Convert it back only for row highlighting.
  const isA31Usb = String(device?.hardware || "").toUpperCase() === "A31" || String(device?.project || "").toUpperCase().includes("UP2STREAM_PRO_V4");
  const rawCurrentId = Number(device?.track?.id);
  const currentId = isA31Usb && Number.isFinite(rawCurrentId) && rawCurrentId > 0
    ? String(rawCurrentId - 1)
    : String(device?.track?.id || "");
  const isUsb = normalizeSource(device?.source) === "USB Disk";
  const currentTitle = isUsb ? (device?.track?.title || "USB Disk") : "USB Disk is not the active source";
  const currentArtist = isUsb ? (device?.track?.artist || "") : "Select a track below to switch to USB";
  const progress = Number(device?.track?.progress) || 0;
  const total = Number(device?.track?.total) || 0;
  const progressPct = total > 0 ? Math.min(100, Math.max(0, progress/total*100)) : 0;

  return <div className="single usbPage">
    <Panel className="usbNowPanel">
      <PanelTitle title="USB Disk" sub="Browse and play tracks stored on the connected USB drive" action={<button className="ghostBtn usbRefresh" onClick={refreshUsb} disabled={loading}><RefreshCw size={15} className={loading?"spin":""}/>{loading?" Scanning…":" Refresh USB"}</button>}/>
      <div className="usbNow">
        <div className="usbDiskIcon"><HardDrive size={34}/></div>
        <div className="usbNowMeta">
          <div className="usbStatusLine"><span className={`usbDot ${(isUsb || device?.rawStatus?.USBModel==="1")?"ready":""}`}/>{isUsb?"USB active":(device?.rawStatus?.USBModel==="1"?"USB connected":"USB ready when supported")}</div>
          <strong title={currentTitle}>{currentTitle}</strong>
          <span>{currentArtist || (isUsb ? "Unknown artist" : "")}</span>
          {isUsb && device?.track?.context && <small>{dirname(device.track.context)}</small>}
        </div>
        <div className="usbTransport">
          <button title="Previous" onClick={()=>run("setPlayerCmd:prev",{quiet:true})}>‹</button>
          <button className="usbPlay" title={isPlaying(device?.track?.playState)?"Pause":"Play / Resume"} onClick={()=>run("setPlayerCmd:onepause",{quiet:true})}>{isPlaying(device?.track?.playState)?<Pause size={21}/>:<Play size={21}/>}</button>
          <button title="Next" onClick={()=>run("setPlayerCmd:next",{quiet:true})}>›</button>
        </div>
      </div>
      <div className="usbProgress"><div style={{width:`${progressPct}%`}}/></div>
      <div className="usbTime"><span>{usbTime(progress)}</span><span>{total?usbTime(total):"--:--"}</span></div>
    </Panel>

    <Panel>
      <PanelTitle title="USB Library" sub={`${tracks.length} playable track${tracks.length===1?"":"s"} · ${rawCount || tracks.length} total entries${hiddenCount?` · ${hiddenCount} hidden macOS file${hiddenCount===1?"":"s"}`:""}`}/>
      <div className="usbLibraryToolbar">
        <div className="usbViewTabs">
          <button className={viewMode==="folders"?"active":""} onClick={()=>setViewMode("folders")}><Folder size={14}/> Folders</button>
          <button className={viewMode==="all"?"active":""} onClick={()=>setViewMode("all")}><Disc3 size={14}/> All tracks</button>
        </div>
        {viewMode==="folders" && <div className="usbBreadcrumbs">
          <button disabled={!normalizedFolderPath} onClick={goFolderUp} title="Back"><ChevronLeft size={15}/></button>
          <button className={!normalizedFolderPath?"current":""} onClick={()=>setFolderPath("")}>USB</button>
          {folderCrumbs.map((part,i)=>{ const target=folderCrumbs.slice(0,i+1).join("/"); return <React.Fragment key={target}><span>/</span><button className={i===folderCrumbs.length-1?"current":""} onClick={()=>setFolderPath(target)}>{part}</button></React.Fragment>; })}
        </div>}
      </div>
      {error && <div className="usbError">{error}</div>}
      {!error && loading && !tracks.length && <div className="usbEmpty">Scanning USB drive…</div>}
      {!loading && !error && !tracks.length && <div className="usbEmpty">No playable tracks found. Insert a USB drive and press Refresh USB.</div>}
      {!!tracks.length && viewMode==="folders" && <div className="usbTrackList">
        {folderEntries.folders.map(name => {
          const target = normalizedFolderPath ? `${normalizedFolderPath}/${name}` : name;
          return <button key={`folder-${target}`} className="usbTrack usbFolder" onClick={()=>setFolderPath(target)}>
            <span className="usbTrackNo"><Folder size={16}/></span>
            <span className="usbTrackText"><b>{name}</b><small>Folder</small></span>
            <ChevronRight size={16}/>
          </button>;
        })}
        {folderEntries.files.map((track,visibleIndex) => {
          const active = isUsb && currentId === String(track.index);
          return <button key={`${track.index}-${track.path}`} className={active?"usbTrack active":"usbTrack"} onClick={()=>playTrack(track)}>
            <span className="usbTrackNo">{visibleIndex+1}</span>
            <span className="usbTrackText"><b>{track.name}</b><small>{track.folder}</small></span>
            <span className="usbTrackDeviceIndex">#{track.index}</span>
            {active && <span className="usbPlaying">PLAYING</span>}
          </button>;
        })}
        {!folderEntries.folders.length && !folderEntries.files.length && <div className="usbEmpty">This folder is empty.</div>}
      </div>}
      {!!tracks.length && viewMode==="all" && <div className="usbTrackList">
        {tracks.map((track,visibleIndex) => {
          const active = isUsb && currentId === String(track.index);
          return <button key={`${track.index}-${track.path}`} className={active?"usbTrack active":"usbTrack"} onClick={()=>playTrack(track)}>
            <span className="usbTrackNo">{visibleIndex+1}</span>
            <span className="usbTrackText"><b>{track.name}</b><small>{track.folder}</small></span>
            <span className="usbTrackDeviceIndex">#{track.index}</span>
            {active && <span className="usbPlaying">PLAYING</span>}
          </button>;
        })}
      </div>}
    </Panel>
</div>;
}
function SystemPanel({device,run,removeCurrent}){return <div className="single"><Panel><PanelTitle title="System" sub="Device information and lifecycle controls"/><div className="infoGrid"><div><span>Device name</span><b>{device.name}</b></div><div><span>Model / project</span><b>{device.model}</b></div><div><span>Firmware</span><b>{device.version}</b></div><div><span>IP</span><b>{device.tcpIp || device.ip}</b></div><div><span>EQ type</span><b>{device.eqType || "—"}</b></div><div><span>EQ enable</span><b>{device.eqEnable || "—"}</b></div></div><div className="actions"><button className="ghostBtn" onClick={()=>run("getStatusEx")}>Refresh info</button><button className="ghostBtn" onClick={()=>run("reboot")}>Reboot</button><button className="dangerBtn" onClick={()=>run("factory")}>Factory reset</button><button className="dangerBtn" onClick={()=>run("shutdown")}>Shutdown</button><button className="dangerBtn" onClick={removeCurrent}>Remove from app</button></div>{device.rawStatus&&<details className="rawDetails"><summary>Raw getStatusEx data</summary><pre className="console">{JSON.stringify(device.rawStatus,null,2)}</pre></details>}</Panel></div>}

// v4.0.1 — platform-specific desktop layout tuning.
// Keep Windows DPI/font metrics from changing the macOS layout.
if (/Windows/i.test(navigator.userAgent)) {
  document.documentElement.classList.add("platform-windows");
}

createRoot(document.getElementById("root")).render(<App />);
