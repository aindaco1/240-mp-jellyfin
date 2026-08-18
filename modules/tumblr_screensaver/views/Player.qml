import QtQuick
import Components

FocusScope {
    id: playerRoot

    property var navParams: ({})
    property string tumblrUrl: navParams.tumblrUrl || ""
    property string loadState: "loading"
    property string errorText: ""
    property string sourceUrl: ""
    property string blogTitle: ""
    property string statusText: ""
    property var images: []
    property bool paused: false
    property int loadedImageCount: 0
    property int postsSeen: 0
    property int totalPosts: -1
    readonly property bool usingExternalOutput: outputLease.active

    signal goBack()

    focus: true

    function imageTitle(item) {
        if (!item)
            return blogTitle || "TUMBLR"
        return item.title || blogTitle || "TUMBLR"
    }

    function setStatus(text) {
        statusText = text
        statusTimer.restart()
    }

    function showError(message) {
        loadState = "error"
        errorText = message
        paused = false
        montage.stop()
    }

    function togglePause() {
        if (loadState !== "playing")
            return
        paused = !paused
        setStatus(paused ? "PAUSED" : imageTitle(montage.currentItem))
    }

    function handlePlayerKey(event) {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back || event.key === Qt.Key_Backspace) {
            montage.stop()
            goBack()
            event.accepted = true
        } else if (loadState === "error" && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            loadState = "loading"
            errorText = ""
            tumblrScreensaverBackend.loadImages(tumblrUrl)
            event.accepted = true
        } else if (loadState === "playing" && (event.key === Qt.Key_Right || event.key === Qt.Key_Down)) {
            montage.next()
            event.accepted = true
        } else if (loadState === "playing" && event.key === Qt.Key_Space) {
            togglePause()
            event.accepted = true
        }
    }

    Keys.onPressed: function(event) { handlePlayerKey(event) }

    MediaOutputLease {
        id: outputLease
        host: root
        enabled: root.hasMediaOutputScreen
        requested: true
        opaque: true
        acceptsFocus: true
    }

    Connections {
        target: tumblrScreensaverBackend

        function onLoadStarted(url) {
            playerRoot.sourceUrl = url
            playerRoot.loadState = "loading"
            playerRoot.errorText = ""
            playerRoot.loadedImageCount = 0
            playerRoot.postsSeen = 0
            playerRoot.totalPosts = -1
        }

        function onLoadProgress(imageCount, seenPosts, allPosts) {
            playerRoot.loadedImageCount = imageCount
            playerRoot.postsSeen = seenPosts
            playerRoot.totalPosts = allPosts
        }

        function onImagesLoaded(loadedImages, loadedBlogTitle, loadedTotalPosts) {
            playerRoot.images = loadedImages || []
            playerRoot.blogTitle = loadedBlogTitle || "Tumblr"
            playerRoot.totalPosts = loadedTotalPosts
            if (playerRoot.images.length === 0) {
                playerRoot.showError("No images were found on that Tumblr.")
                return
            }
            playerRoot.paused = false
            montage.items = playerRoot.images
            montage.start()
        }

        function onErrorOccurred(message) {
            playerRoot.showError(message)
        }
    }

    Connections {
        target: root
        function onMediaOutputKeyPressed(event) {
            if (playerRoot.usingExternalOutput)
                playerRoot.handlePlayerKey(event)
        }
    }

    Timer {
        id: statusTimer
        interval: 3400
        repeat: false
        onTriggered: playerRoot.statusText = ""
    }

    PlaybackControlPanel {
        anchors.fill: parent
        visible: playerRoot.usingExternalOutput
        title: playerRoot.blogTitle !== "" ? playerRoot.blogTitle : "TUMBLR MONTAGE"
        subtitle: "SHOWING ON MEDIA DISPLAY"
        stateText: playerRoot.loadState === "loading"
                   ? (playerRoot.loadedImageCount + " IMAGES  " + playerRoot.postsSeen + "/" + (playerRoot.totalPosts >= 0 ? playerRoot.totalPosts : "?") + " POSTS")
                   : playerRoot.loadState === "error" ? playerRoot.errorText
                     : (playerRoot.paused ? "PAUSED" : playerRoot.imageTitle(montage.currentItem))
        footerText: "[ESC]:BACK [SPACE]:PAUSE [RIGHT]:NEXT"
        controls: [
            { key: "RIGHT / DOWN", action: "Next image" },
            { key: "SPACE", action: "Pause or resume" },
            { key: "ESC / BACK", action: "Stop montage" }
        ]
    }

    Item {
        id: outputSurface
        parent: playerRoot.usingExternalOutput ? root.mediaOutputLayer : playerRoot
        width: parent ? parent.width : playerRoot.width
        height: parent ? parent.height : playerRoot.height

        ImageMontage {
            id: montage
            anchors.fill: parent
            paused: playerRoot.paused
            showDurationMs: 6200
            transitionDurationMs: 1250

            onStarted: {
                playerRoot.loadState = "playing"
                playerRoot.errorText = ""
                playerRoot.setStatus(playerRoot.imageTitle(currentItem))
            }
            onCurrentItemChanged: {
                if (running && currentIndex >= 0)
                    playerRoot.setStatus(playerRoot.imageTitle(currentItem))
            }
            onExhausted: playerRoot.showError("No Tumblr images could be displayed.")
        }

        Rectangle {
            anchors.fill: parent
            color: root.surfaceColor
            visible: playerRoot.loadState === "loading" || playerRoot.loadState === "error"
            z: 1100

            Column {
                anchors.centerIn: parent
                width: outputSurface.width * 0.75
                spacing: outputSurface.height * 0.035

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: playerRoot.loadState === "loading" ? "LOADING TUMBLR" : "TUMBLR ERROR"
                    color: root.secondaryColor
                    font.family: root.globalFont
                    font.capitalization: Font.AllUppercase
                    font.pixelSize: outputSurface.height * 0.05
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: playerRoot.loadState === "loading"
                          ? (playerRoot.loadedImageCount + " IMAGES  " + playerRoot.postsSeen + "/" + (playerRoot.totalPosts >= 0 ? playerRoot.totalPosts : "?") + " POSTS")
                          : playerRoot.errorText
                    color: root.primaryColor
                    font.family: root.globalFont
                    font.capitalization: Font.AllUppercase
                    font.pixelSize: outputSurface.height * 0.0333333
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: playerRoot.loadState === "error"
                    text: "[ENTER]:RETRY [ESC]:BACK"
                    color: root.tertiaryColor
                    font.family: root.globalFont
                    font.pixelSize: outputSurface.height * 0.0333333
                }
            }
        }

        Rectangle {
            visible: playerRoot.statusText !== "" && playerRoot.loadState === "playing"
            color: "#cc000000"
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: outputSurface.width * 0.025
            anchors.bottomMargin: outputSurface.height * 0.025
            width: Math.min(statusLabel.implicitWidth + outputSurface.width * 0.025, outputSurface.width * 0.9)
            height: statusLabel.implicitHeight + outputSurface.height * 0.016
            z: 1200

            Text {
                id: statusLabel
                anchors.centerIn: parent
                width: parent.width - outputSurface.width * 0.018
                text: playerRoot.statusText
                color: "white"
                font.family: root.globalFont
                font.capitalization: Font.AllUppercase
                elide: Text.ElideRight
                font.pixelSize: outputSurface.height * 0.0275
            }
        }
    }

    Component.onCompleted: {
        if (playerRoot.tumblrUrl === "") {
            playerRoot.goBack()
            return
        }
        tumblrScreensaverBackend.loadImages(playerRoot.tumblrUrl)
    }

    Component.onDestruction: montage.stop()
}
