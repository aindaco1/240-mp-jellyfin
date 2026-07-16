# Roadmap

Version 1.1 completed the fork's daily-use Apple Silicon macOS foundation. Future work stays focused on reliability and depth in the existing modules rather than expanding platform or module scope.

## Shipped In 1.1

- Full Jellyfin TV flow: Continue Watching, Up Next, collections/folders, playback negotiation, quality limits, direct-to-transcode fallback, server progress, next-episode autoplay, remembered languages, and capability-gated intro/outro skipping.
- Shared playback lifecycle and named mpv options used across active modules.
- Local images, playlist-relative media, safer symlink handling, subtitle policies/languages, image duration, extension hiding, and ask-at-playback shuffle.
- Loop shuffle/auto-launch and bounded recovery for separate audio.
- Native macOS GameController navigation, Right Shift Back, media keys, menu/paused screen savers, startup module, themes, crop, and output levels.
- Secure signed in-app updates plus hardened notarized release packaging.
- Tumblr GIF playback and persistent normalized favorites.
- Bounded Loop playback selectors for long video and audio filenames.

## Next 1.x Priorities

### Jellyfin Polish

- Add explicit watched/unwatched controls on detail screens.
- Add server-side search for exceptionally large libraries while retaining instant local filtering for loaded pages.
- Add a quick server switch without logging out manually.
- Decide whether mixed-video and music-video libraries fit the intentionally small UI.

### Diagnostics And Recovery

- Add a diagnostics screen for bundled helper versions, app/config/log paths, display selection, and redacted playback failures.
- Distinguish helper, authentication, negotiation, network, and codec failures in user-facing playback errors.
- Add a redacted copy-diagnostics action.

### First-Run Experience

- Guide new users through Jellyfin sign-in and optional Local/Loop directories.
- Explain the primary-display controller and external playback display on first use.
- Keep setup recoverable entirely in-app.

### Reliability And Tests

- Add a fake-server Jellyfin backend suite for auth, paging, PlaybackInfo, reporting, and token-free URLs.
- Establish a QML lint baseline so new runtime warnings are actionable.
- Add a signed-update fixture that exercises DMG identity rejection and rollback behavior in CI.
- Cache Local `ffprobe` results by path and modification time.

### Source Cleanup

- Remove the hidden Plex source after Jellyfin's remaining quick-switch and watched-state parity work is complete.
- Continue consolidating shared list, search, transition, and playback behavior rather than duplicating it per module.
