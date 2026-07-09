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
    property var deck: []
    property int currentImageIndex: -1
    property int pendingImageIndex: -1
    property string pendingTarget: ""
    property bool showingA: true
    property bool paused: false
    property bool transitioning: false
    property int loadedImageCount: 0
    property int postsSeen: 0
    property int totalPosts: -1
    property int showDurationMs: 6200
    property int transitionDurationMs: 1250
    property bool blockOverlayVisible: false
    property real blockProgress: 0
    property int blockVariant: 0
    property int blockColumns: 16
    property int blockRows: 9
    property url blockImageSource: ""
    property var blockSeeds: []
    property bool usingExternalOutput: false

    property real imageAXTo: 0
    property real imageAYTo: 0
    property real imageAOpacityTo: 1
    property real imageAScaleTo: 1
    property real imageARotationTo: 0
    property real imageBXTo: 0
    property real imageBYTo: 0
    property real imageBOpacityTo: 1
    property real imageBScaleTo: 1
    property real imageBRotationTo: 0

    signal goBack()

    focus: true

    function shuffle(values) {
        var result = values.slice()
        for (var i = result.length - 1; i > 0; --i) {
            var j = Math.floor(Math.random() * (i + 1))
            var temp = result[i]
            result[i] = result[j]
            result[j] = temp
        }
        return result
    }

    function refillDeck() {
        var values = []
        for (var i = 0; i < images.length; ++i)
            values.push(i)

        var shuffled = shuffle(values)
        if (shuffled.length > 1 && shuffled[0] === currentImageIndex) {
            var swap = 1 + Math.floor(Math.random() * (shuffled.length - 1))
            var temp = shuffled[0]
            shuffled[0] = shuffled[swap]
            shuffled[swap] = temp
        }
        deck = shuffled
    }

    function nextImageIndex() {
        if (deck.length === 0)
            refillDeck()
        if (deck.length === 0)
            return -1
        var index = deck[0]
        deck = deck.slice(1)
        return index
    }

    function activeImage() {
        return showingA ? imageA : imageB
    }

    function inactiveImage() {
        return showingA ? imageB : imageA
    }

    function resetSlot(slot) {
        slot.x = 0
        slot.y = 0
        slot.opacity = 1
        slot.scale = 1
        slot.rotation = 0
    }

    function setTargets(slot, x, y, opacity, scale, rotation) {
        if (slot === imageA) {
            imageAXTo = x
            imageAYTo = y
            imageAOpacityTo = opacity
            imageAScaleTo = scale
            imageARotationTo = rotation
        } else {
            imageBXTo = x
            imageBYTo = y
            imageBOpacityTo = opacity
            imageBScaleTo = scale
            imageBRotationTo = rotation
        }
    }

    function imageTitle(index) {
        if (index < 0 || index >= images.length)
            return ""
        return images[index].title || blogTitle || "TUMBLR"
    }

    function setStatus(text) {
        statusText = text
        statusTimer.restart()
    }

    function clamp01(value) {
        return Math.max(0, Math.min(1, value))
    }

    function easeOutCubic(value) {
        var t = clamp01(value)
        return 1 - Math.pow(1 - t, 3)
    }

    function easeInCubic(value) {
        var t = clamp01(value)
        return t * t * t
    }

    function resetBlockSeeds() {
        var values = []
        for (var i = 0; i < blockColumns * blockRows; ++i)
            values.push(Math.random())
        blockSeeds = values
    }

    function startBlockOverlay(variant, source) {
        resetBlockSeeds()
        blockVariant = variant
        blockImageSource = source
        blockProgress = 0
        blockOverlayVisible = true
        blockOverlayAnimation.restart()
    }

    function stopBlockOverlay() {
        blockOverlayAnimation.stop()
        blockOverlayVisible = false
        blockImageSource = ""
        blockProgress = 0
    }

    function showFirstImage() {
        var index = nextImageIndex()
        if (index < 0) {
            showError("No images were found on that Tumblr.")
            return
        }

        currentImageIndex = index
        imageA.source = images[index].url
        imageA.visible = true
        imageB.visible = false
        resetSlot(imageA)
        resetSlot(imageB)
        showingA = true
        loadState = "playing"
        paused = false
        setStatus(imageTitle(index))
        displayTimer.restart()
    }

    function queueNextImage() {
        if (loadState !== "playing" || pendingImageIndex >= 0 || transitioning)
            return

        var index = nextImageIndex()
        if (index < 0)
            return

        pendingImageIndex = index
        var target = inactiveImage()
        pendingTarget = target === imageA ? "A" : "B"
        target.source = images[index].url
        target.visible = true
        target.opacity = 0
        target.x = 0
        target.y = 0
        target.scale = 1
        target.rotation = 0

        if (target.status === Image.Ready || target.status === Image.Error)
            startPendingTransition()
    }

    function startPendingTransition() {
        if (pendingImageIndex < 0)
            return

        var incoming = pendingTarget === "A" ? imageA : imageB
        if (incoming.status === Image.Error) {
            pendingImageIndex = -1
            pendingTarget = ""
            displayTimer.interval = 150
            displayTimer.restart()
            return
        }
        if (incoming.status !== Image.Ready)
            return

        currentImageIndex = pendingImageIndex
        pendingImageIndex = -1
        pendingTarget = ""
        runTransition(incoming, activeImage())
    }

    function runTransition(incoming, outgoing) {
        transitioning = true
        stopBlockOverlay()

        resetSlot(incoming)
        resetSlot(outgoing)
        incoming.visible = true
        outgoing.visible = true

        var type = Math.floor(Math.random() * 10)
        if (type === 0) {
            incoming.opacity = 0
            setTargets(incoming, 0, 0, 1, 1, 0)
            setTargets(outgoing, 0, 0, 0, 1, 0)
        } else if (type === 1) {
            incoming.x = outputSurface.width
            setTargets(incoming, 0, 0, 1, 1, 0)
            setTargets(outgoing, -outputSurface.width, 0, 0.25, 1, 0)
        } else if (type === 2) {
            incoming.x = -outputSurface.width
            setTargets(incoming, 0, 0, 1, 1, 0)
            setTargets(outgoing, outputSurface.width, 0, 0.25, 1, 0)
        } else if (type === 3) {
            incoming.y = outputSurface.height
            setTargets(incoming, 0, 0, 1, 1, 0)
            setTargets(outgoing, 0, -outputSurface.height, 0.2, 1, 0)
        } else if (type === 4) {
            incoming.opacity = 0
            incoming.scale = 1.35
            setTargets(incoming, 0, 0, 1, 1, 0)
            setTargets(outgoing, 0, 0, 0, 0.78, 0)
        } else if (type === 5) {
            incoming.opacity = 0
            incoming.scale = 0.58
            incoming.rotation = -6
            setTargets(incoming, 0, 0, 1, 1, 0)
            setTargets(outgoing, 0, 0, 0, 1.25, 6)
        } else if (type === 6) {
            incoming.opacity = 0
            incoming.rotation = 12
            incoming.x = outputSurface.width * 0.18
            setTargets(incoming, 0, 0, 1, 1, 0)
            setTargets(outgoing, -outputSurface.width * 0.18, 0, 0, 1, -12)
        } else {
            startBlockOverlay(type - 7, incoming.source)
            incoming.opacity = 0
            incoming.scale = type === 8 ? 1.12 : 1
            setTargets(incoming, 0, 0, 1, 1, 0)
            setTargets(outgoing, 0, 0, 0.12, type === 9 ? 0.9 : 1, 0)
        }

        transitionAnimation.restart()
    }

    function finishTransition() {
        if (!transitioning)
            return
        transitioning = false
        var outgoing = showingA ? imageA : imageB
        showingA = !showingA
        outgoing.visible = false
        resetSlot(outgoing)
        setStatus(imageTitle(currentImageIndex))
        if (!paused) {
            displayTimer.interval = showDurationMs
            displayTimer.restart()
        }
    }

    function showError(message) {
        loadState = "error"
        errorText = message
        displayTimer.stop()
        transitioning = false
        transitionAnimation.stop()
        stopBlockOverlay()
    }

    function togglePause() {
        if (loadState !== "playing")
            return
        paused = !paused
        if (paused) {
            displayTimer.stop()
            setStatus("PAUSED")
        } else {
            displayTimer.restart()
            setStatus(imageTitle(currentImageIndex))
        }
    }

    function activateExternalOutput() {
        if (root.hasMediaOutputScreen)
            usingExternalOutput = root.openMediaOutput(true, true)
    }

    function handlePlayerKey(event) {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back || event.key === Qt.Key_Backspace) {
            displayTimer.stop()
            transitioning = false
            transitionAnimation.stop()
            stopBlockOverlay()
            goBack()
            event.accepted = true
        } else if (loadState === "error" && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            loadState = "loading"
            errorText = ""
            tumblrScreensaverBackend.loadImages(tumblrUrl)
            event.accepted = true
        } else if (loadState === "playing" && (event.key === Qt.Key_Right || event.key === Qt.Key_Down)) {
            displayTimer.stop()
            queueNextImage()
            event.accepted = true
        } else if (loadState === "playing" && event.key === Qt.Key_Space) {
            togglePause()
            event.accepted = true
        }
    }

    Keys.onPressed: function(event) {
        handlePlayerKey(event)
    }

    Connections {
        target: tumblrScreensaverBackend

        function onLoadStarted(url) {
            sourceUrl = url
            loadState = "loading"
            errorText = ""
            loadedImageCount = 0
            postsSeen = 0
            totalPosts = -1
        }

        function onLoadProgress(imageCount, seenPosts, allPosts) {
            loadedImageCount = imageCount
            postsSeen = seenPosts
            totalPosts = allPosts
        }

        function onImagesLoaded(loadedImages, loadedBlogTitle, loadedTotalPosts) {
            images = loadedImages || []
            blogTitle = loadedBlogTitle || "Tumblr"
            totalPosts = loadedTotalPosts
            deck = []
            currentImageIndex = -1
            showFirstImage()
        }

        function onErrorOccurred(message) {
            showError(message)
        }
    }

    Connections {
        target: root
        function onMediaOutputKeyPressed(event) {
            if (usingExternalOutput)
                handlePlayerKey(event)
        }
    }

    Timer {
        id: displayTimer
        interval: showDurationMs
        repeat: false
        onTriggered: queueNextImage()
    }

    Timer {
        id: statusTimer
        interval: 3400
        repeat: false
        onTriggered: statusText = ""
    }

    PlaybackControlPanel {
        anchors.fill: parent
        visible: usingExternalOutput
        title: blogTitle !== "" ? blogTitle : "TUMBLR MONTAGE"
        subtitle: "SHOWING ON MEDIA DISPLAY"
        stateText: loadState === "loading"
                   ? (loadedImageCount + " IMAGES  " + postsSeen + "/" + (totalPosts >= 0 ? totalPosts : "?") + " POSTS")
                   : loadState === "error" ? errorText : (paused ? "PAUSED" : imageTitle(currentImageIndex))
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

        Rectangle {
            anchors.fill: parent
            color: "black"
        }

    Image {
        id: imageA
        width: parent.width
        height: parent.height
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        smooth: false
        transformOrigin: Item.Center
        visible: false
        onStatusChanged: if (playerRoot.pendingTarget === "A") playerRoot.startPendingTransition()
    }

    Image {
        id: imageB
        width: parent.width
        height: parent.height
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        smooth: false
        transformOrigin: Item.Center
        visible: false
        onStatusChanged: if (playerRoot.pendingTarget === "B") playerRoot.startPendingTransition()
    }

    ParallelAnimation {
        id: transitionAnimation
        onStopped: playerRoot.finishTransition()

        NumberAnimation { target: imageA; property: "x"; to: playerRoot.imageAXTo; duration: playerRoot.transitionDurationMs; easing.type: Easing.InOutQuad }
        NumberAnimation { target: imageA; property: "y"; to: playerRoot.imageAYTo; duration: playerRoot.transitionDurationMs; easing.type: Easing.InOutQuad }
        NumberAnimation { target: imageA; property: "opacity"; to: playerRoot.imageAOpacityTo; duration: playerRoot.transitionDurationMs; easing.type: Easing.InOutQuad }
        NumberAnimation { target: imageA; property: "scale"; to: playerRoot.imageAScaleTo; duration: playerRoot.transitionDurationMs; easing.type: Easing.OutBack }
        NumberAnimation { target: imageA; property: "rotation"; to: playerRoot.imageARotationTo; duration: playerRoot.transitionDurationMs; easing.type: Easing.InOutQuad }

        NumberAnimation { target: imageB; property: "x"; to: playerRoot.imageBXTo; duration: playerRoot.transitionDurationMs; easing.type: Easing.InOutQuad }
        NumberAnimation { target: imageB; property: "y"; to: playerRoot.imageBYTo; duration: playerRoot.transitionDurationMs; easing.type: Easing.InOutQuad }
        NumberAnimation { target: imageB; property: "opacity"; to: playerRoot.imageBOpacityTo; duration: playerRoot.transitionDurationMs; easing.type: Easing.InOutQuad }
        NumberAnimation { target: imageB; property: "scale"; to: playerRoot.imageBScaleTo; duration: playerRoot.transitionDurationMs; easing.type: Easing.OutBack }
        NumberAnimation { target: imageB; property: "rotation"; to: playerRoot.imageBRotationTo; duration: playerRoot.transitionDurationMs; easing.type: Easing.InOutQuad }
    }

    NumberAnimation {
        id: blockOverlayAnimation
        target: playerRoot
        property: "blockProgress"
        from: 0
        to: 1
        duration: playerRoot.transitionDurationMs + 350
        easing.type: Easing.Linear
        onStopped: playerRoot.blockOverlayVisible = false
    }

    Item {
        anchors.fill: parent
        z: 900
        visible: loadState === "playing"
        opacity: 0.22

        Repeater {
            model: Math.max(1, Math.floor(outputSurface.height / 4))
            Rectangle {
                x: 0
                y: index * 4
                width: outputSurface.width
                height: 1
                color: "black"
            }
        }
    }

    Item {
        anchors.fill: parent
        z: 1000
        visible: blockOverlayVisible

        Repeater {
            model: playerRoot.blockColumns * playerRoot.blockRows

            Item {
                property int col: index % playerRoot.blockColumns
                property int row: Math.floor(index / playerRoot.blockColumns)
                property real seed: playerRoot.blockSeeds.length > index ? playerRoot.blockSeeds[index] : 0
                property real columnDelay: col / Math.max(1, playerRoot.blockColumns - 1)
                property real rowDelay: row / Math.max(1, playerRoot.blockRows - 1)
                property real waveDelay: playerRoot.blockVariant === 0
                                         ? (rowDelay * 0.2 + seed * 0.22)
                                         : playerRoot.blockVariant === 1
                                           ? (columnDelay * 0.26 + seed * 0.12)
                                           : ((columnDelay + rowDelay) * 0.15 + seed * 0.12)
                property real enterPhase: playerRoot.clamp01((playerRoot.blockProgress - waveDelay) / 0.34)
                property real exitPhase: playerRoot.clamp01((playerRoot.blockProgress - 0.72 - waveDelay * 0.25) / 0.24)
                property real enterEase: playerRoot.easeOutCubic(enterPhase)
                property real exitEase: playerRoot.easeInCubic(exitPhase)
                property real blockW: Math.ceil(outputSurface.width / playerRoot.blockColumns) + 2
                property real blockH: Math.ceil(outputSurface.height / playerRoot.blockRows) + 2
                property real homeX: col * (outputSurface.width / playerRoot.blockColumns)
                property real homeY: row * (outputSurface.height / playerRoot.blockRows)
                property url tileSource: playerRoot.blockImageSource

                width: blockW
                height: blockH
                clip: true
                x: homeX +
                   (playerRoot.blockVariant === 1 ? Math.sin((row + seed) * 2.7) * outputSurface.width * 0.018 * (1 - enterEase) : 0)
                y: homeY - (1 - enterEase) * (outputSurface.height * (0.45 + seed * 0.75))
                opacity: playerRoot.clamp01(enterPhase * 1.4) * (1 - exitPhase)
                rotation: playerRoot.blockVariant === 2
                          ? (1 - enterEase) * (seed > 0.5 ? 18 : -18)
                          : 0
                scale: playerRoot.blockVariant === 0
                       ? 1
                       : 0.82 + enterEase * 0.18

                Image {
                    source: parent.tileSource
                    width: outputSurface.width
                    height: outputSurface.height
                    x: -parent.homeX
                    y: -parent.homeY
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: true
                    smooth: false
                }

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: "#000000"
                    border.width: Math.max(1, outputSurface.height * 0.0015)
                    opacity: 0.72
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.surfaceColor
        visible: loadState === "loading" || loadState === "error"
        z: 1100

        Column {
            anchors.centerIn: parent
            width: outputSurface.width * 0.75
            spacing: outputSurface.height * 0.035

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: loadState === "loading" ? "LOADING TUMBLR" : "TUMBLR ERROR"
                color: root.secondaryColor
                font.family: root.globalFont
                font.capitalization: Font.AllUppercase
                font.pixelSize: outputSurface.height * 0.05
                wrapMode: Text.WordWrap
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: loadState === "loading"
                      ? (loadedImageCount + " IMAGES  " + postsSeen + "/" + (totalPosts >= 0 ? totalPosts : "?") + " POSTS")
                      : errorText
                color: root.primaryColor
                font.family: root.globalFont
                font.capitalization: Font.AllUppercase
                font.pixelSize: outputSurface.height * 0.0333333
                wrapMode: Text.WordWrap
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: loadState === "error"
                text: "[ENTER]:RETRY [ESC]:BACK"
                color: root.tertiaryColor
                font.family: root.globalFont
                font.pixelSize: outputSurface.height * 0.0333333
            }
        }
    }

    Rectangle {
        visible: statusText !== "" && loadState === "playing"
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
            text: statusText
            color: "white"
            font.family: root.globalFont
            font.capitalization: Font.AllUppercase
            elide: Text.ElideRight
            font.pixelSize: outputSurface.height * 0.0275
        }
    }

    }

    Component.onCompleted: {
        activateExternalOutput()

        if (tumblrUrl === "") {
            goBack()
            return
        }
        tumblrScreensaverBackend.loadImages(tumblrUrl)
    }

    Component.onDestruction: {
        if (usingExternalOutput)
            root.closeMediaOutput()
    }
}
