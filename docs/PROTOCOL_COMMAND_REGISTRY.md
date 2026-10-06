# airControl — Protocol & Command Registry

**Project:** airControl  
**Repository:** keshman74/airControl  
**Registry date:** 2026-10-06  
**Purpose:** one canonical, searchable registry of commands and protocol behavior discovered during airControl reverse engineering.

> Evidence labels used throughout:
> - **HW VERIFIED** — tested on a real device.
> - **SOURCE VERIFIED** — confirmed in decompiled native-app/device source or supplied API documentation.
> - **OBSERVED** — captured on the network or returned by the device.
> - **UNVERIFIED** — discovered/expected but not yet hardware-tested.
>
> Do not promote SOURCE VERIFIED/OBSERVED to HW VERIFIED without a real-device test.
> Do not mix CLOUDYX A33/iAudioCloud with Linkplay/WiiM devices: they are different protocol families.

---

# 1. Platform / chip matrix

| Chip / family | Native ecosystem | Tested examples | Main protocols found |
|---|---|---|---|
| A28 | Linkplay / WiiM Home compatible | support family identified; individual command coverage not fully re-verified | **HTTP** Linkplay control, UPnP/Linkplay services |
| A31 | Linkplay / WiiM Home compatible | A31 | **HTTP** Linkplay control, UPnP/SOAP, USB, network settings, local HTTP playback |
| A97 (ALLWINNER-R328) | Linkplay / WiiM Home compatible | Kitchen, Patio; A97 (ALLWINNER-R328) platform identified as **ALLWINNER-R328** | **HTTPS** Linkplay control, UPnP; runtime capability differs by firmware; no physical USB on user's unit |
| A98 / AmlogicA113 | Linkplay / WiiM Home compatible | Living room; device identifies platform as **AmlogicA113** | **HTTPS** Linkplay control, UPnP; no physical USB on user's unit |
| A33 | **CLOUDYX / iAudioCloud** | CL-BOX Pro 6F72 | UDP discovery :53308, native binary TCP :23040, JSON TCP :1234, ACS2 HTTP/HTTPS, gmrender/DLNA |

---

# 2. Linkplay family — A28 / A31 / R328 / A97 (ALLWINNER-R328) / A98 (AmlogicA113)

## 2.1 Linkplay HTTP / HTTPS command channel

**Transport rule confirmed for the project's tested chip families:**

- **A28 / A31 → HTTP** control.
- **A97 (ALLWINNER-R328) / A98 (AmlogicA113) (AmlogicA113) → HTTPS** control.

Do not assume one transport for all Linkplay generations. Select HTTP vs HTTPS from the device/chip family (and preserve runtime discovery/capability checks where available).

Typical HTTP form used during A28/A31-style testing:

```text
http://DEVICE_IP/httpapi.asp?command=COMMAND
```

Exact transport availability must be detected per device/firmware.

### Player control

| Function | Command / form | Evidence |
|---|---|---|
| Set volume | `setPlayerCmd:vol:N` | **HW VERIFIED A31** — e.g. vol:15 |
| Mute ON | `setPlayerCmd:mute:1` | **HW VERIFIED A31** |
| Mute OFF | `setPlayerCmd:mute:0` | **HW VERIFIED A31** |
| Volume up | `setPlayerCmd:RemoteVol++` | used by airControl; hardware support depends on device |
| Play URL | `setPlayerCmd:play:http://HOST/path.mp3` | **HW VERIFIED A31** |
| Player status | `getPlayerStatus` | **HW VERIFIED A31** |
| Extended status | `getStatusEx` | **HW VERIFIED A31** |

### Source selection / device mode

Observed source names include:

```text
Network
AUX In
Bluetooth
USB Disk
```

| Function | Result | Evidence |
|---|---|---|
| Select AUX In | source switch using exact `AUX In` model string | **HW VERIFIED** |
| Select USB Disk | source switch using exact `USB Disk` model string | **HW VERIFIED** |
| `LineIn` as alias for AUX | did not activate AUX in the tested case | **HW VERIFIED negative result** |

Do not normalize source names blindly; use `DevFunction` / runtime capability data.

### EQ

| Function | Command / value | Evidence |
|---|---|---|
| EQ type | `getEqType` | **HW VERIFIED**; example result `0111` |
| EQ information | `getEqInfo:1`, `getEqInfo:2` | **HW VERIFIED** |
| EQ enable/type state | `eqEnable` values observed including `0010`, `0001` | **HW VERIFIED** |

Observed EQ data included Bass -2 / Treble +3 and Flat profile during tests.

### Network configuration

| Function | Command | Evidence |
|---|---|---|
| Read static/DHCP state | `getStaticIP` | **HW VERIFIED A31** |
| Wi-Fi DHCP | `setDhcp:wifi` | **HW VERIFIED A31** |
| Wi-Fi static address | `setStaticIP` with Wi-Fi JSON payload | **HW VERIFIED A31** |

Observed `getStaticIP` interpretation:
- `wifi=0` → Static
- `wifi=1` → DHCP
- `eth=-1` observed on test device

### USB

USB browsing/playback was confirmed on A31/A33-class project hardware where a physical USB interface exists.  
**A97 (ALLWINNER-R328) / A98 (AmlogicA113) test units have no physical USB port**, so USB must not be advertised solely from chip-family assumptions.

---

## 2.2 Linkplay UPnP / SOAP

A31 test renderer exposed a transport control URL at:

```text
:49152/rendertransport1
```

| Action | Evidence |
|---|---|
| `GetPositionInfo` | **HW VERIFIED A31** |
| network/local media transport | **HW VERIFIED** in project tests |

The implementation must discover/parse actual service URLs rather than assume every model has identical endpoints.

---

## 2.3 Linkplay PlayQueue / WiiM Home reverse engineering

Confirmed from WiiM Home decompilation and device SCPD:

```text
CreateQueue
BrowseQueue
PlayQueueWithIndex
UserLogin
```

Important findings:

