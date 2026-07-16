import QtQuick

Rectangle {
    id: dialog

    property string prompt: "ARE YOU SURE?"
    property string confirmLabel: "YES"
    property string cancelLabel: "NO"
    property int choiceIndex: 1

    signal accepted()
    signal rejected()

    color: root.surfaceColor
    border.color: root.tertiaryColor
    border.width: Math.max(1, root.sh * 0.0041667)
    width: root.sw * 0.625
    height: root.sh * 0.25
    anchors.centerIn: parent
    z: 100
    focus: visible

    Keys.onLeftPressed: choiceIndex = 0
    Keys.onRightPressed: choiceIndex = 1
    Keys.onUpPressed: choiceIndex = 0
    Keys.onDownPressed: choiceIndex = 1
    Keys.onReturnPressed: choiceIndex === 0 ? accepted() : rejected()
    Keys.onEnterPressed: choiceIndex === 0 ? accepted() : rejected()
    Keys.onEscapePressed: rejected()
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Back || event.key === Qt.Key_Backspace) {
            rejected()
            event.accepted = true
        }
    }

    Text {
        text: dialog.prompt
        color: root.secondaryColor
        font.family: root.globalFont
        font.capitalization: Font.AllUppercase
        font.pixelSize: root.sh * 0.0416667
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: root.sh * 0.045
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.sh * 0.045
        spacing: root.sw * 0.08

        Repeater {
            model: [dialog.confirmLabel, dialog.cancelLabel]
            delegate: Item {
                width: root.sw * 0.16
                height: root.sh * 0.0583333

                Rectangle {
                    anchors.fill: optionText
                    color: root.accentColor
                    visible: index === dialog.choiceIndex
                }

                Text {
                    id: optionText
                    text: modelData
                    color: index === dialog.choiceIndex ? root.surfaceColor : root.primaryColor
                    font.family: root.globalFont
                    font.capitalization: Font.AllUppercase
                    font.pixelSize: root.sh * 0.0416667
                    anchors.centerIn: parent
                    leftPadding: root.sw * 0.0125
                    rightPadding: root.sw * 0.0125
                }
            }
        }
    }
}
