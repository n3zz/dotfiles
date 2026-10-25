import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris

// One player's page in the media pop-out
Item {
    id: page

    property var player: null
    property bool active: false

    // Browsers (Zen/Firefox) only report the track length some of the time, and when it's
    // missing Quickshell reports length = position (reads as 100%). So remember the last real
    // length for the current track and keep using it until the track changes.
    property real knownLength: 0
    function captureLength() {
        if (player && player.lengthSupported && player.length > 0) knownLength = player.length
    }
    onPlayerChanged: { knownLength = 0; captureLength() }
    Component.onCompleted: captureLength()
    Connections {
        target: page.player
        function onLengthChanged() { page.captureLength() }
        function onLengthSupportedChanged() { page.captureLength() }
        function onTrackChanged() { page.knownLength = 0 }
        function onPostTrackChanged() { page.captureLength() }
    }

    readonly property bool hasLength: knownLength > 0
    readonly property real frac: hasLength ? Math.max(0, Math.min(1, player.position / knownLength)) : 0
    readonly property string appIcon: player?.desktopEntry ? Quickshell.iconPath(player.desktopEntry, true) : ""

    function fmt(s) {
        s = Math.max(0, Math.floor(s || 0))
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }

    // MPRIS doesn't push position updates, so poke it while this page is visible + playing
    Timer {
        interval: 500
        repeat: true
        running: page.active && (page.player?.isPlaying ?? false)
        onTriggered: page.player.positionChanged()
    }

    component Label: Text {
        color: Colours.fg
        font.family: Theme.font
        font.pixelSize: 13
        textFormat: Text.PlainText
    }

    component CtrlButton: Rectangle {
        id: b
        property string glyph
        property bool enabledBtn: true
        property bool primary: false
        signal clicked()
        implicitWidth: primary ? 42 : 34
        implicitHeight: implicitWidth
        radius: width / 2
        color: primary ? Colours.accent : (bma.containsMouse ? Theme.raisedHover : "transparent")
        opacity: enabledBtn ? 1 : 0.35
        Behavior on color { ColorAnimation { duration: 120 } }
        Label {
            anchors.centerIn: parent
            text: b.glyph
            font.pixelSize: b.primary ? 20 : 18
            color: b.primary ? Colours.bg : Colours.fg
        }
        MouseArea {
            id: bma
            anchors.fill: parent
            hoverEnabled: true
            enabled: b.enabledBtn
            cursorShape: Qt.PointingHandCursor
            onClicked: b.clicked()
        }
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 16; rightMargin: 16; topMargin: 14; bottomMargin: 22 }
        spacing: 16

        ClippingRectangle {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 120
            implicitHeight: 120
            radius: 14
            color: Theme.raised
            Image {
                id: art
                anchors.fill: parent
                source: page.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                sourceSize { width: 240; height: 240 }
                asynchronous: true
            }
            Label {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                text: "󰎆"
                font.pixelSize: 40
                color: Theme.tint(Colours.fg, 0.3)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            // source chip: which app this page controls
            Rectangle {
                implicitWidth: chipRow.implicitWidth + 16
                implicitHeight: 22
                radius: 11
                color: Theme.raised
                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: 6
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: page.appIcon !== ""
                        width: 13; height: 13
                        source: page.appIcon
                        sourceSize { width: 26; height: 26 }
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: page.player?.identity || "Player"
                        font.pixelSize: 11
                        color: Theme.tint(Colours.fg, 0.7)
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                Layout.topMargin: 4
                text: Theme.trackTitle(page.player) || page.player?.identity || "Nothing playing"
                font.bold: true
                font.pixelSize: 15
                elide: Text.ElideRight
            }
            Label {
                Layout.fillWidth: true
                text: page.player?.trackArtist || ""
                visible: text !== ""
                color: Theme.tint(Colours.fg, 0.65)
                elide: Text.ElideRight
            }

            Item { Layout.fillHeight: true }

            WaveProgress {
                Layout.fillWidth: true
                progress: page.frac
                indeterminate: !page.hasLength
                playing: page.player?.isPlaying ?? false
                seekable: page.hasLength && (page.player?.canSeek ?? false) && (page.player?.positionSupported ?? false)
                onSeek: f => page.player.position = f * page.knownLength
            }
            RowLayout {
                Layout.fillWidth: true
                Label { text: page.hasLength ? page.fmt(page.player.position) : "--:--"; font.pixelSize: 11; color: Theme.tint(Colours.fg, 0.5) }
                Item { Layout.fillWidth: true }
                Label { text: page.hasLength ? page.fmt(page.knownLength) : "--:--"; font.pixelSize: 11; color: Theme.tint(Colours.fg, 0.5) }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 18
                CtrlButton {
                    glyph: "󰒮"
                    enabledBtn: page.player?.canGoPrevious ?? false
                    onClicked: page.player.previous()
                }
                CtrlButton {
                    primary: true
                    glyph: page.player?.isPlaying ? "󰏤" : "󰐊"
                    enabledBtn: page.player?.canTogglePlaying ?? false
                    onClicked: page.player.togglePlaying()
                }
                CtrlButton {
                    glyph: "󰒭"
                    enabledBtn: page.player?.canGoNext ?? false
                    onClicked: page.player.next()
                }
            }
        }
    }
}
