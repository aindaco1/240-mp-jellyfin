import QtQuick
import Components

FocusScope {
    id: updateRoot

    signal navigateTo(string path, var params, var listState)
    signal goBack()

    property var navParams: ({})
    property var navListState: ({})

    function primaryLabel() {
        if (updateManager.state === "available") return "Download Update"
        if (updateManager.state === "downloading" || updateManager.state === "checking") return "Cancel"
        if (updateManager.state === "ready") return updateManager.canInstall ? "Install and Restart" : "Open Disk Image"
        if (updateManager.state === "installing") return "Installing..."
        return "Check for Updates"
    }

    function activatePrimary() {
        if (updateManager.state === "available") updateManager.downloadUpdate()
        else if (updateManager.state === "downloading" || updateManager.state === "checking") updateManager.cancel()
        else if (updateManager.state === "ready") {
            if (updateManager.canInstall) updateManager.installAndRestart()
            else updateManager.openDownloadedUpdate()
        } else if (updateManager.state !== "installing" && updateManager.state !== "verifying") {
            updateManager.checkForUpdates()
        }
    }

    Keys.onReturnPressed: activatePrimary()
    Keys.onEnterPressed: activatePrimary()
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace || event.key === Qt.Key_Back) {
            updateRoot.goBack()
            event.accepted = true
        }
    }

    AppBar {
        iconSource: "../../assets/images/settings.svg"
        title: "Software Update"
        subtitle: "Installed " + updateManager.currentVersion
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.125
        anchors.leftMargin: root.sw * 0.125
    }

    Column {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.2583333
        anchors.leftMargin: root.sw * 0.125
        width: root.sw * 0.75
        spacing: root.sh * 0.025

        Text {
            width: parent.width
            text: updateManager.statusMessage
            color: root.primaryColor
            font.family: root.globalFont
            font.pixelSize: root.sh * 0.05
            wrapMode: Text.Wrap
        }

        Rectangle {
            visible: updateManager.state === "downloading" || updateManager.state === "verifying"
            width: parent.width
            height: root.sh * 0.025
            color: root.tertiaryColor

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, updateManager.progress))
                height: parent.height
                color: root.accentColor
            }
        }

        Text {
            visible: updateManager.updateAvailable && updateManager.releaseNotes.length > 0
            width: parent.width
            height: root.sh * 0.15
            text: updateManager.releaseNotes
            color: root.secondaryColor
            font.family: root.globalFont
            font.pixelSize: root.sh * 0.0291667
            wrapMode: Text.Wrap
            elide: Text.ElideRight
        }

        Rectangle {
            width: actionText.width + root.sw * 0.0375
            height: root.sh * 0.0708333
            color: updateManager.state === "installing" || updateManager.state === "verifying"
                   ? root.tertiaryColor : root.accentColor

            Text {
                id: actionText
                anchors.centerIn: parent
                text: updateRoot.primaryLabel()
                color: root.surfaceColor
                font.family: root.globalFont
                font.capitalization: Font.AllUppercase
                font.pixelSize: root.sh * 0.0416667
            }
        }
    }

    Text {
        text: "[ESC]:BACK [ENTER]:SELECT"
        color: root.tertiaryColor
        font.family: root.globalFont
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: root.sh * 0.1041667
        anchors.leftMargin: root.sw * 0.125
        font.pixelSize: root.sh * 0.0333333
    }
}
