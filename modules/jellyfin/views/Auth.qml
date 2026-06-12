import QtQuick
import Components

FocusScope {
    id: authRoot

    property var navParams: ({})
    property int focusRow: 0
    property string errorMessage: ""
    property bool isLoading: false
    property bool isQuickConnectWaiting: false
    property string quickConnectCode: ""

    signal replaceWith(string path, var params)
    signal goBack()

    function updateFocus() {
        serverInput.focus = focusRow === 0
        usernameInput.focus = focusRow === 1
        passwordInput.focus = focusRow === 2
        signInButton.focus = focusRow === 3
        quickConnectButton.focus = focusRow === 4
    }

    function setFocusRow(row) {
        focusRow = Math.max(0, Math.min(4, row))
        updateFocus()
    }

    function moveFocus(delta) {
        setFocusRow(focusRow + delta)
    }

    function submit() {
        if (isLoading) return
        errorMessage = ""
        isLoading = true
        jellyfinBackend.authenticate(serverInput.text, usernameInput.text, passwordInput.text)
    }

    function startQuickConnect() {
        if (isLoading || isQuickConnectWaiting) return
        errorMessage = ""
        quickConnectCode = ""
        isLoading = true
        jellyfinBackend.start_quick_connect(serverInput.text)
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            moveFocus((event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier)) ? -1 : 1)
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            moveFocus(-1)
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            moveFocus(1)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (focusRow === 3)
                submit()
            else if (focusRow === 4)
                startQuickConnect()
            event.accepted = true
        } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back) {
            jellyfinBackend.cancel_quick_connect()
            goBack()
            event.accepted = true
        }
    }

    Connections {
        target: jellyfinBackend
        function onAuthSuccess() {
            authRoot.isLoading = false
            authRoot.isQuickConnectWaiting = false
            authRoot.replaceWith("Libraries.qml", {})
        }
        function onQuickConnectCodeReady(code) {
            authRoot.isLoading = false
            authRoot.isQuickConnectWaiting = true
            authRoot.quickConnectCode = code
        }
        function onErrorOccurred(message) {
            authRoot.isLoading = false
            authRoot.isQuickConnectWaiting = false
            authRoot.errorMessage = message
        }
    }

    focus: true
    Keys.onPressed: function(event) { handleKey(event) }

    AppBar {
        iconSource: moduleRoot.moduleIcon
        title: moduleRoot.moduleName
        subtitle: "SIGN IN"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.125
        anchors.leftMargin: root.sw * 0.125
    }

    Column {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.235
        anchors.leftMargin: root.sw * 0.115625
        width: root.sw * 0.76875
        spacing: root.sh * 0.0125

        Text {
            text: "SERVER URL"
            color: focusRow === 0 ? root.accentColor : root.secondaryColor
            font.family: root.globalFont
            font.capitalization: Font.AllUppercase
            font.pixelSize: root.sh * 0.0333333
        }

        Rectangle {
            width: parent.width
            height: root.sh * 0.0583333
            color: focusRow === 0 ? root.accentColor : root.surfaceColor
            border.color: focusRow === 0 ? root.accentColor : root.tertiaryColor
            border.width: root.sh * 0.003125

            TextInput {
                id: serverInput
                anchors.fill: parent
                anchors.margins: root.sw * 0.009375
                text: jellyfinBackend.get_last_server_url()
                color: focusRow === 0 ? root.surfaceColor : root.primaryColor
                selectionColor: root.secondaryColor
                selectedTextColor: root.surfaceColor
                font.family: root.globalFont
                font.pixelSize: root.sh * 0.0375
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                Keys.onPressed: function(event) { authRoot.handleKey(event) }
            }
        }

        Text {
            text: "USERNAME"
            color: focusRow === 1 ? root.accentColor : root.secondaryColor
            font.family: root.globalFont
            font.capitalization: Font.AllUppercase
            font.pixelSize: root.sh * 0.0333333
        }

        Rectangle {
            width: parent.width
            height: root.sh * 0.0583333
            color: focusRow === 1 ? root.accentColor : root.surfaceColor
            border.color: focusRow === 1 ? root.accentColor : root.tertiaryColor
            border.width: root.sh * 0.003125

            TextInput {
                id: usernameInput
                anchors.fill: parent
                anchors.margins: root.sw * 0.009375
                color: focusRow === 1 ? root.surfaceColor : root.primaryColor
                selectionColor: root.secondaryColor
                selectedTextColor: root.surfaceColor
                font.family: root.globalFont
                font.pixelSize: root.sh * 0.0375
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                Keys.onPressed: function(event) { authRoot.handleKey(event) }
            }
        }

        Text {
            text: "PASSWORD"
            color: focusRow === 2 ? root.accentColor : root.secondaryColor
            font.family: root.globalFont
            font.capitalization: Font.AllUppercase
            font.pixelSize: root.sh * 0.0333333
        }

        Rectangle {
            width: parent.width
            height: root.sh * 0.0583333
            color: focusRow === 2 ? root.accentColor : root.surfaceColor
            border.color: focusRow === 2 ? root.accentColor : root.tertiaryColor
            border.width: root.sh * 0.003125

            TextInput {
                id: passwordInput
                anchors.fill: parent
                anchors.margins: root.sw * 0.009375
                echoMode: TextInput.Password
                color: focusRow === 2 ? root.surfaceColor : root.primaryColor
                selectionColor: root.secondaryColor
                selectedTextColor: root.surfaceColor
                font.family: root.globalFont
                font.pixelSize: root.sh * 0.0375
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                Keys.onPressed: function(event) { authRoot.handleKey(event) }
            }
        }

        Rectangle {
            id: signInButton
            width: root.sw * 0.25
            height: root.sh * 0.0583333
            color: focusRow === 3 ? root.accentColor : root.surfaceColor
            border.color: focusRow === 3 ? root.accentColor : root.tertiaryColor
            border.width: root.sh * 0.003125

            Text {
                anchors.centerIn: parent
                text: isLoading ? "SIGNING IN..." : "SIGN IN"
                color: focusRow === 3 ? root.surfaceColor : root.primaryColor
                font.family: root.globalFont
                font.capitalization: Font.AllUppercase
                font.pixelSize: root.sh * 0.0375
            }
            Keys.onPressed: function(event) { authRoot.handleKey(event) }
        }

        Rectangle {
            id: quickConnectButton
            width: root.sw * 0.35
            height: root.sh * 0.0583333
            color: focusRow === 4 ? root.accentColor : root.surfaceColor
            border.color: focusRow === 4 ? root.accentColor : root.tertiaryColor
            border.width: root.sh * 0.003125

            Text {
                anchors.centerIn: parent
                text: isQuickConnectWaiting ? "WAITING..." : "QUICK CONNECT"
                color: focusRow === 4 ? root.surfaceColor : root.primaryColor
                font.family: root.globalFont
                font.capitalization: Font.AllUppercase
                font.pixelSize: root.sh * 0.0375
            }
            Keys.onPressed: function(event) { authRoot.handleKey(event) }
        }

        Text {
            visible: quickConnectCode !== ""
            width: parent.width
            text: "CODE: " + quickConnectCode
            color: root.primaryColor
            font.family: root.globalFont
            font.capitalization: Font.AllUppercase
            font.pixelSize: root.sh * 0.05
        }

        Text {
            visible: isQuickConnectWaiting
            width: parent.width
            text: "APPROVE QUICK CONNECT IN JELLYFIN"
            color: root.secondaryColor
            font.family: root.globalFont
            font.capitalization: Font.AllUppercase
            font.pixelSize: root.sh * 0.0333333
        }

        Text {
            visible: errorMessage !== ""
            width: parent.width
            text: errorMessage
            color: root.tertiaryColor
            font.family: root.globalFont
            wrapMode: Text.WordWrap
            font.pixelSize: root.sh * 0.0333333
        }
    }

    Text {
        text: "[ESC]:BACK [TAB/▲▼]:FIELD [ENTER]:SELECT"
        color: root.tertiaryColor
        font.family: root.globalFont
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: root.sh * 0.1041667
        anchors.leftMargin: root.sw * 0.125
        font.pixelSize: root.sh * 0.0333333
    }

    Component.onCompleted: updateFocus()
}