- `CreateQueue` accepts one QueueContext.
- QueueContext XML contains `<PlayList><ListName>...`.
- Entries carry Source / Id / URL / Metadata.
- `PlayQueueWithIndex` uses queue name plus index.
- Qobuz context title flows into queue/head title.
- SMB playback in WiiM Home is built from direct `smb://...` resource URLs through PlayQueue; no evidence was found that the phone proxies the SMB audio stream.
- Runtime Samba capability must be checked. UI text such as `SMB (1)` can mean one discovered SMB server and **does not prove native Samba capability**.

### Qobuz capability thresholds recovered from WiiM Home

| Capability | Minimum observed Qobuz capability |
|---|---:|
| PlayNext | 1.5 |
| PlayLast (also requires StreamCapability >= 1.2) | 1.6 |
| OAuth | 1.8 |
| new artist behavior | 1.9 |
| replayGain | 2.0 |
| Weekly Queue | 2.1 |
| Qobuz Radio | 2.2 |

### Tested Linkplay capability matrix

| Device | Firmware | StreamCapability | Qobuz |
|---|---|---:|---:|
| A31 | test firmware varies | 1.0 | 1.2 |
| R328 Kitchen | Linkplay.4.6.437434 | 1.1 | 1.4 |
| R328 Patio | Linkplay.4.6.529755 | 1.2 | 1.6 |
| A98 Living room | Linkplay.4.8.827634 | 1.6 | 2.2 |

**Conclusion:** chip model alone is insufficient. airControl should gate features using runtime capabilities and firmware.

---

# 3. CLOUDYX A33 / iAudioCloud

Test device:

```text
CL-BOX Pro 6F72
IP during current tests: 192.168.0.105
VERSION: 2.35.0023.33
ProjectName: CL-BOPro
ProjectType: EC04
TCP native port: 23040
```

Device Info also reported:

```text
DevFunction:
Network
AUX In
Bluetooth
USB Disk
HDMI ARC

EqType: 0111
EqEnable: 0101
DevVolumeMax: 100
```

---

# 4. A33 UDP discovery — port 53308

iAudioCloud listens for temporary-device discovery messages on UDP **53308**.

Live A33 broadcast observed:

```json
{"product_type":"EC04","net":"lan","host":"192.168.0.105","port":"16800","eth0_mac":"40:D9:5A:C2:6F:71","wlan0_mac":"40:D9:5A:C2:6F:72"}
```

Native port decoding recovered from iAudioCloud source:

```text
realPort = Integer.decode("0x" + port) >> 2
0x16800 = 92160
92160 >> 2 = 23040
```

**Status: SOURCE VERIFIED + HW VERIFIED.**

Fallback `DevicesInteracter.PORT_TCP_DEVICE = 58803` exists in source, but it is a fallback and is **not** the live port used by this A33.

---

# 5. A33 native binary TCP — port 23040

## 5.1 Packet framing

Recovered from `DeviceModel.makeSendParams()`:

```text
A3 BF | SEQ | LEN_LO LEN_HI | CMD_LO CMD_HI | DATA | FB
```

- `SEQ`: iAudioCloud increments a byte sequence number.
- `LEN`: UTF-8 DATA length, little-endian.
- `CMD`: two-byte command ID.
- DATA may be raw string or serialized JSON depending on the call.
- terminator: `FB`.

**SOURCE VERIFIED.**

Multiple Seek packets in one persistent TCP connection were **HW VERIFIED**.

---

## 5.2 A33 Device Info

```text
CMD 00 00
DATA = empty string
```

Example request, SEQ=00:

```text
A3 BF 00 00 00 00 00 FB
```

**SOURCE VERIFIED + HW VERIFIED.**

The real device returned a large JSON DeviceModel including VERSION, source capabilities, EQ, TCP port, volume, playback/service state, etc.

Current device reported:

```text
VERSION = 2.35.0023.33
TCPport = 23040
DevVolume = 5 (at capture time)
DevVolumeMax = 100
VolumeState = active
DevVolumeChannel = stereo
```

Sensitive service tokens returned inside Device Info must never be committed to this registry.

---

## 5.3 A33 transport commands

### Play / Pause

```text
CMD 00 32
PLAY DATA  = plays
PAUSE DATA = pause
```

Source path:

```text
PlaybackControlAgreement.sendPlay()
→ DeviceModel.makeSendParams(COMMAND_ID_PLAY_PAUSE, ...)
→ SocketUtils.sendSocketData(...)
```

**SOURCE VERIFIED.**

### Next / Previous

```text
CMD 00 33
```

Payload before JSON serialization:

Next:
```json
{"index":"+1","SongPlay":"null"}
```

Previous:
```json
{"index":"-1","SongPlay":"null"}
```

`"null"` is a literal string, not JSON null.

**SOURCE VERIFIED.**  
Do not rely on JSON key ordering because source builds a HashMap.

### Seek

```text
CMD 00 34
DATA = ASCII decimal target position in seconds
```

Examples actually tested:

```text
A3 BF 00 02 00 00 34 36 30 FB  → about 60 s
A3 BF 01 02 00 00 34 33 30 FB  → about 30 s
```

**SOURCE VERIFIED + HW VERIFIED.**

Also **HW VERIFIED:** two Seek commands sent sequentially through the same TCP connection moved first to ~60 s and then ~30 s.

> Historical note: an older recovery document described Seek as ASCII `"4"+seconds`. Later iAudioCloud decompilation plus direct hardware tests corrected this. The canonical format is **CMD 00 34 + ASCII seconds**.

---

## 5.4 Native TCP :23040 — additional live traffic observed 2026-10-06

A live tcpdump between the desktop controller and A33 at `192.168.0.31` confirmed that the native `:23040` connection is bidirectional and carries unsolicited device-state updates in addition to request/reply traffic.

**OBSERVED on A33 firmware 2.35.0023.33:**

