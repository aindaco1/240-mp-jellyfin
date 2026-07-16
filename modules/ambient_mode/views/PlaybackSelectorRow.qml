import QtQuick

Item {
    id: selectorRoot

    property string label: ""
    property string value: ""
    property bool selected: false
    property bool canGoPrevious: false
    property bool canGoNext: false
    property color primaryColor: "white"
    property color tertiaryColor: "gray"
    property color accentColor: "lightblue"
    property color surfaceColor: "navy"
    property string fontFamily: ""

    readonly property real horizontalPadding: height * 0.2142857
    readonly property real selectorGap: height * 0.4285714
    readonly property real arrowWidth: height * 0.7857143

    Rectangle {
        anchors.fill: parent
        color: selectorRoot.selected ? selectorRoot.accentColor : "transparent"
    }

    Text {
        id: labelText
        objectName: "selectorLabel"
        text: selectorRoot.label
        color: selectorRoot.selected ? selectorRoot.surfaceColor : selectorRoot.primaryColor
        font.family: selectorRoot.fontFamily
        font.capitalization: Font.AllUppercase
        anchors.left: parent.left
        anchors.leftMargin: selectorRoot.horizontalPadding
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: selectorRoot.height * 0.7142857
    }

    Item {
        id: valueArea
        objectName: "selectorValueArea"
        anchors.left: labelText.right
        anchors.leftMargin: selectorRoot.selectorGap
        anchors.right: parent.right
        anchors.rightMargin: selectorRoot.horizontalPadding
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        clip: true

        Text {
            id: previousArrow
            objectName: "selectorPreviousArrow"
            text: "◄"
            color: selectorRoot.selected ? selectorRoot.surfaceColor : selectorRoot.tertiaryColor
            font.family: selectorRoot.fontFamily
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: selectorRoot.arrowWidth
            font.pixelSize: selectorRoot.height * 0.6428571
            visible: selectorRoot.canGoPrevious
        }

        Text {
            id: nextArrow
            objectName: "selectorNextArrow"
            text: "►"
            color: selectorRoot.selected ? selectorRoot.surfaceColor : selectorRoot.tertiaryColor
            font.family: selectorRoot.fontFamily
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: selectorRoot.arrowWidth
            font.pixelSize: selectorRoot.height * 0.6428571
            visible: selectorRoot.canGoNext
        }

        Text {
            id: valueText
            objectName: "selectorValue"
            text: selectorRoot.value
            color: selectorRoot.selected ? selectorRoot.surfaceColor : selectorRoot.primaryColor
            font.family: selectorRoot.fontFamily
            font.capitalization: Font.AllUppercase
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            anchors.left: previousArrow.right
            anchors.right: nextArrow.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            elide: Text.ElideMiddle
            font.pixelSize: selectorRoot.height * 0.7142857
        }
    }
}
