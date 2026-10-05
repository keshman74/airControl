const { contextBridge, ipcRenderer } = require("electron");
contextBridge.exposeInMainWorld("airCloud", {
  request: (args) => ipcRenderer.invoke("device:request", args),
  logMultiroomDiagnostic: (payload) => ipcRenderer.send("diagnostic:multiroom", payload),
  discoverDevices: () => ipcRenderer.invoke("device:discover"),
  onDiscoveredDevice: (callback) => {
    const listener = (_event, device) => callback(device);
    ipcRenderer.on("device:discovery-device", listener);
    return () => ipcRenderer.removeListener("device:discovery-device", listener);
  },
  discoverMediaServers: () => ipcRenderer.invoke("media:discover"),
  browseMediaServer: (args) => ipcRenderer.invoke("media:browse", args),
  playDlnaTrackUpnp: (args) => ipcRenderer.invoke("media:upnpPlay", args),
  listSmbShares: (args) => ipcRenderer.invoke("smb:listShares", args),
  browseSmb: (args) => ipcRenderer.invoke("smb:browse", args),
  // v4.4.6: SMB playback is fire-and-forget. Status/results arrive on smb:play-status.
  // Do not use ipcRenderer.invoke here: a native SMB stream failure must never be able
  // to invalidate an outstanding Electron invoke reply.
  playSmbTrack: (args) => { ipcRenderer.send("smb:play", args); return Promise.resolve({ok:true,accepted:true,step:"SMB PLAY REQUESTED"}); },
  onSmbPlaybackStatus: (callback) => {
    const listener = (_event, status) => callback(status);
    ipcRenderer.on("smb:play-status", listener);
    return () => ipcRenderer.removeListener("smb:play-status", listener);
  },
  debugSsdp: () => ipcRenderer.invoke("discovery:ssdpDebug"),
  probeLinkplay: (args) => ipcRenderer.invoke("linkplay:probe", args),
  autoProbeLinkplay: (args) => ipcRenderer.invoke("linkplay:autoProbe", args),
  getLinkplayUpnpMetadata: (args) => ipcRenderer.invoke("linkplay:upnpPositionInfo", args),
  resolveArtworkUrl: (args) => ipcRenderer.invoke("artwork:resolve", args),
  linkplayMcuRequest: (args) => ipcRenderer.invoke("linkplay:mcuRequest", args),
  onLinkplayMcuEvent: (callback) => {
    const listener = (_event, data) => callback(data);
    ipcRenderer.on("linkplay:mcuEvent", listener);
    return () => ipcRenderer.removeListener("linkplay:mcuEvent", listener);
  },
  getTestAudioInfo: (deviceIp) => ipcRenderer.invoke("test-audio:info", deviceIp),
  requestMicrophonePermission: () => ipcRenderer.invoke("microphone:permission"),
  chooseMusicFolder: () => ipcRenderer.invoke("library:chooseFolder"),
  scanMusicFolder: (root) => ipcRenderer.invoke("library:scan", root),
  getLocalMediaUrl: (args) => ipcRenderer.invoke("library:mediaUrl", args),
  playLocalTrackUpnp: (args) => ipcRenderer.invoke("library:upnpPlay", args),
  playRadioStationUpnp: (args) => ipcRenderer.invoke("radio:upnpPlay", args),
  playRadioStationA33: (args) => ipcRenderer.invoke("radio:a33NativePlay", args),
  qobuzConnect: () => ipcRenderer.invoke("qobuz:connect"),
  qobuzImportSession: () => ipcRenderer.invoke("qobuz:importSession"),
  qobuzProfile: (args) => ipcRenderer.invoke("qobuz:profile", args),
  qobuzFavorites: (args) => ipcRenderer.invoke("qobuz:favorites", args),
  qobuzPlaylists: (args) => ipcRenderer.invoke("qobuz:playlists", args),
  qobuzPlaylist: (args) => ipcRenderer.invoke("qobuz:playlist", args),
  qobuzSearch: (args) => ipcRenderer.invoke("qobuz:search", args),
  qobuzAlbum: (args) => ipcRenderer.invoke("qobuz:album", args),
  qobuzPlay: (args) => ipcRenderer.invoke("qobuz:play", args),
  getStreamCapabilities: (args) => ipcRenderer.invoke("linkplay:streamCapabilities", args)
});
