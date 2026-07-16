# 240-mp-jellyfin

240-mp-jellyfin is a macOS Apple Silicon fork of 240-MP: a retro VCR-style media shell built with C++ Qt 6 and QML. The fork keeps the CRT/240p-inspired interface, Local playback, Loop, Retro decade feeds, and a Tumblr image screensaver, adds Jellyfin as the main server-backed media module, and adds a sixteen-source Karaoke queue.

The app is a browsing shell, not an embedded video renderer. It launches `mpv` as a subprocess for playback and uses `ffprobe` to inspect local audio/subtitle tracks. CMake supplies pinned standalone `yt-dlp` and Deno helpers for YouTube extraction. Packaged macOS apps also bundle `ffmpeg` for high-quality Karaoke prefetch, along with all required non-system libraries, so end users do not need Homebrew or system helper installs.

## Supported Platform

- Apple Silicon macOS only.
- CMake intentionally fails on non-macOS hosts.
- Intel macOS, Raspberry Pi OS, and Linux packaging are out of scope for this fork.

## Current Modules

The home screen order is Jellyfin, Karaoke, Retro, Tumblr, Local, then Loop.

### Jellyfin

- Password login and Jellyfin Quick Connect.
- Movie libraries and TV show libraries.
- TV browsing through shows, seasons, episodes, then the same metadata, track-selection, and playback flow used for movies.
- Large movie and TV lists load progressively in 250-item pages.
- Live title filter narrows the list as you type.
- Accent-insensitive filtering, so names with characters like `e` and `é` match naturally.
- Direct-play movie and episode playback through mpv.
- Resume prompt based on Jellyfin playback position.
- Audio and subtitle selection before movie and episode playback.
- External Jellyfin subtitle URLs are loaded through authenticated mpv requests without putting access tokens in media URLs.

Not yet implemented: music libraries, Continue Watching hubs, playback progress reporting back to Jellyfin, watched-state updates, and transcoding fallback.

### Karaoke

- Automatically indexes the Funbox, KaraokeNerds, JLo.Instru, Offbeat Karaoke, Peareoke, Karaoke Office, CCKaraokeX, Nicky Dee Karaoke, Karaoke Balka, Pants Karaoke, Karaokearr, ObsKure, 1Music Karaoke, Janet Email Karaoke, Couch Potato Karaoke, and Lemmy Caution Karaoke YouTube channels and keeps a persistent 24-hour catalog cache. After the first complete sync, later launches show saved results immediately while stale catalogs reconcile additions, removals, and metadata changes in the background.
- Live accent-insensitive title search with article-insensitive alphabetical results and progressive results during a cold catalog load.
- Cleans `(Funbox Karaoke, YEAR)` to `(YEAR)`; removes provider-specific Karaoke/Instrumental branding, including Karaoke Office's ordinary suffix and verified malformed/inverted aliases, Nicky Dee's parenthesized and Balka's bullet-delimited markers, plain parenthesized or bracketed Karaoke markers from Karaokearr and Pants Karaoke, converts Pants' quoted performance/byline, parody, live-cover, and attributed cover-version sentences to `Artist - Song (Qualifier)`, canonicalizes its animal-sound Eye of the Tiger uploads, and excludes the one unattributed `25 Minutes or Less` parody, while leaving any previously queued copy editable; strips split CCKaraokeX forms and ObsKure Best Karaoke Version forms; removes all Offbeat key-signature forms while retaining remix/cover qualifiers; converts JLo.Instru's variably spaced `Song - Artist - Instrumental[-Version] - Karaoke[-Lyrics]` conventions to `Artist - Song` while retaining verified artist-first exceptions; strips legacy 1Music `MusicKaraoke`/vocal-removal/instrumental-version/XRINA branding, repairs its unspaced or omitted separators through a centralized artist-prefix list, reorders edition-first titles to `Artist - Song (Edition)`, and collapses redundant `2Pac - Tupac Shakur` aliases; normalizes Janet's em-dash separators and Couch Potato's dash-delimited Karaoke markers; and retains meaningful qualifiers. Lemmy's trailing performance labels and repeated-artist live/year metadata become compact parentheticals such as `(Stop Making Sense)` and `(Live) (1969)`. Shared display cleanup also normalizes square brackets, quoted `"Weird Al"`, leading context tags such as `(Sonic Adventure 2)`, removes redundant leading or trailing `Version` from parenthetical edition labels, moves `YYYY Version; Edit` into `(Edit) (YYYY)`, shortens `7 Inch Version` to `(7")`, and canonicalizes `Featuring`/`Feat`/`Ft` credits as `Ft.` on the artist side, moving misplaced title-side credits there.
- Reconciles equivalent titles across and within sources with case-, accent-, punctuation-, apostrophe-, conjunction-, and article-insensitive matching. Duplicate preference is Funbox, KaraokeNerds, JLo.Instru, Offbeat Karaoke, Peareoke, Karaoke Office, CCKaraokeX, Nicky Dee Karaoke, Karaoke Balka, Pants Karaoke, Karaokearr, ObsKure, 1Music Karaoke, Janet Email Karaoke, Couch Potato Karaoke, then Lemmy Caution Karaoke.
- One persistent queue with duplicate songs, keyboard reorder, remove, and clear controls.
- Search, add, reorder, and remove remain available on the primary display while mpv plays fullscreen on an external display.
- Artist and song render as readable two-line rows; selecting any queued song and pressing Enter jumps to it immediately.
- While a song plays, the next queued song is downloaded and merged at up to 720p in a bounded persistent cache, then substituted into mpv's live playlist for a fast handoff.
- Retro fade, slide, and falling-block transitions mask the handoff on the media display.
- Completed songs leave the queue; failed songs stay visibly marked for retry or manual removal.
- A manual catalog refresh action is available in Karaoke settings.

