import QtQuick
import QtQuick.Layouts
import Quickshell

// Media part of the clock pill.
//  Collapsed (default): play/pause + mini wave; hover shows the song name.
//  Expanded (click):    source app, scrolling song name, progress wave, and a ⌄ button for the full player.
// Click toggles; right-click play/pause; scroll switches source.
Item {
    id: chip

    property var player: null
    signal openRequested()
    signal cycle(int dir)

    readonly property bool expanded: Notifs.mediaExpanded
    readonly property bool hovered: ma.containsMouse
    readonly property bool showName: expanded || hovered
    readonly property string label: !player ? "" :
        (Theme.trackTitle(player) || player.identity || "Unknown")
        + (player.trackArtist ? "  ·  " + player.trackArtist : "")
    readonly property string appIcon: player?.desktopEntry ? Quickshell.iconPath(player.desktopEntry, true) : ""

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

    Timer {
        interval: 1000
        repeat: true
        running: chip.player?.isPlaying ?? false
        onTriggered: chip.player.positionChanged()
    }

    // widths
    readonly property real waveW: expanded ? 100 : 110
    readonly property real nameW: expanded ? 210 : Math.min(nameText.implicitWidth, 300)
    readonly property real sourceW: expanded ? sourceRow.implicitWidth + 12 : 0
    readonly property real tailW: expanded ? chevron.implicitWidth + 10 : 0

    implicitHeight: 38
    implicitWidth: playIcon.implicitWidth + 10 + sourceW
                   + (expanded ? nameW + 12 + waveW : (hovered ? nameW : waveW))
                   + tailW
    Behavior on implicitWidth { NumberAnimation { duration: 340; easing.type: Easing.OutQuint } }

    // click anywhere on the chip: toggle expanded; right-click play/pause; scroll: switch source
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onWheel: wheel => chip.cycle(wheel.angleDelta.y > 0 ? -1 : 1)
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (chip.player?.canTogglePlaying) chip.player.togglePlaying()
            } else {
                Notifs.mediaExpanded = !Notifs.mediaExpanded
            }
        }
    }

    Text {
        id: playIcon
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        text: chip.player?.isPlaying ? "󰏤" : "󰐊"
        color: Colours.accent
        font { family: Theme.font; pixelSize: 14 }
    }

    Item {
        id: area
        anchors { left: playIcon.right; leftMargin: 10; right: parent.right; top: parent.top; bottom: parent.bottom }
        clip: true

        // ----- source (expanded only) -----
        Row {
            id: sourceRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            opacity: chip.expanded ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 200 } }
            Image {
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.appIcon !== ""
                width: 14; height: 14
                source: chip.appIcon
                sourceSize { width: 28; height: 28 }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.player?.identity ?? ""
                color: Theme.tint(Colours.fg, 0.6)
                font { family: Theme.font; pixelSize: 11 }
            }
        }

        // ----- song name (hover when collapsed, always when expanded), marquee if too long -----
        Item {
            id: nameBox
            x: chip.sourceW
            width: chip.nameW
            height: parent.height
            clip: true
            opacity: chip.showName ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 220 } }

            // two copies side by side; sliding left by one copy + gap and looping is seamless
            readonly property int gap: 48
            readonly property bool scrolling: chip.showName && nameText.implicitWidth > nameBox.width

            Row {
                id: marquee
                anchors.verticalCenter: parent.verticalCenter
                spacing: nameBox.gap
                x: 0
                Text {
                    id: nameText
                    text: chip.label
                    color: Colours.fg
                    textFormat: Text.PlainText
                    font { family: Theme.font; pixelSize: 13 }
                }
                Text {
                    visible: nameBox.scrolling
                    text: chip.label
                    color: Colours.fg
                    textFormat: Text.PlainText
                    font: nameText.font
                }
            }

            SequentialAnimation {
                id: scroll
                running: nameBox.scrolling
                PauseAnimation { duration: 1200 }
                NumberAnimation {
                    target: marquee; property: "x"
                    from: 0; to: -(nameText.implicitWidth + nameBox.gap)
                    duration: (nameText.implicitWidth + nameBox.gap) * 30     // ~33 px/s
                    loops: Animation.Infinite
                }
                onStopped: marquee.x = 0
            }
            Connections {
                target: chip
                function onLabelChanged() { marquee.x = 0; if (scroll.running) scroll.restart() }
            }

            // soft edges while scrolling
            // (only as tall as the text, so they never paint over the pill's border)
            Rectangle {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                width: 18
                height: nameText.height + 4
                opacity: nameBox.scrolling && marquee.x < 0 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.surface }
                    GradientStop { position: 1; color: Theme.tint(Theme.surface, 0) }
                }
            }
            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 18
                height: nameText.height + 4
                visible: nameBox.scrolling
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.tint(Theme.surface, 0) }
                    GradientStop { position: 1; color: Theme.surface }
                }
            }
        }

        // ----- progress wave (rest state, and after the name when expanded) -----
        WaveProgress {
            anchors.verticalCenter: parent.verticalCenter
            x: chip.expanded ? chip.sourceW + chip.nameW + 12 : 0
            width: chip.waveW
            implicitHeight: 14
            wavelength: 14
            amplitude: 2.2
            progress: chip.frac
            indeterminate: chip.knownLength <= 0
            playing: chip.player?.isPlaying ?? false
            opacity: chip.expanded || !chip.hovered ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Behavior on x { NumberAnimation { duration: 340; easing.type: Easing.OutQuint } }
        }

        // ----- open the full player (expanded only) -----
        Text {
            id: chevron
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: "󰅀"
            color: chevMa.containsMouse ? Colours.accent : Theme.tint(Colours.fg, 0.6)
            font { family: Theme.font; pixelSize: 14 }
            opacity: chip.expanded ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 200 } }
            MouseArea {
                id: chevMa
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: chip.openRequested()
            }
        }
    }
}
