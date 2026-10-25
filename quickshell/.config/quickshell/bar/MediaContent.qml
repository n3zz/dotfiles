import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris

// Compact player that unfolds out of the clock pill (lives inside Bar.qml's hub)
Item {
    id: media

    property var player: null
    property bool active: false

    readonly property real frac: player && player.length > 0 ? Math.min(1, player.position / player.length) : 0

    function fmt(s) {
        s = Math.max(0, Math.floor(s || 0))
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }

    implicitWidth: 460
    implicitHeight: 152

    // MPRIS doesn't push position updates, so poke it once a second while visible + playing
    Timer {
        interval: 1000
        repeat: true
        running: media.active && (media.player?.isPlaying ?? false)
        onTriggered: media.player.positionChanged()
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
        anchors { fill: parent; margins: 16 }
        spacing: 16

        ClippingRectangle {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 118
            implicitHeight: 118
            radius: 14
            color: Theme.raised
            Image {
                id: art
                anchors.fill: parent
                source: media.player?.trackArtUrl ?? ""
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

            Label {
                Layout.fillWidth: true
                text: media.player?.trackTitle || "Nothing playing"
                font.bold: true
                font.pixelSize: 15
                elide: Text.ElideRight
            }
            Label {
                Layout.fillWidth: true
                text: media.player?.trackArtist || media.player?.identity || ""
                color: Theme.tint(Colours.fg, 0.65)
                elide: Text.ElideRight
            }
            Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: media.player?.trackAlbum ?? ""
                font.pixelSize: 11
                color: Theme.tint(Colours.fg, 0.45)
                elide: Text.ElideRight
            }

            Item { Layout.fillHeight: true }

            // progress (click to seek)
            Rectangle {
                id: track
                Layout.fillWidth: true
                visible: media.player?.lengthSupported ?? false
                implicitHeight: 6
                radius: 3
                color: Theme.raised
                Rectangle {
                    width: parent.width * media.frac
                    height: parent.height
                    radius: 3
                    color: Colours.accent
                    Behavior on width { NumberAnimation { duration: 400 } }
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    enabled: (media.player?.canSeek ?? false) && (media.player?.positionSupported ?? false)
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        media.player.position = Math.max(0, Math.min(1, mouse.x / track.width)) * media.player.length
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                visible: track.visible
                Label { text: media.fmt(media.player?.position); font.pixelSize: 11; color: Theme.tint(Colours.fg, 0.5) }
                Item { Layout.fillWidth: true }
                Label { text: media.fmt(media.player?.length); font.pixelSize: 11; color: Theme.tint(Colours.fg, 0.5) }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 18
                CtrlButton {
                    glyph: "󰒮"
                    enabledBtn: media.player?.canGoPrevious ?? false
                    onClicked: media.player.previous()
                }
                CtrlButton {
                    primary: true
                    glyph: media.player?.isPlaying ? "󰏤" : "󰐊"
                    enabledBtn: media.player?.canTogglePlaying ?? false
                    onClicked: media.player.togglePlaying()
                }
                CtrlButton {
                    glyph: "󰒭"
                    enabledBtn: media.player?.canGoNext ?? false
                    onClicked: media.player.next()
                }
            }
        }
    }
}
