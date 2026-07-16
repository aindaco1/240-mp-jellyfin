import QtQuick
import Components

FocusScope {
    id: detailRoot

    property var navParams: ({})

    signal navigateTo(string path, var params)
    signal goBack()

    property string filePath: navParams.filePath || ""
    property string itemTitle: navParams.title || ""
    property var audioStreams: []
    property var subtitleStreams: [{ "id": -1, "mpvTrack": -1, "displayTitle": "OFF", "subFile": "" }]
    property int focusRow: 0
    property int audioIdx: 0
    property int subtitleIdx: 0
    property bool subtitleTouched: false

    function isPlaylist(path) {
        return localFilesBackend.isPlaylist(path)
    }

    function loadTracks() {
        if (filePath === "" || isPlaylist(filePath) || localFilesBackend.isImage(filePath))
            return

        var tracks = localFilesBackend.probeMediaTracks(filePath)
        audioStreams = tracks.audioStreams || []

        var subs = [{ "id": -1, "mpvTrack": -1, "displayTitle": "OFF", "subFile": "" }]
        var probedSubs = tracks.subtitleStreams || []
        for (var i = 0; i < probedSubs.length; i++)
            subs.push(probedSubs[i])
        subtitleStreams = subs
    }

    function maxFocusRow() {
        var maxRow = 0
        if (audioStreams.length > 0)
            maxRow = 1
        if (subtitleStreams.length > 1)
            maxRow = 2
        return maxRow
    }

    function selectedAudioTrack() {
        if (!audioStreams[audioIdx])
            return 0
        return audioStreams[audioIdx].mpvTrack || audioStreams[audioIdx].id || 0
    }

    function selectedSubtitleTrack() {
        var selected = subtitleStreams[subtitleIdx]
        if (!selected)
            return -1
        if (selected.subFile && selected.subFile !== "")
            return 0
        if (selected.mpvTrack !== undefined && selected.mpvTrack !== null)
            return selected.mpvTrack
        if (selected.id !== undefined && selected.id !== null)
            return selected.id
        return -1
    }

    function selectedSubtitleFiles() {
        var selected = subtitleStreams[subtitleIdx]
        if (selected && selected.subFile && selected.subFile !== "")
            return [selected.subFile]
        return []
    }

    function playSelected() {
        if (filePath === "")
            return
        navigateTo("Player.qml", {
            filePath: filePath,
            title: itemTitle,
            audioTrack: selectedAudioTrack(),
            subtitleTrack: selectedSubtitleTrack(),
            subtitleFiles: selectedSubtitleFiles(),
            subtitleExplicit: subtitleTouched
        })
    }

    Component.onCompleted: {
        loadTracks()
        focusRow = 0
    }

    focus: true

    Keys.onUpPressed: {
        if (focusRow > 0)
            focusRow--
    }
    Keys.onDownPressed: {
        var maxRow = maxFocusRow()
        if (focusRow < maxRow)
            focusRow++
    }
    Keys.onLeftPressed: {
        if (focusRow === 1 && audioStreams.length > 1)
            audioIdx = (audioIdx - 1 + audioStreams.length) % audioStreams.length
        else if (focusRow === 2 && subtitleStreams.length > 1) {
            subtitleIdx = (subtitleIdx - 1 + subtitleStreams.length) % subtitleStreams.length
            subtitleTouched = true
        }
    }
    Keys.onRightPressed: {
        if (focusRow === 1 && audioStreams.length > 1)
            audioIdx = (audioIdx + 1) % audioStreams.length
        else if (focusRow === 2 && subtitleStreams.length > 1) {
            subtitleIdx = (subtitleIdx + 1) % subtitleStreams.length
            subtitleTouched = true
        }
    }
    Keys.onReturnPressed: playSelected()
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace || event.key === Qt.Key_Back) {
            goBack()
            event.accepted = true
        }
    }

    AppBar {
        iconSource: moduleRoot.moduleIcon
        title: moduleRoot.moduleName
        subtitle: "Playback"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.125
        anchors.leftMargin: root.sw * 0.125
    }

    Item {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.25
        anchors.leftMargin: root.sw * 0.115625
        width: root.sw * 0.76875
        height: root.sh * 0.525
        clip: true

        Row {
            id: itemDetails
            height: root.sh * 0.35
            spacing: root.sw * 0.0375

            Rectangle {
                color: focusRow === 0 ? root.accentColor : root.surfaceColor
                border.color: focusRow === 0 ? root.accentColor : root.tertiaryColor
                width: root.sw * 0.1875
                height: root.sh * 0.1166667
                border.width: root.sh * 0.003125

                Text {
                    anchors.centerIn: parent
                    text: "PLAY \u25BA"
                    color: focusRow === 0 ? root.surfaceColor : root.primaryColor
                    font.family: root.globalFont
                    font.pixelSize: root.sh * 0.05
                }
            }

            Column {
                topPadding: root.sh * 0.0083333
                width: root.sw * 0.54375
                spacing: root.sh * 0.0166667

                Text {
                    text: itemTitle
                    color: root.primaryColor
                    font.family: root.globalFont
                    font.capitalization: Font.AllUppercase
                    elide: Text.ElideRight
                    width: parent.width
                    font.pixelSize: root.sh * 0.05
                }

                Text {
                    text: isPlaylist(filePath) ? "PLAYLIST"
                          : localFilesBackend.isImage(filePath) ? "IMAGE"
                          : "LOCAL MEDIA"
                    color: root.secondaryColor
                    font.family: root.globalFont
                    font.capitalization: Font.AllUppercase
                    elide: Text.ElideRight
                    width: parent.width
                    font.pixelSize: root.sh * 0.0333333
                }

                Text {
                    text: {
                        var parts = []
                        if (audioStreams.length > 0)
                            parts.push(audioStreams.length + " AUDIO")
                        if (subtitleStreams.length > 1)
                            parts.push((subtitleStreams.length - 1) + " SUBTITLE")
                        return parts.length > 0 ? parts.join(" - ") : "DEFAULT TRACKS"
                    }
                    color: root.primaryColor
                    font.family: root.globalFont
                    font.capitalization: Font.AllUppercase
                    elide: Text.ElideRight
                    width: parent.width
                    font.pixelSize: root.sh * 0.0291667
                }
            }
        }

        Text {
            id: pbSettingsLabel
            visible: audioStreams.length > 0 || subtitleStreams.length > 1
            text: "Playback Settings:"
            color: root.secondaryColor
            font.family: root.globalFont
            font.capitalization: Font.AllUppercase
            anchors.top: itemDetails.bottom
            anchors.topMargin: root.sh * 0.0145833
            leftPadding: root.sw * 0.009375
            rightPadding: root.sw * 0.009375
            font.pixelSize: root.sh * 0.0291667
        }

        Item {
            id: audioRow
            visible: audioStreams.length > 0
            anchors.top: pbSettingsLabel.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: root.sh * 0.0145833
            height: visible ? root.sh * 0.0583333 : 0

            Rectangle {
                anchors.fill: parent
                color: focusRow === 1 ? root.accentColor : "transparent"
            }

            Text {
                text: "Audio"
                color: focusRow === 1 ? root.surfaceColor : root.primaryColor
                font.family: root.globalFont
                font.capitalization: Font.AllUppercase
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: root.sw * 0.009375
                font.pixelSize: root.sh * 0.0416667
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: root.sw * 0.009375
                width: root.sw * 0.5
                spacing: root.sw * 0.00625

                Text {
                    text: "\u25C4"
                    color: focusRow === 1 ? root.surfaceColor : root.tertiaryColor
                    font.family: root.globalFont
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: root.sh * 0.0375
                }
                Text {
                    text: audioStreams[audioIdx] ? audioStreams[audioIdx].displayTitle : ""
                    color: focusRow === 1 ? root.surfaceColor : root.primaryColor
                    font.family: root.globalFont
                    font.capitalization: Font.AllUppercase
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - root.sw * 0.075
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignRight
                    font.pixelSize: root.sh * 0.0416667
                }
                Text {
                    text: "\u25BA"
                    color: focusRow === 1 ? root.surfaceColor : root.tertiaryColor
                    font.family: root.globalFont
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: root.sh * 0.0375
                }
            }
        }

        Item {
            id: subtitleRow
            visible: subtitleStreams.length > 1
            anchors.top: audioRow.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: visible ? root.sh * 0.0583333 : 0

            Rectangle {
                anchors.fill: parent
                color: focusRow === 2 ? root.accentColor : "transparent"
            }

            Text {
                text: "Subtitles"
                color: focusRow === 2 ? root.surfaceColor : root.primaryColor
                font.family: root.globalFont
                font.capitalization: Font.AllUppercase
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: root.sw * 0.009375
                font.pixelSize: root.sh * 0.0416667
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: root.sw * 0.009375
                width: root.sw * 0.5
                spacing: root.sw * 0.00625

                Text {
                    text: "\u25C4"
                    color: focusRow === 2 ? root.surfaceColor : root.tertiaryColor
                    font.family: root.globalFont
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: root.sh * 0.0375
                }
                Text {
                    text: subtitleStreams[subtitleIdx] ? subtitleStreams[subtitleIdx].displayTitle : ""
                    color: focusRow === 2 ? root.surfaceColor : root.primaryColor
                    font.family: root.globalFont
                    font.capitalization: Font.AllUppercase
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - root.sw * 0.075
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignRight
                    font.pixelSize: root.sh * 0.0416667
                }
                Text {
                    text: "\u25BA"
                    color: focusRow === 2 ? root.surfaceColor : root.tertiaryColor
                    font.family: root.globalFont
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: root.sh * 0.0375
                }
            }
        }
    }

    Text {
        text: "[ESC]:BACK [\u25B2\u25BC]:NAVIGATE [\u25C4\u25BA]:CHANGE [ENTER]:PLAY"
        color: root.tertiaryColor
        font.family: root.globalFont
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: root.sh * 0.1041667
        anchors.leftMargin: root.sw * 0.125
        font.pixelSize: root.sh * 0.0333333
    }
}