- the controller sends short 8-byte native frames and the device acknowledges applicable requests with ASCII `OK`;
- device-originated state includes JSON objects such as `{"DevVolume":"34"}`;
- mute state is pushed as `{"VolumeState":"unmute"}` (and the same field is used for mute state);
- playback-state traffic includes `plays`;
- current-media traffic includes `MusicData` and service-specific metadata, including Qobuz track identity/artwork information;
- device capability/state traffic reported a `MusicSupportList` whose `Preset` services included `TIDAL`, `TuneIn`, `Qobuz`, `vTuner`, and `OpenNetworkStream`.

This capture proves that A33 has a native preset-capability model, but it does **not** yet identify the exact native command/payload that recalls preset slots 1…10. Do not map the Linkplay `MCU+KEY+001..010` preset protocol onto A33.

The capture also confirms that `:23040` should be treated as a persistent bidirectional state/control channel. Unsolicited volume, mute, playback and media updates can be used for feedback/reconciliation instead of polling the same state continuously.

**Evidence:** OBSERVED from live network capture; exact command-to-response correlation for the unidentified 8-byte requests remains under investigation.

---

# 6. A33 native volume / mute

iAudioCloud selects old/new volume protocol from the second dot-separated VERSION component:

```text
if VERSION component[1] >= 33 → new protocol
else                           → old protocol
```

Real A33:

```text
VERSION 2.35.0023.33
second component = 35
35 >= 33
→ NEW volume protocol
```

## 6.1 New Volume

```text
CMD 00 47
DATA JSON: {"DevVolume":"N"}
```

Example tested:

```json
{"DevVolume":"10"}
```

Result: physical volume became 10.

**SOURCE VERIFIED + HW VERIFIED on A33 2.35.0023.33.**

## 6.2 New Mute

```text
CMD 00 48
Mute:   {"VolumeState":"mute"}
Unmute: {"VolumeState":"unmute"}
```

Results:
- Mute → physical sound disappeared.
- Unmute → physical sound returned.

**SOURCE VERIFIED + HW VERIFIED on A33 2.35.0023.33.**

## 6.3 Old Volume/Mute path

For VERSION second component < 33:

```text
CMD 00 40
```

Old volume payload:

```json
{
  "VolumeState":"null",
  "DevVolumeL":"...",
  "DevVolumeR":"..."
}
```

Old mute uses `VolumeState:"mute"` or `"active"` plus current L/R volume.

**SOURCE VERIFIED; not promoted here to current-A33 HW VERIFIED.**

---

# 7. A33 native command-ID catalogue recovered from iAudioCloud

The following IDs are source discoveries. Hardware status varies.