### Retro

- MyRetroTVs-backed feeds for the 50s, 60s, 70s, 80s, 90s, and 00s.
- Fullscreen mpv playback of decoded YouTube clips, with no TV-frame overlay.
- Keyboard channel surfing, clip skipping, feed filtering, and decade jumping.
- CRT-style noise, glow, black-and-white, and static transition effects.

### Local

- Folder browsing.
- The first view shows the active media directory, defaulting to `~/Desktop`.
- Common video file support: `mp4`, `mkv`, `avi`, `mov`, `m4v`, `webm`, `wmv`, `flv`, `f4v`, `mpg`, `mpeg`, `vob`.
- `m3u` and `m3u8` playlists.
- Loop and shuffle playback options.
- Resume history.
- Audio and subtitle selection before playback.
- Sidecar subtitle discovery for common subtitle formats.

### Loop

- Looping background video playback.
- Optional separate audio playlist.
- The first view shows the active media directory, defaulting to `~/Desktop`.
- Kept from the original project as a first-class module.

### Tumblr

- Public Tumblr URL input, defaulting to `https://pixelskylines.tumblr.com/` for quick testing.
- Image discovery through Tumblr's public `/api/read/json` feed pages.
- Fullscreen image montage that shuffles the image deck and does not repeat until every discovered image has been shown.
- Retro 90s-style QML transitions, including falling blocks built from clipped pieces of the incoming image.

### Plex

The original Plex module remains in the source tree as a reference implementation, but its manifest is marked hidden so it does not appear in normal module discovery or Settings. It can be removed after Jellyfin reaches the desired parity.

## Build And Run

See [BUILDING.md](BUILDING.md) for the full build, run, packaging, and release workflow.

Quick macOS development build:

```bash
brew install cmake qt mpv ffmpeg
cmake -B build -DCMAKE_PREFIX_PATH=/opt/homebrew/opt/qt .
cmake --build build
APP_ROOT=$(pwd) ./build/240-mp-jellyfin.app/Contents/MacOS/240-mp-jellyfin
```

## Install

See [INSTALL.md](INSTALL.md). The release artifact is a macOS Apple Silicon DMG containing `240-mp-jellyfin.app`.

## Project Docs

- [CHANGELOG.md](CHANGELOG.md) records user-facing changes.
- [ROADMAP.md](ROADMAP.md) tracks planned work and improvement ideas.
- [ARCHITECTURE.md](ARCHITECTURE.md) explains the module, playback, and backend structure.
- [CONTRIBUTING.md](CONTRIBUTING.md) covers contribution and testing expectations.

## Configuration

User configuration is stored outside the app bundle:

```text
~/Library/Application Support/240-mp-jellyfin/
  config.json
  jellyfin_auth.json
  karaoke_catalog.json
  karaoke_queue.json
  karaoke_queue.m3u8
```

`jellyfin_auth.json` stores the Jellyfin server URL, access token, user ID, username, server identity, and client device ID. Passwords are not persisted. Karaoke files contain public catalog metadata, queue state, and validated canonical YouTube watch URLs; they contain no credentials.

## Security Notes

- Jellyfin access tokens are stored with owner read/write permissions only.
- Jellyfin playback tokens are sent to mpv through a temporary private mpv config include instead of command-line header arguments.
- Jellyfin stream URLs do not include `api_key` tokens.
- Playback logs redact known token query parameters.

## License

This project remains licensed under the GNU General Public License v3.0. See [LICENSE](LICENSE) for the full text.

If you distribute a modified version, you must also distribute it under GPL-3.0 and make the source available.
