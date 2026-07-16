# 240-mp-jellyfin Architecture

240-mp-jellyfin is a retro VCR-style media app built with **C++ Qt 6 + QML**, targeting **Apple Silicon macOS**. This is the reference for working on the fork's code, whether you are adding a new module or changing an existing one.

If you just want to install or build the app, see [INSTALL.md](INSTALL.md) and [BUILDING.md](BUILDING.md). 

If you want to contribute, please start with [CONTRIBUTING.md](CONTRIBUTING.md).

## Philosophy

Think of 240-mp-jellyfin as a **browsing shell** that hands off to **purpose-built tools**.

- The app shell handles browsing, auth, and settings.
- **Modules** are self-contained media integrations that the shell discovers and loads at startup.
- When a user picks something to play, the shell hands off to **mpv**, launched as a subprocess by `MpvController`. Development builds can use mpv from `PATH`; packaged macOS builds bundle mpv and its non-system dynamic libraries. YouTube extraction uses pinned bundled yt-dlp and Deno helpers. The app does not link against libmpv.

The guiding idea: **browse structured content, then hand off to the right tool for the job** rather than bundling everything into one binary.

## Project Structure

```
240-mp-jellyfin/
  src/                              # C++ source
    main.cpp                        # app entry point — engine setup, context properties, registerModule calls
    AppCore.h / AppCore.cpp         # app shell: module registry, config r/w, settings routing
    modules/                        # per-module C++ backends
      local_files/
        LocalFilesBackend.h/.cpp
      plex/
        PlexBackend.h/.cpp          # hidden reference backend retained until Jellyfin parity
      jellyfin/
        JellyfinBackend.h/.cpp      # Jellyfin auth, browsing, stream URL building
      karaoke/
        KaraokeBackend.h/.cpp       # multi-source catalog cache and persistent queue
      ...
    player/
      MpvController.h/.cpp          # mpv subprocess controller: QProcess launch + IPC socket
  modules/                          # QML + assets per module (discovered at startup)
    jellyfin/
      manifest.json                 # module identity and settings shape
      assets/images/logo.svg
      views/
        Root.qml                    # module router (required)
        ...
    karaoke/
    local_files/
    retro_tv/
    plex/                           # hidden from normal module discovery
    ...
  views/                            # app-level QML
    ModuleList.qml
    Settings.qml
    ...
    Components/                     # shared QML components (AppBar, qmldir)
  Main.qml                          # app root
  CMakeLists.txt
```

The user-facing modules appear as Jellyfin, Karaoke, Retro, Tumblr, Local, and Loop. Their source IDs are `jellyfin`, `karaoke`, `retro_tv`, `tumblr_screensaver`, `local_files`, and `ambient_mode`. `plex` remains installed and registerable, but its manifest is marked `hidden: true` while Jellyfin moves toward parity.

## Anatomy of a Module

A module has up to three parts:

| Part | Location | Required? |
|---|---|---|
| `manifest.json` | `modules/<name>/manifest.json` | **Yes** — read by `AppCore` at startup |
| QML views | `modules/<name>/views/` (entry point `Root.qml`) | **Yes** |
| C++ backend | `src/modules/<name>/<Name>Backend.h/.cpp` | Optional |

`AppCore` scans `modules/*/manifest.json` at startup. A module that needs **no backend** (pure QML) requires **no C++ changes at all** — drop in the folder and it's discovered. A module that needs a backend adds one `registerModule(...)` call in `main.cpp` (see [AppCore](#appcore--the-app-shell)).

```
modules/<name>/
  manifest.json             # identity + settings
  assets/images/logo.svg    # logo for the module / single color `#ffffff` to enable color schemes to re-color
  views/
    Root.qml                # module router (entry point)
    Items.qml               # list view
    Detail.qml              # detail/leaf view