| Command | ID | Status / notes |
|---|---|---|
| DEVICE_INFO | 00 00 | **HW VERIFIED** |
| RENAME | 00 01 | SOURCE VERIFIED |
| RESET_FACTORY | 00 02 | SOURCE VERIFIED; destructive — do not test casually |
| REBOOT | 00 03 | SOURCE VERIFIED |
| STANDBY | 00 04 | SOURCE VERIFIED |
| HEARTBEAT | 00 05 | SOURCE VERIFIED |
| CHANGE_MODE_DEVICE_SET | 00 06 | SOURCE VERIFIED |
| CHANGE_MODE_DEVICE_GET | 00 07 | SOURCE VERIFIED |
| BLE_CONFIG_NETWORK | 00 08 | SOURCE VERIFIED |
| BATTERY_INFO | 00 09 | SOURCE VERIFIED |
| PLAY_MODE_SET | 00 10 | SOURCE VERIFIED |
| PLAY_MODE_GET | 00 11 | SOURCE VERIFIED |
| TIDAL_SONGS | 00 20 | SOURCE VERIFIED |
| UPDATE_TOKEN | 00 21 | SOURCE VERIFIED |
| SONGLIST_UPDATE | 00 22 | SOURCE VERIFIED |
| MSG_ERROR | 00 30 | SOURCE VERIFIED |
| PROGRESS_DURATION | 00 31 | SOURCE VERIFIED |
| PLAY_PAUSE | 00 32 | SOURCE VERIFIED |
| LAST_NEXT | 00 33 | SOURCE VERIFIED |
| SET_PROGRESS | 00 34 | **HW VERIFIED** |
| CHANGE_SONGS_ID | 00 35 | SOURCE VERIFIED |
| PLAY_STATUS | 00 36 | SOURCE VERIFIED |
| VOLUME (old) | 00 40 | SOURCE VERIFIED |
| MAX_VOLUME | 00 42 | SOURCE VERIFIED |
| VOLUME_CHANGE (new) | 00 47 | **HW VERIFIED current A33** |
| VOLUME_MUTE (new) | 00 48 | **HW VERIFIED current A33** |
| VOLUME_CHANNEL | 00 49 | SOURCE VERIFIED |
| MULTI_ROOM_OPEN | 00 50 | SOURCE VERIFIED |
| MULTI_ROOM_EXIT | 00 51 | SOURCE VERIFIED |
| MULTI_ROOM_STATUS | 00 52 | SOURCE VERIFIED |
| RADIO | 00 60 | SOURCE VERIFIED |
| RADIO_PLAY_STATUS | 00 61 | SOURCE VERIFIED |
| USB_SONG_LIST | 00 80 | SOURCE VERIFIED |
| USB_SONG | 00 81 | SOURCE VERIFIED |
| USB_PLAY | 00 82 | SOURCE VERIFIED |
| USB_SONG_CHANGE | 00 83 | SOURCE VERIFIED |
| USB_SONG_LIST_GET | 00 84 | SOURCE VERIFIED |
| USB_SONG_GET | 00 85 | SOURCE VERIFIED |
| USB_END | 00 86 | SOURCE VERIFIED |
| USB_PLAY_MODE_SET | 00 87 | SOURCE VERIFIED |
| USB_MOUNT | 00 88 | SOURCE VERIFIED |
| USB_PORT | 00 89 | SOURCE VERIFIED |
| LOCAL_PLAY | 00 90 | SOURCE VERIFIED |
| LOCAL_PROGRESS | 00 91 | SOURCE VERIFIED |
| LOCAL_INFO | 00 92 | SOURCE VERIFIED |
| DLNA_SONG_INFO | 01 00 | SOURCE VERIFIED |
| DLNA_SONG_GET | 01 01 | SOURCE VERIFIED |
| AIRPLAY_META | 01 20 | SOURCE VERIFIED |
| AIRPLAY_META_GET | 01 21 | SOURCE VERIFIED |
| AIRPLAY_SONG_NAME | 01 22 | SOURCE VERIFIED |
| AIRPLAY_SONG_IMG | 01 24 | SOURCE VERIFIED |
| AIRPLAY_MAC_CONNECT | 01 26 | SOURCE VERIFIED |
| AIRPLAY_MAC_BREAK | 01 27 | SOURCE VERIFIED |
| AIRPLAY_PROGRESS | 01 28 | SOURCE VERIFIED |
| AIRPLAY_TOTAL_TIME | 01 29 | SOURCE VERIFIED |
| HTTP_URL_INFO | 01 30 | SOURCE VERIFIED |
| HTTP_URL_SEND | 01 31 | SOURCE VERIFIED |
| QOBUZ_SONGS | 01 40 | SOURCE VERIFIED |
| OTA_NOTIFY | 01 50 | SOURCE VERIFIED |
| OTA_REQUEST | 01 51 | SOURCE VERIFIED |
| OTA_RESULT | 01 52 | SOURCE VERIFIED |
| TIME_ZONE | 01 60 | SOURCE VERIFIED |
| TIME_ZONE_NEED | 01 61 | SOURCE VERIFIED |
| WIFI_SSID | 01 70 | SOURCE VERIFIED |
| OTA_NEW_VERSION | 01 90 | SOURCE VERIFIED |
| VTUNER_PLAY | 02 00 | SOURCE VERIFIED |
| SPOTIFY_PLAY | 02 10 | SOURCE VERIFIED |
| SPOTIFY_MODE | 02 11 | SOURCE VERIFIED |
| HOME_SHARE_PLAY | 02 20 | SOURCE VERIFIED |
| HOME_SHARE_GET | 02 21 | SOURCE VERIFIED |
| ALARM_SET | 02 30 | SOURCE VERIFIED |
| ALARM_EDIT | 02 33 | SOURCE VERIFIED |
| ALARM_SUPPORT | 02 35 | SOURCE VERIFIED |
| DEVELOP_INFO_GET | 02 40 | SOURCE VERIFIED |
| SSID_EDIT | 02 41 | SOURCE VERIFIED |
| EQ_TYPE_SYNC | 02 50 | SOURCE VERIFIED |
| EQ_VOLUME_SYNC | 02 51 | SOURCE VERIFIED |
| EQ_SET | 02 52 | SOURCE VERIFIED |
| EQ_UPDATA | 02 55 | SOURCE VERIFIED |
| EQ_CUSTOM_REMOVE | 02 56 | SOURCE VERIFIED |
| EQ_OFF_NO | 02 57 | SOURCE VERIFIED |
| EQ_UPDATA_NAME | 02 58 | SOURCE VERIFIED |
| MFI_AIRPALY_CONNECT | 02 70 | SOURCE VERIFIED |
| HOME_MEDIA_SONG_PLAY | 02 80 | SOURCE VERIFIED |
| HOME_MEDIA_SONG_PROGRESS | 02 81 | SOURCE VERIFIED |
| HOME_MEDIA_SONG_GET | 02 82 | SOURCE VERIFIED |
| QOBUZ_CONNECT | 02 90 | SOURCE VERIFIED |

Some IDs in the decompiled source are expressed through SMB symbolic constants rather than numeric literals. They are intentionally omitted from the numeric table until their exact byte value is source-confirmed; do not guess them from external SMB knowledge.

---

# 8. A33 TCP JSON — port 1234

This is a **different channel** from native binary TCP :23040.

A persistent connection receives asynchronous JSON events and accepts JSON controls.

## 8.1 Client → A33 commands

| Function | JSON | Evidence |
|---|---|---|
| Play | `{"cmd":"play"}` | **HW VERIFIED** |
| Pause | `{"cmd":"pause"}` | **HW VERIFIED** |
| Next | `{"cmd":"next"}` | **HW VERIFIED** |
| Previous | `{"cmd":"prev"}` | **HW VERIFIED** |
| Volume | `{"cmd":"volume","level":30}` | **HW VERIFIED** |
| Mute ON | `{"cmd":"mute","state":"on"}` | **HW VERIFIED** |
| Mute OFF | `{"cmd":"mute","state":"off"}` | **HW VERIFIED** |

## 8.2 A33 → client events observed

Observed event types include:

```text
volume
mute
play_info
process
get_mode
get_playlist
play / pause-related state
```

`process` behaves as playback progress/duration state.

`play_info` contains fields including playback state, current-song metadata, position, volume, mute, shuffle and repeat state.

A device-originated event of the form:

```json
{"cmd":"get_mode","mode":"Network1"}
```

was observed.

A one-shot client request `{"cmd":"get_mode"}` produced no output in a test. Therefore **do not treat get_mode as a proven request/response API**.

Qobuz playlist traffic was observed on this channel. Captured authentication tokens are credentials and must not be stored in GitHub documentation.

---

# 9. A33 ACS2 HTTP / HTTPS

A33 also exposes the CLOUDYX ACS2 command family, separate from TCP :1234 and native :23040.

Observed/test environment used forms such as:

```text
http://DEVICE_IP:8000/?Instruct=...
```

Documentation also provides HTTPS transport on port 8443 in relevant configurations.

Known project-level ACS2 functions include:

```text
setHost
setSlave
disconnectSlave
breakUp
getInformation
```

These are used for A33 multiroom topology/control.

**Important:** do not transplant Linkplay `JoinGroup/LeaveGroup` assumptions onto A33. A33 multiroom is a separate CLOUDYX mechanism.

---

## 9.1 ACS2/status responses additionally observed 2026-10-06

