# WiiM Home APK Protocol Research

> airControl protocol research notebook.
>
> Scope: findings recovered from decompiled WiiM Home APK plus hardware-verified behavior on Linkplay/WiiM devices used during airControl development.
>
> Status labels:
> - **Hardware verified** — confirmed against a real device.
> - **APK verified** — confirmed in decompiled WiiM Home code.
> - **Inference** — supported by code/behavior but not yet proven end-to-end on hardware.

## 1. Device capability discovery

### StreamServicesCapability
**APK verified**

WiiM Home queries a custom UPnP action named `StreamServicesCapability`.

Recovered call construction:

- Service selected by WiiM Home: UPnP `RenderingControl`
- Action: `StreamServicesCapability`
- `InstanceID = 0`
- `AppVersion = BuildConfig.VERSION_NAME`
- In this decompiled dependency, `BuildConfig.VERSION_NAME = "1.0"`
- Response field: `StreamCapability`

Recovered code path:

`zv9.m(device, retries, callback)`
→ `n42.f1.c(device)`
→ RenderingControl service
→ `b1b`
→ `StreamServicesCapability`
→ `StreamCapability`

WiiM Home retries the request when the service is unavailable or the invocation fails.

### RenderingControl discovery
**APK verified**

`n42.f1.c(device)` returns the UPnP `RenderingControl` service.

Related helper mapping found in `n42.f1`:

- `a(device)` → AVTransport
- `b(device)` → `urn:wiimu-com:serviceId:PlayQueue`
- `c(device)` → RenderingControl

### Hardware endpoints
**Hardware verified**

All three tested devices exposed:

- RenderingControl service type: `urn:schemas-upnp-org:service:RenderingControl:1`
- RenderingControl control URL: `/upnp/control/rendercontrol1`
- PlayQueue service ID: `urn:wiimu-com:serviceId:PlayQueue`
- PlayQueue control URL: `/upnp/control/PlayQueue1`

The endpoint is discovered from each device description and should not be hardcoded in airControl.

## 2. Hardware capability matrix

### A31 — 192.168.0.101
**Hardware verified**

`StreamCapability.version = 1.0`

Advertised services:

- Prime 1.1
- Tidal 2.1
- newTuneIn 1.1
- Rhapsody 1.0
- Deezer 1.1
- Qobuz 1.2
- iHeartRadio 1.0
- vTuner 1.1

Not advertised in the tested response:

- Samba
- Plex
- SpotifyConnect
- TidalConnect
- QobuzConnect
- Roon
- Squeezelite
- YouTubeMusic

### A97 — 192.168.0.106
**Hardware verified**

`StreamCapability.version = 1.2`

Advertised services:

- Prime 1.4, quality: SD
- Tidal 2.2, quality: LOW / HIGH / LOSSLESS
- newTuneIn 1.1
- Rhapsody 1.0
- soundmachine 1.1
- Deezer 1.1
- Qobuz 1.6, quality: 5 / 6 / 7 / 27
- iHeartRadio 1.0
- Pandora 1.0
- vTuner 1.1
- CalmRadio 1.1, quality: 64 / 128 / 192 / 320
- SoundCloud 1.0

Not advertised:

- Samba

### A98 — 192.168.0.107
**Hardware verified**

`StreamCapability.version = 1.6`

Advertised services include:

- Prime 1.4, SD / HD / UHD
- Tidal 2.3, LOW / HIGH / LOSSLESS / HI_RES, ReplayGain
- newTuneIn 1.2
- Rhapsody 1.1
- SoundMachine 1.2
- Deezer2 1.1, LOW / MEDIUM / HIGH / LOSSLESS
- Qobuz 2.2, quality 5 / 6 / 7 / 27, ReplayGain
- iHeartRadio 1.0
- iHeart 1.0
- Pandora2 1.1
- vTuner 1.1
- CalmRadio 1.1
- SoundCloud 1.3
- Plex 1.4, ReplayGain
- KKBOX 1.0
- RadioParadise2 1.0
- HotMix 1.0
- WiiMRadio 1.0
- SpotifyConnect 1.3, configurable=true, active=true
- TidalConnect 1.0, configurable=true, active=true
- AVS_MRM 1.0
- Squeezelite 1.2
- Roon 1.0
- Soundtrack 1.0
- QobuzConnect 1.0
- AudioCast 1.0
- Samba 1.0
- YouTubeMusic 1.0, brand=WiiM, model=Pro

### Architecture rule for airControl
**Hardware + APK verified**

Do not enable services solely from a hardware-family label such as A31/A97/A98.

Preferred flow:

`discover device`
→ `discover UPnP services`
→ query `StreamServicesCapability`
→ build feature/UI availability from the returned capabilities.

This is especially important for Samba and newer online/connect services.

## 3. Qobuz capability negotiation

### Qobuz version is device-dependent
**APK verified + Hardware verified**

WiiM Home reads Qobuz service version from the selected device:

`getStreamServiceVersion(StreamServicesCapability.StreamServices.QOBUZ)`

and stores it in `QobuzUserInfo.sourceVersion`.

It also stores:

- overall StreamCapability version
- Qobuz ReplayGain support

Real tested values:

- A31 → Qobuz 1.2
- A97 → Qobuz 1.6
- A98 → Qobuz 2.2

### Feature gates found in WiiM Home
**APK verified**

Recovered Qobuz feature thresholds:

- Qobuz >= 1.5 → Play Next
- Qobuz >= 1.6 and StreamCapability >= 1.2 → Play Last
- Qobuz >= 1.8 → new OAuth login flow
- Qobuz >= 1.9 → new Artist behavior
- Qobuz >= 2.0 plus device flag → ReplayGain
- Qobuz >= 2.1 → Weekly Queue
- Qobuz >= 2.2 → Qobuz Radio

