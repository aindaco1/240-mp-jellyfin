# Mac-only Jellyfin Fork Plan And Status

This fork keeps 240-MP's existing Qt/QML shell, macOS app bundle support, Local Files module, Ambient Mode, and mpv playback handoff. The core change is to make the project a macOS-focused media app and make Jellyfin the primary server-backed integration.

## Current Fit

| Goal | Current fork status | Remaining effort |
|---|---|---|
| macOS app | Apple Silicon macOS-only CMake/build/release path is in place | Distribution polish only |
| Local playback | Local Files remains enabled with pre-play audio/subtitle selection | Low |
| Jellyfin playback instead of Plex | Movies, auth, library browsing, direct play, filtering, paging, resume prompt, and pre-play track selection are implemented | Moderate for parity |

The clean path remains adapting the existing app instead of rewriting it. The app provides module discovery, settings storage, keyboard-first QML navigation, app-level routing, and `MpvController` playback through an external `mpv` process.

## Architecture Direction

The Jellyfin work should live beside the existing Plex code first:

```text
modules/jellyfin/
  manifest.json
  assets/images/logo.svg
  views/Root.qml
  views/Auth.qml
  views/Libraries.qml
  views/Items.qml
  views/Detail.qml
  views/Player.qml

src/modules/jellyfin/
  JellyfinBackend.h
  JellyfinBackend.cpp
```

`src/main.cpp` registers the backend once:

```cpp
JellyfinBackend jellyfinBackend(appRoot, dataRoot);
appCore.registerModule(
    "com.240mp.jellyfin",
    "jellyfinBackend",
    &jellyfinBackend,
    ctx
);
```

`CMakeLists.txt` includes `src/modules/jellyfin/JellyfinBackend.cpp`.

## Jellyfin API Scope

Start with direct play only. Do not port Plex transcoding logic line for line.

Phase 2 minimum backend calls:

| App need | Jellyfin endpoint |
|---|---|
| Password login | `POST /Users/AuthenticateByName` |
| Libraries | `GET /UserViews` |
| Library items | `GET /Items` with paged movie requests |
| Item detail | `GET /Items/{itemId}` |
| Direct video stream | `GET /Videos/{itemId}/stream` |

The implementation persists only server URL, access token, user ID, username, server ID, server name, and a stable client device ID in `jellyfin_auth.json`. It does not persist passwords, and the auth file is written with owner read/write permissions only.

## Implemented In This Fork

- macOS-only CMake configuration and release workflow.
- Product/app naming: `240-mp-jellyfin`.
- macOS config directory: `~/Library/Application Support/240-mp-jellyfin/`.
- Plex hidden from module discovery and Settings through `hidden: true`.
- Jellyfin module with password auth and Quick Connect.
- Jellyfin movie libraries only.
- Jellyfin movie lists load progressively in 250-item pages with lightweight fields.
- Session cache for completed Jellyfin library lists, cleared on logout/new auth.
- Accent-insensitive live title filtering in Jellyfin movie lists.
- Direct-play Jellyfin stream handoff through mpv.
- Jellyfin stream URLs avoid `api_key`; auth is passed through a temporary owner-only mpv include file.
- Local Files pre-play detail screen with audio/subtitle selection.
- Local track probing through bundled or PATH `ffprobe`.
- Packaged macOS app embeds `mpv`, `ffprobe`, and their non-system dynamic libraries.

## Phased Plan

1. **Baseline macOS/local playback** - done
   - Build the current app on macOS.
   - Confirm Local Files playback launches mpv.
   - Confirm keyboard navigation still works after fork changes.

2. **Minimal Jellyfin direct-play module** - done
   - Add `com.240mp.jellyfin` manifest, icon, QML router, auth screen, library list, item list, detail screen, and player screen.
   - Add `JellyfinBackend` with password authentication, library loading, item loading, item detail loading, and stream URL construction.
   - Add generic mpv HTTP header support so Jellyfin requests can send a `MediaBrowser` authorization header.

3. **Playback state** - partial
   - Resume prompt from Jellyfin user data is implemented.
   - Report playback start, progress, stop, and completion to Jellyfin.
   - Add Continue Watching.

4. **Media controls** - partial
   - Audio stream selection is implemented.
   - Subtitle selection, including external subtitle URLs, is implemented for the current direct-play path.
   - Add watched/unwatched controls.

5. **Transcoding and quality** - not started
   - Use Jellyfin `PlaybackInfo` with a real client capability profile.
   - Add a quality setting and transcode fallback when direct play fails.

6. **Mac-only fork cleanup** - mostly done
   - Product name, bundle ID, config directory, and release artifact names are set.
   - Raspberry Pi/Linux build and install paths are removed from current docs and CMake.
   - Plex is hidden until Jellyfin covers the required use cases.
   - README, BUILDING, INSTALL, architecture, contribution, and security docs are fork-aware.

## Decisions

- Plex stays in the codebase but is hidden from normal module discovery and Settings until Jellyfin reaches parity; then it can be removed.
- Jellyfin supports both password login and Quick Connect early.
- The first Jellyfin browsing scope is movies only.
- The retro CRT UI stays.
- Local Files and Ambient Mode stay.
- Runtime/product naming moves to `240-mp-jellyfin`.
- Apple Silicon macOS is the first and only supported runtime.
- Packaged macOS apps bundle `mpv` and `ffprobe`; development builds can still use Homebrew tools from `PATH`.
- The fork remains GPL-3.0 if distributed.

## Remaining Planning Questions

1. How much Jellyfin parity is required before Plex is removed: progress reporting, Continue Watching, watched-state controls, transcoding, playlists/collections, or all of it?
2. Should distribution stop at signed/notarized DMGs, or should it include an updater later?
3. Should future Jellyfin scope include TV episodes, music videos, mixed libraries, or only movies?
