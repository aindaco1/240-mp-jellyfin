import QtQuick

Item {
    id: media

    property url source: ""
    property bool animated: false
    property bool paused: false
    readonly property int status: animated ? animatedImage.status : stillImage.status
    readonly property bool ready: animated
                                  ? animatedImage.status === AnimatedImage.Ready
                                  : stillImage.status === Image.Ready
    readonly property bool failed: animated
                                   ? animatedImage.status === AnimatedImage.Error
                                   : stillImage.status === Image.Error
    readonly property int currentFrame: animated ? animatedImage.currentFrame : 0

    Image {
        id: stillImage
        anchors.fill: parent
        visible: !media.animated
        source: visible ? media.source : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        smooth: false
    }

    AnimatedImage {
        id: animatedImage
        anchors.fill: parent
        visible: media.animated
        source: visible ? media.source : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        smooth: false
        playing: visible && !media.paused
    }
}
