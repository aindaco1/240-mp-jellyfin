# 240-mp-jellyfin Security Policy

240-mp-jellyfin handles local media paths and Jellyfin credentials, so security reports are taken seriously even though this is a small fork.

## Supported Versions

This project does not maintain long-term support branches. Only the current `main` branch and the latest GitHub release are supported.

## Reporting A Vulnerability

Do not open a public issue for security problems.

Use GitHub's private vulnerability reporting for this repository when available, or contact the maintainer privately through GitHub. Include:

- Affected commit or release.
- macOS version and hardware.
- Steps to reproduce.
- Potential impact.
- Proof of concept, if one is safe to share privately.

## Security-Sensitive Areas

- `jellyfin_auth.json` stores Jellyfin server URL, access token, user ID, username, server identity, and client device ID. It must not store passwords.
- Auth files containing tokens should be written with owner read/write permissions only.
- Tokens, passwords, full auth headers, and token-bearing URLs must not be logged.
- Jellyfin stream URLs should not include `api_key`; mpv should receive Jellyfin auth through the private temporary mpv include file created by `MpvController`.
- Movie library caches are in memory only and are cleared on logout or new Jellyfin authentication.
- Karaoke catalog and queue files contain only public metadata, entry UUIDs, display state, and canonical `https://www.youtube.com/watch?v=<id>` URLs. They must never accept arbitrary playlist URLs from cache or QML.
- Karaoke helper stderr and stored failure messages must redact URLs before they are surfaced or persisted.
- yt-dlp and Deno release assets are version-pinned and SHA-256 verified at configure time. Packaged helpers are signed with the rest of the app, and helper updates require reviewing both version and checksum changes.
- Modules should only communicate directly with their intended media service and should only write state under `~/Library/Application Support/240-mp-jellyfin/`.

## Out Of Scope

- Bugs with no security impact.
- Vulnerabilities in upstream dependencies such as Qt, mpv, FFmpeg, OpenSSL, or Jellyfin Server. Report those to the respective upstream projects.
- Unsupported platforms, including Raspberry Pi OS, Linux packaging, and Intel macOS.
