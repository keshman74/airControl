# iOS feature behavior to Android logic map

This map separates what belongs to presentation from the operation that must be ported. File names refer to the checked-in `../ios-native/` snapshot.

| Feature | iOS source to inspect | Android behavior contract | Portable evidence / implementation source |
|---|---|---|---|
| Device discovery and selection | `LPMusicKitDemo/LPDeviceListViewController.m`, `LPDeviceListTableViewCell.m`, `ACHome.m` | Discover, deduplicate, refresh, retain selection by stable device identity, recover after app resume/Wi-Fi changes | Linkplay discovery capability; Android network/discovery implementation still required |
| Device status and inputs | `ACHome.m`, device settings controllers | Read status/capabilities and show only inputs actually announced by the device; issue source change to selected device | HTTPAPI status plus per-device capability evidence in Protocol KB |
| Transport and volume | `LPPlayview/LPPlayViewController.m`, `LPPlayer/LPPlayerViewController.m`, `ACHome.m` | Play/pause/previous/next/seek/volume; refresh state and prevent stale UI after source or room changes | `../src/linkplay.js` has shared HTTP/UPnP transport helpers; validate command variants on hardware |
| Queue / active item | `ACHome.m`, SDK queue calls | Read queue for current source, normalize item metadata, highlight active item from source-appropriate index | `BrowseQueue` and `LastPlayIndex` evidence in KB; shared parser in `../src/linkplay.js` |
| USB folders and playback | `LPUSB/LPUSBViewController.m`, `ACHome.m` | Browse folders recursively, back navigation, launch selected item, keep selection synced with transport | `BrowseQueue`/USB queue evidence; validate index base and malformed DIDL behavior per device |
| Multiroom | `LPMultiroom/LPMultiroomViewController.m`, `ACHome.m` | Explicit master, join/leave members, separate group and per-room volume, never invert master/member | SDK behavior in native source; Android equivalent must respect selected master UUID and device response |
| Deezer login/catalog/playback | `ACHome.m`; supporting analysis docs at repo root | Register/login against selected device, verify session, browse/search library, launch a queue on that device, handle A31/A98 service difference | `../src/deezer.js`, `../src/linkplay.js`, `A31-KNX-DEEZER.md`, `AUDIO-PRO-LEGACY-DEEZER-ANALYSIS.md`, and hardware KB; credentials stay transient |
| Qobuz | `ACHome.m` and SDK headers in `../ios-native/LPMusicKitDemo/Framework` | Use device-reported OAuth profile/redirect settings; process consent/callback; retrieve library/catalog and launch on selected zone | `WIIM-SERVICE-PLAYBACK.md`, `APP-MOBILE-SERVICE-COMPARISON.md`, KB; do not synthesize absent client ID or redirect URI |
| TuneIn / Radio Browser | `ACHome.m` | Preserve category path while drilling into countries/genres; render station rows; play selected station on selected room | Existing React service research, catalog APIs, and device command behavior; validate on device |
| Presets | `ACHome.m`, `PresetViewController` | Read all slots, show empty slots explicitly, activate/delete and refresh after device switch | SDK operation in native source; map actual protocol/capability before Android coding |
| EQ / device settings | `ACHome.m`, SDK headers | Read current settings and expose only supported chip-specific bands/commands | SDK has iOS API; Android requires matching authorized SDK or a verified wire command |
| Alarm / sleep timer | `ACHome.m`, alarm controller files | Persist schedule/music/volume/duration per device and report command result | SDK/API source plus real-device verification; do not assume platform-local timer equals speaker alarm |

## Device and session invariants

1. Every async browse/play/settings response is tagged with the device identity and navigation request that initiated it; discard stale responses after switching rooms.
2. Keep credentials out of analytics, logs, crash reports, and repository data. Store tokens only in platform secure storage if the provider flow returns a token.
3. Device-reported support and service profile outrank assumptions based on chip label alone.
4. Distinguish app-account authentication, speaker-side service registration, catalog access, and playback. Success at one step does not imply the next step succeeded.
5. Preserve unknown protocol fields in diagnostics with secrets redacted, to help extend support without breaking known devices.
