# A98 AirPlay cover stability — 2026-10-24

## Symptom

After the HTTPS artwork resolver fix, the user observed that an AirPlay cover briefly flashes in airControl 5.0.0 and then disappears.

## Source-level diagnosis

The renderer resolves getMetaInfo.albumArtURI and UPnP art through Electron. If a refresh cannot resolve the player's local self-signed URL, the original URL can still reach parseLinkplayStatus. Chromium then attempts the same URL directly and can reject the certificate. In parallel, regular A98 polling can repeatedly refresh the track view. This is a plausible code-path explanation for the reported flash; the exact failing request from the user's Mac was not captured.

## Patch

AirPlayArtworkStability-v1 in src/services/deviceDrivers.js filters the selected device's raw /data/AirplayArtWorkData.jpeg URL from rich, UPnP, and previous artwork candidates. Resolved data: URLs remain valid. If artwork temporarily fails for the same track, the last good resolved cover remains. On a changed track, unresolved previous art is cleared so stale art is not shown.

The filter applies only when the URL hostname matches the selected device's stored IP and path is exactly /data/AirplayArtWorkData.jpeg. It does not change public CDN artwork handling.

## Validation

The parser regression tests passed for:
- transient failure retains last successful cover;
- raw selected-player AirPlay URL is never surfaced;
- changed track with unresolved artwork clears old cover;
- new resolved data URL replaces old cover.

The guarded installer applied successfully to a full 5.0.0 package fixture and was idempotent on a second run. Real A98 playback validation and complete Electron/Vite build are still pending.
