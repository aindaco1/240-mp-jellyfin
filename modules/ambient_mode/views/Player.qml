import QtQuick
import Components

FocusScope {
    id: playerRoot

    property var navParams: ({})

    signal goBack()

    property string videoPath:      navParams.videoPath || ""
    property string audioPath:      navParams.audioPath || ""
    property bool   hasCustomAudio: audioPath !== ""
    property bool   shuffleVideo:   navParams.shuffleVideo || false
    property bool   shuffleAudio:   navParams.shuffleAudio || false
    property var    videoPaths:     navParams.videoPaths || []
    property var    audioPaths:     navParams.audioPaths || []

    focus: true

    function shuffled(values) {
        var result = values.slice()
        for (var i = result.length - 1; i > 0; i--) {
            var j = Math.floor(Math.random() * (i + 1))
            var value = result[i]
            result[i] = result[j]
            result[j] = value
        }
        return result
    }

    Keys.onPressed: function(event) {
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

    Connections {
        target: mpvController
        function onPlaybackEnded(finalPositionMs, finalDurationMs, reason) {
            ambientModeBackend.stopAudio()
            goBack()
        }
    }

    Component.onCompleted: {
        if (videoPath === "") {
            goBack()
            return
        }
        mpvController.loadAndPlayWithOptions(videoPath, {
            subtitleTrack: -2,
            loop: true,
            muteAudio: hasCustomAudio,
            oscMode: "ambient"
        })
        if (shuffleVideo && videoPaths.length > 1) {
            var remainingVideos = shuffled(videoPaths.filter(function(path) { return path !== videoPath }))
            for (var i = 0; i < remainingVideos.length; i++)
                mpvController.appendPlaylistItem(remainingVideos[i])
        }
        if (hasCustomAudio) {
            var tracks = [audioPath]
            if (shuffleAudio && audioPaths.length > 1)
                tracks = tracks.concat(shuffled(audioPaths.filter(function(path) { return path !== audioPath })))
            ambientModeBackend.startAudio(tracks, false)
        }
    }

    PlaybackControlPanel {
        anchors.fill: parent
        title: "LOOP PLAYBACK"
        subtitle: root.hasMediaOutputScreen ? "PLAYING ON MEDIA DISPLAY" : "PLAYING"
        stateText: hasCustomAudio ? "SEPARATE AUDIO ACTIVE" : ""
        footerText: "[ESC]:STOP [SPACE]:PAUSE"
        controls: [
            { key: "SPACE / ENTER", action: "Pause or resume video" },
            { key: "ARROWS", action: "Forward to video controls" },
            { key: "ESC / BACK", action: "Stop loop" }
        ]
    }
}
