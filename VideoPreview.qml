import QtQuick
import QtMultimedia

// Loaded on demand by SettingsGui.qml, so the GUI still starts when QtMultimedia is missing.
Item {
    id: root
    property url source
    property bool playing: true
    signal failed()

    MediaPlayer {
        id: mp
        source: root.playing ? root.source : ""
        videoOutput: vo
        loops: MediaPlayer.Infinite
        onSourceChanged: { if (source.toString() !== "") play(); else stop() }
        onErrorOccurred: function (e, s) { root.failed() }
    }
    VideoOutput {
        id: vo
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }
}
