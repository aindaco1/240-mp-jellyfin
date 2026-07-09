import QtQuick

Item {
    id: panel

    property string title: "PLAYBACK"
    property string subtitle: ""
    property string stateText: ""
    property string footerText: "[ESC]:BACK"
    property var controls: []

    Rectangle {
        anchors.fill: parent
        color: root.surfaceColor
    }

    Text {
        id: titleText
        text: panel.title
        color: root.secondaryColor
        font.family: root.globalFont
        font.capitalization: Font.AllUppercase
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.125
        anchors.leftMargin: root.sw * 0.125
        width: root.sw * 0.75
        elide: Text.ElideRight
        font.pixelSize: root.sh * 0.05
    }

    Text {
        id: subtitleText
        text: panel.subtitle
        visible: text !== ""
        color: root.tertiaryColor
        font.family: root.globalFont
        font.capitalization: Font.AllUppercase
        anchors.top: titleText.bottom
        anchors.left: titleText.left
        anchors.topMargin: root.sh * 0.02
        width: root.sw * 0.75
        elide: Text.ElideRight
        font.pixelSize: root.sh * 0.03125
    }

    Text {
        id: stateLabel
        text: panel.stateText
        visible: text !== ""
        color: root.primaryColor
        font.family: root.globalFont
        font.capitalization: Font.AllUppercase
        anchors.top: subtitleText.visible ? subtitleText.bottom : titleText.bottom
        anchors.left: titleText.left
        anchors.topMargin: root.sh * 0.045
        width: root.sw * 0.75
        elide: Text.ElideRight
        font.pixelSize: root.sh * 0.0375
    }

    ListView {
        id: controlsList
        anchors.top: stateLabel.visible ? stateLabel.bottom : (subtitleText.visible ? subtitleText.bottom : titleText.bottom)
        anchors.left: titleText.left
        anchors.topMargin: root.sh * 0.045
        width: root.sw * 0.68
        height: root.sh * 0.43
        model: panel.controls
        interactive: false
        clip: true

        delegate: Item {
            width: controlsList.width
            height: root.sh * 0.043

            Text {
                id: keyText
                text: modelData.key || ""
                color: root.primaryColor
                font.family: root.globalFont
                font.capitalization: Font.AllUppercase
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: root.sw * 0.2
                elide: Text.ElideRight
                font.pixelSize: root.sh * 0.028
            }

            Text {
                text: modelData.action || ""
                color: root.tertiaryColor
                font.family: root.globalFont
                font.capitalization: Font.AllUppercase
                anchors.left: keyText.right
                anchors.leftMargin: root.sw * 0.025
                anchors.verticalCenter: parent.verticalCenter
                width: controlsList.width - keyText.width - root.sw * 0.025
                elide: Text.ElideRight
                font.pixelSize: root.sh * 0.028
            }
        }
    }

    Text {
        text: panel.footerText
        color: root.tertiaryColor
        font.family: root.globalFont
        font.capitalization: Font.AllUppercase
        anchors.bottom: parent.bottom
        anchors.left: titleText.left
        anchors.bottomMargin: root.sh * 0.1041667
        width: root.sw * 0.75
        elide: Text.ElideRight
        font.pixelSize: root.sh * 0.0333333
    }
}
