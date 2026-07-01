import QtQuick
import Components
import "RetroTvData.js" as RetroTvData

FocusScope {
    id: itemsRoot

    property var navParams: ({})
    property var navListState: navParams.navListState || ({})
    readonly property var entries: RetroTvData.menuEntries()
    readonly property var controls: RetroTvData.controls()

    signal navigateTo(string path, var params, var listState)
    signal goBack()

    focus: true
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace || event.key === Qt.Key_Back) {
            goBack()
            event.accepted = true
        }
    }

    function openCurrentEntry() {
        var item = entryList.model[entryList.currentIndex]
        if (!item)
            return
        navigateTo("Player.qml",
                   { feed: item.feed },
                   { currentIndex: entryList.currentIndex })
    }

    AppBar {
        iconSource: moduleRoot.moduleIcon
        title: moduleRoot.moduleName
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.125
        anchors.leftMargin: root.sw * 0.125
    }

    Text {
        text: "FEEDS"
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

    ListView {
        id: entryList
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.25
        anchors.leftMargin: root.sw * 0.115625
        width: root.sw * 0.25
        height: root.sh * 0.4
        model: entries
        keyNavigationEnabled: true
        clip: true
        focus: true

        Keys.onReturnPressed: itemsRoot.openCurrentEntry()
        Keys.onEnterPressed: itemsRoot.openCurrentEntry()

        delegate: Item {
            width: entryList.width
            height: root.sh * 0.0583333

            Item {
                id: textClip
                width: Math.min(rowText.implicitWidth, entryList.width)
                height: parent.height
                clip: true

                Rectangle {
                    color: root.accentColor
                    anchors.fill: rowText
                    visible: entryList.currentIndex === index
                }

                Text {
                    id: rowText
                    text: modelData.name
                    color: entryList.currentIndex === index ? root.surfaceColor : root.primaryColor
                    font.family: root.globalFont
                    font.capitalization: Font.AllUppercase
                    anchors.verticalCenter: parent.verticalCenter
                    x: 0
                    topPadding: root.sh * 0.0041667
                    leftPadding: root.sw * 0.009375
                    rightPadding: root.sw * 0.009375
                    bottomPadding: root.sh * 0.00625
                    font.pixelSize: root.sh * 0.05
                }

                SequentialAnimation {
                    running: (entryList.currentIndex === index) &&
                             (rowText.implicitWidth > textClip.width)
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
        }
    }

    Text {
        id: controlsTitle
        text: "CONTROLS"
        color: root.secondaryColor
        font.family: root.globalFont
        font.capitalization: Font.AllUppercase
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.25
        anchors.leftMargin: root.sw * 0.475
        font.pixelSize: root.sh * 0.0375
    }

    ListView {
        id: controlsList
        anchors.top: controlsTitle.bottom
        anchors.left: controlsTitle.left
        anchors.topMargin: root.sh * 0.025
        width: root.sw * 0.4
        height: root.sh * 0.52
        model: controls
        interactive: false
        clip: true

        delegate: Item {
            width: controlsList.width
            height: root.sh * 0.035

            Text {
                id: keyText
                text: modelData.keys
                color: root.primaryColor
                font.family: root.globalFont
                font.capitalization: Font.AllUppercase
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: root.sw * 0.16
                elide: Text.ElideRight
                font.pixelSize: root.sh * 0.024
            }

            Text {
                text: modelData.action
                color: root.tertiaryColor
                font.family: root.globalFont
                font.capitalization: Font.AllUppercase
                anchors.left: keyText.right
                anchors.leftMargin: root.sw * 0.02
                anchors.verticalCenter: parent.verticalCenter
                width: root.sw * 0.21
                elide: Text.ElideRight
                font.pixelSize: root.sh * 0.024
            }
        }
    }

    Text {
        text: "[ESC]:BACK [UP/DOWN]:NAVIGATE [ENTER]:PLAY"
        color: root.tertiaryColor
        font.family: root.globalFont
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: root.sh * 0.1041667
        anchors.leftMargin: root.sw * 0.125
        font.pixelSize: root.sh * 0.0333333
    }

    Component.onCompleted: {
        var restore = (navListState.currentIndex !== undefined) ? navListState.currentIndex : 0
        entryList.currentIndex = Math.min(restore, entries.length - 1)
        entryList.positionViewAtIndex(entryList.currentIndex, ListView.Contain)
        entryList.forceActiveFocus()
    }
}
