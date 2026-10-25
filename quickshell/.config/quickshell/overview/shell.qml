import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Workspace overview (Task View style) for the focused monitor, with live window previews.
// Click a window to focus it, click a workspace to switch, middle-click a window to close it.
// ←/→ (or 1-9) pick a workspace, Enter switches, Esc / click outside closes.
PanelWindow {
    id: win

    readonly property string home: Quickshell.env("HOME")
    readonly property var mon: Hyprland.focusedMonitor
    readonly property var workspaces: Hyprland.workspaces.values
        .filter(w => w.id > 0 && w.monitor && mon && w.monitor.name === mon.name)
        .sort((a, b) => a.id - b.id)
    property int current: Math.max(0, workspaces.findIndex(w => w.active))

    // matte palette from wal
    function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1) }
    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    readonly property color surface: Colours.bg
    readonly property color raised: mix(Colours.bg, Colours.fg, 0.06)
    readonly property color line: mix(Colours.bg, Colours.fg, 0.18)
    readonly property string font: "JetBrainsMono Nerd Font"

    // tile sizing: up to 4 per row, monitor aspect ratio
    readonly property int cols: Math.max(1, Math.min(4, workspaces.length))
    readonly property real tileW: Math.min(440, (width * 0.88 - (cols - 1) * 24) / cols)
    readonly property real tileH: tileW * height / Math.max(1, width)
    readonly property real s: tileW / Math.max(1, width)     // screen → tile scale

    function close() { if (!closing) { closing = true; outro.start() } }
    property bool closing: false
    function goTo(ws) { ws.activate(); close() }

    Component.onCompleted: Hyprland.refreshToplevels()   // fresh window positions/sizes

    screen: Quickshell.screens.find(sc => sc.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell-overview"

    component Label: Text {
        color: Colours.fg
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
    }

    Item {
        id: stage
        anchors.fill: parent
        opacity: 0
        Component.onCompleted: intro.start()

        NumberAnimation { id: intro; target: stage; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
        SequentialAnimation {
            id: outro
            NumberAnimation { target: stage; property: "opacity"; to: 0; duration: 160; easing.type: Easing.InCubic }
            ScriptAction { script: Qt.quit() }
        }

        // backdrop
        Rectangle {
            anchors.fill: parent
            color: win.tint(Colours.bg, 0.82)
            MouseArea { anchors.fill: parent; onClicked: win.close() }
        }

        focus: true
        Keys.onPressed: e => {
            const n = win.workspaces.length
            if (e.key === Qt.Key_Escape) win.close()
            else if (e.key === Qt.Key_Left || e.key === Qt.Key_H) win.current = (win.current + n - 1) % n
            else if ((e.key === Qt.Key_Right || e.key === Qt.Key_L || e.key === Qt.Key_Tab) && n) win.current = (win.current + 1) % n
            else if (e.key === Qt.Key_Up || e.key === Qt.Key_K) win.current = Math.max(0, win.current - win.cols)
            else if (e.key === Qt.Key_Down || e.key === Qt.Key_J) win.current = Math.min(n - 1, win.current + win.cols)
            else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && n) win.goTo(win.workspaces[win.current])
            else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9) {
                const ws = win.workspaces.find(w => w.id === e.key - Qt.Key_0)
                if (ws) win.goTo(ws)
            } else return
            e.accepted = true
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 22

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: "Workspaces  ·  " + (win.mon?.name ?? "")
                font.pixelSize: 15
                font.bold: true
                color: win.tint(Colours.fg, 0.7)
            }

            GridLayout {
                Layout.alignment: Qt.AlignHCenter
                columns: win.cols
                columnSpacing: 24
                rowSpacing: 30

                Repeater {
                    model: win.workspaces

                    ColumnLayout {
                        id: tileCol
                        required property var modelData
                        required property int index
                        readonly property bool selected: index === win.current
                        spacing: 8

                        // staggered pop-in
                        opacity: 0
                        scale: 0.94
                        Component.onCompleted: popIn.start()
                        ParallelAnimation {
                            id: popIn
                            PauseAnimation { duration: tileCol.index * 35 }
                            NumberAnimation { target: tileCol; property: "opacity"; to: 1; duration: 260; easing.type: Easing.OutCubic }
                            NumberAnimation { target: tileCol; property: "scale"; to: 1; duration: 340; easing.type: Easing.OutQuint }
                        }

                        // workspace tile
                        Rectangle {
                            id: tile
                            implicitWidth: win.tileW
                            implicitHeight: win.tileH
                            radius: 14
                            color: win.raised
                            border.width: tileCol.selected ? 2 : 1
                            border.color: tileCol.selected ? Colours.accent : win.line
                            clip: true
                            scale: tileMa.containsMouse ? 1.02 : 1
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                            // wallpaper behind the windows
                            Image {
                                anchors.fill: parent
                                source: "file://" + win.home + "/.cache/current-wallpaper"
                                fillMode: Image.PreserveAspectCrop
                                sourceSize { width: 480; height: 270 }
                                asynchronous: true
                                opacity: 0.55
                            }

                            MouseArea {
                                id: tileMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: win.current = tileCol.index
                                onClicked: win.goTo(tileCol.modelData)
                            }

                            // windows, placed where they really are (floating ones on top)
                            Repeater {
                                model: tileCol.modelData.toplevels.values

                                Rectangle {
                                    id: wnd
                                    required property var modelData
                                    readonly property var ipc: modelData.lastIpcObject ?? {}
                                    readonly property bool hasGeom: ipc.at !== undefined && ipc.size !== undefined
                                    readonly property string appId: modelData.wayland?.appId ?? ""

                                    x: hasGeom ? (ipc.at[0] - (win.mon?.x ?? 0)) * win.s : 6
                                    y: hasGeom ? (ipc.at[1] - (win.mon?.y ?? 0)) * win.s : 6
                                    width: hasGeom ? Math.max(24, ipc.size[0] * win.s) : tile.width - 12
                                    height: hasGeom ? Math.max(18, ipc.size[1] * win.s) : tile.height - 12
                                    z: ipc.floating ? 2 : 1
                                    radius: 7
                                    color: win.surface
                                    border.width: modelData.activated ? 2 : 1
                                    border.color: modelData.activated ? Colours.accent
                                                : wndMa.containsMouse ? win.tint(Colours.fg, 0.6) : win.line
                                    clip: true

                                    ScreencopyView {
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        captureSource: wnd.modelData.wayland
                                        live: true
                                    }

                                    // app icon badge
                                    Rectangle {
                                        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 6 }
                                        visible: wnd.height > 50 && iconImg.status === Image.Ready
                                        width: 26; height: 26; radius: 8
                                        color: win.surface
                                        border.width: 1
                                        border.color: win.line
                                        Image {
                                            id: iconImg
                                            anchors.centerIn: parent
                                            width: 18; height: 18
                                            source: wnd.appId ? Quickshell.iconPath(wnd.appId, true) : ""
                                            sourceSize { width: 36; height: 36 }
                                        }
                                    }

                                    MouseArea {
                                        id: wndMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                        onEntered: win.current = tileCol.index
                                        onClicked: mouse => {
                                            const t = wnd.modelData.wayland
                                            if (!t) return
                                            if (mouse.button === Qt.MiddleButton) { t.close(); return }
                                            t.activate()
                                            win.close()
                                        }
                                    }

                                    // title on hover
                                    Rectangle {
                                        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 4 }
                                        visible: wndMa.containsMouse && wnd.width > 60
                                        height: 20
                                        radius: 6
                                        color: win.surface
                                        Label {
                                            anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                                            verticalAlignment: Text.AlignVCenter
                                            text: wnd.modelData.title
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }

                        // label under the tile
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 8
                            Rectangle {
                                implicitWidth: 22; implicitHeight: 22; radius: 7
                                color: tileCol.modelData.active ? Colours.accent : win.raised
                                Label {
                                    anchors.centerIn: parent
                                    text: tileCol.modelData.id
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: tileCol.modelData.active ? Colours.bg : Colours.fg
                                }
                            }
                            Label {
                                readonly property int n: tileCol.modelData.toplevels.values.length
                                text: n === 0 ? "empty" : n + (n === 1 ? " window" : " windows")
                                font.pixelSize: 12
                                color: win.tint(Colours.fg, 0.55)
                            }
                        }
                    }
                }
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: "click a window to focus      middle-click to close      ←→ / 1–9 workspace      esc close"
                font.pixelSize: 11
                color: win.tint(Colours.fg, 0.4)
            }
        }
    }
}