Live traffic on A33 at `192.168.0.31:8000` confirmed these status queries in active desktop use:

| Request | Observed response/use | Evidence |
|---|---|---|
| `getStatusEx` | extended device/status JSON | **OBSERVED** |
| `getPlayerStatus` | player state including source/service, play state, volume and mute | **OBSERVED** |
| `getMetaInfo` | current media metadata | **OBSERVED** |
| `getPresetInfo` | returned `Error` on the tested A33 | **HW VERIFIED negative result** |

One captured `getPlayerStatus` response reported Qobuz playback, `play` state, volume `10`, and unmuted state.

**Canonical rule:** `getPresetInfo` must not be used as the A33 preset API. Preset recall remains unresolved until its actual A33 native/JSON command and payload are correlated from source or capture.

---

# 10. A33 gmrender / DLNA / UPnP

A33 contains a gmrender-resurrect-based renderer, but this is **not the same playback/control engine as iAudioCloud TCP :1234/:23040**.

## 10.1 Discovery

Use SSDP. Do **not** hardcode the HTTP port.

Observed LOCATION ports changed between:

```text
49495
49494
```

Device identity observed:

```text
friendlyName: CL-BOX Pro 6F72
MediaRenderer
AVTransport
ConnectionManager
RenderingControl
Tencent QPlay
```

## 10.2 AVTransport actions

Upstream/source/device study found:

```text
GetCurrentTransportActions
GetDeviceCapabilities
GetMediaInfo
GetPositionInfo
GetTransportInfo
GetTransportSettings
SetAVTransportURI
SetNextAVTransportURI
Play
Pause
Stop
Seek
Next
Previous
SetPlayMode
```

Real A33 additionally advertised `Next`, `Previous`, `SetPlayMode` compared with the studied upstream baseline.

`SetPlayMode NORMAL` was **HW VERIFIED successful**.

### Important negative/unsafe results

- While iAudioCloud music was playing, gmrender `GetPositionInfo` returned track/duration/time as zero/empty.
- `GetTransportInfo` returned STOPPED.
- gmrender RenderingControl volume remained 40 while iAudioCloud volume was changed independently.
- Therefore gmrender transport/volume state is **independent from the main iAudioCloud playback state**.
- Calling gmrender `Next` during iAudioCloud multi-track playback did not switch the track; the old renderer port disappeared and SSDP later exposed a different port/NLS identity. Treat gmrender Next as **unsafe for main playback** and do not repeat casually.
- Local HTTP MP3: `SetAVTransportURI` + `Play` caused the A33 to fetch the MP3 and advance the gmrender timeline, but the user heard no physical audio. This proves fetch/transport activity, **not audible output routing**.

Tencent QPlay was identified as QQ Music-related and is not currently a project priority.

---

# 11. Protocol selection rules for airControl

## Linkplay chips (A28/A31/R328/A97 (ALLWINNER-R328) / A98 (AmlogicA113))

1. Discover actual device/runtime capabilities.
2. Prefer confirmed Linkplay HTTP/native service commands for player control.
3. Use UPnP/PlayQueue where the feature requires it.
4. Gate Qobuz/SMB/features by runtime capability, not chip name alone.
5. Preserve working A31 USB/progress behavior; do not regress it.

## CLOUDYX A33

Current architecture:

```text
A33
├── UDP :53308
│   └── discovery → native TCP port decoding
├── TCP :23040
│   └── native iAudioCloud binary protocol
│       Device Info / transport / seek / volume / mute / EQ / USB / services...
├── TCP :1234
│   └── CLOUDYX JSON control + asynchronous playback/service state
├── ACS2 :8000 / :8443
│   └── device / multiroom command family
└── SSDP-discovered gmrender/DLNA
    └── separate UPnP renderer state; not main iAudioCloud playback
```

For current A33 v2.35.0023.33:
- native Seek → TCP :23040, CMD 00 34
- native Volume → TCP :23040, CMD 00 47
- native Mute → TCP :23040, CMD 00 48
- JSON transport/state is also available on TCP :1234

---

# 12. Rules for maintaining this registry

Every newly discovered command must be added with:

1. chip/device family;
2. protocol and port;
3. exact request/payload/framing;
4. response/event format when known;
5. firmware/version tested;
6. evidence status: SOURCE VERIFIED / OBSERVED / HW VERIFIED / UNVERIFIED;
7. important side effects or regressions;
8. date/test note when behavior is firmware-specific.

Never commit:
- Qobuz/TIDAL/etc. user auth tokens;
- passwords;
- private credentials;
- temporary signed streaming URLs containing secrets.

When an old entry is disproved, keep a short historical note and mark the corrected form as canonical. This prevents repeating already-resolved reverse-engineering work.

---

## Current canonical A33 quick reference

```text
DISCOVERY
UDP 53308

NATIVE TCP
TCP 23040
Frame: A3 BF | SEQ | LEN_LE | CMD[2] | DATA | FB

00 00  Device Info         HW VERIFIED
00 32  Play/Pause          SOURCE VERIFIED
00 33  Next/Previous       SOURCE VERIFIED
00 34  Seek seconds        HW VERIFIED
00 47  Volume (new)        HW VERIFIED on v2.35.0023.33
00 48  Mute/Unmute (new)   HW VERIFIED on v2.35.0023.33

23040 RX push state observed: DevVolume / VolumeState / plays / MusicData
Preset capability observed: TIDAL / TuneIn / Qobuz / vTuner / OpenNetworkStream
Exact A33 preset-slot recall command: NOT YET IDENTIFIED

JSON TCP
TCP 1234
play / pause / next / prev / volume / mute  HW VERIFIED

ACS2
8000 HTTP / 8443 HTTPS family
multiroom: setHost / setSlave / disconnectSlave / breakUp / getInformation

DLNA
SSDP-discovered dynamic gmrender port
Separate renderer state; do not use as substitute for main iAudioCloud control.
```


---

# 13. WiiM Home decompilation — Linkplay runtime capabilities and faster control

