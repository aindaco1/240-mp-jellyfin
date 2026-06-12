import QtQuick
import Components

FocusScope {
    id: detailRoot

    property var navParams: ({})

    signal navigateTo(string path, var params)
    signal goBack()

    property var item: navParams.item || {}
    property string libraryName: navParams.libraryName || ""
    property var detail: null
    property string errorMessage: ""
    property var audioStreams: []
    property var subtitleStreams: [{ "id": "-1", "mpvTrack": -1, "displayTitle": "OFF", "subFile": "" }]
    property int focusRow: 0
    property int audioIdx: 0
    property int subtitleIdx: 0

    function durationStr(ms) {
        if (!ms) return ""
        var totalMin = Math.floor(ms / 60000)
        var h = Math.floor(totalMin / 60)
        var m = totalMin % 60
        if (h > 0) return h + "HR:" + (m < 10 ? "0" : "") + m + "MIN"
        return m + "MIN"
    }

    function buildSubtitleStreams(d) {
        var subs = [{ "id": "-1", "mpvTrack": -1, "displayTitle": "OFF", "subFile": "" }]
        var loaded = d.subtitleStreams || []
        for (var i = 0; i < loaded.length; i++)
            subs.push(loaded[i])
        return subs
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
        return audioStreams[audioIdx].mpvTrack || 0
    }

    function selectedSubtitleTrack() {
        var selected = subtitleStreams[subtitleIdx]
        if (!selected)
            return -1
        if (selected.subFile && selected.subFile !== "")
            return 0
        if (selected.mpvTrack !== undefined && selected.mpvTrack !== null)
            return selected.mpvTrack
        return -1
    }

    function selectedSubtitleFiles() {
        var selected = subtitleStreams[subtitleIdx]
        if (selected && selected.subFile && selected.subFile !== "")
            return [selected.subFile]
        return []
    }

    Connections {
        target: jellyfinBackend
        function onItemLoaded(d) {
            detailRoot.detail = d
            detailRoot.errorMessage = ""
            detailRoot.audioStreams = d.audioStreams || []
            detailRoot.subtitleStreams = buildSubtitleStreams(d)
            detailRoot.audioIdx = 0
            detailRoot.subtitleIdx = 0
            detailRoot.focusRow = 0
        }
        function onStreamUrlReady(url, headers) {
            if (!detailRoot.detail) return
            detailRoot.navigateTo("Player.qml", {
                streamUrl: url,
                httpHeaders: headers,
                itemId: detailRoot.detail.id,
                title: detailRoot.detail.title,
                viewOffset: detailRoot.detail.viewOffset || 0,
                duration: detailRoot.detail.duration || 0,
                audioTrack: selectedAudioTrack(),
                subtitleTrack: selectedSubtitleTrack(),
                subtitleFiles: selectedSubtitleFiles()
            })
        }
        function onErrorOccurred(message) {
            detailRoot.errorMessage = message
        }
    }

    Component.onCompleted: {
        if (item.id)
            jellyfinBackend.load_item_detail(item.id)
    }

    focus: true

    Keys.onUpPressed: {
        if (focusRow > 0)
            focusRow--
    }
    Keys.onDownPressed: {
        if (detail) {
            var maxRow = maxFocusRow()
            if (focusRow < maxRow)
                focusRow++
        }
    }
    Keys.onLeftPressed: {
        if (!detail) return
        if (focusRow === 1 && audioStreams.length > 1)
            audioIdx = (audioIdx - 1 + audioStreams.length) % audioStreams.length
        else if (focusRow === 2 && subtitleStreams.length > 1)
            subtitleIdx = (subtitleIdx - 1 + subtitleStreams.length) % subtitleStreams.length
    }
    Keys.onRightPressed: {
        if (!detail) return
        if (focusRow === 1 && audioStreams.length > 1)
            audioIdx = (audioIdx + 1) % audioStreams.length
        else if (focusRow === 2 && subtitleStreams.length > 1)
            subtitleIdx = (subtitleIdx + 1) % subtitleStreams.length
    }
    Keys.onReturnPressed: {
        if (focusRow === 0 && detail)
            jellyfinBackend.build_stream_url(detail.id, detail.mediaSourceId || "")
    }
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace || event.key === Qt.Key_Back) {
            goBack()
            event.accepted = true
        }
    }

    AppBar {
        iconSource: moduleRoot.moduleIcon
        title: moduleRoot.moduleName
        subtitle: libraryName
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.125
        anchors.leftMargin: root.sw * 0.125
    }

    Text {
        visible: !detail && errorMessage === ""
        text: "LOADING..."
        color: root.tertiaryColor
        font.family: root.globalFont
        anchors.centerIn: parent
        font.pixelSize: root.sh * 0.05
    }

    Text {
        visible: errorMessage !== ""
        text: errorMessage
        color: root.tertiaryColor
        font.family: root.globalFont
        anchors.centerIn: parent
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        width: root.sw * 0.76875
        font.pixelSize: root.sh * 0.05
    }

    Item {
        visible: detail !== null
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
                    text: (detail && detail.viewOffset > 0) ? "RSUM \u25BA" : "PLAY \u25BA"
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
                    text: detail ? detail.title : ""
                    color: root.primaryColor
                    font.family: root.globalFont
                    font.capitalization: Font.AllUppercase
                    elide: Text.ElideRight
                    width: parent.width
                    font.pixelSize: root.sh * 0.05
                }

                Text {
                    text: {
                        if (!detail) return ""
                        var parts = []
                        if (detail.year) parts.push(String(detail.year))
                        if (detail.duration) parts.push(durationStr(detail.duration))
                        return parts.join(" - ")
                    }
                    color: root.secondaryColor
                    font.family: root.globalFont
                    font.capitalization: Font.AllUppercase
                    elide: Text.ElideRight
                    width: parent.width
                    font.pixelSize: root.sh * 0.0333333
                }

                Item {
                    id: summaryContainer
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: root.sh * 0.1375
                    clip: true

                    Text {
                        id: summaryText
                        anchors.left: parent.left
                        anchors.right: parent.right
                        text: detail ? detail.summary : ""
                        color: root.primaryColor
                        font.family: root.globalFont
                        wrapMode: Text.WordWrap
                        font.pixelSize: root.sh * 0.0291667
                        lineHeight: 1.3
                    }

                    SequentialAnimation {
                        running: detail !== null && summaryText.implicitHeight > summaryContainer.height
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) summaryText.y = 0
                        PauseAnimation { duration: 3000 }
                        NumberAnimation {
                            target: summaryText
                            property: "y"
                            to: summaryContainer.height - summaryText.implicitHeight
                            duration: Math.abs(to) * 120
                        }
                        PauseAnimation { duration: 4000 }
                        PropertyAction { target: summaryText; property: "y"; value: 0 }
                    }
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
