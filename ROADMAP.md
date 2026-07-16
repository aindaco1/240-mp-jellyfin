# Roadmap

1.0 establishes the macOS-only Jellyfin fork: movie-library browsing, direct-play playback, Local support, Loop, bundled playback helpers, and a hidden Plex reference module. Post-1.0 work has added TV show, season, and episode browsing, Retro decade feeds, a Tumblr image screensaver, and a persistent multi-source Karaoke queue.

The next goal is to make 240-mp-jellyfin reliable as a daily-use macOS media app before expanding the media surface.

## Post-1.0 Priorities

### Jellyfin Playback State

- Report playback start, progress, stop, and completion to Jellyfin.
- Clear resume position when playback reaches the end.
- Add watched/unwatched state updates from the detail screen.
- Add Continue Watching once playback reporting is reliable.

### Faster Large-Library Navigation

- Add server-side Jellyfin search for very large libraries.
- Keep the current local live filter for already-loaded items.
- Add a clearer loading/progress state for paged libraries.
- Cache normalized search keys in QML or C++ so accent folding is not repeated on every keystroke.

### Track Selection Polish

- Preserve the last selected audio/subtitle preference per Jellyfin item when practical.
- Improve labels for commentary, forced subtitles, default streams, and external subtitles.
- Add a quick "Subtitles Off" shortcut on the detail screen.
- Consider a global subtitle default: off, default, forced only, or last used.

### Packaging Hardening

- Document signing/notarization secrets required by the release workflow.
- Add a release checklist for local install verification before tagging.
- Add a deliberate pinned-helper update cadence and a small diagnostics surface for bundled mpv, ffprobe, yt-dlp, and Deno versions.

## Candidate 1.x Features

### Jellyfin Media Scope

- Polish TV browsing with better show/season resume shortcuts once Jellyfin playback reporting is reliable.
- Add mixed video libraries if the UI can stay simple.
- Decide whether music videos belong in Jellyfin scope or should be a separate module surface.

### Transcoding And Quality

- Implement Jellyfin `PlaybackInfo` with a real client capability profile.
- Add direct play, direct stream, and transcode decision handling.
- Add quality limits for remote or constrained networks.
- Add a fallback path when mpv cannot play the direct stream.

### Metadata And Artwork

- Add optional poster/backdrop display while preserving the retro interface.
- Cache artwork carefully so large libraries do not slow startup.
- Keep list-first navigation fast even if images are enabled later.

### Local Improvements

- Cache `ffprobe` results per file mtime so returning to a detail screen is instant.
- Add manual subtitle file selection for non-matching sidecars.
- Add folder-level sort modes.
- Add a local media rescan/refresh action.

### Retro Improvements

- Add clearer handling for feeds or YouTube clips that fail because of upstream availability.
- Consider persisting the last selected Retro feed, filters, and effect settings.
- Keep the MyRetroTVs parser isolated so upstream site changes are easier to repair.

## Larger Ideas

### First-Run Setup

- Start new users in a focused setup flow for Jellyfin sign-in and Local directory selection.
- Show bundled helper versions and config paths in a diagnostics view.
- Make auth/setup recoverable without requiring users to edit files.

### Better Playback Diagnostics

- Surface common failure causes: helper missing, Jellyfin unauthorized, stream not found, unsupported direct play, subtitle fetch failure.
- Add a "copy diagnostics" action that redacts tokens automatically.
- Link failures to the relevant log path.

### Remove Plex

- Define the Jellyfin parity line for removing Plex from source.
- Remove Plex backend/QML/resources after that line is met.
- Clean up any remaining Plex-specific settings, docs, and compatibility paths.

### Reliability And Test Coverage

- Add focused backend tests for auth file handling, URL construction, paging, and path safety.
- Add smoke tests for module discovery and hidden modules.
- Add a small QML lint baseline so new warnings are easier to spot.
- Add release automation that builds, installs, verifies helpers, and checks the final bundle contents.

### App Experience

- Add better empty states for no Jellyfin libraries, no movie libraries, and no local media directory.
- Add configurable startup behavior: module list, last module, or Jellyfin libraries.
- Add a simple in-app "About" screen with app version, build type, helper versions, and GPL notice.
- Consider an update-check flow only after release signing/notarization is stable.