This section consolidates the WiiM Home reverse-engineering results recovered on 2026-10-02. It is canonical for Linkplay capability negotiation and must remain separate from CLOUDYX A33/iAudioCloud.

## 13.1 Runtime capability discovery

**APK VERIFIED + HW VERIFIED**

WiiM Home does not enable features solely from a hardware-family label such as A31/A97/A98. It discovers the device UPnP services and queries `StreamServicesCapability` (RenderingControl, `InstanceID=0`), then derives service/UI availability from the returned capability/version data.

Recommended airControl flow:

```text
discover device
→ discover actual UPnP services/endpoints
→ query StreamServicesCapability
→ parse overall StreamCapability + per-service versions/flags
→ build DeviceCapabilities
→ enable only supported features
```

Do not hardcode the service endpoint; discover it from the device description.

### Hardware capability matrix

| Device family | StreamCapability | Qobuz | Important observed capability notes |
|---|---:|---:|---|
| A31 | 1.0 | 1.2 | No Samba advertised in tested response |
| A97 (ALLWINNER-R328) | 1.2 | 1.6 | No Samba advertised; service set is newer than A31 |
| A98 (AmlogicA113) | 1.6 | 2.2 | Samba 1.0; Plex; SpotifyConnect; TidalConnect; QobuzConnect; Roon; Squeezelite; YouTubeMusic and other newer services advertised |

Selected hardware-observed service sets:

**A31:** Prime 1.1, Tidal 2.1, newTuneIn 1.1, Rhapsody 1.0, Deezer 1.1, Qobuz 1.2, iHeartRadio 1.0, vTuner 1.1.

**A97 (ALLWINNER-R328):** Prime 1.4, Tidal 2.2, newTuneIn 1.1, Rhapsody 1.0, soundmachine 1.1, Deezer 1.1, Qobuz 1.6, iHeartRadio 1.0, Pandora 1.0, vTuner 1.1, CalmRadio 1.1, SoundCloud 1.0.

**A98 (AmlogicA113):** Prime 1.4, Tidal 2.3, newTuneIn 1.2, Rhapsody 1.1, SoundMachine 1.2, Deezer2 1.1, Qobuz 2.2, iHeartRadio/iHeart, Pandora2 1.1, vTuner 1.1, CalmRadio 1.1, SoundCloud 1.3, Plex 1.4, KKBOX 1.0, RadioParadise2 1.0, HotMix 1.0, WiiMRadio 1.0, SpotifyConnect 1.3, TidalConnect 1.0, AVS_MRM 1.0, Squeezelite 1.2, Roon 1.0, Soundtrack 1.0, QobuzConnect 1.0, AudioCast 1.0, Samba 1.0, YouTubeMusic 1.0.

**Architecture rule:** chip/platform is useful for selecting the basic transport (A31 HTTP; A97/A98 HTTPS), but feature availability must be negotiated at runtime because firmware and service-capability versions differ.

## 13.2 Qobuz feature negotiation recovered from WiiM Home

**APK VERIFIED; capability values HW VERIFIED**

WiiM Home reads the Qobuz version from the selected device using the equivalent of:

```text
getStreamServiceVersion(StreamServicesCapability.StreamServices.QOBUZ)
```

Recovered feature gates:

| Requirement | Feature |
|---|---|
| Qobuz >= 1.5 | Play Next |
| Qobuz >= 1.6 AND StreamCapability >= 1.2 | Play Last |
| Qobuz >= 1.8 | new OAuth login flow |
| Qobuz >= 1.9 | new Artist behavior |
| Qobuz >= 2.0 + device flag | ReplayGain |
| Qobuz >= 2.1 | Weekly Queue |
| Qobuz >= 2.2 | Qobuz Radio |

These versions are confirmed as feature-negotiation inputs. They do **not** by themselves prove that every version uses a different wire transport.

## 13.3 Qobuz playback model

**APK VERIFIED; final wire payload still under investigation**

Recovered chain:

```text
Qobuz API
→ QobuzPlayItem
→ LPPlayMusicList
→ LPMSPlayData
→ wp6.F()
→ eh6.d()
→ LPPlayMediaData
→ n42.m0()
→ device network playback
```

Important findings:

- the real Qobuz track ID is carried separately as `playItemId`;
- Qobuz service/search context is retained in the playback model;
- playlist/queue data is passed through the common playback pipeline;
- the `trackUrl` seen in this path is context/API data and is **not proven to be a direct audio-stream URL**;
- the exact final Qobuz PlayQueue `QueueContext` body remains a research item.

Recovered Qobuz API route families include artist, album, playlist, artist radio, album radio, track radio, and search categories.

## 13.4 WiiM PlayQueue service

**APK VERIFIED + service HW VERIFIED**

```text
Service ID: urn:wiimu-com:serviceId:PlayQueue
Observed control URL: /upnp/control/PlayQueue1
```

The endpoint must still be discovered from the device rather than blindly hardcoded.

Recovered actions:

| Action | Known arguments / result | Status |
|---|---|---|
| CreateQueue | QueueContext | APK VERIFIED |
| ReplaceQueue | queue replacement payload | APK VERIFIED |
| AppendTracksInQueue | append tracks | APK VERIFIED |
| AppendTracksInQueueEx | extended append | APK VERIFIED |
| PlayQueueWithIndex | QueueName, Index | APK VERIFIED |
| BrowseQueue | QueueName → QueueContext | APK VERIFIED |
| DeleteQueue | queue name/context | APK VERIFIED |

This is a major candidate for replacing controller-side track-by-track orchestration with device-side queue management.

## 13.5 AVTransport / RenderingControl

**APK VERIFIED**

WiiM Home uses UPnP AVTransport callbacks/actions for:

```text
Play
Pause
Previous
Next
Seek
GetMediaInfo
GetInfoEx
```

Therefore Linkplay/WiiM control is a **multi-protocol architecture**, not merely the classic HTTP/HTTPS `httpapi.asp` interface.

