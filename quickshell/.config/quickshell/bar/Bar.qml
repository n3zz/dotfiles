import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import Quickshell.Widgets

// Floating-island bar: workspaces + title | clock + media | stats + net + volume + bell + tray
// The clock pill unfolds into the dashboard; the right island unfolds into the notification centre.
PanelWindow {
    id: root

    required property var screenRef
    property string hubMode: ""            // "" (closed), "dash" or "media"
    property string shownMode: "dash"      // last mode opened, so the shape keeps its size while folding
    readonly property bool dashOpen: hubMode !== ""
    onHubModeChanged: if (hubMode !== "") shownMode = hubMode
    readonly property bool sideOpen: Notifs.sidebarOn && Notifs.sidebarScreen === screenRef.name
    readonly property bool anyOpen: dashOpen || sideOpen

    readonly property var monitor: Hyprland.monitorFor(screenRef)
    readonly property var player: {
        // skip playerctld's proxy player, it mirrors real ones and is often empty
        const ps = Mpris.players.values.filter(p => !p.dbusName.includes("playerctld"))
        return ps.find(p => p.isPlaying) ?? ps[0] ?? null
    }
    readonly property var sink: Pipewire.defaultAudioSink

    // ---------- motion ----------
    // Each panel is driven by one 0→1 value so size, corners, tint and content move as one.
    // Curve: "emphasized decelerate" — fast start, long soft landing.
    property real dashP: dashOpen ? 1 : 0
    property real sideP: sideOpen ? 1 : 0
    Behavior on dashP {
        NumberAnimation { duration: 520; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0] }
    }
    Behavior on sideP {
        NumberAnimation { duration: 560; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0] }
    }
    function lerp(a, b, t) { return a + (b - a) * t }
    // content waits for the shape to mostly open, and is gone before it folds shut
    function reveal(p) { return Math.max(0, Math.min(1, (p - 0.4) / 0.6)) }

    // The window spans the screen height, but only reserves the bar's height,
    // and the mask lets clicks through everywhere except the islands/panels.
    screen: screenRef
    anchors { top: true; left: true; right: true }
    margins { top: 8 }
    implicitHeight: screenRef.height - 8
    exclusiveZone: 42
    color: "transparent"
    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.keyboardFocus: anyOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Region {
        item: leftIsland
        Region { item: hub }
        Region { item: rightIsland }
        Region { item: sidePanel }
    }

    // click anywhere outside the bar to fold everything back up
    HyprlandFocusGrab {
        windows: [root]
        active: root.anyOpen
        onCleared: root.closeAll()
    }

    function closeAll() {
        hubMode = ""
        if (sideOpen) Notifs.sidebarOn = false
    }
    function toggleHub(mode) {
        const opening = hubMode !== mode
        closeAll()
        if (opening) {
            hubMode = mode
            hub.forceActiveFocus()
        }
    }
    // the sidebar can also be opened by keybind (IPC), so react to the state itself
    onSideOpenChanged: if (sideOpen) { hubMode = ""; sidePanel.forceActiveFocus() }

    PwObjectTracker { objects: [root.sink] }
    SystemClock { id: clock; precision: SystemClock.Minutes }

    // "Caffeine" toggle in the sidebar: block idle/lock while on
    IdleInhibitor { window: root; enabled: Notifs.caffeine }

    // ---------- building blocks ----------
    component Island: Rectangle {
        default property alias content: row.data
        implicitWidth: row.implicitWidth + 28
        height: 38
        radius: height / 2
        color: Theme.surface
        border.width: 1
        border.color: Theme.line
        RowLayout { id: row; anchors.centerIn: parent; spacing: 14 }
    }
    component Label: Text {
        color: Colours.fg
        font.family: Theme.font
        font.pixelSize: 13
    }
    component Sep: Rectangle {
        implicitWidth: 1
        implicitHeight: 16
        color: Theme.tint(Colours.fg, 0.15)
    }

    // ---------- left: workspaces + active window ----------
    Island {
        id: leftIsland
        anchors { left: parent.left; leftMargin: 12; top: parent.top }

        Row {
            spacing: 6
            Repeater {
                model: Hyprland.workspaces.values.filter(w =>
                    w.id > 0 && root.monitor && w.monitor && w.monitor.name === root.monitor.name)

                Rectangle {
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    width: modelData.active ? 22 : 8
                    height: 8
                    radius: 4
                    color: modelData.active ? Colours.accent
                         : modelData.urgent ? Theme.danger
                         : Theme.tint(Colours.fg, 0.45)
                    Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                    Behavior on color { ColorAnimation { duration: 200 } }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        cursorShape: Qt.PointingHandCursor
                        onClicked: parent.modelData.activate()
                    }
                }
            }
        }

        Label {
            text: Hyprland.activeToplevel?.title ?? ""
            visible: text !== ""
            elide: Text.ElideRight
            Layout.maximumWidth: 360
            color: Theme.tint(Colours.fg, 0.75)
        }
    }

    // ---------- centre hub: clock pill → dashboard (click clock) or player (click song) ----------
    Rectangle {
        id: hub
        z: 2
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }

        readonly property real closedW: pill.implicitWidth + 28
        readonly property real dashW: Math.min(780, root.width - 40)
        readonly property real mediaW: Math.max(closedW, mediaContent.implicitWidth)

        // open size for the current mode; animates when switching dash <-> media
        property real targetW: root.shownMode === "media" ? mediaW : dashW
        property real targetH: root.shownMode === "media" ? mediaContent.implicitHeight : dashContent.implicitHeight
        Behavior on targetW { NumberAnimation { duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0] } }
        Behavior on targetH { NumberAnimation { duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0] } }

        // crossfade between the two contents
        property real dashVis: root.shownMode === "dash" ? 1 : 0
        property real mediaVis: root.shownMode === "media" ? 1 : 0
        Behavior on dashVis { NumberAnimation { duration: 220 } }
        Behavior on mediaVis { NumberAnimation { duration: 220 } }

        width: root.lerp(closedW, targetW, root.dashP)
        height: root.lerp(38, 38 + targetH, root.dashP)
        radius: root.lerp(19, 24, root.dashP)
        color: Theme.surface
        border.width: 1
        border.color: Theme.line
        clip: true

        Keys.onEscapePressed: root.closeAll()

        // pill row: always visible, stays put at the top of the hub
        RowLayout {
            id: pill
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
            height: 38
            spacing: 14

            Label {
                text: Qt.formatDateTime(clock.date, "ddd d MMM   HH:mm")
                font.bold: true
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleHub("dash")
                }
            }

            Sep { visible: root.player !== null }

            Label {
                visible: root.player !== null
                text: !root.player ? "" :
                    (root.player.isPlaying ? "󰏤  " : "󰐊  ")
                    + (root.player.trackTitle || "Unknown")
                    + (root.player.trackArtist ? "  ·  " + root.player.trackArtist : "")
                elide: Text.ElideRight
                Layout.maximumWidth: 320
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    // left: media pop-out; right: quick play/pause
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            if (root.player?.canTogglePlaying) root.player.togglePlaying()
                        } else {
                            root.toggleHub("media")
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors { top: pill.bottom; left: parent.left; right: parent.right; leftMargin: 20; rightMargin: 20 }
            height: 1
            color: Theme.tint(Colours.fg, 0.10)
            opacity: root.reveal(root.dashP)
        }

        DashContent {
            id: dashContent
            anchors { top: pill.bottom; horizontalCenter: parent.horizontalCenter }
            width: hub.dashW
            active: root.hubMode === "dash"
            player: root.player
            opacity: root.reveal(root.dashP) * hub.dashVis
            visible: opacity > 0.01
            transform: Translate { y: (1 - root.reveal(root.dashP)) * -10 }
            onCloseRequested: root.closeAll()
        }

        MediaContent {
            id: mediaContent
            anchors { top: pill.bottom; horizontalCenter: parent.horizontalCenter }
            width: hub.mediaW
            active: root.hubMode === "media"
            player: root.player
            opacity: root.reveal(root.dashP) * hub.mediaVis
            visible: opacity > 0.01
            transform: Translate { y: (1 - root.reveal(root.dashP)) * -10 }
        }
    }

    // ---------- right: stats, net, volume, bell, tray ----------
    Island {
        id: rightIsland
        anchors { right: parent.right; rightMargin: 12; top: parent.top }

        Label {
            text: "  " + Stats.cpu + "%  " + Stats.cpuTemp + "°"
            color: Stats.cpuTemp >= 85 ? Theme.danger : Colours.fg
        }
        Label {
            text: "󰢮  " + Stats.gpu + "%  " + Stats.gpuTemp + "°"
            color: Stats.gpuTemp >= 83 ? Theme.danger : Colours.fg
        }
        Label { text: "󰍛  " + Stats.mem + "%" }
        Label {
            readonly property int pct: Stats.rootDisk ? Stats.rootDisk.pct : 0
            text: "󰋊  " + pct + "%"
            color: pct >= 90 ? Theme.danger : Colours.fg
        }

        Sep {}

        Label {
            text: Stats.net === "ethernet" ? "󰈀" : Stats.net === "wifi" ? "󰖩" : "󰖪"
            color: Stats.net === "" ? Theme.danger : Colours.fg
            font.pixelSize: 15
        }

        Label {
            readonly property var audio: root.sink?.audio ?? null
            text: !audio ? "󰝟" :
                audio.muted ? "󰝟  muted" :
                (audio.volume > 0.6 ? "󰕾" : audio.volume > 0.25 ? "󰖀" : "󰕿")
                    + "  " + Math.round(audio.volume * 100) + "%"
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                // left: mute; right: open the mixer; scroll: volume
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) Notifs.openSidebar(root.screenRef.name, "audio")
                    else if (parent.audio) parent.audio.muted = !parent.audio.muted
                }
                onWheel: wheel => {
                    const a = parent.audio
                    if (!a) return
                    a.volume = Math.max(0, Math.min(1, a.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)))
                }
            }
        }

        Label {
            text: (Notifs.dnd ? "󰂛" : Notifs.count > 0 ? "󰂞" : "󰂚")
                  + (Notifs.count > 0 ? "  " + Notifs.count : "")
            color: root.sideOpen || (Notifs.count > 0 && !Notifs.dnd) ? Colours.accent : Colours.fg
            font.pixelSize: 14
            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                // left: open the notification centre on this monitor; right: Do Not Disturb
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) Notifs.dnd = !Notifs.dnd
                    else Notifs.openSidebar(root.screenRef.name, "notifs")
                }
            }
        }

        Sep { visible: tray.count > 0 }

        Row {
            spacing: 10
            Repeater {
                id: tray
                model: SystemTray.items.values

                IconImage {
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    source: modelData.icon
                    implicitSize: 16

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: mouse => {
                            const it = parent.modelData
                            if (mouse.button === Qt.RightButton || it.onlyMenu) {
                                if (it.hasMenu) {
                                    const p = parent.mapToItem(null, 0, parent.height + 10)
                                    it.display(root, p.x, p.y)
                                }
                            } else if (mouse.button === Qt.MiddleButton) {
                                it.secondaryActivate()
                            } else {
                                it.activate()
                            }
                        }
                    }
                }
            }
        }
    }

    // ---------- notification centre: slides in from the right edge ----------
    Rectangle {
        id: sidePanel
        z: 3
        width: 420
        y: 46
        height: root.height - y - 12
        // parked just past the screen edge, slides to 12px from it
        x: root.lerp(root.width + 24, root.width - width - 12, root.sideP)
        visible: root.sideP > 0.001
        radius: 24
        color: Theme.surface
        border.width: 1
        border.color: Theme.line

        Keys.onEscapePressed: root.closeAll()

        // content travels with the panel, so it's fully visible the whole way in
        SideContent { anchors.fill: parent }
    }
}
