## v3.0.7.45
Internet Radio on A31 now sends station metadata and artwork to the player via UPnP DIDL-Lite, using the same proven path as Local Library. Station artwork is proxied through the local airControl media server for player compatibility.

# airControl v3.0.7.20


## v3.0.7.18

### Final neutral theme cleanup
- Removed the remaining navy/blue surfaces from Room EQ and USB Library.
- Room EQ cards, test controls, meter background, graph frame, status/preview blocks and tables now use shared dark/light theme variables.
- Room EQ measurement/target/prediction graph lines are neutral grayscale; PEQ itself remains yellow/orange.
- USB track rows, device icon, transport, progress bar and active row are now monochrome hardware-style controls.
- Green/red remain reserved for semantic ready/online/error states.
- Light theme receives the matching white/light-gray equivalents automatically.
- Device-control logic is unchanged.

## v3.0.7.16

### Theme cleanup
- Removed remaining legacy blue panel/background styling from Player, Internet Radio, EQ and Room EQ.
- Dark theme now uses black / neutral graphite / gray lines throughout.
- Light theme uses white / neutral light gray equivalents through the same CSS variables.
- Active controls are monochrome; online/error states remain green/red.
- PEQ response remains yellow/orange in both themes.
- Device-control logic is unchanged.

- Added **Reset PEQ to 0** for both A33 and A98/WiiM. The reset preserves filter type, frequency and Q, and sets all PEQ gains to 0 dB on the actual device.
- A98/WiiM EQ now uses the same tab-style navigation concept as A33: **Graphic EQ / Parametric EQ / Room EQ**.
- Added the shared **Room EQ** measurement/Auto EQ page to A98/WiiM. Its 10-band correction can be loaded into the A98 EqNp editor and then committed with **Apply all PEQ**.
- Added **Apply all PEQ** to A98/WiiM for Room EQ suggestions or full-editor commits while retaining the proven serialized per-band LV2 transport.
- Room EQ wording is now device-neutral so the same measurement engine can be shared by A33 and A98/WiiM.
- A31 and A97 control paths are unchanged.

## v3.0.7.13
- Unified A33 and A98/WiiM Parametric EQ presentation.
- Added interactive logarithmic 10 Hz–22 kHz response graph with −12…+12 dB scale.
- Numbered PEQ control points can be dragged: X changes frequency, Y changes gain.
- Q and filter type update the calculated response curve immediately.
- A33 keeps its existing setParameterEq transport; A98/WiiM keeps the verified EqNp LV2 per-band transport.


## A98 / WiiM EQ dB display + PEQ probe
- Keeps the working A98/WiiM 10-band `EQGetBand` / `EQSetBand` implementation from v3.0.7.9.
- Shows graphic-EQ gain in dB while still sending the device's proven native 0–99 values.
- Conversion used for the current integer API: 50 = 0.0 dB and 5 native steps = 1 dB (0.2 dB per step), matching the legacy Eq10HP decimal-gain representation.
- Native values remain visible in small text for verification during testing.
- Adds a safe, read-only Parametric EQ capability probe using the WiiM LV2 `EqNp` plugin (`EQGetLV2BandEx`, with `EQGetLV2Band` fallback).
- PEQ writes are intentionally not enabled until the real A98 response structure is captured.
- A31 and A33 control paths are unchanged.

# airCloudCTRL v3.0.7.9

## A98 / WiiM EQ
- Enables the EQ page for A98/WiiM-class Linkplay devices (Amlogic/WiiM project detection).
- Uses the documented HTTP commands `EQGetBand`, `EQSetBand`, `EQGetList`, `EQLoad:<name>`, `EQOn`, and `EQOff`.
- Adds the documented 10 bands: 31, 63, 125, 250, 500 Hz, 1, 2, 4, 8, and 16 kHz.
- Uses the native 0–99 value range with 50 = flat and deliberately does not invent a dB conversion.
- Polls `EQGetBand` for external feedback while no local slider is being dragged.
- Keeps the verified A31 MCU/8899 EQ implementation unchanged. A97 EQ remains disabled until verified.

# airCloudCTRL v3.0.7.8

A31 EQ native-app synchronization and layout update.

