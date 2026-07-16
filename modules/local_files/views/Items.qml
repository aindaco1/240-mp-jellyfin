import QtQuick
import Components

FocusScope {
    id: itemsRoot

    property var navParams: ({})
    property var navListState: navParams.navListState || ({})
    property string folderPath: navParams.folderPath || localFilesBackend.mediaRoot()
    property string folderName: navParams.folderName || ""
    property bool hideExtensions: false

    signal navigateTo(string path, var params, var listState)
    signal goBack()

    function displayName(item) {
        var name = item.name || ""
        if (!hideExtensions || item.isFolder || name.charAt(0) === ".")
            return name
        var dot = name.lastIndexOf(".")
        return dot > 0 ? name.slice(0, dot) : name
    }

    focus: true
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace || event.key === Qt.Key_Back) {
            goBack()
            event.accepted = true
        }
    }

    // ---
    // UI
    // ---

    // Header
    AppBar {
        iconSource: moduleRoot.moduleIcon
        title: moduleRoot.moduleName
        subtitle: folderName !== "" ? folderName : ""
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.125 //60
        anchors.leftMargin: root.sw * 0.125 //80
    }

    Text {
        text: "Media Directory: " + localFilesBackend.mediaRoot()
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

    // Empty state
    Column {
        anchors.centerIn: parent
        spacing: root.sh * 0.0333333 //16
        visible: fileList.count === 0
        Text {
            text: "No items found"
            color: root.secondaryColor
            font.family: root.globalFont
            font.capitalization: Font.AllUppercase
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: root.sh * 0.05 //24
        }
        Text {
            visible: pinCode !== ""
            text: "Please add items in the local media directory"
            color: root.tertiaryColor
            font.family: root.globalFont
            font.capitalization: Font.AllUppercase
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: root.sh * 0.0333333 //16
        }
    }

    // File list
    ListView {
        id: fileList
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.25 //120
        anchors.leftMargin: root.sw * 0.115625 //74
        width: root.sw * 0.76875 //492
        height: root.sh * 0.525 //252
        keyNavigationEnabled: true
        clip: true
        focus: true

        Keys.onReturnPressed: {
            var item = model[currentIndex]
            if (!item) return
            if (item.isFolder) {
                navigateTo("Items.qml",
                    { folderPath: item.path, folderName: item.name },
                    { currentIndex: fileList.currentIndex })
            } else {
                navigateTo("Detail.qml",
                    { filePath: item.path, title: item.name },
                    { currentIndex: fileList.currentIndex })
            }
        }

        delegate: Item {
            width: fileList.width
            height: root.sh * 0.0583333 //28

            Item {
                id: textClip
                width: Math.min(rowText.implicitWidth, fileList.width)
                height: parent.height
                clip: true

                Rectangle {
                    color: root.accentColor
                    anchors.fill: rowText
                    visible: fileList.currentIndex === index
                }

                Text {
                    id: rowText
                    text: itemsRoot.displayName(modelData) + (modelData.isFolder ? "/" : "")
                    color: fileList.currentIndex === index ? root.surfaceColor : root.primaryColor
                    font.family: root.globalFont
                    font.capitalization: Font.AllUppercase
                    anchors.verticalCenter: parent.verticalCenter
                    x: 0
                    topPadding: root.sh * 0.0041667 //2
                    leftPadding: root.sw * 0.009375 //6
                    rightPadding: root.sw * 0.009375 //6
                    bottomPadding: root.sh * 0.00625 //3
                    font.pixelSize: root.sh * 0.05 //24
                }

                SequentialAnimation {
                    running: (fileList.currentIndex === index) &&
                             (rowText.implicitWidth > textClip.width)
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) rowText.x = 0
                    PauseAnimation { duration: 1500 }
                    NumberAnimation {
                        target: rowText; property: "x"
                        to: textClip.width - rowText.implicitWidth
                        duration: Math.abs(to) * 20
                    }
                    PauseAnimation { duration: 2000 }
                    PropertyAction { target: rowText; property: "x"; value: 0 }
                }
            }
        }
    }

    Component.onCompleted: {
        var hideRaw = appCore.get_setting(moduleRoot.moduleId, "hide_extensions")
        hideExtensions = hideRaw === true || hideRaw === "ON"
        var loaded = localFilesBackend.getItems(folderPath)
        fileList.model = loaded
        if (loaded.length > 0) {
            var restore = (navListState.currentIndex !== undefined) ? navListState.currentIndex : 0
            fileList.currentIndex = Math.min(restore, loaded.length - 1)
            fileList.positionViewAtIndex(fileList.currentIndex, ListView.Contain)
        }
        fileList.forceActiveFocus()
    }

    // Footer
    Text {
        id: footer
        text: "[ESC]:BACK [▲▼]:NAVIGATE [ENTER]:SELECT"
        color: root.tertiaryColor
        font.family: root.globalFont
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: root.sh * 0.1041667 //50
        anchors.leftMargin: root.sw * 0.125 //80
        font.pixelSize: root.sh * 0.0333333 //16
    }
}
