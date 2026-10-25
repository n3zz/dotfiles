import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Power / session menu. ←/→ or 1-5 to choose, Enter to run, Esc or click outside to close.
// Log out, reboot and shut down need a second press to confirm.
PanelWindow {
    id: win

    property int current: 0
    property int armedIndex: -1          // which dangerous action is waiting for confirmation
    property string uptime: ""

    readonly property var actions: [
        { glyph: "󰌾", label: "Lock",      danger: false, cmd: ["hyprlock"] },
        { glyph: "󰍃", label: "Log out",   danger: true,  cmd: ["bash", "-c", "loginctl terminate-session \"$XDG_SESSION_ID\""] },
        { glyph: "󰤄", label: "Suspend",   danger: false, cmd: ["systemctl", "suspend"] },
        { glyph: "󰜉", label: "Reboot",    danger: true,  cmd: ["systemctl", "reboot"] },
        { glyph: "󰐥", label: "Shut down", danger: true,  cmd: ["systemctl", "poweroff"] }
    ]

    // matte palette from wal (same recipe as the bar's Theme.qml)
    function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1) }
    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    readonly property color surface: Colours.bg
    readonly property color raised: mix(Colours.bg, Colours.fg, 0.06)
    readonly property color line: mix(Colours.bg, Colours.fg, 0.18)
    readonly property color danger: "#e5534b"
    readonly property string font: "JetBrainsMono Nerd Font"

    function run(i) {
        const a = actions[i]
        if (a.danger && armedIndex !== i) {
            armedIndex = i
            current = i
            disarm.restart()
            return
        }
        Quickshell.execDetached(a.cmd)
        Qt.quit()
    }

    Timer { id: disarm; interval: 3000; onTriggered: win.armedIndex = -1 }

    Process {
        command: ["uptime", "-p"]
        running: true
        stdout: StdioCollector { onStreamFinished: win.uptime = text.trim().replace(/^up /, "") }
    }

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell-power"

    component Label: Text {
        color: Colours.fg
        font.family: win.font
        font.pixelSize: 13
    }

    // fade the whole thing in
    Item {
        id: stage
        anchors.fill: parent
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity { NumberAnimation { duration: 200 } }

        // dim backdrop, click to close
        Rectangle {
            anchors.fill: parent
            color: win.tint(Colours.bg, 0.72)
            MouseArea { anchors.fill: parent; onClicked: Qt.quit() }
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: buttons.implicitWidth + 48
            height: col.implicitHeight + 48
            radius: 26
            color: win.surface
            border.width: 1
            border.color: win.line
            scale: stage.opacity < 1 ? 0.96 : 1
            Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }

            MouseArea { anchors.fill: parent }   // don't close when clicking the card

            focus: true
            Keys.onPressed: event => {
                const n = win.actions.length
                if (event.key === Qt.Key_Escape) Qt.quit()
                else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) win.current = (win.current + n - 1) % n
                else if (event.key === Qt.Key_Right || event.key === Qt.Key_L || event.key === Qt.Key_Tab) win.current = (win.current + 1) % n
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) win.run(win.current)
                else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_5) win.run(event.key - Qt.Key_1)
                else return
                event.accepted = true
            }
            Component.onCompleted: forceActiveFocus()

            ColumnLayout {
                id: col
                anchors.centerIn: parent
                spacing: 20

                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 2
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: "See you soon"
                        font.pixelSize: 20
                        font.bold: true
                    }
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        visible: win.uptime !== ""
                        text: "Up " + win.uptime
                        font.pixelSize: 12
                        color: win.tint(Colours.fg, 0.55)
                    }
                }

                RowLayout {
                    id: buttons
                    spacing: 14

                    Repeater {
                        model: win.actions

                        Rectangle {
                            id: btn
                            required property var modelData
                            required property int index
                            readonly property bool selected: win.current === index
                            readonly property bool armed: win.armedIndex === index

                            implicitWidth: 112
                            implicitHeight: 112
                            radius: 22
                            color: armed ? win.tint(win.danger, 0.28)
                                 : selected ? win.tint(Colours.accent, 0.28)
                                 : win.raised
                            border.width: selected || armed ? 1 : 0
                            border.color: armed ? win.danger : Colours.accent
                            scale: selected ? 1.04 : 1
                            Behavior on color { ColorAnimation { duration: 140 } }
                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }

                            Column {
                                anchors.centerIn: parent
                                spacing: 8
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: btn.modelData.glyph
                                    font.pixelSize: 30
                                    color: btn.armed ? win.danger : btn.selected ? Colours.accent : Colours.fg
                                }
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: btn.armed ? "Again to confirm" : btn.modelData.label
                                    font.pixelSize: btn.armed ? 10 : 12
                                    font.bold: btn.selected
                                    color: btn.armed ? win.danger : Colours.fg
                                }
                            }

                            Label {
                                anchors { top: parent.top; right: parent.right; margins: 8 }
                                text: btn.index + 1
                                font.pixelSize: 10
                                color: win.tint(Colours.fg, 0.3)
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: win.current = btn.index
                                onClicked: win.run(btn.index)
                            }
                        }
                    }
                }

                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: "←→ choose      ↵ select      1–5 quick pick      esc close"
                    font.pixelSize: 11
                    color: win.tint(Colours.fg, 0.4)
                }
            }
        }
    }
}
