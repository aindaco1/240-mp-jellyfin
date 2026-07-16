import QtQuick
import Components

FocusScope {
    id: itemsRoot

    property var navParams: ({})
    property var navListState: navParams.navListState || ({})

    signal navigateTo(string path, var params, var listState)
    signal goBack()
    signal songEnqueued(var song)
    signal queueEntryMoved(int fromIndex, int toIndex)
    signal queueEntryRemoved(int index, string entryId)
    signal queueEntryRequested(int index, string entryId)
    signal upcomingQueueCleared()

    property var allSongs: []
    property var songs: []
    property var queue: []
    property string filterText: navListState.filterText || ""
    property int activePane: navListState.activePane !== undefined ? navListState.activePane : 0
    property bool catalogLoading: false
    property bool catalogRefreshing: false
    property string catalogError: ""
    property string statusMessage: ""
    property bool moveMode: false
    property bool clearConfirmationVisible: false
    property bool playbackActive: false
    property string currentEntryId: ""
    property string readyEntryId: ""
    property string playbackStatusText: ""

    readonly property int currentQueueIndex: indexOfQueueEntry(currentEntryId)

    function indexOfQueueEntry(entryId) {
        for (var index = 0; index < queue.length; ++index) {
            if (queue[index].entryId === entryId)
                return index
        }
        return -1
    }

    function decoratedSongs(items) {
        var decorated = []
        for (var index = 0; index < items.length; ++index) {
            var song = Object.assign({}, items[index])
            song.searchKey = TextSearch.normalize((song.displayTitle || "") + " " + (song.rawTitle || ""))
            song.sortKey = TextSearch.articleInsensitiveSortKey(song.displayTitle || "")
            song.titleKey = TextSearch.normalize(song.displayTitle || "")
            decorated.push(song)
        }
        return decorated
    }

    function replaceCatalog(items) {
        allSongs = decoratedSongs(items || [])
        applyFilter(navListState.searchIndex !== undefined ? navListState.searchIndex : searchList.currentIndex)
    }

    function appendCatalog(items) {
        var merged = allSongs.slice()
        var decorated = decoratedSongs(items || [])
        for (var index = 0; index < decorated.length; ++index)
            merged.push(decorated[index])
        allSongs = merged
        applyFilter(searchList.currentIndex)
    }

    function applyFilter(preferredIndex) {
        var matches = []
        for (var index = 0; index < allSongs.length; ++index) {
            if (TextSearch.matchesNormalized(allSongs[index].searchKey, filterText))
                matches.push(allSongs[index])
        }
        matches.sort(function(left, right) {
            if (left.sortKey < right.sortKey) return -1
            if (left.sortKey > right.sortKey) return 1
            if (left.titleKey < right.titleKey) return -1
            if (left.titleKey > right.titleKey) return 1
            return String(left.videoId || "").localeCompare(String(right.videoId || ""))
        })
        songs = matches
        if (songs.length === 0) {
            searchList.currentIndex = -1
            return
        }
        var nextIndex = preferredIndex !== undefined ? preferredIndex : searchList.currentIndex
        searchList.currentIndex = Math.min(Math.max(0, nextIndex), songs.length - 1)
        searchList.positionViewAtIndex(searchList.currentIndex, ListView.Contain)
    }

    function queueEntryIdAt(index) {
        return index >= 0 && index < queue.length ? queue[index].entryId || "" : ""
    }

    function syncQueue(items) {
        var selectedId = queueEntryIdAt(queueList.currentIndex)
        var previousIndex = queueList.currentIndex
        queue = (items || []).slice()
        var restored = -1
        if (selectedId !== "") {
            for (var index = 0; index < queue.length; ++index) {
                if (queue[index].entryId === selectedId) {
                    restored = index
                    break
                }
            }
        }
        if (restored < 0 && queue.length > 0)
            restored = Math.min(Math.max(0, previousIndex), queue.length - 1)
        queueList.currentIndex = restored
        if (restored >= 0)
            queueList.positionViewAtIndex(restored, ListView.Contain)
    }

    function selectedSearchSong() {
        return searchList.currentIndex >= 0 ? songs[searchList.currentIndex] : null
    }

    function addSelectedSong() {
        var song = selectedSearchSong()
        if (!song)
            return
        if (karaokeBackend.enqueue(song)) {
            statusMessage = "ADDED: " + song.displayTitle
            statusTimer.restart()
            var persistedQueue = karaokeBackend.getQueue()
            songEnqueued(persistedQueue[persistedQueue.length - 1])
        }
    }

    function moveSelectedQueueEntry(direction) {
        var fromIndex = queueList.currentIndex
        var toIndex = fromIndex + direction
        if (fromIndex < 0 || toIndex < 0 || toIndex >= queue.length)
            return
        if (playbackActive && (fromIndex <= currentQueueIndex || toIndex <= currentQueueIndex)) {
            statusMessage = "ONLY UPCOMING SONGS CAN BE MOVED"
            statusTimer.restart()
            return
        }
        if (karaokeBackend.moveQueueEntry(fromIndex, toIndex)) {
            queueEntryMoved(fromIndex, toIndex)
            queueList.currentIndex = toIndex
            queueList.positionViewAtIndex(toIndex, ListView.Contain)
        }
    }

    function removeSelectedQueueEntry() {
        var entry = queueList.currentIndex >= 0 ? queue[queueList.currentIndex] : null
        if (!entry)
            return
        if (playbackActive && queueList.currentIndex <= currentQueueIndex) {
            statusMessage = queueList.currentIndex === currentQueueIndex
                          ? "THE CURRENT SONG CANNOT BE REMOVED"
                          : "PAST SONGS CANNOT BE REMOVED DURING PLAYBACK"
            statusTimer.restart()
            return
        }
        var removeIndex = queueList.currentIndex
        if (karaokeBackend.removeQueueEntry(entry.entryId))
            queueEntryRemoved(removeIndex, entry.entryId)
    }

    function startQueue() {
        if (queue.length === 0 || queueList.currentIndex < 0)
            return
        if (playbackActive) {
            var requested = queue[queueList.currentIndex]
            queueEntryRequested(queueList.currentIndex, requested.entryId || "")
            statusMessage = "PLAYING: " + (requested.displayTitle || "KARAOKE SONG")
            statusTimer.restart()
            return
        }
        var playlistPath = karaokeBackend.writePlaybackPlaylist()
        if (playlistPath === "") {
            statusMessage = "COULD NOT PREPARE PLAYLIST"
            statusTimer.restart()
            return
        }
        navigateTo("Player.qml", {
            playlistPath: playlistPath,
            startIndex: queueList.currentIndex
        }, {
            filterText: filterText,
            activePane: activePane,
            searchIndex: searchList.currentIndex,
            queueIndex: queueList.currentIndex
        })
    }

    function requestClearQueue() {
        if (queue.length === 0)
            return
        clearConfirmationVisible = true
        clearDialog.choiceIndex = 1
        clearDialog.forceActiveFocus()
    }

    function confirmClearQueue() {
        if (!clearConfirmationVisible)
            return
        clearDialog.accepted()
    }

    function cancelClearQueue() {
        if (!clearConfirmationVisible)
            return
        clearDialog.rejected()
    }

    function handlePlaybackCommand(command) {
        if (clearConfirmationVisible)
            return
        if (command === "karaoke-up") {
            activePane = 1
            if (moveMode)
                moveSelectedQueueEntry(-1)
            else if (queueList.currentIndex > 0)
                queueList.currentIndex--
        } else if (command === "karaoke-down") {
            activePane = 1
            if (moveMode)
                moveSelectedQueueEntry(1)
            else if (queueList.currentIndex < queue.length - 1)
                queueList.currentIndex++
        } else if (command === "karaoke-move-up") {
            activePane = 1
            moveSelectedQueueEntry(-1)
        } else if (command === "karaoke-move-down") {
            activePane = 1
            moveSelectedQueueEntry(1)
        } else if (command === "karaoke-move-mode") {
            activePane = 1
            moveMode = !moveMode
            statusMessage = moveMode ? "MOVE MODE ON" : "MOVE MODE OFF"
            statusTimer.restart()
        } else if (command === "karaoke-remove") {
            activePane = 1
            removeSelectedQueueEntry()
        } else if (command === "karaoke-clear") {
            requestClearQueue()
        } else if (command === "karaoke-play-selected") {
            activePane = 1
            startQueue()
        }
        queueList.positionViewAtIndex(queueList.currentIndex, ListView.Contain)
    }

    function handleKey(event) {
        if (clearConfirmationVisible)
            return

        if (event.key === Qt.Key_Tab) {
            activePane = activePane === 0 ? 1 : 0
            moveMode = false
            event.accepted = true
            return
        }

        if (activePane === 0) {
            if (event.key === Qt.Key_Right) {
                activePane = 1
                event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                if (searchList.currentIndex > 0) searchList.currentIndex--
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                if (searchList.currentIndex < searchList.count - 1) searchList.currentIndex++
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                addSelectedSong()
                event.accepted = true
            } else if (event.key === Qt.Key_Backspace) {
                if (filterText.length > 0) {
                    filterText = filterText.slice(0, -1)
                    applyFilter(0)
                } else {
                    goBack()
                }
                event.accepted = true
            } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back) {
                if (filterText.length > 0) {
                    filterText = ""
                    applyFilter(0)
                } else {
                    goBack()
                }
                event.accepted = true
            } else {
                var typed = event.text || ""
                if (!(event.modifiers & Qt.ControlModifier) &&
                    !(event.modifiers & Qt.MetaModifier) &&
                    !(event.modifiers & Qt.AltModifier) &&
                    typed.length === 1 && typed.charCodeAt(0) >= 32) {
                    filterText += typed
                    applyFilter(0)
                    event.accepted = true
                }
            }
            return
        }

        if (event.key === Qt.Key_Left) {
            activePane = 0
            moveMode = false
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            if (moveMode || (event.modifiers & Qt.ShiftModifier))
                moveSelectedQueueEntry(-1)
            else if (queueList.currentIndex > 0)
                queueList.currentIndex--
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            if (moveMode || (event.modifiers & Qt.ShiftModifier))
                moveSelectedQueueEntry(1)
            else if (queueList.currentIndex < queueList.count - 1)
                queueList.currentIndex++
            event.accepted = true
        } else if (event.key === Qt.Key_M) {
            moveMode = !moveMode
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            startQueue()
            event.accepted = true
        } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            removeSelectedQueueEntry()
            event.accepted = true
        } else if (event.key === Qt.Key_C) {
            requestClearQueue()
            event.accepted = true
        } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back) {
            if (moveMode)
                moveMode = false
            else if (playbackActive)
                goBack()
            else
                activePane = 0
            event.accepted = true
        }
    }

    focus: true
    Keys.onPressed: function(event) { handleKey(event) }

    Connections {
        target: karaokeBackend

        function onCatalogLoadStarted(hasCachedCatalog) {
            catalogLoading = !hasCachedCatalog
            catalogRefreshing = hasCachedCatalog
            catalogError = ""
        }
        function onCatalogReset(items, fromCache) {
            replaceCatalog(items)
        }
        function onCatalogItemsAppended(items) {
            appendCatalog(items)
        }
        function onCatalogLoadFinished(itemCount, fromCache) {
            catalogLoading = false
            catalogRefreshing = false
            catalogError = ""
        }
        function onCatalogLoadFailed(message, usingCache) {
            catalogLoading = false
            catalogRefreshing = false
            catalogError = usingCache ? "REFRESH FAILED - USING SAVED CATALOG" : message
        }
        function onQueueChanged(items) {
            syncQueue(items)
        }
    }

    AppBar {
        iconSource: moduleRoot.moduleIcon
        title: moduleRoot.moduleName
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.125
        anchors.leftMargin: root.sw * 0.125
    }

    Text {
        text: "SEARCH " + songs.length + "/" + allSongs.length +
              (catalogRefreshing ? " - REFRESHING" : "")
        color: activePane === 0 ? root.secondaryColor : root.tertiaryColor
        font.family: root.globalFont
        font.capitalization: Font.AllUppercase
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.205
        anchors.leftMargin: root.sw * 0.115625
        width: root.sw * 0.46
        elide: Text.ElideRight
        font.pixelSize: root.sh * 0.0291667
    }

    Text {
        text: "QUEUE " + queue.length + (moveMode ? " - MOVE MODE" : "")
        color: activePane === 1 ? root.secondaryColor : root.tertiaryColor
        font.family: root.globalFont
        font.capitalization: Font.AllUppercase
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.205
        anchors.leftMargin: root.sw * 0.60625
        width: root.sw * 0.28
        elide: Text.ElideRight
        font.pixelSize: root.sh * 0.0291667
    }

    ListView {
        id: searchList
        model: songs
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.25
        anchors.leftMargin: root.sw * 0.10625
        width: root.sw * 0.485
        height: root.sh * 0.525
        clip: true
        interactive: false

        delegate: SelectableMarqueeRow {
            width: searchList.width
            label: modelData.displayTitle || ""
            selected: activePane === 0 && searchList.currentIndex === index
            twoLine: true
            splitAtSeparator: true
            textSize: root.sh * 0.0229167
        }
    }

    ListView {
        id: queueList
        model: queue
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.25
        anchors.leftMargin: root.sw * 0.596875
        width: root.sw * 0.37
        height: root.sh * 0.525
        clip: true
        interactive: false

        delegate: SelectableMarqueeRow {
            width: queueList.width
            label: (index + 1) + ". " +
                   (modelData.entryId === currentEntryId ? "[PLAYING] " : "") +
                   (modelData.entryId === readyEntryId ? "[READY] " : "") +
                   (modelData.status === "failed" ? "[FAILED] " : "") +
                   (modelData.displayTitle || "")
            selected: activePane === 1 && queueList.currentIndex === index
            normalColor: modelData.entryId === currentEntryId
                         ? root.secondaryColor
                         : (modelData.status === "failed" ? root.tertiaryColor : root.primaryColor)
            twoLine: true
            splitAtSeparator: true
            textSize: root.sh * 0.021875
        }
    }

    Text {
        visible: catalogLoading && allSongs.length === 0
        text: "LOADING KARAOKE CATALOG..."
        color: root.tertiaryColor
        font.family: root.globalFont
        anchors.centerIn: searchList
        font.pixelSize: root.sh * 0.0416667
    }

    Text {
        visible: !catalogLoading && songs.length === 0
        text: filterText !== "" ? "NO MATCHES" : "NO SONGS FOUND"
        color: root.tertiaryColor
        font.family: root.globalFont
        anchors.centerIn: searchList
        font.pixelSize: root.sh * 0.0416667
    }

    Text {
        visible: catalogError !== ""
        text: catalogError
        color: root.tertiaryColor
        font.family: root.globalFont
        font.capitalization: Font.AllUppercase
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.sw * 0.115625
        anchors.bottomMargin: root.sh * 0.15
        width: root.sw * 0.77
        elide: Text.ElideRight
        font.pixelSize: root.sh * 0.025
    }

    Text {
        visible: filterText !== "" || statusMessage !== "" || playbackStatusText !== ""
        text: statusMessage !== "" ? statusMessage
              : (filterText !== "" ? "FILTER: " + filterText : playbackStatusText)
        color: root.secondaryColor
        font.family: root.globalFont
        font.capitalization: Font.AllUppercase
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.sw * 0.115625
        anchors.bottomMargin: root.sh * 0.125
        width: root.sw * 0.77
        elide: Text.ElideRight
        font.pixelSize: root.sh * 0.0291667
    }

    Text {
        text: activePane === 0
              ? "[TYPE]:SEARCH [ENTER]:ADD [TAB/RIGHT]:QUEUE [ESC]:BACK"
              : (playbackActive
                 ? "[ENTER]:PLAY [SHIFT+UP/DOWN]:MOVE [M]:MOVE MODE [DEL]:REMOVE [C]:CLEAR [ESC]:STOP"
                 : "[ENTER]:PLAY [SHIFT+UP/DOWN]:MOVE [M]:MOVE MODE [DEL]:REMOVE [C]:CLEAR")
        color: root.tertiaryColor
        font.family: root.globalFont
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: root.sh * 0.0833333
        anchors.leftMargin: root.sw * 0.115625
        width: root.sw * 0.77
        elide: Text.ElideRight
        font.pixelSize: root.sh * 0.025
    }

    ConfirmDialog {
        id: clearDialog
        visible: clearConfirmationVisible
        prompt: "CLEAR THE KARAOKE QUEUE?"
        confirmLabel: "CLEAR"
        cancelLabel: "CANCEL"
        onAccepted: {
            if (playbackActive) {
                karaokeBackend.clearQueueExcept(currentEntryId)
                upcomingQueueCleared()
            } else {
                karaokeBackend.clearQueue()
            }
            clearConfirmationVisible = false
            itemsRoot.forceActiveFocus()
        }
        onRejected: {
            clearConfirmationVisible = false
            itemsRoot.forceActiveFocus()
        }
    }

    Timer {
        id: statusTimer
        interval: 2500
        repeat: false
        onTriggered: statusMessage = ""
    }

    Component.onCompleted: {
        syncQueue(karaokeBackend.getQueue())
        karaokeBackend.loadCatalog()
        var searchRestore = navListState.searchIndex !== undefined ? navListState.searchIndex : 0
        var queueRestore = navListState.queueIndex !== undefined ? navListState.queueIndex : 0
        searchList.currentIndex = songs.length > 0 ? Math.min(searchRestore, songs.length - 1) : -1
        queueList.currentIndex = queue.length > 0 ? Math.min(queueRestore, queue.length - 1) : -1
    }
}
