# Install 240-mp-jellyfin

240-mp-jellyfin is currently distributed as a macOS Apple Silicon app bundle inside a DMG.

## Requirements

- Apple Silicon Mac.
- macOS current enough to run the Qt 6 app bundle.
- Network access to your Jellyfin server for Jellyfin playback and to YouTube for Karaoke/Retro playback.

The packaged app bundles `mpv`, `ffmpeg`, `ffprobe`, pinned standalone `yt-dlp`, pinned Deno, and required non-system dynamic libraries. End users do not need to install Homebrew, Python, mpv, FFmpeg, yt-dlp, or a JavaScript runtime.

## Install

1. Download the latest `240-mp-jellyfin-<version>-macOS-arm64.dmg` from GitHub Releases.
2. Open the DMG.
3. Drag `240-mp-jellyfin.app` into `/Applications`.
4. Launch `240-mp-jellyfin.app`.

The app opens as a full-screen, keyboard-first media interface.

## Update

1. Download the newer DMG from GitHub Releases.
2. Open the DMG.
3. Replace the existing `240-mp-jellyfin.app` in `/Applications`.

Your settings, Jellyfin authentication, Karaoke catalog cache, and Karaoke queue are kept in `~/Library/Application Support/240-mp-jellyfin/`, so replacing the app bundle does not erase them.

## Uninstall

Remove the application:

```bash
rm -rf /Applications/240-mp-jellyfin.app
```

Optionally remove user configuration and Jellyfin auth:

```bash
rm -rf "$HOME/Library/Application Support/240-mp-jellyfin"
```

## Development Installs

Development builds can be run directly from the build directory:

```bash
APP_ROOT=$(pwd) ./build/240-mp-jellyfin.app/Contents/MacOS/240-mp-jellyfin
```

For development prerequisites and packaging steps, see [BUILDING.md](BUILDING.md).
