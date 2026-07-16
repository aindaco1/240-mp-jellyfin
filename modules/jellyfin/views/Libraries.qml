import QtQuick
import Components

FocusScope {
    id: browseRoot

    property var navParams: ({})
    property var navListState: navParams.navListState || ({})

    signal navigateTo(string path, var params, var listState)
    signal goBack()

    property var libraries: []
    property string serverName: ""
    property string userName: ""
    property string errorMessage: ""

    function browseParamsForLibrary(lib) {
        if (lib.id === "__continue__")
            return { mode: "continue", libraryName: "Continue Watching" }
        if (lib.id === "__upnext__")
            return { mode: "upnext", libraryName: "Up Next" }
        var collectionType = String(lib.collectionType || "").toLowerCase()
        var itemType = collectionType === "tvshows" ? "Series"
                     : collectionType === "boxsets" ? "BoxSet" : "Movie"
        return {
            parentId: lib.id,
            libraryId: lib.id,
            libraryName: lib.title,
            collectionType: collectionType,
            itemType: itemType,
            recursive: collectionType !== "boxsets",
            mode: collectionType === "homevideos" ? "folder" : "browse"
        }
    }

    Connections {
        target: jellyfinBackend
        function onLibrariesLoaded(items) {
            var combined = [
                { id: "__continue__", title: "Continue Watching", collectionType: "" },
                { id: "__upnext__", title: "Up Next", collectionType: "" }
            ].concat(items)
            browseRoot.libraries = combined
            if (combined.length > 0) {
                var restore = (navListState.currentIndex !== undefined) ? navListState.currentIndex : 0
                libraryList.currentIndex = Math.min(restore, combined.length - 1)
                libraryList.positionViewAtIndex(libraryList.currentIndex, ListView.Contain)
            }
        }
        function onErrorOccurred(message) {
            browseRoot.errorMessage = message
        }
    }

    Component.onCompleted: {
        browseRoot.serverName = jellyfinBackend.get_active_server_name()
        browseRoot.userName = jellyfinBackend.get_active_user_name()
        jellyfinBackend.load_libraries()
    }

    focus: true

    AppBar {
        iconSource: moduleRoot.moduleIcon
        title: moduleRoot.moduleName
        subtitle: browseRoot.serverName + (browseRoot.userName ? " (" + browseRoot.userName + ")" : "")
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.125
        anchors.leftMargin: root.sw * 0.125
    }

    Text {
        visible: libraries.length === 0 && errorMessage === ""
        text: "LOADING..."
        color: root.tertiaryColor
        font.family: root.globalFont
        anchors.centerIn: parent
        font.pixelSize: root.sh * 0.05
    }

    Text {
        visible: errorMessage !== ""
        text: errorMessage
        color: root.tertiaryColor
        font.family: root.globalFont
        anchors.centerIn: parent
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        width: root.sw * 0.76875
        font.pixelSize: root.sh * 0.05
    }

    ListView {
        id: libraryList
        model: libraries
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.25
        anchors.leftMargin: root.sw * 0.115625
        width: root.sw * 0.76875
        height: root.sh * 0.525
        clip: true
        focus: true

        Keys.onUpPressed: if (currentIndex > 0) currentIndex--
        Keys.onDownPressed: if (currentIndex < count - 1) currentIndex++
        Keys.onReturnPressed: {
            var lib = libraries[currentIndex]
            if (!lib) return
            browseRoot.navigateTo("Items.qml", browseRoot.browseParamsForLibrary(lib),
                                  { currentIndex: libraryList.currentIndex })
        }
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace || event.key === Qt.Key_Back) {
                browseRoot.goBack()
                event.accepted = true
            }
        }

        delegate: Item {
            width: libraryList.width
            height: root.sh * 0.0583333

            Item {
                id: textClip
                width: Math.min(rowText.implicitWidth, libraryList.width)
                height: parent.height
                clip: true

                Rectangle {
                    color: root.accentColor
                    anchors.fill: rowText
                    visible: libraryList.currentIndex === index
                }

                Text {
                    id: rowText
                    text: modelData.title || ""
                    color: libraryList.currentIndex === index ? root.surfaceColor : root.primaryColor
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
                    running: (libraryList.currentIndex === index) &&
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
        text: "[ESC]:BACK [▲▼]:NAVIGATE [ENTER]:SELECT"
        color: root.tertiaryColor
        font.family: root.globalFont
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: root.sh * 0.1041667
        anchors.leftMargin: root.sw * 0.125
        font.pixelSize: root.sh * 0.0333333
    }
}
