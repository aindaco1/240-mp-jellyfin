import QtQuick
import Components
import "JellyfinMedia.js" as JellyfinMedia

FocusScope {
    id: playerRoot

    property var navParams: ({})

    signal goBack()
    signal updateBackItem(var item)

    property var detail: navParams.detail || ({})
    property string streamUrl: ""
    property var httpHeaders: []
    property string itemId: navParams.itemId || detail.id || ""
    property string mediaSourceId: navParams.mediaSourceId || detail.mediaSourceId || itemId
    property string itemTitle: navParams.title || ""
    property int viewOffset: navParams.viewOffset || 0
    property var audioStreams: navParams.audioStreams || []
    property var subtitleStreams: navParams.subtitleStreams || []
    property int audioIdx: navParams.audioIdx || 0
    property int subtitleIdx: navParams.subtitleIdx || 0
    property bool overlayVisible: false
    property bool playbackErrorVisible: false
    property int choiceIndex: 0
    property string resumeSetting: "ask"
    property bool autoplayNext: false
    property bool pendingTranscodeRetry: false
    property bool stoppedReported: false
    property int pendingStartMs: 0
    property int lastKnownPositionMs: 0
    property int lastKnownDurationMs: 0
    property var segments: []
    property var activeSegment: null
    property bool skipPromptShown: false
    property bool introSkipped: false
    property bool outroSkipped: false
    property string introSkipSetting: "Off"
    property string outroSkipSetting: "Off"

    focus: true

    function toTicks(ms) { return Math.max(0, Math.floor(ms || 0)) * 10000 }

    function requestPlayback(offsetMs, forceTranscode) {
        pendingStartMs = offsetMs || 0
        jellyfinBackend.request_playback(
            itemId, mediaSourceId,
            JellyfinMedia.selectedAudioStreamIndex(audioStreams, audioIdx),
            JellyfinMedia.selectedSubtitleStreamIndex(subtitleStreams, subtitleIdx),
            forceTranscode || false, toTicks(pendingStartMs))
    }

    function launchMpv() {
        var lowerUrl = streamUrl.toLowerCase()
        var transcoding = lowerUrl.indexOf("master.m3u8") >= 0 ||
                          lowerUrl.indexOf("/videos/") < 0
        var audioTrack = transcoding ? 0 : JellyfinMedia.selectedAudioTrack(audioStreams, audioIdx)
        var subtitleTrack = transcoding ? -2 : JellyfinMedia.selectedSubtitleTrack(subtitleStreams, subtitleIdx)
        var subtitleFiles = transcoding ? [] : JellyfinMedia.selectedSubtitleFiles(subtitleStreams, subtitleIdx)
        mpvController.loadAndPlayWithOptions(streamUrl, {
            startSeconds: pendingStartMs / 1000.0,
            audioTrack: audioTrack,
            subtitleTrack: subtitleTrack,
            subtitleFiles: subtitleFiles,
            httpHeaderFields: httpHeaders
        })
    }

    function reportStopped(failed) {
        if (stoppedReported) return
        stoppedReported = true
        jellyfinBackend.report_playback_stopped(
            itemId, mediaSourceId,
            toTicks(lastKnownPositionMs || mpvController.position || pendingStartMs),
            failed || false)
    }

    function findActiveSegment(ms) {
        for (var i = 0; i < segments.length; i++) {
            if (ms >= segments[i].startMs && ms < segments[i].endMs)
                return segments[i]
        }
        return null
    }

    function applyTrackPreferences() {
        audioIdx = JellyfinMedia.preferredAudioIndex(
            audioStreams, jellyfinBackend.get_last_audio_language())
        subtitleIdx = JellyfinMedia.preferredSubtitleIndex(
            subtitleStreams, jellyfinBackend.get_last_subtitle_language())
    }

    function advanceToEpisode(next) {
        detail = next
        itemId = next.id
        mediaSourceId = next.mediaSourceId || next.id
        itemTitle = JellyfinMedia.playbackTitle(next)
        viewOffset = next.viewOffset || 0
        audioStreams = next.audioStreams || []
        subtitleStreams = JellyfinMedia.buildSubtitleStreams(next)
        applyTrackPreferences()
        stoppedReported = false
        pendingTranscodeRetry = false
        lastKnownPositionMs = 0
        lastKnownDurationMs = 0
        segments = []
        activeSegment = null
        skipPromptShown = false
        introSkipped = false
        outroSkipped = false
        updateBackItem(next)
        requestPlayback(viewOffset, false)
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
                requestPlayback(choiceIndex === 0 ? viewOffset : 0, false)
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
        function onPositionChanged(ms) {
            if (ms > 0) lastKnownPositionMs = ms
            if (segments.length > 0) {
                var segment = findActiveSegment(ms)
                if (segment && segment !== activeSegment) {
                    activeSegment = segment
                    var setting = segment.type === "Intro" ? introSkipSetting : outroSkipSetting
                    if (setting === "Auto") {
                        if (segment.type === "Intro" && !introSkipped) introSkipped = true
                        else if (segment.type === "Outro" && !outroSkipped) outroSkipped = true
                        else return
                        mpvController.seekTo(segment.endMs)
                    } else if (setting === "Button" && !skipPromptShown) {
                        skipPromptShown = true
                        mpvController.showOsdSkipPrompt()
                    }
                } else if (!segment && activeSegment) {
                    activeSegment = null
                    skipPromptShown = false
                    mpvController.clearOsdPrompt()
                }
            }
        }
        function onDurationChanged(ms) {
            if (ms > 0) lastKnownDurationMs = ms
        }
        function onSkipRequested() {
            if (!activeSegment) return
            if (activeSegment.type === "Intro") introSkipped = true
            else outroSkipped = true
            mpvController.seekTo(activeSegment.endMs)
            mpvController.clearOsdPrompt()
        }
        function onPlaybackEnded(finalPositionMs, finalDurationMs, reason) {
            if (reason === "failed" && !pendingTranscodeRetry &&
                    streamUrl.toLowerCase().indexOf("master.m3u8") < 0) {
                reportStopped(true)
                stoppedReported = false
                pendingTranscodeRetry = true
                requestPlayback(lastKnownPositionMs || pendingStartMs, true)
                return
            }
            reportStopped(reason === "failed")
            if (reason === "eof" && autoplayNext && detail.type === "episode") {
                jellyfinBackend.load_next_episode(itemId)
            } else if (reason === "failed") {
                playbackErrorVisible = true
            } else {
                goBack()
            }
        }
    }

    Connections {
        target: jellyfinBackend
        function onStreamUrlReady(url, headers) {
            streamUrl = url
            httpHeaders = headers || []
            launchMpv()
            if (introSkipSetting !== "Off" || outroSkipSetting !== "Off")
                jellyfinBackend.fetchSegments(itemId)
        }
        function onNextEpisodeReady(next) {
            if (!next || !next.id) goBack()
            else advanceToEpisode(next)
        }
        function onSegmentsReady(segmentItemId, loadedSegments) {
            if (segmentItemId === itemId) segments = loadedSegments || []
        }
        function onErrorOccurred(message) {
            playbackErrorVisible = true
        }
    }

    Timer {
        interval: 10000
        repeat: true
        running: streamUrl !== "" && !overlayVisible && !playbackErrorVisible
        onTriggered: jellyfinBackend.update_playback_progress(
            itemId, mediaSourceId, toTicks(lastKnownPositionMs || mpvController.position), false)
    }

    Component.onCompleted: {
        if (itemId === "") return
        resumeSetting = appCore.get_setting(moduleRoot.moduleId, "resume_playback") || "ask"
        var autoplayRaw = appCore.get_setting(moduleRoot.moduleId, "autoplay_next_episode")
        autoplayNext = autoplayRaw === true || autoplayRaw === "ON"
        introSkipSetting = appCore.get_setting(moduleRoot.moduleId, "intro_skip") || "Off"
        outroSkipSetting = appCore.get_setting(moduleRoot.moduleId, "outro_skip") || "Off"
        if (resumeSetting === "ask" && viewOffset > 0)
            overlayVisible = true
        else
            requestPlayback(resumeSetting === "no" ? 0 : viewOffset, false)
    }

    Component.onDestruction: reportStopped(false)

    PlaybackControlPanel {
        anchors.fill: parent
        title: itemTitle !== "" ? itemTitle : "JELLYFIN PLAYBACK"
        subtitle: root.hasMediaOutputScreen ? "PLAYING ON MEDIA DISPLAY" : "PLAYING"
        stateText: mpvController.duration > 0 ? (formatTime(mpvController.position) + " / " + formatTime(mpvController.duration)) : ""
        footerText: "[ESC]:STOP [SPACE]:PAUSE [ARROWS]:SEEK"
        controls: [
            { key: "SPACE / ENTER", action: "Pause or resume" },
            { key: "LEFT / RIGHT", action: "Seek" },
            { key: "UP / DOWN", action: "Adjust playback" },
            { key: "ESC / BACK", action: "Stop playback" }
        ]
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