For airControl, UPnP/event-capable state should be preferred where it reduces repetitive polling, while preserving HTTP/HTTPS fallback for known working controls.

## 13.6 SMB

**APK VERIFIED + capability HW VERIFIED**

WiiM Home contains SMB playback classes/subsystem.

Capability results:

```text
A31                         Samba not advertised
A97 (ALLWINNER-R328)       Samba not advertised
A98 (AmlogicA113)          Samba 1.0 advertised
```

Presence of SMB code in WiiM Home does not mean every Linkplay device supports native SMB playback. SMB UI/support must be capability-gated.

Recovered WiiM behavior indicates direct `smb://...` resource URLs are represented in PlayQueue rather than proving that the phone proxies the audio stream.

## 13.7 A31 MCU/TCP 8899 — Arylic TCP API + UART passthrough

**HW VERIFIED on user's A31 for this API family; official command catalogue from Arylic documentation.**

A31 `getStatusEx` reports `uart_pass_port=8899` and `communication_port=8819`. TCP 8899 is a bidirectional persistent socket: the device can push state changes without polling.

### TCP connection rules

- Connect to `<device IP>:8899`.
- Keep the TCP connection open for future commands and asynchronous messages.
- Arylic specifies a minimum **200 ms interval** between commands.
- Arylic specifies **one connection per client IP at a time**.
- Basic TCP commands/messages are carried in a packet:
  - header: `18 96 18 20`
  - payload length: 32-bit little-endian
  - checksum: sum of payload bytes, 32-bit little-endian
  - reserved: 8 zero bytes
  - payload: ASCII command/message
- Commands normally begin `MCU+`; messages normally begin `AXX+`. PAS passthrough is an exception.
- Normal payload is often 11 bytes; longer payloads are terminated by `&`.

### TCP API command catalogue

**Device/status:** `MCU+DEV+GET`, `MCU+INF+GET`, `MCU+WWW+GET`, `MCU+USB+GET`.

**Volume/audio:** `MCU+VOL+nnn`, `MCU+VOL+GET`, `MCU+MUT+000/001`, `MCU+MUT+GET`.

**Device control:** `MCU+NAM+SET{name}&`, `MCU+DEV+RST&`, `MCU+FACTORY`.

**Playback:** `MCU+PLY-PUS` pause; `MCU+PLY+PUS` toggle; `MCU+PLY-PLA` resume; `MCU+PLY-STP` stop; `MCU+PLY+NXT` next; `MCU+PLY+PRV` previous; `MCU+PLY+PUQ` resume last playlist.

**Playback mode:** `MCU+PLP+000..004`; `MCU+PLP+GET`. Values: 000 repeat-all, 001 repeat-one, 002 repeat-all+shuffle, 003 shuffle, 004 sequence.

**Presets:** `MCU+KEY+001..010`, `MCU+KEY+NXT`, `MCU+KEY+PRE`; save current supported playlist as preset with `MCU+PRE+nnn`.

**Input/playback state:** `MCU+PLM+GET`. Documented mode IDs include Idle 000, AirPlay 001, DLNA 002, online playlist 010, USB playlist 011, HTTP API 020, Spotify Connect 031, TIDAL Connect 032 (documented A97), LINE-IN 040, Bluetooth 041, Coaxial 045, LINE-IN2 047, HDMI 049, USB DAC 051, External Bluetooth 053, Phono 054, Optical2 056, Coaxial2 057, ARC 058, Slave 099.

**Now playing/status:** `MCU+SONGGET` → short `AXX+SNG+INF{...}&` progress/status; `MCU+MEA+GET` → metadata; `MCU+PINFGET` → richer player state including source/mode, loop, status, progress/duration, title/artist/album, queue count/index, volume and mute. `AXX+SPY+000/001` reports Spotify state.

The TCP API is explicitly bidirectional, so airControl should use unsolicited state messages where reliable instead of polling the same values repeatedly.

### PAS / UART-over-TCP

Arylic documents that newer BP10XX base-board UART commands can be evaluated over TCP by wrapping the raw UART message:

```text
raw UART:  VOL:50
TCP 8899: MCU+PAS+RAKOIT:VOL:50&
```

The A31 captures already confirmed this family, including `MCU+PAS+RAKOIT:VER&`, `VOL`, `MXV`, `TRE`, `BAL`, `EQS`, `PEQ`, `MID` and EQ/state traffic.

### UART physical connection rules

Official Arylic UART settings:

```text
115200 baud
8 data bits
no parity
1 stop bit
no flow control
```

UART messages use 3-character command fields separated with `:` and **commands sent over physical UART must terminate with `;`**. State messages may arrive asynchronously without a query. A command without a parameter normally queries/current-controls; with a parameter it normally changes state.

For supported BP10XX devices, most UART commands can be carried over TCP 8899 as:

```text
MCU+PAS+RAKOIT:{uart_message}&
```

Do **not** include the physical-UART terminating `;` inside this documented TCP wrapper unless a specific device test proves it necessary; follow the Arylic TCP wrapper form.

### UART/PAS command families

**Device:** `STA`, `SYS:REBOOT`, `SYS:STANDBY`, `SYS:RESET`, `WWW`, `NAM[:hextext]`, `ETH`, `WIF`, `WRS`, `WSS`, `BSS`, `IPA`, `TME`, `COE[:onoff]`, `COD[:pin]`.

**Playback:** `SRC[:source]`, `POP`, `STP`, `NXT`, `PRE`, `PST:preset`, `LPM[:loopmode]`, `BTC[:onoff]`, `PLA`, `CHN`, `MRM`, `TIT`, `ART`, `ALB`, `VND`, `ELP`, `PLI`, `APL[:onoff]`.

Documented `SRC` values include `NET`, `BT`, `USBDAC`, `LINE-IN`, `OPT`, `COAX`, `LINE-IN2`, `OPT2`, `COAX2`, `HDMI`.

