# iOS-to-Android screen map

Use the latest iPhone screenshots from this project conversation as visual references. Re-capture after significant UI changes and attach the image/date to the relevant row.

| Screen / flow | iOS reference area | Android work item | Important visible states |
|---|---|---|---|
| Rooms / devices | `LPDeviceListViewController`, `LPDeviceListTableViewCell`, `ACHome` | Room cards, online status, selected room, add/stop controls, zone navigation | Offline / online, selected, playing, grouped master, expanded group |
| Grouped rooms | `LPMultiroomViewController`, `ACHome` | Master group card with group-volume slider and individual room sliders | Master and member roles; group boundary, link/unlink, member volume |
| Transport / now playing | `LPPlayview/LPPlayViewController`, `LPPlayer/LPPlayerViewController`, `ACHome` | Source label, square high-resolution artwork, track metadata, seek, repeat, transport, volume, queue | Radio/live streams may have unknown duration; artwork loading/fallback; selected source |
| Browse / library home | `ACHome` | Selected-room banner, source inputs, local library, radio catalogs, music services, compact mini-player | Room changed, no active item, source unavailable, service logged out/in |
| USB library | `LPUSB/LPUSBViewController`, `ACHome` | Folder-first browsing, back navigation, albums/tracks/art, play selected item | Empty/unmounted disk, folder, malformed per-track metadata, playing highlight |
| Presets | `PresetViewController` plus `ACHome` | Preset rows, artwork, empty slots, activate/delete | Populated/empty slots, loading and device error |
| Internet radio | `ACHome` (TuneIn and Radio Browser flows) | Search, country/genre/local radio, nested categories, station rows/art | Loading, empty/error, category transition, station playing |
| Deezer | `ACHome` | Login, session state, catalog, search, library categories, album/playlist detail, track playback | A31 legacy service vs A98 Deezer2; authenticated/session-expired; selected track |
| Qobuz | `ACHome` | Account/session, Discover and Library, playlists/albums/artists/tracks, album detail | OAuth profile/capabilities, authorization handoff, session, catalog errors |
| Settings / device info | `ACHome`, SDK settings controllers | Language, source inputs, EQ, device information, network/IP, sleep timer, alarm, service accounts | Selected zone, unsupported capability, pending/failed command |
| Equalizer | `ACHome` and Linkplay SDK EQ calls | Chip-specific presets/custom bands with enable state | Supported/unsupported chip, read values, edit/apply result |
| Alarm | `ACHome` / alarm controllers | Time, repeat, music/preset selection, volume, duration, save/edit | Disabled/enabled, repeating days, selected source, validation/error |
| Queue | `ACHome` and device queue API | Current source queue, active track highlight, source-specific refresh | USB/Qobuz index mapping, unknown index, malformed item metadata |

## Layout rules already requested

- Black/charcoal surfaces with white text and fine separators; amber/orange for selected controls and important sliders; green reserved for device connection status.
- RTL must mirror the full control geometry (including slider direction and labels), not just translated text.
- Keep transport and mini-player within safe areas; avoid controls overlaying metadata or bottom navigation.
- Artwork is square and uses an appropriately large source image without blocking list rendering.