## v3.0.7.8 — A31 Mid control
- Added A31 Mid-frequency control using the native MCU command family observed in the manufacturer app.
- Read: `MCU+PAS+RAKOIT:MID&` → `MID:n`.
- Write: `MCU+PAS+RAKOIT:MID:n&`, exposed as −5…+5 with 0 neutral.
- Mid is included in serialized live polling and write/readback verification.
- Virtual Bass Intensity remains unchanged as a write-only 1…100 control.
- Existing A33, A97/A98 and all other A31 controls are unchanged.


## v3.0.7.6 — A31 advanced audio controls

- Added A31 EQ preset buttons with named preset groups and current-preset feedback.
- Added Virtual Bass ON/OFF, intensity and enhance controls using MCU RAKOIT passthrough.
- Added maximum-volume read/write control.
- Existing serialized A31 Bass/Treble/Balance feedback remains intact.
- A33, A97 and A98 control paths are unchanged.
- VB:INT/VB:ENH numeric ranges are not specified by the published API; UI exposes raw 0–100 test values and labels this explicitly.


## v3.0.7.4 — A31 live EQ feedback
- While the A31 EQ page is open, Bass, Treble and Balance are re-read from the verified MCU TCP interface about every 1.2 seconds.
- Changes made in the manufacturer's/native app now appear automatically in airCloudCTRL without pressing Read EQ.
- Background polling pauses while a local slider is being dragged or a write/readback cycle is in progress, preventing the slider from fighting the user.
- Treble is now the left control and Bass the right control, as requested.
- A33 and A97/A98 control logic is unchanged.

# airCloudCTRL v3.0.7.1

A31 EQ reliability update based on real-device feedback.

## v3.0.7.1 — A31 EQ write/readback fix
- Bass/Treble now commit on Pointer Up (mouse/touch/pen) instead of separate mouse/touch handlers.
- Added explicit Apply Bass / Apply Treble buttons as a reliable fallback.
- Every Bass/Treble write is automatically verified with `EQGet`.
- Every Balance write is automatically verified with `RAKOIT:BAL`.
- The UI is updated from the real device immediately after each write; Read EQ is no longer required for feedback.
- A33 and A97/A98 logic is unchanged.

# airCloudCTRL v3.0.7

Stable full-project snapshot based on v3.0.6.

## v3.0.7 — verified A31 EQ
- A31 / UP2STREAM_PRO_V4: added real Bass and Treble controls through Linkplay MCU TCP passthrough on port 8899.
- A31: added real Balance control (−100…+100, centre 0).
- A31: reads the standard Linkplay EQ preset index using `getEqualizer` (read-only until preset names/write mapping are verified).
- Slider values are sent on release, not continuously while dragging.
- A97/A98 EQ remains disabled until its command path is verified on real hardware.
- A33 behavior from v3.0.6 is unchanged.

# airCloudCTRL v3.0.6

Stable full-project snapshot.

## v3.0.6 fix
- A33: Radio Browser metadata remains authoritative for direct radio streams started by airCloudCTRL (`http_music`).
- A33: selecting native TuneIn or vTuner in the manufacturer's app immediately clears the airCloudCTRL radio overlay, so native metadata/status becomes visible.
- A31/A97/A98 behavior unchanged.

# airCloudCTRL v3.0.5

Clean full project snapshot. This archive is intended to replace the patch-by-patch installation workflow.

## Device families
- **airCloud** — CLOUDIX A33-compatible devices.
- **airScope** — Linkplay/Arylic/WiiM-compatible devices.

## Current transport behavior
- A33: HTTP/8000 or HTTPS/8443.
- Linkplay A31: HTTP/80.
- WiiM/newer Linkplay: HTTPS/443 with self-signed certificate support.

## Run
```bash
npm install
npm run dev
```

See `INSTALL-MAC.txt` for a clean macOS installation.


## v3.0.1 metadata synchronization

This build fixes stale Internet Radio metadata remaining on screen after playback is changed from a native device app. For newer Linkplay/WiiM generations, `getMetaInfo` is used to enrich playback with album artwork when the endpoint is available. A31 remains on the documented HTTP metadata path; cover art for A31 requires a later UPnP implementation.


## v3.0.2 playback metadata compatibility

- A33 radio state merges `getStatusEx` with optional `getPlayerStatus`.
- Radio Browser overlay has a grace period and is cleared only on strong evidence of a source/stream change.
- A31 and A97/ALLWINNER-R328 can obtain missing artwork from UPnP AVTransport metadata on port 49152.
- A98/AmlogicA113 continues to use `getMetaInfo` first, with UPnP only as fallback.