Current interpretation: Qobuz service version is at least a feature-negotiation mechanism. It has not yet been proven that each version uses a completely different wire transport.

## 4. Qobuz URL and item model

### Qobuz API URL builder
**APK verified**

`ec9` contains Qobuz API URL construction.

Recovered examples:

- Artist: `/artist/page?artist_id=<id>`
- Album: `/album/get?album_id=<id>&offset=<n>&limit=50`
- Playlist: `/playlist/get?playlist_id=<id>&extra=tracks&offset=<n>&limit=50`
- Artist Radio: `/radio/artist?artist_id=<id>`
- Album Radio: `/radio/album?album_id=<id>`
- Track Radio: `/radio/track?track_id=<id>`

Search routes use categories such as playlist / album / artist / track / catalog.

### QobuzPlayItem
**APK verified**

`QobuzPlayItem` inherits from `LPPlayItem`.

Important finding:

The Qobuz `trackUrl` used in this path behaves as API/search/context data, not as a proven direct audio-stream URL.

The app also passes the real Qobuz track identifier separately.

## 5. Qobuz playback chain

### High-level chain
**APK verified**

Recovered program chain:

`Qobuz API`
→ `QobuzPlayItem`
→ `LPPlayMusicList`
→ `LPMSPlayData`
→ `wp6.F()`
→ `eh6.d()`
→ `LPPlayMediaData`
→ `n42.m0()`
→ device network playback

### LPMSPlayData construction
**APK verified**

For a selected Qobuz item, WiiM Home:

- stores the real Qobuz track ID in `playItemId`
- keeps Qobuz search/context information in the Qobuz header
- stores the generated `LPPlayMusicList` in `LPMSPlayData.playData`
- sends this through the common playback pipeline

For ordinary album/playlist playback, `searchUrl` is retained.

For special contexts such as Search / Artist Radio / Track Radio, the app may intentionally clear or rebuild the search context.

### Important conclusion
**APK verified / wire format still under investigation**

Qobuz playback is not modeled as simply:

`direct FLAC URL → renderer`

Instead the recovered application model carries:

- Qobuz track ID
- Qobuz service/search context
- playlist/queue data
- service capability/version context

The final exact PlayQueue payload is the current active research point.

## 6. PlayQueue service

### Service
**APK verified + Hardware verified**

Service ID:

`urn:wiimu-com:serviceId:PlayQueue`

Hardware control URL on tested devices:

`/upnp/control/PlayQueue1`

### Actions found in APK
**APK verified**

Recovered PlayQueue actions include:

- `CreateQueue`
- `ReplaceQueue`
- `AppendTracksInQueue`
- `AppendTracksInQueueEx`
- `PlayQueueWithIndex`
- `BrowseQueue`
- `DeleteQueue`

Recovered argument examples:

#### CreateQueue
`CreateQueue`
- `QueueContext`

#### PlayQueueWithIndex
`PlayQueueWithIndex`
- `QueueName`
- `Index`

#### BrowseQueue
`BrowseQueue`
- `QueueName`
- returns `QueueContext`

The exact Qobuz `QueueContext` XML/body passed through `n42.m0()` is the next item to finish decoding.

## 7. Shared playback architecture

### Local playback
**Previously hardware verified**

For local files served by airControl during testing, the renderer can fetch an HTTP URL hosted by the controller machine.

Example previously verified on A31:

`http://<controller-ip>:<port>/test.mp3`

This is distinct from Qobuz service playback.

### SMB
**APK verified + capability hardware verified**

WiiM Home contains an SMB subsystem and SMB playback item classes.

However, SMB must be gated by device capability:

- tested A98 advertises `Samba 1.0`
- tested A97 does not advertise Samba
- tested A31 does not advertise Samba

Presence of SMB code in WiiM Home does not imply that every Linkplay device supports native SMB playback.

## 8. Other recovered command families

### Linkplay HTTP command builder
**APK verified**

The decompiled app contains builders for classic Linkplay HTTP commands such as:

- `getStatusEx`
- multiroom commands
- Bluetooth discovery
- system/device commands

These coexist with UPnP AVTransport / RenderingControl / PlayQueue.

### AVTransport
**APK verified**

WiiM Home uses normal UPnP AVTransport callbacks for:

- Play
- Pause
- Previous
- Next
- Seek
- GetMediaInfo
- GetInfoEx

So the architecture is multi-protocol rather than a single HTTP API.

## 9. Research rules for airControl

1. Distinguish **APK verified** from **hardware verified**.
2. Never assume all Linkplay generations expose identical features.
3. Prefer runtime capability detection over fixed chip-family assumptions.
4. Preserve exact service/action/argument names recovered from the APK.
5. Document every hardware-confirmed request/response pair.
6. Do not treat a Qobuz catalog/search URL as a proven media stream URL.
7. Keep the A33 TCP/native protocol research separate from WiiM/Linkplay UPnP PlayQueue unless a bridge is explicitly proven.
8. Every newly confirmed command or function should be added to this document.

## 10. Current active research point

Decode the final implementation of:

`n42.m0(LPPlayMediaData, callback)`

and its immediate calls into `np8` / PlayQueue helpers.

Goal:

- identify the exact PlayQueue action used for Qobuz start
- capture exact `QueueContext` / XML payload structure
- identify fields for Qobuz ID, source, search URL, metadata, index and queue name
- determine whether Qobuz 1.2 / 1.6 / 2.2 alters wire payload or only feature behavior
- reproduce the command against A31 first, then compare A97/A98

---

Last major update: 2026-10-02.
