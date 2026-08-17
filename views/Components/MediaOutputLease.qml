import QtQml

QtObject {
    id: lease

    required property var host
    property bool enabled: false
    property bool requested: false
    property bool opaque: true
    property bool acceptsFocus: false
    readonly property bool active: internalActive
    property bool internalActive: false

    function sync() {
        var shouldBeActive = enabled && requested
        if (shouldBeActive === internalActive)
            return

        if (shouldBeActive) {
            internalActive = !!host.openMediaOutput(opaque, acceptsFocus)
        } else {
            host.closeMediaOutput()
            internalActive = false
        }
    }

    onEnabledChanged: sync()
    onRequestedChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: {
        if (internalActive)
            host.closeMediaOutput()
    }
}