## v3.0.3
- A33: Radio Browser station metadata is pinned while the station started by airCloudCTRL is active.
- A33: stale metadata/timing from the previously played native track no longer removes the radio overlay after a few seconds.
- A33: the overlay still clears when the source leaves Network or when a genuinely new native media identity is detected.
- Linkplay A31/A97/A98 behavior from v3.0.2 is unchanged.


## v3.0.5 — A33 Internet Radio ownership
- Radio Browser metadata started by airCloudCTRL is authoritative on A33 while the device stays on Network/http_music; stale A33 URLs/Unknown metadata no longer evict it.
- A33 native-app Internet Radio now maps `getPlayerStatus.PlayStatus` correctly, so play/pause feedback is visible.
- A33 native radio with no station metadata is shown as `Internet Radio` instead of recycling the previous song.
- Native music with real metadata can still take ownership back.
- A31/A97/A98 behavior is unchanged.


## v3.0.5
- A33 native TuneIn/vTuner are recognized as Internet Radio services.
- A33 TuneIn status parsing tolerates stray control bytes returned by some firmware.
- Native radio Play/Pause continues to come from getPlayerStatus.


## v3.0.7.2 — A31 EQ scale and slider geometry
- A31 Bass/Treble now use the documented 0…10 MCU range, shown as −5…+5 with neutral 5 = 0.
- Horizontal A31 EQ and global volume/seek sliders use explicit WebKit track/thumb geometry so the thumb reaches both visual ends of the track.
- A33 device logic and A97/A98 transport logic are unchanged.

- v3.0.7.4: A31 EQ native-app feedback polling rewritten as a serialized non-overlapping MCU/8899 loop.


## v3.0.7.7 — A31 Virtual Bass Intensity
- Added the verified A31 Virtual Bass Intensity control using `MCU+PAS+RAKOIT:VBI:n&`.
- Range is 1…100, matching traffic captured from the native macOS application.
- `VBI&` is intentionally not polled because this A31 firmware accepts the query but returns no value, including when requested by the native application.
- Existing VBS, MXV, EQ preset, Bass/Treble and Balance behavior is unchanged.

## v3.0.7.23
- Fixed the visible seam below the sticky selected-device header.
- Added an opaque theme-colored apron below the fixed header so scrolling content cannot show through between the header/tabs and page content.


## v3.0.7.23
- Moved selected-device master volume to the global top bar before User Mode.
- Added Mute/Unmute beside the top-bar volume control.
- The top-bar volume follows the currently selected audio zone/device.
- Removed Volume from the Player Playback settings card; Loop mode and Channel remain.


## v3.0.7.25
- Fixed packaged Electron startup (blank window in DMG).
- Vite now builds JS/CSS asset URLs relative to `dist/index.html` using `base: "./"`.
- Development mode (`npm run dev`) is unchanged.
- Package version uses valid SemVer `3.0.7-25` while project folder/version remains v3.0.7.25.


## v3.0.7.26 Windows UI polish
- Responsive fixed columns for Windows DPI scaling.
- No page-level horizontal overflow.
- Compact, dark scrollbars.
- Windows application menu bar hidden for a cleaner native window.
- Device header/tabs compressed at smaller effective desktop widths.


## v3.0.7.27
- Approved monochrome FILMOSCOPE LAB / airControl application icon for macOS and Windows.
- Persistent global Now Playing bar fixed to the bottom edge of the application.
- Main workspace and device list scroll independently above the global player bar.
- Removed the v3.0.7.23 master-volume slider from the top bar.
- Clicking the speaker in the global player opens a vertical selected-zone volume popover; Mute/Unmute is available inside the popover.
- Windows installer keeps the existing appId/product identity and includes x64 + ARM64 build targets for upgrade testing over v3.0.7.26.


## v3.0.7.28
- Fixed Add Device modal stacking: dialogs are viewport-fixed above sticky header, tabs, workspace and global Player footer, with internal scrolling on small windows.
- Enabled shared USB browser/player for airScope Linkplay A31/A97/A98-class devices using native Linkplay getLocalPlayList and playLocalList commands.
- Linkplay USB paths are decoded from firmware hex strings; USB source uses udisk and the existing transport/status UI remains shared.


## v3.0.7.30
- Fixed A31 USB folder browsing: Linkplay getLocalPlayList HEX paths such as /media/sda1/... are decoded and normalized to the USB root before building the folder tree.
- A33 USB folder handling remains unchanged.
