# Changelog

All notable changes to 240-mp-jellyfin are documented here.

## [1.0] - 2026-06-12

### Added

- Added the Jellyfin module as the primary server-backed media integration.
- Added Jellyfin password login and Quick Connect.
- Added movie-library browsing for Jellyfin.
- Added paged Jellyfin movie loading so large libraries become usable before every item has loaded.
- Added accent-insensitive live filtering in Jellyfin movie lists.
- Added Jellyfin direct-play playback through mpv.
- Added pre-play audio and subtitle selection for Jellyfin movies.
- Added pre-play detail and track-selection flow for Local Files.
- Added local media track probing through `ffprobe`.
- Added sidecar subtitle discovery for Local Files.
- Added packaged macOS helper bundling for `mpv`, `ffprobe`, and their non-system dynamic libraries.
- Added `AGENTS.md` as the single local development-agent guide.
- Added `ROADMAP.md` for post-1.0 project direction.

### Changed

- Renamed the runtime product to `240-mp-jellyfin`.
- Set the app version to `1.0`.
- Changed the app data directory to `~/Library/Application Support/240-mp-jellyfin/`.
- Changed the build to macOS-only; CMake now fails on non-macOS hosts.
- Changed the release workflow to publish an Apple Silicon macOS DMG only.
- Changed release tagging docs and workflow matching to support `v1.0` style tags.
- Changed Plex to a hidden module so it stays available as a reference without appearing in normal module discovery or Settings.
- Changed Jellyfin movie list requests to use lightweight fields and defer heavier metadata until the detail view.
- Changed Jellyfin library caching to be in-memory and session-scoped.
- Updated README, install, build, architecture, contribution, and security docs for the macOS Jellyfin fork.

### Security

- Jellyfin stream URLs no longer include `api_key` tokens.
- mpv receives Jellyfin HTTP auth through a temporary owner-only mpv include file instead of visible command-line header arguments.
- Playback logs redact known token query parameters and auth-header text.
- `jellyfin_auth.json` is written with owner read/write permissions only.
- Jellyfin in-memory library cache is cleared on logout and new authentication.

### Removed

- Removed the stale Raspberry Pi install script from the macOS fork.
- Removed duplicate `CLAUDE.md`; use `AGENTS.md` for local agent instructions.
- Removed `JELLYFIN_MAC_FORK_PLAN.md`; the release history now lives here and future work lives in `ROADMAP.md`.

### Release Scope

- Apple Silicon macOS is the only supported runtime for 1.0.
- The retro CRT-style UI stays.
- Local Files and Ambient Mode stay user-facing.
- Plex stays hidden until Jellyfin has enough parity to remove it.
- Jellyfin starts with movie libraries and direct play before broader media support.
- Packaged macOS apps bundle playback/probing helpers; development builds can still use Homebrew tools from `PATH`.
