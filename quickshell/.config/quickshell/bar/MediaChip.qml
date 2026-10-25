import QtQuick
import QtQuick.Layouts
import Quickshell

// Media part of the clock pill.
// At rest: play/pause icon + a mini wavy progress bar for the chosen source.
// On hover: widens and shows "Title · Artist", scrolling if it's too long.
Item {
    id: chip

    property var player: null
    signal openRequested()
    signal cycle(int dir)

    readonly property bool hovered: ma.containsMouse
    readonly property string label: !player ? "" :
        (Theme.trackTitle(player) || player.identity || "Unknown")
        + (player.trackArtist ? "  ·  " + player.trackArtist : "")

    // remember the real track length (browsers report it intermittently)
    property real knownLength: 0
    function captureLength() { if (player && player.lengthSupported && player.length > 0) knownLength = player.length }
    onPlayerChanged: { knownLength = 0; captureLength() }
    Connections {
        target: chip.player
        function onLengthChanged() { chip.captureLength() }
        function onTrackChanged() { chip.knownLength = 0 }
        function onPostTrackChanged() { chip.captureLength() }
    }
    readonly property real frac: knownLength > 0 && player ? Math.max(0, Math.min(1, player.position / knownLength)) : 0

    // keep position fresh while playing (MPRIS doesn't push it)
    Timer {
        interval: 1000
        repeat: true
        running: chip.player?.isPlaying ?? false
        onTriggered: chip.player.positionChanged()
    }

    readonly property real restW: 110
    readonly property real maxTextW: 300
    readonly property real textW: Math.min(fullText.implicitWidth, maxTextW)

    implicitHeight: 38
    implicitWidth: icon.implicitWidth + 10 + (hovered ? textW : restW)
    Behavior on implicitWidth { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }

    Text {
        id: icon
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        text: chip.player?.isPlaying ? "󰏤" : "󰐊"
        color: Colours.accent
        font { family: Theme.font; pixelSize: 14 }
    }

    // content area to the right of the icon
    Item {
        id: area
        anchors { left: icon.right; leftMargin: 10; right: parent.right; top: parent.top; bottom: parent.bottom }
        clip: true

        // at rest: mini wave
        WaveProgress {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: chip.restW
            implicitHeight: 14
            wavelength: 14
            amplitude: 2.2
            progress: chip.frac
            indeterminate: chip.knownLength <= 0
            playing: chip.player?.isPlaying ?? false
            opacity: chip.hovered ? 0 : 1
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 180 } }
        }

        // on hover: title · artist, marquee if it doesn't fit
        Text {
            id: fullText
            anchors.verticalCenter: parent.verticalCenter
            text: chip.label
            color: Colours.fg
            textFormat: Text.PlainText
            font { family: Theme.font; pixelSize: 13 }
            opacity: chip.hovered ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 220 } }

            readonly property real overflow: Math.max(0, implicitWidth - chip.maxTextW)
            x: 0
            SequentialAnimation on x {
                running: chip.hovered && fullText.overflow > 0
                loops: Animation.Infinite
                PauseAnimation { duration: 900 }
                NumberAnimation { to: -fullText.overflow; duration: Math.max(1500, fullText.overflow * 28); easing.type: Easing.InOutSine }
                PauseAnimation { duration: 900 }
                NumberAnimation { to: 0; duration: Math.max(1500, fullText.overflow * 28); easing.type: Easing.InOutSine }
                onStopped: fullText.x = 0
            }
        }

        // soft fade at the right edge while scrolling
        Rectangle {
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: 18
            visible: chip.hovered && fullText.overflow > 0
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.tint(Theme.surface, 0) }
                GradientStop { position: 1; color: Theme.surface }
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        // left: media pop-out; right: play/pause; scroll: switch source
        onWheel: wheel => chip.cycle(wheel.angleDelta.y > 0 ? -1 : 1)
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (chip.player?.canTogglePlaying) chip.player.togglePlaying()
            } else {
                chip.openRequested()
            }
        }
    }
}
