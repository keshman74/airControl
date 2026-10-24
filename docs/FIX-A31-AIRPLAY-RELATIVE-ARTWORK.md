# A31 AirPlay artwork relative URL — 2026-10-24

## Hardware observation

On A31 at 192.168.0.35, the user's SOAP GetPositionInfo call returned HTTP 200. Parsed TrackMetaData:
- title: Air
- artist: Bicep, soarr
- album: Gas / Ultra / Equarium
- albumArtURI: /data/airplay_f67a80954965fd2f79a144f41d4bbe38.jpg

This confirms the A31 advertises a per-track relative artwork URI in AVTransport metadata. It is distinct from /data/AirplayArtWorkData.jpeg, which returned 404 on the same A31. The actual GET status/content/bytes for the new relative path have not yet been captured.

## airControl implementation

AirPlayArtworkPath-v1 was added to branch feature/v5.0.x-active-presets-a98. It recognizes only /data/airplay_<32 hex>.jpg, resolves that path against the selected zone's scheme, IP, and port, then sends it through Electron's artwork-to-data-URL resolver. The parser filters the raw relative or selected-player URL on temporary failure; last-good artwork remains for the same track, while old art is cleared on changed track if a new image is not available. The existing fixed A98 artwork path remains supported. TLS exception remains scoped to selected private player's exact known artwork paths.

Validation in the patch archive includes synthetic local HTTP retrieval of the A31 relative path, selected-player TLS isolation, parser transient-failure behavior, and installer guard/idempotence. User hardware download of the new A31 URL remains pending; no A31 image GET 200 or rendered-cover hardware confirmation is claimed yet.

Source commit will be linked here after publication.
