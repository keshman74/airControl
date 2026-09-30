# airCloudCTRL v0.2 — Real Device Integration

Desktop control application for Cloudyx A33 / compatible CS-series audio devices.

## What changed in v0.2

- Real A33 status polling via `getStatusEx` every 2 seconds.
- Real Online / Offline state.
- Parses actual device fields observed on CS-8 Audio firmware, including `DevName`, `UserDevName`, `VERSION`, `DevVolumeL`, `DevVolumeMax`, `VolumeState`, `TCPIP`, `NetworkMode`, `DevFunction`, `DevMode`, `StreamSource`, `MultiroomStatus`, `Host`, `EqType`, `EqEnable`, and `AltMate` metadata.
- Now Playing uses `AltMate.TrackTitle`, `TrackArtist`, `TrackAlbum`, `TrackImage`, `Progress` and `TotalTime` when available.
- Live Play/Pause, Previous, Next, Volume, Mute, Source and Seek commands.
- Per-device HTTP/HTTPS + port settings (no longer reuses the Add Device dialog settings).
- Device list is persisted in localStorage.
- DevTools no longer opens automatically.
- Default first device is configured for the current test unit at `http://192.168.0.12:8000`.

## Run

```bash
npm install
npm run dev
```

## Notes

- The app currently uses the A33 HTTP/HTTPS API directly from Electron's main process, so browser CORS does not block local device requests.
- HTTPS requests accept self-signed local certificates.
- EQ, Multiroom, USB and network configuration screens are still being expanded; Installer Mode exposes the raw API console for testing exact device responses.