```

## manifest.json Reference

Loaded at startup by `AppCore` — the single source of truth for a module's identity and settings. No C++ changes are needed to add or modify settings.

```json
{
  "id": "com.240mp.<name>",
  "name": "<DISPLAY NAME>",
  "display_order": 100,
  "hidden": false,
  "icon": "assets/images/logo.svg",
  "entry_point_qml": "views/Root.qml",
  "settings": [ ... ]
}
```

Top-level `hidden: true` keeps a module installed and registerable but omits it from normal module discovery and Settings. This fork uses that for Plex while Jellyfin is being brought to parity. `display_order` controls the home-screen and Settings module order; lower numbers appear first.

### Setting types

| `type` | Description | Extra fields |
|---|---|---|
| `toggle` | ON/OFF toggle | `default: "ON"` or `"OFF"` |
| `list_single` | Single-select list | `options_source`, `options_slot`, `apply_slot` |
| `multiselect_submenu` | Multi-select list via submenu | `options_source`, `options_slot` |
| `directory_browser` | Keyboard-navigable directory picker | `default` (path string, may be empty) |
| `action` | Button that calls a backend slot | `action_slot` |

Additional fields any setting may carry:

- `key` — the config key written under `modules.<id>.<key>` in `config.json`. Supports dot-notation.
- `label` — display text in Settings.
- `requires_auth` — if `true`, the setting is only shown when the module reports an authenticated state via `get_module_auth_state(moduleId)`. Used by authenticated modules to hide settings until sign-in.

### Dynamic options and apply slots

- For `list_single` / `multiselect_submenu` with `"options_source": "dynamic"`, the backend slot named by `options_slot` must emit `dynamicOptionsReady(key, [{id, label}])`. `AppCore` re-emits it to QML with the module ID prepended.
- For `list_single` with `apply_slot`, that slot is called automatically (routed through `invoke_module_action`) when the user changes the value.

A real example from Plex — note `requires_auth`, dynamic options, and apply slots:

```json
{
  "key": "server_machine_id",
  "label": "Server",
  "type": "list_single",
  "options_source": "dynamic",
  "options_slot": "getServers",
  "apply_slot": "applyCurrentServerSetting",
  "requires_auth": true
}
```

## AppCore — the App Shell

`AppCore` (`src/AppCore.h/.cpp`) is the shell. It's exposed to all QML as the context property **`appCore`**.

**Global context properties** (available in all QML): `appCore`, `mpvController`, plus one per module backend (`localFilesBackend`, `jellyfinBackend`, `plexBackend`, `ambientModeBackend`, ...). Backend names are assigned by the `registerModule` call in `main.cpp`.

### Q_INVOKABLE slots used by QML

| Slot | Purpose |
|---|---|
| `scan_for_modules()` | Emits `modulesLoaded` with enabled modules |
| `get_settings()` | Returns entire `config.json` as a map |
| `get_setting(moduleId, key)` | Returns a single setting value |
| `save_setting(moduleId, key, value)` | Writes to `config.json`; supports dot-notation keys |
| `get_module_info(moduleId)` | Returns `{name, icon}` for a module |
| `get_module_settings_schema(moduleId)` | Returns the module's settings array |
| `invoke_module_action(moduleId, slotName)` | Routes to the registered backend via `QMetaObject::invokeMethod` |
| `get_module_auth_state(moduleId)` | Returns the module's auth state (for `requires_auth` settings) |
| `getCustomColorScheme()` | Returns the user's custom color scheme |
| `listDirectories(path)` / `parentDirectory(path)` / `homePath()` | Helpers for `directory_browser` |

### Signals

`modulesLoaded`, `appSettingChanged`, `moduleSettingChanged(moduleId, key, value)`, `dynamicOptionsReady(moduleId, key, options)`, `moduleAuthStateChanged(moduleId)`.

### registerModule — wiring a backend in

Backends are wired in from `main.cpp` with a single call:

```cpp
YourBackend yourBackend(appRoot, dataRoot);   // construct with whatever args the ctor needs

