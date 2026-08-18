pragma ComponentBehavior: Bound

import QtQuick
import Components

Item {
    id: montage

    property var items: []
    property bool paused: false
    property int showDurationMs: 6200
    property int transitionDurationMs: 1250

    readonly property int currentIndex: internalCurrentIndex
    readonly property var currentItem: internalCurrentIndex >= 0 && internalCurrentIndex < items.length
                                       ? items[internalCurrentIndex] : ({})
    readonly property bool running: internalRunning
    readonly property bool transitioning: internalTransitioning
    readonly property int failedItemCount: failedIndices.length

    property var deck: []
    property var failedIndices: []
    property int internalCurrentIndex: -1
    property int pendingIndex: -1
    property string pendingTarget: ""
    property bool pendingFirst: false
    property bool showingA: true
    property bool internalRunning: false
    property bool internalTransitioning: false
    property bool blockOverlayVisible: false
    property real blockProgress: 0
    property int blockVariant: 0
    property int blockColumns: 16
    property int blockRows: 9
    property url blockImageSource: ""
    property var blockSeeds: []

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

    signal started()
    signal exhausted()
    signal itemFailed(var item)
    signal cycleCompleted()

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

    function isFailed(index) {
        return failedIndices.indexOf(index) >= 0
    }

    function markFailed(index) {
        if (index < 0 || isFailed(index))
            return
        var updated = failedIndices.slice()
        updated.push(index)
        failedIndices = updated
        if (index < items.length)
            itemFailed(items[index])
    }

    function refillDeck() {
        var values = []
        for (var i = 0; i < items.length; ++i) {
            if (!isFailed(i))
                values.push(i)
        }

        var shuffled = shuffle(values)
        if (shuffled.length > 1 && shuffled[0] === internalCurrentIndex) {
            var swap = 1 + Math.floor(Math.random() * (shuffled.length - 1))
            var temp = shuffled[0]
            shuffled[0] = shuffled[swap]
            shuffled[swap] = temp
        }
        deck = shuffled
        if (internalCurrentIndex >= 0 && shuffled.length > 0)
            cycleCompleted()
    }

    function nextIndex() {
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

    function clearSlot(slot) {
        slot.visible = false
        slot.source = ""
        slot.animated = false
        resetSlot(slot)
    }

    function start() {
        stop()
        deck = []
        failedIndices = []
        internalCurrentIndex = -1
        internalRunning = true
        queueNext()
    }

    function stop() {
        displayTimer.stop()
        internalRunning = false
        internalTransitioning = false
        pendingIndex = -1
        pendingTarget = ""
        pendingFirst = false
        transitionAnimation.stop()
        stopBlockOverlay()
        clearSlot(imageA)
        clearSlot(imageB)
        internalCurrentIndex = -1
    }

    function next() {
        if (!internalRunning || pendingIndex >= 0 || internalTransitioning)
            return
        displayTimer.stop()
        queueNext()
    }

    function queueNext() {
        if (!internalRunning || pendingIndex >= 0 || internalTransitioning)
            return

        var index = nextIndex()
        if (index < 0) {
            internalRunning = false
            exhausted()
            return
        }

        pendingIndex = index
        pendingFirst = internalCurrentIndex < 0
        var target = pendingFirst ? imageA : inactiveImage()
        pendingTarget = target === imageA ? "A" : "B"
        target.animated = items[index].animated === true
        target.source = items[index].url || ""
        target.visible = true
        target.opacity = pendingFirst ? 1 : 0
        target.x = 0
        target.y = 0
        target.scale = 1
        target.rotation = 0

        if (target.ready || target.failed)
            startPendingTransition()
    }

    function retryAfterFailure() {
        if (internalRunning)
            queueNext()
    }

    function startPendingTransition() {
        if (pendingIndex < 0)
            return

        var incoming = pendingTarget === "A" ? imageA : imageB
        if (incoming.failed) {
            var failedIndex = pendingIndex
            incoming.visible = false
            incoming.source = ""
            pendingIndex = -1
            pendingTarget = ""
            pendingFirst = false
            markFailed(failedIndex)
            Qt.callLater(retryAfterFailure)
            return
        }
        if (!incoming.ready)
            return

        var nextItemIndex = pendingIndex
        pendingIndex = -1
        pendingTarget = ""

        if (pendingFirst) {
            pendingFirst = false
            showingA = incoming === imageA
            internalCurrentIndex = nextItemIndex
            incoming.visible = true
            resetSlot(incoming)
            started()
            if (!paused) {
                displayTimer.interval = showDurationMs
                displayTimer.restart()
            }
            return
        }

        internalCurrentIndex = nextItemIndex
        runTransition(incoming, activeImage())
    }

    function runTransition(incoming, outgoing) {
        internalTransitioning = true
        stopBlockOverlay()

        resetSlot(incoming)
        resetSlot(outgoing)
        incoming.visible = true
        outgoing.visible = true

        // Falling blocks use one static texture. Animated media stays in the
        // slide/fade family so frame advancement remains continuous.
        var type = Math.floor(Math.random() * (incoming.animated ? 7 : 10))
        if (type === 0) {
            incoming.opacity = 0
            setTargets(incoming, 0, 0, 1, 1, 0)
            setTargets(outgoing, 0, 0, 0, 1, 0)
        } else if (type === 1) {
            incoming.x = montage.width
            setTargets(incoming, 0, 0, 1, 1, 0)
            setTargets(outgoing, -montage.width, 0, 0.25, 1, 0)
        } else if (type === 2) {
            incoming.x = -montage.width
            setTargets(incoming, 0, 0, 1, 1, 0)
            setTargets(outgoing, montage.width, 0, 0.25, 1, 0)
        } else if (type === 3) {
            incoming.y = montage.height
            setTargets(incoming, 0, 0, 1, 1, 0)
            setTargets(outgoing, 0, -montage.height, 0.2, 1, 0)
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
            incoming.x = montage.width * 0.18
            setTargets(incoming, 0, 0, 1, 1, 0)
            setTargets(outgoing, -montage.width * 0.18, 0, 0, 1, -12)
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
        if (!internalTransitioning)
            return
        internalTransitioning = false
        var outgoing = showingA ? imageA : imageB
        showingA = !showingA
        outgoing.visible = false
        outgoing.source = ""
        resetSlot(outgoing)
        if (!paused) {
            displayTimer.interval = showDurationMs
            displayTimer.restart()
        }
    }

    onPausedChanged: {
        if (!internalRunning)
            return
        if (paused)
            displayTimer.stop()
        else if (!internalTransitioning && pendingIndex < 0) {
            displayTimer.interval = showDurationMs
            displayTimer.restart()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    MontageMedia {
        id: imageA
        width: parent.width
        height: parent.height
        paused: montage.paused
        transformOrigin: Item.Center
        visible: false
        onReadyChanged: if (montage.pendingTarget === "A") montage.startPendingTransition()
        onFailedChanged: if (montage.pendingTarget === "A") montage.startPendingTransition()
    }

    MontageMedia {
        id: imageB
        width: parent.width
        height: parent.height
        paused: montage.paused
        transformOrigin: Item.Center
        visible: false
        onReadyChanged: if (montage.pendingTarget === "B") montage.startPendingTransition()
        onFailedChanged: if (montage.pendingTarget === "B") montage.startPendingTransition()
    }

    Timer {
        id: displayTimer
        interval: montage.showDurationMs
        repeat: false
        onTriggered: montage.queueNext()
    }

    ParallelAnimation {
        id: transitionAnimation
        onStopped: montage.finishTransition()

        NumberAnimation { target: imageA; property: "x"; to: montage.imageAXTo; duration: montage.transitionDurationMs; easing.type: Easing.InOutQuad }
        NumberAnimation { target: imageA; property: "y"; to: montage.imageAYTo; duration: montage.transitionDurationMs; easing.type: Easing.InOutQuad }
        NumberAnimation { target: imageA; property: "opacity"; to: montage.imageAOpacityTo; duration: montage.transitionDurationMs; easing.type: Easing.InOutQuad }
        NumberAnimation { target: imageA; property: "scale"; to: montage.imageAScaleTo; duration: montage.transitionDurationMs; easing.type: Easing.OutBack }
        NumberAnimation { target: imageA; property: "rotation"; to: montage.imageARotationTo; duration: montage.transitionDurationMs; easing.type: Easing.InOutQuad }

        NumberAnimation { target: imageB; property: "x"; to: montage.imageBXTo; duration: montage.transitionDurationMs; easing.type: Easing.InOutQuad }
        NumberAnimation { target: imageB; property: "y"; to: montage.imageBYTo; duration: montage.transitionDurationMs; easing.type: Easing.InOutQuad }
        NumberAnimation { target: imageB; property: "opacity"; to: montage.imageBOpacityTo; duration: montage.transitionDurationMs; easing.type: Easing.InOutQuad }
        NumberAnimation { target: imageB; property: "scale"; to: montage.imageBScaleTo; duration: montage.transitionDurationMs; easing.type: Easing.OutBack }
        NumberAnimation { target: imageB; property: "rotation"; to: montage.imageBRotationTo; duration: montage.transitionDurationMs; easing.type: Easing.InOutQuad }
    }

    NumberAnimation {
        id: blockOverlayAnimation
        target: montage
        property: "blockProgress"
        from: 0
        to: 1
        duration: montage.transitionDurationMs + 350
        easing.type: Easing.Linear
        onStopped: montage.blockOverlayVisible = false
    }

    Item {
        anchors.fill: parent
        z: 900
        visible: montage.internalRunning
        opacity: 0.22

        Repeater {
            model: Math.max(1, Math.floor(montage.height / 4))
            Rectangle {
                required property int index
                x: 0
                y: index * 4
                width: montage.width
                height: 1
                color: "black"
            }
        }
    }

    Item {
        anchors.fill: parent
        z: 1000
        visible: montage.blockOverlayVisible

        Repeater {
            model: montage.blockColumns * montage.blockRows

            Item {
                required property int index
                property int col: index % montage.blockColumns
                property int row: Math.floor(index / montage.blockColumns)
                property real seed: montage.blockSeeds.length > index ? montage.blockSeeds[index] : 0
                property real columnDelay: col / Math.max(1, montage.blockColumns - 1)
                property real rowDelay: row / Math.max(1, montage.blockRows - 1)
                property real waveDelay: montage.blockVariant === 0
                                         ? (rowDelay * 0.2 + seed * 0.22)
                                         : montage.blockVariant === 1
                                           ? (columnDelay * 0.26 + seed * 0.12)
                                           : ((columnDelay + rowDelay) * 0.15 + seed * 0.12)
                property real enterPhase: TransitionMath.clamp01((montage.blockProgress - waveDelay) / 0.34)
                property real exitPhase: TransitionMath.clamp01((montage.blockProgress - 0.72 - waveDelay * 0.25) / 0.24)
                property real enterEase: TransitionMath.easeOutCubic(enterPhase)
                property real exitEase: TransitionMath.easeInCubic(exitPhase)
                property real blockW: Math.ceil(montage.width / montage.blockColumns) + 2
                property real blockH: Math.ceil(montage.height / montage.blockRows) + 2
                property real homeX: col * (montage.width / montage.blockColumns)
                property real homeY: row * (montage.height / montage.blockRows)
                property url tileSource: montage.blockImageSource

                width: blockW
                height: blockH
                clip: true
                x: homeX +
                   (montage.blockVariant === 1 ? Math.sin((row + seed) * 2.7) * montage.width * 0.018 * (1 - enterEase) : 0)
                y: homeY - (1 - enterEase) * (montage.height * (0.45 + seed * 0.75))
                opacity: TransitionMath.clamp01(enterPhase * 1.4) * (1 - exitPhase)
                rotation: montage.blockVariant === 2
                          ? (1 - enterEase) * (seed > 0.5 ? 18 : -18)
                          : 0
                scale: montage.blockVariant === 0
                       ? 1
                       : 0.82 + enterEase * 0.18

                Image {
                    source: parent.tileSource
                    width: montage.width
                    height: montage.height
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
                    border.width: Math.max(1, montage.height * 0.0015)
                    opacity: 0.72
                }
            }
        }
    }
}
