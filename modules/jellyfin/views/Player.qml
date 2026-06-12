import QtQuick

FocusScope {
    id: playerRoot

    property var navParams: ({})

    signal goBack()

    property string streamUrl: navParams.streamUrl || ""
    property var httpHeaders: navParams.httpHeaders || []
    property string itemTitle: navParams.title || ""
    property int viewOffset: navParams.viewOffset || 0
    property int audioTrack: navParams.audioTrack || 0
    property int subtitleTrack: (navParams.subtitleTrack !== undefined && navParams.subtitleTrack !== null)
                                ? navParams.subtitleTrack : -1
    property var subtitleFiles: navParams.subtitleFiles || []
    property bool overlayVisible: false
    property bool playbackErrorVisible: false
    property int choiceIndex: 0
    property string resumeSetting: "ask"

    focus: true

    function startPlayback(offsetMs) {
        mpvController.loadAndPlay(streamUrl, offsetMs / 1000.0,
                                  audioTrack, subtitleTrack, subtitleFiles, false, -1, 0.0, "",
                                  false, "", false, httpHeaders)
    }

    Keys.onPressed: function(event) {
        if (playbackErrorVisible) {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace || event.key === Qt.Key_Back ||
                event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                goBack()
                event.accepted = true
            }
        } else if (overlayVisible) {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace || event.key === Qt.Key_Back) {
                goBack()
                event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                choiceIndex = 0
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                choiceIndex = 1
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                overlayVisible = false
                startPlayback(choiceIndex === 0 ? viewOffset : 0)
                event.accepted = true
            }
        } else {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back) {
                mpvController.sendKey("ESC")
                event.accepted = true
            } else if (event.key === Qt.Key_Backspace) {
                mpvController.sendKey("BS")
                event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                mpvController.sendKey("UP")
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                mpvController.sendKey("DOWN")
                event.accepted = true
            } else if (event.key === Qt.Key_Left) {
                mpvController.sendKey("LEFT")
                event.accepted = true
            } else if (event.key === Qt.Key_Right) {
                mpvController.sendKey("RIGHT")
                event.accepted = true
            } else if (event.key === Qt.Key_Space) {
                mpvController.sendKey("SPACE")
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                mpvController.sendKey("ENTER")
                event.accepted = true
            }
        }
    }

    Connections {
        target: mpvController
        function onPlaybackFinished(finalPositionMs, finalDurationMs) {
            goBack()
        }
        function onPlaybackFailed() {
            playbackErrorVisible = true
        }
    }

    Component.onCompleted: {
        if (streamUrl === "") return
        resumeSetting = appCore.get_setting(moduleRoot.moduleId, "resume_playback") || "ask"
        if (resumeSetting === "ask" && viewOffset > 0)
            overlayVisible = true
        else
            startPlayback(resumeSetting === "no" ? 0 : viewOffset)
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    Rectangle {
        anchors.fill: parent
        color: root.surfaceColor
        visible: overlayVisible

        Rectangle {
            id: dialogRect
            color: root.surfaceColor
            anchors.centerIn: parent
            width: root.sw * 0.76875
            height: root.sh * 0.2833333

            Column {
                id: dialogColumn
                anchors.fill: parent
                spacing: root.sh * 0.05

                Text {
                    text: "RESUME PLAYBACK?"
                    color: root.secondaryColor
                    font.family: root.globalFont
                    font.pixelSize: root.sh * 0.0333333
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Column {
                    Repeater {
                        model: [
                            "Resume from " + formatTime(viewOffset),
                            "Start from the beginning"
                        ]
                        delegate: Item {
                            width: dialogColumn.width
                            height: root.sh * 0.0583333

                            Rectangle {
                                anchors.fill: delegateText
                                color: root.accentColor
                                visible: index === choiceIndex
                            }

                            Text {
                                id: delegateText
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData
                                color: index === choiceIndex ? root.surfaceColor : root.primaryColor
                                font.family: root.globalFont
                                font.capitalization: Font.AllUppercase
                                topPadding: root.sh * 0.0041667
                                leftPadding: root.sw * 0.009375
                                rightPadding: root.sw * 0.009375
                                bottomPadding: root.sh * 0.00625
                                font.pixelSize: root.sh * 0.0416667
                            }
                        }
                    }
                }

                Text {
                    text: "[ESC]:BACK [▲▼]:NAVIGATE [ENTER]:SELECT"
                    color: root.tertiaryColor
                    font.family: root.globalFont
                    font.pixelSize: root.sh * 0.0333333
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.surfaceColor
        visible: playbackErrorVisible

        Column {
            anchors.centerIn: parent
            width: root.sw * 0.76875
            spacing: root.sh * 0.05

            Text {
                text: "PLAYBACK FAILED"
                color: root.secondaryColor
                font.family: root.globalFont
                font.pixelSize: root.sh * 0.05
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "CHECK JELLYFIN STREAM OR MPV LOG"
                color: root.primaryColor
                font.family: root.globalFont
                font.capitalization: Font.AllUppercase
                font.pixelSize: root.sh * 0.0333333
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "[ESC]:BACK [ENTER]:BACK"
                color: root.tertiaryColor
                font.family: root.globalFont
                font.pixelSize: root.sh * 0.0333333
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    function formatTime(ms) {
        var s = Math.floor(ms / 1000)
        var h = Math.floor(s / 3600)
        var m = Math.floor((s % 3600) / 60)
        var sec = s % 60
        if (h > 0)
            return h + ":" + pad(m) + ":" + pad(sec)
        return m + ":" + pad(sec)
    }

    function pad(n) { return n < 10 ? "0" + n : "" + n }
}
