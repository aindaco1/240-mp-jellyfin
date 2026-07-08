import QtQuick
import Components

FocusScope {
    id: itemsRoot

    property var navParams: ({})
    property var navListState: navParams.navListState || ({})
    property int focusRow: 0
    readonly property string moduleId: "com.240mp.tumblr_screensaver"
    readonly property string defaultUrl: "https://pixelskylines.tumblr.com/"

    signal navigateTo(string path, var params, var listState)
    signal goBack()

    focus: true

    function savedUrl() {
        var saved = appCore.get_setting(moduleId, "tumblr_url")
        return saved && saved !== "" ? saved : defaultUrl
    }

    function setFocusRow(row) {
        focusRow = Math.max(0, Math.min(1, row))
        if (focusRow === 0)
            urlInput.forceActiveFocus()
        else
            startButton.forceActiveFocus()
    }

    function startMontage() {
        var value = urlInput.text.trim()
        if (value === "")
            return
        appCore.save_setting(moduleId, "tumblr_url", value)
        navigateTo("Player.qml", { tumblrUrl: value }, {})
    }

    Component.onCompleted: {
        urlInput.text = savedUrl()
        setFocusRow(0)
        urlInput.selectAll()
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace || event.key === Qt.Key_Back) {
            goBack()
            event.accepted = true
        } else if (event.key === Qt.Key_Tab) {
            setFocusRow((focusRow + 1) % 2)
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            setFocusRow(focusRow - 1)
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            setFocusRow(focusRow + 1)
            event.accepted = true
        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && focusRow === 1) {
            startMontage()
            event.accepted = true
        }
    }

    AppBar {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.125
        anchors.leftMargin: root.sw * 0.125
        iconSource: moduleRoot.moduleIcon
        title: moduleRoot.moduleName
    }

    Text {
        id: urlLabel
        text: "TUMBLR URL"
        color: root.tertiaryColor
        font.family: root.globalFont
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.1958333
        anchors.leftMargin: root.sw * 0.125
        width: root.sw * 0.76875
        elide: Text.ElideRight
        font.pixelSize: root.sh * 0.0291667
    }

    Item {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.25
        anchors.leftMargin: root.sw * 0.115625
        width: root.sw * 0.76875
        height: root.sh * 0.22

        Rectangle {
            id: inputFrame
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: root.sh * 0.0666667
            color: focusRow === 0 ? root.accentColor : "transparent"
            border.color: focusRow === 0 ? root.accentColor : root.tertiaryColor
            border.width: Math.max(1, root.sh * 0.002)

            TextInput {
                id: urlInput
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: root.sw * 0.0125
                anchors.rightMargin: root.sw * 0.0125
                color: focusRow === 0 ? root.surfaceColor : root.primaryColor
                selectedTextColor: root.surfaceColor
                selectionColor: root.accentColor
                font.family: root.globalFont
                font.pixelSize: root.sh * 0.0416667
                clip: true
                focus: focusRow === 0
                selectByMouse: false
                activeFocusOnTab: true
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase

                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back) {
                        itemsRoot.goBack()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Down) {
                        itemsRoot.setFocusRow(1)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        itemsRoot.startMontage()
                        event.accepted = true
                    }
                }
            }
        }

        Item {
            id: startButton
            anchors.top: inputFrame.bottom
            anchors.left: parent.left
            anchors.topMargin: root.sh * 0.0416667
            width: root.sw * 0.34
            height: root.sh * 0.0583333
            focus: focusRow === 1

            Rectangle {
                color: focusRow === 1 ? root.accentColor : "transparent"
                anchors.fill: parent
            }

            Text {
                text: "START MONTAGE"
                color: focusRow === 1 ? root.surfaceColor : root.primaryColor
                font.family: root.globalFont
                font.capitalization: Font.AllUppercase
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: root.sw * 0.009375
                rightPadding: root.sw * 0.009375
                font.pixelSize: root.sh * 0.05
            }
        }
    }

    Text {
        text: "[ESC]:BACK [TAB]:FIELD [ENTER]:START"
        color: root.tertiaryColor
        font.family: root.globalFont
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: root.sh * 0.1041667
        anchors.leftMargin: root.sw * 0.125
        font.pixelSize: root.sh * 0.0333333
    }
}