appCore.registerModule("com.240mp.<name>", "yourBackend", &yourBackend, ctx);
```

`registerModule(moduleId, contextProperty, backend, ctx)` does everything: it stores the backend for `invoke_module_action` routing, exposes it to QML under `contextProperty`, and connects the backend's optional signals/slots **by introspection** — each is wired only if the backend actually declares it, so there are no per-capability lambdas:

| Backend member (if declared) | Auto-connected to |
|---|---|
| signal `dynamicOptionsReady(QString, QVariant)` | re-emitted as `appCore.dynamicOptionsReady(moduleId, key, options)` |
| signal `authStateChanged()` | re-emitted as `appCore.moduleAuthStateChanged(moduleId)` |
| slot `onSettingChanged(QString, QString, QVariant)` | `appCore.moduleSettingChanged(moduleId, key, value)` |

The module ID lives in exactly one place per module — this call. Declare these members with the exact signatures above and `registerModule` wires them with no other changes to `main.cpp`.

## Playback Hand-off (MpvController)

The current mpv implementation is a good reference implementation of the "browse & hand-off" philosophy. When a module decides to play a video, it hands off to **mpv** rather than rendering video itself. All of that lives in `MpvController` (`src/player/MpvController.h/.cpp`), exposed to QML as the context property **`mpvController`**.

### How the hand-off works

1. **Launch** — `loadAndPlay(url, startSeconds, audioTrack, subTrack, ...)` starts mpv as a `QProcess`. Playback parameters are passed as mpv command-line flags: `--start=<sec>` (resume offset), `--playlist-start=<n>`, `--loop-playlist=inf`, selected audio/subtitle tracks, sidecar subtitle files, optional video filters, optional input bindings, and so on. On macOS, if another display is connected, mpv is launched fullscreen on the first non-main screen by default. `Main.qml` also owns a second-screen QML output layer for pure-QML media and mpv-adjacent overlays, while the primary window stays available as a playback control surface. `HelperResolver` resolves packaged helpers first, then development overrides and `PATH`, and builds a per-process `PATH`; the app never mutates its global environment or links libmpv.
2. **Authenticated HTTP playback** — Jellyfin headers are written to a temporary owner-only mpv include file and passed with `--include=<file>`, so tokens are not exposed as normal command-line header arguments. Jellyfin stream URLs avoid `api_key` query tokens.
3. **Control channel** — mpv is started with `--input-ipc-server=<socket>` (a Unix domain socket at `/tmp/240-mp-jellyfin-mpv.sock`). `MpvController` connects to it with a `QLocalSocket` and sends JSON commands via `sendCommand(QJsonArray)`. Seeking, key input, video filters, messages, and playlist append/remove/move/clear/play/replace operations go over this channel. mpv client messages using the `240mp-key` prefix are bridged back to QML through `mpvKeyPressed`; `file-loaded` is surfaced separately so overlays can reveal only after the replacement video is ready.
4. **State back to QML** — `MpvController` issues `observe_property` for `time-pos`, `duration`, and `playlist-pos`, and re-publishes them as `Q_PROPERTY`s + the `positionChanged` / `durationChanged` / `playlistPosChanged` signals. A watchdog timer logs a warning if no `time-pos` event arrives for about 30 s.
5. **Exit and item outcome** — mpv `end-file` events are surfaced as `playbackItemEnded(playlistIndex, reason, error)`. When mpv quits, `MpvController` emits **`playbackFinished(finalPos, finalDur)`** on a normal exit, or **`playbackFailed()`** on a non-zero exit. Karaoke uses item outcomes to remove completed entries and retain failed entries; Local records resume position from process signals, while Jellyfin currently uses them only to return or show failure.

### Bundled helper policy

`cmake/BundledHelpers.cmake` is the single source of truth for yt-dlp and Deno versions, release URLs, and SHA-256 hashes. Configure downloads are cached under `build/bundled-helpers/`; install rules copy the executables and license files to `Contents/Resources/bin` and `Contents/Resources/licenses`. YouTube playback gives mpv's ytdl hook the resolved yt-dlp path explicitly, supplies the resolved Deno runtime as an app-owned raw extractor option, and ignores user helper configuration. Packaged apps also include `ffmpeg`, used by yt-dlp to merge Karaoke's prefetched 720p video and audio. This keeps packaged extraction and prefetch independent of the launch environment and stale system installs. Release CI runs the helpers with a stripped `PATH`, performs a live one-item extraction from each Karaoke source, checks executable load paths, then signs every bundled helper.

### Custom OSC (Lua)

The on-screen controls mpv shows during playback are custom Lua scripts in `scripts/` (`mpv-osc.lua` for normal playback, `ambient-osc.lua` for Loop), loaded via mpv's `--script=` flag. Retro uses `mpv-osc.lua` in `retro-tv` mode so `M` opens the mpv controls while arrow keys remain available for channel surfing and clip skipping.

### Adding a different hand-off target

`MpvController` is the template for that: launch the external tool as a `QProcess`, drive it over whatever control channel it offers, and surface progress/exit back to QML via signals.

## C++ Backend Patterns

Backends are `QObject` subclasses registered via `registerModule(...)` before the engine loads.
Please review `JellyfinBackend` for the current third-party API integration pattern. `PlexBackend` is still useful as a larger reference, but Plex is hidden in this fork.

- All HTTP via `QNetworkAccessManager` — async, on the main thread, no worker threads needed.
- Results returned to QML via signals.
- Auth/state persisted to JSON files in the data dir.
- Auth files that contain tokens should be written with owner read/write permissions only.
- `Q_INVOKABLE` for slots called from QML; `signals:` for callbacks to QML.
- For dynamic settings dropdowns, emit `dynamicOptionsReady(key, [{id, label}])` — auto-connected; `AppCore` re-emits with the module ID prepended.
- For auth-gated modules, emit `authStateChanged()` on sign-in/out — auto-connected and re-emitted as `moduleAuthStateChanged(moduleId)`.
- To react to your own settings changing, add a slot `onSettingChanged(moduleId, key, value)` — auto-connected to `moduleSettingChanged`.
- A backend resolves its own configured paths in its constructor — e.g. `LocalFilesBackend` / `AmbientModeBackend` read `media_directory` from `config.json` (defaulting to `~/Desktop`). `main.cpp` does not touch module paths.

## Jellyfin Module

The Jellyfin module lives in `modules/jellyfin/` and `src/modules/jellyfin/`.

- Auth supports password login and Quick Connect.
- Auth state is persisted in `jellyfin_auth.json`; passwords are never persisted.
- User-facing library browsing supports movie libraries and TV show libraries.
- Movie and TV list loading is paged through `/Items` with `limit=250`, typed `includeItemTypes` requests, lightweight list fields, and `enableTotalRecordCount=false`.
- TV libraries browse `Series` -> `Season` -> `Episode`; episodes reuse the same metadata detail, track selection, and playback flow as movies.
- Completed lists are cached per parent/type for the current app session and cleared on logout or new authentication.
- Detail loading fetches heavier fields, including `Overview` and `MediaSources`, only when a playable movie or episode is opened.
- Stream URLs use `/Videos/{itemId}/stream` with direct/static playback and mpv HTTP headers.

## Retro Module

The Retro module lives entirely in `modules/retro_tv/`; it has no C++ backend.

- Feed discovery loads decade-specific MyRetroTVs sites for the 50s, 60s, 70s, 80s, 90s, and 00s.
- `RetroTvData.js` fetches the feed homepage, resolves the hashed JavaScript bundle, extracts the site's YouTube ID decode map, then parses `d.json` into filterable channel groups.
- `Player.qml` hands decoded YouTube watch URLs to mpv through `MpvController`, using custom input bindings for channel surfing, clip skipping, filtering, special effects, and exit behavior.
- CRT effects are mpv video filters where possible; the static transition is a QML fullscreen noise overlay shown during channel and clip handoff.
- Because feeds are remote and YouTube-backed, playback uses the same resolved mpv and pinned yt-dlp/Deno helper path as Karaoke.

## Karaoke Module

Karaoke lives in `modules/karaoke/` and `src/modules/karaoke/`.

- `KaraokeBackend` runs the pinned yt-dlp asynchronously against fixed Funbox, KaraokeNerds, JLo.Instru, Offbeat Karaoke, Peareoke, Karaoke Office, CCKaraokeX, Nicky Dee Karaoke, Karaoke Balka, Pants Karaoke, Karaokearr, ObsKure, 1Music Karaoke, Janet Email Karaoke, Couch Potato Karaoke, and Lemmy Caution Karaoke channel IDs. It reads newline-delimited JSON incrementally, validates 11-character video IDs and source identity, deduplicates IDs, and emits cold-load batches of 64 songs.
- Title cleanup uses anchored, case-insensitive source rules: trailing `(Funbox Karaoke, YYYY[/YYYY...])` becomes `(YYYY[/YYYY...])`; generic and provider-specific Karaoke/Instrumental branding is removed while meaningful qualifiers remain, including Karaoke Office's ordinary suffix and a centralized alias map for verified malformed or inverted records, Nicky Dee's parenthetical and Balka's bullet-delimited markers; Pants quoted performance/byline, parody, live-cover, and attributed cover-version sentences are reordered to artist-first through shared grammars and a small verified attribution map, equivalent animal-sound Eye of the Tiger uploads share one canonical title, and the single unattributed `25 Minutes or Less` parody is excluded at catalog ingestion and cache loading without mutating persistent queues; JLo.Instru separators are normalized before its branded song-first titles—including Instrumental Version/Karaoke Lyrics forms—are reordered to artist-first; every Offbeat key-signature form is removed while remix, cover, and year segments survive; CCKaraokeX bullets become ` - ` and its split CC/Karaoke Version/UVR tags are stripped; ObsKure descriptor chains include Best Karaoke Version forms; legacy 1Music `MusicKaraoke`, XRINA, vocal-removal, training, instrumental-version, and Karaoke labels are removed before shared all-uppercase title casing, separators are repaired or recovered from a centralized list of known undelimited artist prefixes, edition-first records are reordered to `Artist - Song (Edition)`, and redundant `2Pac - Tupac Shakur` aliases collapse; Lemmy post-Karaoke performance labels and repeated-artist live/year metadata become compact parentheticals; Janet em dashes become ASCII separators; and Couch Potato's dash-delimited Karaoke marker is removed. Shared cleanup converts square brackets to parentheses, normalizes quoted `"Weird Al" Yankovic`, repairs the known `Bela Lugosis Dead` possessive, removes a leading context tag when a separate artist/title structure follows, removes redundant leading or trailing `Version` from parenthetical edition descriptors, moves year-version metadata after named edits, shortens 7 Inch Version to `(7")`, and normalizes artist credits to `Ft.`, including relocating credits supplied after the song title. Raw, display, and source identities are retained through the catalog and persistent queue, and cached display titles are always regenerated from those fields on load.
- Catalog reconciliation derives one comparison key from the shared cleaned-title path. It folds case and accents, normalizes punctuation, apostrophes, conjunctions, and English articles, removes trailing Funbox years, then applies the registry ranking Funbox → KaraokeNerds → JLo.Instru → Offbeat Karaoke → Peareoke → Karaoke Office → CCKaraokeX → Nicky Dee Karaoke → Karaoke Balka → Pants Karaoke → Karaokearr → ObsKure → 1Music Karaoke → Janet Email Karaoke → Couch Potato Karaoke → Lemmy Caution Karaoke. The first upload from the winning source is retained, collapsing duplicate uploads within a channel while preserving distinct meaningful annotations.
- `karaoke_catalog.json` is an atomic, schema-versioned multi-source catalog cache. Schema 1 Funbox-only, schema 2 Funbox/ObsKure, schema 3 four-source, schema 4 five-source, schema 5 six-source, schema 6 nine-source, schema 7 eleven-source, schema 8 thirteen-source, and schema 9 fifteen-source caches remain immediately readable and force a background migration to the current sixteen-source schema 10. After the first full inventory, later launches show saved results immediately. Missing or 24-hour-stale data refreshes automatically in the background, reconciling additions, removals, and changed titles before atomically swapping the catalog. Each source must independently pass truncation checks, so one failed channel cannot erase the others; Couch Potato uses a lower floor because its complete channel is smaller than 100 videos. Watch URLs are regenerated from validated IDs rather than reused as expiring media links. A Settings action invokes the same refresh manually. Stale data stays visible if refresh fails.
- `karaoke_queue.json` is one atomic persistent queue. Entry UUIDs allow duplicate videos. Completed entries are removed; failures remain marked. `karaoke_queue.m3u8` is regenerated with validated canonical watch URLs before playback.
- `Items.qml` owns the shared live-search and queue editor used both before and during playback. Search normalization and article-insensitive alphabetical sort keys are shared through `TextSearch.qml`; marquee rows and confirmation UI are shared components.
- `Player.qml` keeps that browser active on the primary display while mpv plays on the external display. Backend mutations are mirrored to mpv's live playlist over IPC, protecting the current and past entries while allowing upcoming append, reorder, remove, and clear operations.
- Enter on a selected queue row uses `playlist-play-index`, so a host can jump to any retained item without rebuilding the playlist. The queue remains editable after the jump.
- Once the current file is loaded, `KaraokeBackend` asynchronously prepares the next entry with the pinned yt-dlp/Deno pair and bundled `ffmpeg`. The completed, validated owner-only media file is stored under `karaoke_playback_cache`, limited to eight unprotected files or 1 GiB, and inserted into the matching upcoming mpv slot before the remote URL is removed. Cache files referenced by the persisted queue are protected from eviction.
- The shared `PlaybackTransitionOverlay` presents randomized fade, slide, and falling-block handoffs on the transparent external QML layer. Its easing functions live in the `TransitionMath` singleton and are also used by Tumblr's block transition, keeping the animation math centralized.

## Tumblr Screensaver Module

The Tumblr module lives in `modules/tumblr_screensaver/` and `src/modules/tumblr_screensaver/`.

- Users enter a public Tumblr URL in the module's first view; the URL is persisted through `appCore.save_setting(...)`.
- `TumblrScreensaverBackend` fetches Tumblr's public JSON feed pages through `/api/read/json`, using `posts-total` and paged `start`/`num` requests to collect the blog.
- The backend extracts Tumblr-hosted image URLs from post HTML, prefers the largest `srcset` candidate for still images, keeps GIF sources when present, and deduplicates exact image URLs.
- `Player.qml` renders a fullscreen QML image montage, shuffling the loaded images so a cycle does not repeat until every image has been shown once.
- Transitions are handled entirely in QML with retro slide/zoom/fade motion, scanlines, and falling-block effects rather than mpv.
- Falling-block transitions divide the incoming image into clipped tile regions so the next screen appears on the blocks as they fall.

## Track Selection

Local and Jellyfin both expose audio/subtitle choices before playback.

- Local calls bundled or PATH `ffprobe` through `LocalFilesBackend::probeMediaTracks()`, validates the probed path stays under the configured media root, and adds matching sidecar subtitles from the same directory.
- Jellyfin parses `MediaStreams` from item detail responses and maps audio/subtitle choices to mpv `--aid`, `--sid`, and `--sub-file` values.
- External subtitles are passed as authenticated mpv subtitle URLs when Jellyfin provides `DeliveryUrl`.

## QML View Patterns

### Root.qml — module router

Every module requires `Root.qml` as its entry point. It owns the internal nav stack and handles exiting back to the module list.

```qml
import QtQuick

FocusScope {
    id: moduleRoot

    signal goBack()

    property var navParams: ({})

    // must match your manifest id
    property var _moduleInfo: appCore ? appCore.get_module_info("com.240mp.<name>") : ({})
    property string moduleName: _moduleInfo.name || ""
    property string moduleIcon: _moduleInfo.icon || ""

    property var navStack: []
    property var currentParams: ({})

    function navigateTo(viewPath, params, fromState) {
        var resolved = Qt.resolvedUrl(viewPath)
        navStack.push({ source: internalLoader.source, params: currentParams, listState: fromState || {} })
        currentParams = params || {}
        internalLoader.setSource(resolved, { "navParams": params || {} })
    }

    function navigateBack() {
        if (navStack.length === 0) {
            moduleRoot.goBack()
            return
        }
        var prev = navStack.pop()
        if (!prev.source || prev.source.toString() === "") {
            moduleRoot.goBack()
            return
        }
        var restored = Object.assign({}, prev.params)
        restored.navListState = prev.listState || {}
        currentParams = restored
        internalLoader.setSource(prev.source, { "navParams": restored })
    }

    Loader {
        id: internalLoader
        anchors.fill: parent
        focus: true
        onLoaded: { if (item) item.forceActiveFocus() }

        Connections {
            target: internalLoader.item
            ignoreUnknownSignals: true
            function onNavigateTo(path, params, listState) { moduleRoot.navigateTo(path, params, listState) }
            function onGoBack() { moduleRoot.navigateBack() }
        }
    }

    Component.onCompleted: navigateTo("Items.qml", {})
}
```

**Rules:**
- `id` is always `moduleRoot`.
- `moduleName` / `moduleIcon` always come from `appCore.get_module_info(...)` — never hardcoded.
- `goBack()` is the only signal that leaves the module — child views never emit it directly.
- `navigateBack` merges `navListState` back into params on pop so list views can restore position.
- For auth flows that need `replaceWith` (navigate without pushing to the stack), please see the Plex module as a reference.

### Items.qml — list view

```qml
import QtQuick
import Components

FocusScope {
    id: itemsRoot

    property var navParams: ({})
    property var navListState: navParams.navListState || ({})

    signal navigateTo(string path, var params, var listState)
    signal goBack()

    focus: true
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
            goBack()
            event.accepted = true
        }
    }

    AppBar {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.125
        anchors.leftMargin: root.sw * 0.125
        iconSource: moduleRoot.moduleIcon
        title: moduleRoot.moduleName
    }

    ListView {
        id: itemList
        anchors.topMargin: root.sh * 0.25
        anchors.leftMargin: root.sw * 0.115625

        // restore list position on back-navigate
        Component.onCompleted: {
            var restore = navListState.currentIndex !== undefined ? navListState.currentIndex : 0
            currentIndex = Math.min(restore, Math.max(0, count - 1))
            positionViewAtIndex(currentIndex, ListView.Contain)
        }

        Keys.onReturnPressed: {
            navigateTo("Detail.qml", { item: model[currentIndex] }, { currentIndex: currentIndex })
        }
    }
}
```

### Detail.qml — leaf view

```qml
import QtQuick
import Components

FocusScope {
    id: detailRoot

    property var navParams: ({})

    signal goBack()

    focus: true
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
            goBack()
            event.accepted = true
        }
    }

    AppBar {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.125
        anchors.leftMargin: root.sw * 0.125
        iconSource: moduleRoot.moduleIcon
        title: moduleRoot.moduleName
        subtitle: navParams.item || ""
    }
}
```

**View rules:**
- Always declare `property var navParams: ({})` — the router passes params via `Loader.setSource`.
- List views also declare `property var navListState: navParams.navListState || ({})` and restore position in `Component.onCompleted`.
- `navigateTo` always takes 3 args: `(path, params, listState)` — pass `{ currentIndex: listView.currentIndex }` as listState when pushing to a detail view.
- Leaf views only need `signal goBack()` — no `navigateTo`.
- Use `root.sh` / `root.sw` for all margins and sizes — never hardcoded pixels. This keeps layouts responsive across CRT (240p/480i, watch overscan) and HDMI/LCD.
- Access shared state via `moduleRoot.moduleName`, `moduleRoot.moduleIcon`.
- Navigate via signals — never call router functions directly.

## Components (WIP)

Shared QML components live in `views/Components/` (registered via `qmldir`, imported as `import Components`).

### AppBar (`views/Components/AppBar.qml`)

| Property | Type | Description |
|---|---|---|
| `iconSource` | `url` | Module icon — use `moduleRoot.moduleIcon` |
| `title` | `string` | Module name — use `moduleRoot.moduleName` |
| `subtitle` | `string` | Optional context label (hidden when empty) |

The icon is automatically colorized to the app accent color

## Config Storage

User configuration is stored in `config.json` in the app's data directory:

```json
{
  "app": {
    "color_scheme": "Video 1",
    "prevent_sleep": "ON",
    "battery_sleep_threshold": "10%"
  },
  "modules": {
    "com.240mp.jellyfin": { "enabled": true, "resume_playback": "ask", "video_quality": "direct" },
    "com.240mp.karaoke": { "enabled": true },
    "com.240mp.local_files": { "enabled": true, "media_directory": "~/Desktop" },
    "com.240mp.ambient_mode": { "enabled": false, "media_directory": "~/Desktop" },
    "com.240mp.tumblr_screensaver": { "enabled": true, "tumblr_url": "https://pixelskylines.tumblr.com/" }
  }
}
```

Each module's settings live under `modules.<id>`. App-wide settings live under `app`; `prevent_sleep` controls the macOS idle sleep assertion, and `battery_sleep_threshold` releases that assertion while the internal battery is discharging at or below the configured percentage so macOS can sleep normally. Use `save_setting` / `get_setting` (which support dot-notation keys) rather than writing the file directly. The data directory is created on first run and is separate from the app itself, so rebuilding never wipes user settings. For the exact macOS path, see [BUILDING.md](BUILDING.md#configuration).