**Audio:** `AUD[:onoff]`, `VOL[:volume]`, `MUT[:onoff]`, `BAS[:tone]`, `TRE[:tone]`, `MID[:tone]`, `VBS[:onoff]`, `BAL[:balance]`, `VOF[:volume]`, `VOG[:volume]`, `PEQ`, `EQS[:eqidx]`, `VST[:step]`, `EQE[:onoff]`, `CFE[:onoff]`, `CFF[:frequency]`.

Useful ranges from Arylic: BAS/TRE tone -10..+10 dB; BAL -100..+100; fixed output VOF 0..100; volume step VST 0..10; crossfilter CFF 50..300.

### Evidence / compatibility boundary

- **A31:** TCP 8899 API family is **HW VERIFIED** from the user's previous tests/captures.
- **A97 (ALLWINNER-R328):** TCP 8899 remains **NOT TESTED / UNKNOWN** in our project. A command documented by Arylic as “A97” is not enough to mark the user's A97 hardware as verified.
- **A98 (AmlogicA113):** TCP 8899 remains **NOT TESTED / UNKNOWN**.
- `communication_port=8819` is separate; do not mix it with 8899.
- Direct physical UART operation on the user's hardware is **DOCUMENTED, NOT YET HW VERIFIED** even though its API can be tunneled through the A31 8899 PAS path.
- Passthrough functions depend on the base-board/platform and may differ by model even when the Wi-Fi module exposes the same basic TCP API.

## 13.8 Linkplay transport and optimization policy for airControl

Current canonical transport split:

```text
A28 / A31                  HTTP control
A97 (ALLWINNER-R328)       HTTPS control
A98 (AmlogicA113)          HTTPS control
```

But HTTP/HTTPS is only one layer. The optimized Linkplay adapter should combine:

```text
HTTP/HTTPS
+ UPnP AVTransport
+ RenderingControl / StreamServicesCapability
+ PlayQueue
+ event/state channels where verified
+ A31 TCP 8899 where safe and verified
```

Recommended Device Core behavior:

1. Discover device and actual endpoints once.
2. Query runtime capabilities once and cache them with a sensible refresh policy.
3. Build a normalized `DeviceCapabilities` object rather than scattering chip/firmware conditionals through React UI.
4. Prefer push/event state where available instead of frequent polling.
5. Keep HTTP/HTTPS as reliable fallback.
6. Interpolate playback progress locally between authoritative state updates instead of querying the device every second.
7. Coalesce/throttle rapid volume slider/encoder changes.
8. Let PlayQueue manage queues on-device instead of sending unnecessary per-track controller operations.
9. Never enable Samba/Qobuz/new service features merely from the chip name; use capability/version gates.

This design is specifically intended to reduce CPU use, network traffic, wakeups and battery consumption in the future iOS/Android airControl while also improving desktop responsiveness.


## 13.9 A31 v4.5.0 Core — verified responsive state/update policy

**HW VERIFIED on user's A31 — 2026-10-05.**

The v4.5.0 Core integration established the following working optimization rules:

- React player controls route through **airControl Core**; A31 Play/Pause, Next/Previous, Volume and Mute are hardware-verified through the Core/TCP 8899 path.
- A31 unsolicited TCP 8899 state is used for Volume, Mute and Play/Pause reconciliation; external changes were observed in airControl practically immediately.
- Keep heavy/full Linkplay refresh separate from lightweight player reconciliation. A lightweight `getPlayerStatus` refresh can run at about 1 s for title/progress reconciliation while full status/metadata refresh remains much slower (currently about 10 s).
- Lightweight refresh must preserve existing rich artist/album/artwork until fresh rich metadata for the new track arrives.
- When the lightweight path detects a real track-title change, trigger the rich metadata refresh immediately rather than waiting for the next periodic full refresh.
- **React rule:** do not derive the `trackChanged` flag by mutating a local variable from inside a `setDevices(state => ...)` updater and then reading that variable immediately after `setDevices`. React may execute the updater later. Compute the old/new media identity synchronously from the current device snapshot and `getPlayerStatus` result **before** calling `setDevices`, then schedule the rich refresh.
- After applying this rule, the user hardware-tested track switching between albums and confirmed that artwork updates became **much faster**.
- A31 Library playback progress and automatic transition to the next local track remain hardware-verified and must be preserved.

### Timing evidence for the artwork path

Direct A31/Qobuz measurements showed that the approximately multi-second artwork lag was not caused by the device/network path:

```text
getStatusEx          ~0.071 s
getPlayerStatus      ~0.029 s
UPnP GetPositionInfo ~0.025 s
Qobuz artwork fetch  ~0.072 s
```

A separate live UPnP test showed the new track title and new `albumArtURI` changing together in the same `GetPositionInfo` result. Qobuz artwork downloads were approximately 0.085–0.120 s in repeated tests.

**Canonical implementation rule:** for A31, use push events for state where verified, lightweight polling for reconciliation/progress, and an immediate rich refresh on synchronously detected media-identity change. Do not increase heavy polling frequency to solve artwork responsiveness.

---

# 14. Unified airControl Device Core target

The protocol research now supports a common logical API above chip-specific adapters:

```text
React UI
   │
Device State Store
   │
airControl Device Core
   │
   ├── Linkplay adapter
   │     A28/A31 → HTTP
   │     A97 (ALLWINNER-R328) / A98 (AmlogicA113) → HTTPS
   │     + UPnP / capabilities / PlayQueue
   │     + A31 TCP 8899 when verified
   │
   └── CLOUDYX A33 adapter
         TCP 1234 event/control
         TCP 23040 native binary
         ACS2 for applicable device/multiroom functions
         DLNA/gmrender only for dedicated DLNA use
```

UI-facing operations should remain protocol-independent, e.g. `play`, `pause`, `next`, `previous`, `setVolume`, `setMute`, `seek`, source, EQ, queue, presets and grouping.

The adapter chooses the most efficient verified transport for the actual device/firmware/capability set. Electron-specific code should not own protocol semantics so the same Device Core can later be reused by the mobile transport layer.

