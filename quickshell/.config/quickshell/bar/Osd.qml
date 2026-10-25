import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

// Volume OSD: a small pill near the bottom of the focused monitor whenever the output
// volume / mute / device changes. Click-through, auto-hides.
PanelWindow {
    id: osd

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink?.audio ?? null
    readonly property real level: audio ? audio.volume : 0
    readonly property bool muted: audio?.muted ?? false
    property bool deviceChanged: false

    // don't flash on startup / reload
    property bool armed: false
    Timer { interval: 1500; running: true; onTriggered: osd.armed = true }

    property bool showing: false
    property real shown: showing ? 1 : 0
    Behavior on shown { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    function poke(fromDevice) {
        if (!armed || Notifs.sidebarOn) return
        deviceChanged = fromDevice
        showing = true
        hideTimer.restart()
    }

    Timer { id: hideTimer; interval: 1500; onTriggered: osd.showing = false }

    PwObjectTracker { objects: [osd.sink] }

    Connections {
        target: osd.audio
        function onVolumesChanged() { osd.poke(false) }
        function onMutedChanged() { osd.poke(false) }
    }
    onSinkChanged: poke(true)

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    anchors.bottom: true
    margins.bottom: 90
    implicitWidth: 320
    implicitHeight: 64
    visible: shown > 0.01
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}          // fully click-through
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-osd"

    component Label: Text {
        color: Colours.fg
        font.family: Theme.font
        font.pixelSize: 13
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.surface
        border.width: 1
        border.color: Theme.line
        opacity: osd.shown
        transform: Translate { y: (1 - osd.shown) * 14 }

        RowLayout {
            anchors { fill: parent; leftMargin: 20; rightMargin: 22 }
            spacing: 14

            Label {
                text: osd.muted ? "󰝟" : osd.level > 0.6 ? "󰕾" : osd.level > 0.25 ? "󰖀" : "󰕿"
                font.pixelSize: 22
                color: osd.muted ? Theme.danger : Colours.accent
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Label {
                    Layout.fillWidth: true
                    visible: osd.deviceChanged
                    text: osd.sink ? (osd.sink.nickname || osd.sink.description || osd.sink.name) : ""
                    font.pixelSize: 11
                    color: Theme.tint(Colours.fg, 0.65)
                    elide: Text.ElideRight
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 8
                    radius: 4
                    color: Theme.raised
                    Rectangle {
                        width: parent.width * Math.min(1, osd.level)
                        height: parent.height
                        radius: 4
                        color: osd.muted ? Theme.tint(Colours.fg, 0.3) : Colours.accent
                        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }
                }
            }

            Label {
                Layout.preferredWidth: 38
                horizontalAlignment: Text.AlignRight
                text: osd.muted ? "muted" : Math.round(osd.level * 100) + "%"
                font.pixelSize: 13
                font.bold: true
            }
        }
    }
}
