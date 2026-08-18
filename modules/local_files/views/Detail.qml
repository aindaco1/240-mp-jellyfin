import QtQuick
import Components

FocusScope {
    id: detailRoot

    property var navParams: ({})
    property string filePath: navParams.filePath || ""
    property string itemTitle: navParams.title || ""
    property var audioStreams: []
    property var subtitleStreams: [{ "id": -2, "mpvTrack": -2, "displayTitle": "OFF", "subFile": "" }]
    property var actions: []
    property int focusRow: 0
    property int actionIndex: 0
    property int audioIdx: 0
    property int subtitleIdx: 0
    property bool subtitleTouched: false
    property string statusMessage: ""

    signal navigateTo(string path, var params)
    signal goBack()

    function isPlaylist() { return localFilesBackend.isPlaylist(filePath) }
    function isImage() { return localFilesBackend.isImage(filePath) }
    function isAudio() { return localFilesBackend.isAudio(filePath) }

    function loadTracks() {
        if (filePath === "" || isPlaylist() || isImage())
            return
        var tracks = localFilesBackend.probeMediaTracks(filePath)
        audioStreams = tracks.audioStreams || []
        var subtitles = [{ "id": -2, "mpvTrack": -2, "displayTitle": "OFF", "subFile": "" }]
        var probed = tracks.subtitleStreams || []
        for (var index = 0; index < probed.length; ++index)
            subtitles.push(probed[index])
        subtitleStreams = subtitles
    }

    function buildActions() {
        var result = [{ id: "play", label: "PLAY \u25BA" }]
        if (isPlaylist()) {
            result.push({ id: "media", label: "ADD TO QUEUE" })
            result.push({ id: "soundtrack", label: "ADD SOUNDTRACK" })
        } else if (isAudio()) {
            result.push({ id: "soundtrack", label: "ADD SOUNDTRACK" })
        } else {
            result.push({ id: "media", label: "ADD TO QUEUE" })
        }
        actions = result
    }

    function selectedAudioTrack() {
        var selected = audioStreams[audioIdx]
        return selected ? (selected.mpvTrack || selected.id || 0) : 0
    }

    function selectedSubtitleTrack() {
        var selected = subtitleStreams[subtitleIdx]
        if (!selected)
            return -1
        if (selected.subFile)
            return 0
        if (selected.mpvTrack !== undefined && selected.mpvTrack !== null)
            return selected.mpvTrack
        return selected.id !== undefined ? selected.id : -1
    }

    function selectedSubtitleFiles() {
        var selected = subtitleStreams[subtitleIdx]
        return selected && selected.subFile ? [selected.subFile] : []
    }

    function queueCandidate() {
        return {
            filePath: filePath,
            audioTrack: selectedAudioTrack(),
            subtitleTrack: selectedSubtitleTrack(),
            subtitleFiles: selectedSubtitleFiles(),
            subtitleExplicit: subtitleTouched
        }
    }

    function performAction() {
        var action = actions[actionIndex]
        if (!action || filePath === "")
            return
        if (action.id === "play") {
            navigateTo("Player.qml", {
                filePath: filePath,
                title: itemTitle,
                audioTrack: selectedAudioTrack(),
                subtitleTrack: selectedSubtitleTrack(),
                subtitleFiles: selectedSubtitleFiles(),
                subtitleExplicit: subtitleTouched
            })
            return
        }
        var added = localFilesBackend.enqueue(action.id, queueCandidate())
        if (added > 0) {
            statusMessage = added === 1 ? (action.id === "media" ? "ADDED TO QUEUE"
                                                                  : "ADDED TO SOUNDTRACK")
                                       : "ADDED " + added + " ITEMS"
        } else {
            statusMessage = action.id === "media"
                          ? "NO PLAYABLE VIDEO OR IMAGE ITEMS"
                          : "NO PLAYABLE AUDIO ITEMS"
        }
        statusTimer.restart()
    }

    function visibleRows() {
        var rows = [0]
        if (audioStreams.length > 0)
            rows.push(1)
        if (subtitleStreams.length > 1)
            rows.push(2)
        return rows
    }

    function moveFocus(direction) {
        var rows = visibleRows()
        var current = rows.indexOf(focusRow)
        focusRow = rows[(current + direction + rows.length) % rows.length]
    }

    focus: true
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace || event.key === Qt.Key_Back) {
            goBack()
        } else if (event.key === Qt.Key_Up) {
            moveFocus(-1)
        } else if (event.key === Qt.Key_Down) {
            moveFocus(1)
        } else if (event.key === Qt.Key_Left) {
            if (focusRow === 0)
                actionIndex = (actionIndex - 1 + actions.length) % actions.length
            else if (focusRow === 1 && audioStreams.length > 1)
                audioIdx = (audioIdx - 1 + audioStreams.length) % audioStreams.length
            else if (focusRow === 2 && subtitleStreams.length > 1) {
                subtitleIdx = (subtitleIdx - 1 + subtitleStreams.length) % subtitleStreams.length
                subtitleTouched = true
            }
        } else if (event.key === Qt.Key_Right) {
            if (focusRow === 0)
                actionIndex = (actionIndex + 1) % actions.length
            else if (focusRow === 1 && audioStreams.length > 1)
                audioIdx = (audioIdx + 1) % audioStreams.length
            else if (focusRow === 2 && subtitleStreams.length > 1) {
                subtitleIdx = (subtitleIdx + 1) % subtitleStreams.length
                subtitleTouched = true
            }
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            performAction()
        } else {
            return
        }
        event.accepted = true
    }

    AppBar {
        iconSource: moduleRoot.moduleIcon
        title: moduleRoot.moduleName
        subtitle: "Playback & Queue"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.125
        anchors.leftMargin: root.sw * 0.125
    }

    Text {
        text: itemTitle
        color: root.primaryColor
        font.family: root.globalFont
        font.capitalization: Font.AllUppercase
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.225
        anchors.leftMargin: root.sw * 0.115625
        width: root.sw * 0.76875
        elide: Text.ElideMiddle
        font.pixelSize: root.sh * 0.0416667
    }

    Row {
        id: actionRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.30625
        anchors.leftMargin: root.sw * 0.115625
        width: root.sw * 0.76875
        height: root.sh * 0.0958333
        spacing: root.sw * 0.009375

        Repeater {
            model: actions
            delegate: Rectangle {
                width: (actionRow.width - actionRow.spacing * (actions.length - 1)) / actions.length
                height: actionRow.height
                color: focusRow === 0 && actionIndex === index ? root.accentColor : root.surfaceColor
                border.color: focusRow === 0 && actionIndex === index ? root.accentColor : root.tertiaryColor
                border.width: root.sh * 0.003125

                Text {
                    anchors.centerIn: parent
                    width: parent.width - root.sw * 0.0125
                    text: modelData.label
                    color: focusRow === 0 && actionIndex === index ? root.surfaceColor : root.primaryColor
                    font.family: root.globalFont
                    font.capitalization: Font.AllUppercase
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    font.pixelSize: root.sh * 0.0291667
                }
            }
        }
    }

    Column {
        anchors.top: actionRow.bottom
        anchors.left: actionRow.left
        anchors.right: actionRow.right
        anchors.topMargin: root.sh * 0.0333333
        spacing: 0

        PlaybackSelectorRow {
            visible: audioStreams.length > 0
            width: parent.width
            height: visible ? root.sh * 0.0583333 : 0
            label: "Audio"
            value: audioStreams[audioIdx] ? audioStreams[audioIdx].displayTitle : "DEFAULT"
            selected: focusRow === 1
            canGoPrevious: audioStreams.length > 1
            canGoNext: audioStreams.length > 1
            primaryColor: root.primaryColor
            tertiaryColor: root.tertiaryColor
            accentColor: root.accentColor
            surfaceColor: root.surfaceColor
            fontFamily: root.globalFont
        }

        PlaybackSelectorRow {
            visible: subtitleStreams.length > 1
            width: parent.width
            height: visible ? root.sh * 0.0583333 : 0
            label: "Subtitles"
            value: subtitleStreams[subtitleIdx] ? subtitleStreams[subtitleIdx].displayTitle : "OFF"
            selected: focusRow === 2
            canGoPrevious: subtitleStreams.length > 1
            canGoNext: subtitleStreams.length > 1
            primaryColor: root.primaryColor
            tertiaryColor: root.tertiaryColor
            accentColor: root.accentColor
            surfaceColor: root.surfaceColor
            fontFamily: root.globalFont
        }
    }

    Text {
        visible: statusMessage !== ""
        text: statusMessage
        color: root.secondaryColor
        font.family: root.globalFont
        font.capitalization: Font.AllUppercase
        anchors.left: actionRow.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.sh * 0.125
        width: actionRow.width
        elide: Text.ElideRight
        font.pixelSize: root.sh * 0.0291667
    }

    Text {
        text: "[ESC]:BACK [UP/DOWN]:ROW [LEFT/RIGHT]:CHANGE [ENTER]:SELECT"
        color: root.tertiaryColor
        font.family: root.globalFont
        anchors.bottom: parent.bottom
        anchors.left: actionRow.left
        anchors.bottomMargin: root.sh * 0.0833333
        font.pixelSize: root.sh * 0.025
    }

    Timer {
        id: statusTimer
        interval: 2500
        repeat: false
        onTriggered: statusMessage = ""
    }

    Component.onCompleted: {
        buildActions()
        loadTracks()
    }
}
