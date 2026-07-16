import QtQuick

Item {
    id: row

    property string label: ""
    property bool selected: false
    property color normalColor: root.primaryColor
    property color selectedTextColor: root.surfaceColor
    property color selectionColor: root.accentColor
    property int capitalization: Font.AllUppercase
    property real textSize: root.sh * 0.05
    property bool twoLine: false
    property bool splitAtSeparator: false
    property real lineSpacing: root.sh * 0.0025

    readonly property int hyphenSeparatorIndex: splitAtSeparator ? label.indexOf(" - ") : -1
    readonly property int enDashSeparatorIndex: splitAtSeparator ? label.indexOf(" – ") : -1
    readonly property int emDashSeparatorIndex: splitAtSeparator ? label.indexOf(" — ") : -1
    readonly property int separatorIndex: {
        var result = -1
        var candidates = [hyphenSeparatorIndex, enDashSeparatorIndex, emDashSeparatorIndex]
        for (var index = 0; index < candidates.length; ++index) {
            if (candidates[index] >= 0 && (result < 0 || candidates[index] < result))
                result = candidates[index]
        }
        return result
    }
    readonly property string firstLine: separatorIndex >= 0
                                                ? label.slice(0, separatorIndex)
                                                : label
    readonly property string secondLine: separatorIndex >= 0
                                                 ? label.slice(separatorIndex + 3)
                                                 : ""

    height: twoLine ? root.sh * 0.0875 : root.sh * 0.0583333
    clip: true

    Item {
        id: textClip
        width: Math.min(rowText.implicitWidth, parent.width)
        height: parent.height
        clip: true
        visible: !row.twoLine

        Rectangle {
            color: row.selectionColor
            anchors.fill: rowText
            visible: row.selected
        }

        Text {
            id: rowText
            text: row.label
            color: row.selected ? row.selectedTextColor : row.normalColor
            font.family: root.globalFont
            font.capitalization: row.capitalization
            anchors.verticalCenter: parent.verticalCenter
            x: 0
            topPadding: root.sh * 0.0041667
            leftPadding: root.sw * 0.009375
            rightPadding: root.sw * 0.009375
            bottomPadding: root.sh * 0.00625
            font.pixelSize: row.textSize
        }

        SequentialAnimation {
            running: row.selected && rowText.implicitWidth > textClip.width
            loops: Animation.Infinite
            onRunningChanged: if (!running) rowText.x = 0
            PauseAnimation { duration: 1500 }
            NumberAnimation {
                target: rowText
                property: "x"
                to: textClip.width - rowText.implicitWidth
                duration: Math.abs(to) * 20
            }
            PauseAnimation { duration: 2000 }
            PropertyAction { target: rowText; property: "x"; value: 0 }
        }
    }

    Item {
        id: twoLineClip
        anchors.fill: parent
        visible: row.twoLine
        clip: true

        readonly property real horizontalPadding: root.sw * 0.009375
        readonly property real contentWidth: Math.max(firstLineText.implicitWidth,
                                                       secondLineText.implicitWidth)

        Rectangle {
            color: row.selectionColor
            visible: row.selected
            width: Math.min(twoLineClip.width,
                            twoLineClip.contentWidth + twoLineClip.horizontalPadding * 2)
            height: parent.height
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: row.lineSpacing

            Text {
                id: firstLineText
                width: parent.width
                leftPadding: twoLineClip.horizontalPadding
                rightPadding: twoLineClip.horizontalPadding
                text: row.firstLine
                color: row.selected ? row.selectedTextColor : row.normalColor
                font.family: root.globalFont
                font.capitalization: row.capitalization
                font.pixelSize: row.textSize
                elide: Text.ElideRight
            }

            Text {
                id: secondLineText
                width: parent.width
                leftPadding: twoLineClip.horizontalPadding
                rightPadding: twoLineClip.horizontalPadding
                text: row.secondLine
                visible: text !== ""
                color: row.selected ? row.selectedTextColor : row.normalColor
                font.family: root.globalFont
                font.capitalization: row.capitalization
                font.pixelSize: row.textSize
                elide: Text.ElideRight
            }
        }
    }
}
