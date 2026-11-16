# Audio Pro Legacy: A31 discovery and Deezer playback

## Artifact and evidence

- APK: `/Users/lab/AI/App Mobile/Audio+pro+legacy_3.2.1.230920_APKPure.apk`
- Package/version: `com.wifiaudio.AudioPro` / `3.2.1.230920` (version code `2023092013`)
- APK SHA-256: `361c5695c55ad7e208938e3d002c1d2710c930ac743dcfe0e2ae17529f111970`
- Static review: JADX decompilation and Ghidra 12.1.4 review of the ARM64 `libwiimundk.so`.
- The APK was not run by the analysis. Runtime playback below is the user's report, accompanied by sanitized, read-only A31 snapshots.

## Device discovery fallback

Audio Pro Legacy does more than wait for UPnP multicast:

1. `IPScanService` maintains previously known Linkplay addresses and checks candidates on the local network. Its scan worker checks TCP port `8819` and requests Linkplay device properties.
2. `IPScanReceiver` validates the returned project/UPnP UUID and de-duplicates devices.
3. For a valid candidate it creates an SSDP `HTTP/1.1 200 OK` response with `LOCATION: http://<device>:59152/description.xml`, `ST: urn:schemas-upnp-org:device:MediaRenderer:1`, and the device UUID.
4. It injects that response into the Cling UPnP router as if it had arrived over SSDP. Cling then loads the device description and services.

This gives the app a unicast IP-scan recovery path when a legacy device is not surfaced reliably by normal multicast discovery. It is a concrete candidate for airControl's intermittent/missing-device problem. The source proves the fallback exists in the APK; it does not by itself prove which branch was used in the user's successful session.

## Legacy Deezer sign-in

The Deezer login screen (`FragDeezerLogin.W2`) reads the account username and password, runs the password through `WiimuNDK.encryptPwd`, and calls `DeezerLoginRequest` for the selected renderer. The UPnP task is `UserLogin` on the renderer's PlayQueue service. Its inputs are:

- `AccountSource = Deezer`
- `UserName = <account username>`
- `PassWord = <WiimuNDK output>`
- `Code = empty`
- `Proxy = empty`
- `SavePass = 0`
- `Token = empty`

This legacy flow uses no observed Deezer App ID, OAuth token, or app-side API key. The native method is a reversible byte-obfuscation transform, not cryptographic password encryption. On ARM64, the observed routine starts with state `0x1e00`; for each input byte it XORs the byte with `state >> 8`, updates the 32-bit state using `((state & 0xffff) + byte) * 0xce6d + 0x58bf`, then encodes the resulting byte as two uppercase letters (`A + byte/26`, `A + byte%26`). It reads a JNI UTF string and processes up to its 255-byte buffer limit. Static review did not execute this method; confirm the transform against a non-production test value on both Android and iOS before relying on a port.

The app parses the `UserLogin` result and then calls the corresponding user-info operation. The renderer, not the phone, is responsible for the Deezer account session and resolving playable track streams. Previous A31 donor-firmware analysis found the renderer-side Deezer login and track-stream resolver.

## Queue creation and playback

For the legacy `Deezer` source, the app builds a `PlayList` XML payload containing `SourceName`, `SearchUrl`, account fields, quality, page/index metadata, and track entries. It submits that payload through the PlayQueue `CreateQueue` action. The newer service-version path also uses `CreateQueue`; `Deezer2` is a separate capability-gated source and should not be substituted for legacy `Deezer` on older A31 firmware.

Relevant decompiled entry points include `org.teleal.cling.c.a.a.k` (`UserLogin` SOAP arguments), `org.teleal.cling.c.a.a.n.j` / `n.k` (legacy Deezer browse and queue XML), `com.wifiaudio.service.d.M0` (login dispatch), and `com.wifiaudio.service.d.e0` / `L` (queue creation dispatch).

## Sanitized live observations

Read-only snapshots were taken on 2026-11-10. They contain no track titles, raw XML, full URLs, account names, or credential/token values.

| A31 build | Player state | Queue observation |
|---|---|---|
| `4.6.629929`, project `a31youyishi` | Playing | `SourceName=Deezer`, 12 queue entries, queue browse HTTP 200 |
| `4.6.415156`, project `UP2STREAM_PRO_V4` | Playing | `SourceName=UPnPServer`, one entry; URL host `icecast.walmradio.com`, not a Deezer endpoint |

The user separately confirmed Audio Pro Legacy discovered the spare A31 and started a Deezer track. The snapshots distinguish two responding A31s; the second row must not be misattributed as the successful Deezer session. The matching live Deezer queue is the first row.

Local redacted snapshots:

- `/Users/lab/AI/airControl/office-live-current-20261110.json`
- `/Users/lab/AI/airControl/office-29-current-20261110.json`

## airControl implementation implications

1. Add an IP-scan discovery fallback alongside SSDP: scan only the active local subnet, identify Linkplay-compatible hosts from a minimal status/property read, then feed the advertised description URL into the existing UPnP parser. Keep subnet size, timeouts, and candidate validation bounded.
2. The shared Capacitor app now implements the legacy Deezer path in `src/deezer.js`: `GetUserInfo`, `UserLogin`, device-provided Airable catalog URL, time-based Basic authorization, category/library/search/pagination navigation, and a Deezer `PlayList` payload. No Deezer App ID or OAuth registration was found or added.
3. Playback uses the advertised PlayQueue `CreateQueue`, followed by `PlayQueueWithIndex` at the selected one-based track index. The queue includes the current catalog page's playable tracks and its page URL so firmware can resolve the service-side streams and continue the queue. This follows the Audio Pro Legacy path (`service.f.t` / `service.d.e0`, `d0`, `n.k`) rather than sending a public Deezer stream URL.
4. SOAP actions and required input names are checked against the device's SCPD before sending. External catalog requests are restricted to HTTPS hosts beneath `airable.io`; credentials and signed authorization are kept transiently in memory and are not logged or written to disk. The password compatibility transform is reversible obfuscation, not security encryption, and `SavePass=0` is sent at login.
5. The Deezer tab is shared by iOS and Android through the existing Capacitor HTTP bridge. The password field is cleared after successful login. Switching the selected device clears the in-memory Deezer session and catalog state.

## Limits

- Static APK analysis establishes implemented code paths, not which path ran during the user's playback session.
- The current device snapshots do not include a capture of Audio Pro Legacy's outgoing SOAP, so they do not independently prove the exact payload sent in that session.
- The airControl implementation has not yet been exercised end-to-end with a fresh Deezer login and selected track on a physical device. Firmware variants may differ in optional PlayQueue actions or catalog payload details; these are reported as explicit device/API errors.
- The APK signature was not verified. Treat the APKPure artifact as a supplied binary, not as an authenticated vendor release.
