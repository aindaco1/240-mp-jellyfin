import QtQuick

Item {
    id: overlay

    property string title: ""
    property string phase: "idle"
    property int variant: 0
    property int direction: 1
    property real coverage: 0
    property bool revealPending: false
    property int blockColumns: 18
    property int blockRows: 10
    property var blockSeeds: []

    signal covered()
    signal revealed()

    visible: phase !== "idle"

    function resetSeeds() {
        var values = []
        for (var index = 0; index < blockColumns * blockRows; ++index)
            values.push(Math.random())
        blockSeeds = values
    }

    function cover(nextTitle) {
        title = nextTitle || ""
        variant = Math.floor(Math.random() * 3)
        direction = Math.random() < 0.5 ? -1 : 1
        revealPending = false
        resetSeeds()
        phase = "covering"
        coverage = 0
        revealAnimation.stop()
        coverAnimation.restart()
    }

    function reveal() {
        if (phase === "idle")
            return
        if (coverAnimation.running) {
            revealPending = true
            return
        }
        phase = "revealing"
        revealAnimation.restart()
    }

    NumberAnimation {
        id: coverAnimation
        target: overlay
        property: "coverage"
        from: 0
        to: 1
        duration: 420
        easing.type: Easing.InOutQuad
        onStopped: {
            overlay.phase = "covered"
            overlay.covered()
            if (overlay.revealPending) {
                overlay.revealPending = false
                overlay.reveal()
            }
        }
    }

    NumberAnimation {
        id: revealAnimation
        target: overlay
        property: "coverage"
        from: 1
        to: 0
        duration: 520
        easing.type: Easing.InOutQuad
        onStopped: {
            overlay.phase = "idle"
            overlay.title = ""
            overlay.revealed()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.surfaceColor
        visible: overlay.variant === 0
        opacity: TransitionMath.easeInCubic(overlay.coverage)
    }

    Rectangle {
        width: parent.width
        height: parent.height
        color: root.surfaceColor
        visible: overlay.variant === 1
        x: overlay.direction * (1 - TransitionMath.easeOutCubic(overlay.coverage)) * width
    }

    Item {
        anchors.fill: parent
        visible: overlay.variant === 2

        Repeater {
            model: overlay.blockColumns * overlay.blockRows

            Rectangle {
                required property int index
                readonly property int column: index % overlay.blockColumns
                readonly property int row: Math.floor(index / overlay.blockColumns)
                readonly property real seed: overlay.blockSeeds.length > index
                                                   ? overlay.blockSeeds[index] : 0
                readonly property real delay: (row / Math.max(1, overlay.blockRows - 1)) * 0.25
                                                   + seed * 0.22
                readonly property real enterPhase: TransitionMath.clamp01(
                                                       (overlay.coverage - delay) / 0.34)

                x: column * (overlay.width / overlay.blockColumns)
                y: row * (overlay.height / overlay.blockRows)
                   - (1 - TransitionMath.easeOutCubic(enterPhase))
                     * overlay.height * (0.18 + seed * 0.35)
                width: Math.ceil(overlay.width / overlay.blockColumns) + 2
                height: Math.ceil(overlay.height / overlay.blockRows) + 2
                color: root.surfaceColor
                opacity: TransitionMath.clamp01(enterPhase * 1.35)
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: overlay.coverage > 0.02
        opacity: overlay.coverage * 0.2

        Repeater {
            model: Math.max(1, Math.floor(overlay.height / 4))
            Rectangle {
                required property int index
                x: 0
                y: index * 4
                width: overlay.width
                height: 1
                color: "black"
            }
        }
    }

    Text {
        anchors.centerIn: parent
        width: parent.width * 0.82
        text: overlay.title !== "" ? "NEXT UP\n" + overlay.title : "NEXT UP"
        color: root.primaryColor
        font.family: root.globalFont
        font.capitalization: Font.AllUppercase
        font.pixelSize: Math.max(22, overlay.height * 0.045)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        maximumLineCount: 3
        elide: Text.ElideRight
        opacity: TransitionMath.clamp01((overlay.coverage - 0.62) / 0.28)
    }
}
