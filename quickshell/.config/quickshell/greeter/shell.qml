import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd

// Login screen (greetd greeter) — same look and motion as the lock screen.
// Runs as the `greeter` user inside a tiny Hyprland started by greetd.
// Wallpaper + colours come from /var/lib/qs-greeter (kept in sync from your session).
//
// Preview safely from your own session:  quickshell -p ~/.config/quickshell/greeter
// (no greetd there, so it runs in preview mode: the password isn't checked, Esc quits)
ShellRoot {
    id: root

    readonly property string themeDir: "/var/lib/qs-greeter"
    readonly property bool preview: !Greetd.available

    property var users: []
    property int userIdx: 0
    readonly property string user: users[userIdx] ?? ""
    property var sessions: []              // [{ type, name, exec, desktop, id }]
    property int sessionIdx: 0
    readonly property var session: sessions[sessionIdx] ?? null
    property string hostname: ""

    property string password: ""
    property bool busy: false
    property bool unlocking: false
    property string status: ""
    property int shakeTick: 0
    property bool sessionMenu: false

    // matte palette from wallust
    function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1) }
    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    readonly property color surface: Colours.bg
    readonly property color raised: mix(Colours.bg, Colours.fg, 0.06)
    readonly property color line: mix(Colours.bg, Colours.fg, 0.18)
    readonly property color danger: "#e5534b"
    readonly property string font: "JetBrainsMono Nerd Font"

    // ---------- remember the last user + session ----------
    FileView {
        path: Quickshell.env("HOME") + "/.qs-greeter.json"
        blockLoading: true
        printErrors: false
        onAdapterUpdated: writeAdapter()
        JsonAdapter {
            id: saved
            property string user: ""
            property string session: ""
        }
    }
    function pickDefaults() {
        const u = users.indexOf(saved.user)
        if (u >= 0) userIdx = u
        let s = sessions.findIndex(x => x.id === saved.session)
        if (s < 0) s = sessions.findIndex(x => /hyprland/i.test(x.id) && !/uwsm/i.test(x.id))
        sessionIdx = Math.max(0, s)
    }

    // ---------- users (real accounts with a login shell) ----------
    Process {
        running: true
        command: ["awk", "-F:", "$3>=1000 && $3<60000 && $7 !~ /(nologin|false)$/ {print $1}", "/etc/passwd"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.users = text.split("\n").filter(l => l.trim() !== "")
                root.pickDefaults()
            }
        }
    }

    // ---------- sessions from /usr/share/{wayland-sessions,xsessions} ----------
    Process {
        running: true
        command: ["sh", "-c", `
            for f in /usr/share/wayland-sessions/*.desktop /usr/share/xsessions/*.desktop; do
              [ -f "$f" ] || continue
              case "$f" in */wayland-sessions/*) t=wayland ;; *) t=x11 ;; esac
              grep -qiE '^(NoDisplay|Hidden)=true' "$f" && continue
              n=$(grep -m1 '^Name=' "$f" | cut -d= -f2-)
              e=$(grep -m1 '^Exec=' "$f" | cut -d= -f2-)
              d=$(grep -m1 '^DesktopNames=' "$f" | cut -d= -f2- | tr ';' ':' | sed 's/:$//')
              printf '%s\\t%s\\t%s\\t%s\\t%s\\n' "$t" "$n" "$e" "$d" "$(basename "$f" .desktop)"
            done`]
        stdout: StdioCollector {
            onStreamFinished: {
                root.sessions = text.split("\n").filter(l => l.includes("\t")).map(l => {
                    const p = l.split("\t")
                    return { type: p[0], name: p[1], exec: p[2], desktop: p[3] || p[1], id: p[4] }
                })
                root.pickDefaults()
            }
        }
    }
    Process {
        running: true
        command: ["cat", "/etc/hostname"]
        stdout: StdioCollector { onStreamFinished: root.hostname = text.trim() }
    }

    // "Exec=" line -> argv (drops %f-style field codes, keeps quoted args together)
    function argv(exec) {
        return (exec.match(/"[^"]*"|\S+/g) ?? [])
            .filter(a => !/^%[a-zA-Z]$/.test(a))
            .map(a => a.replace(/^"|"$/g, ""))
    }

    // ---------- login flow ----------
    function submit() {
        if (busy || unlocking || password === "" || user === "") return
        status = ""
        busy = true
        if (preview) { previewCheck.start(); return }
        Greetd.createSession(user)
    }
    function fail(msg) {
        busy = false
        password = ""
        status = msg
        shakeTick++
    }
    function launchSession() {
        saved.user = user
        saved.session = session?.id ?? ""
        if (preview) { Qt.quit(); return }
        const s = session
        if (!s) { Greetd.launch(["sh", "-l"]); return }
        const env = ["XDG_SESSION_TYPE=" + s.type, "XDG_CURRENT_DESKTOP=" + s.desktop, "XDG_SESSION_DESKTOP=" + s.id]
        if (s.type === "x11") Greetd.launch(["startx", "/usr/bin/env"].concat(argv(s.exec)), env)
        else Greetd.launch(argv(s.exec), env)
    }

    Connections {
        target: Greetd
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) Greetd.respond(root.password)
            else if (message !== "") root.status = message
        }
        function onReadyToLaunch() {
            root.busy = false
            root.password = ""
            root.unlocking = true
            launchTimer.start()
        }
        function onAuthFailure(message) { root.fail("Wrong password") }
        function onError(error) {
            Greetd.cancelSession()
            root.fail(error)
        }
    }
    // preview mode: pretend any password works
    Timer {
        id: previewCheck
        interval: 700
        onTriggered: { root.busy = false; root.password = ""; root.unlocking = true; launchTimer.start() }
    }
    // let the outro play, then hand over to the session (greetd closes the greeter)
    Timer { id: launchTimer; interval: 820; onTriggered: root.launchSession() }

    SystemClock { id: clock; precision: SystemClock.Seconds }

    // ---------- a digit that rolls over when it changes ----------
    component Digit: Item {
        id: d
        property string ch: "0"
        property string prev: ""
        property string last: ""
        property real size: 112
        property color color: "white"
        property real roll: 1
        implicitWidth: cur.implicitWidth
        implicitHeight: cur.implicitHeight
        clip: true
        onChChanged: { prev = last; last = ch; rollAnim.stop(); roll = 0; rollAnim.start() }
        NumberAnimation on roll { id: rollAnim; running: false; from: 0; to: 1; duration: 520; easing.type: Easing.OutQuint }
        Text {
            text: d.prev
            color: d.color
            font { family: "JetBrainsMono Nerd Font"; pixelSize: d.size; bold: true }
            y: -d.height * d.roll
            opacity: 1 - d.roll
        }
        Text {
            id: cur
            text: d.ch
            color: d.color
            font { family: "JetBrainsMono Nerd Font"; pixelSize: d.size; bold: true }
            y: d.height * (1 - d.roll)
            opacity: d.roll
        }
        Component.onCompleted: { last = ch; prev = ch }
    }

    // pill-shaped button used along the bottom edge
    component Chip: Rectangle {
        id: chip
        property string glyph
        property string label
        property bool armed: false
        property bool hot: armed || cma.containsMouse
        signal clicked()
        implicitWidth: chipRow.implicitWidth + 28
        implicitHeight: 42
        radius: 21
        color: armed ? Qt.rgba(0.898, 0.325, 0.294, 0.28) : cma.containsMouse ? Qt.lighter(Colours.bg, 1.35) : Colours.bg
        border.width: 1
        border.color: armed ? "#e5534b" : cma.containsMouse ? Qt.rgba(Colours.accent.r, Colours.accent.g, Colours.accent.b, 0.6)
                                                            : Qt.rgba(Colours.fg.r, Colours.fg.g, Colours.fg.b, 0.16)
        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on border.color { ColorAnimation { duration: 160 } }
        scale: cma.pressed ? 0.94 : 1
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: chip.label !== "" ? 10 : 0
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.glyph
                color: chip.armed ? "#e5534b" : chip.hot ? Colours.accent : Colours.fg
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                visible: text !== ""
                color: chip.armed ? "#e5534b" : Colours.fg
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
            }
        }
        MouseArea {
            id: cma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    // ---------- one window per monitor; the login card goes on the biggest one ----------
    readonly property var mainScreen: {
        let best = null
        for (const s of Quickshell.screens) if (!best || s.width * s.height > best.width * best.height) best = s
        return best
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: surf
            required property var modelData
            readonly property bool isMain: modelData === root.mainScreen
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: root.surface
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-greeter"
            WlrLayershell.keyboardFocus: isMain ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            // ---------- choreography (same as the lock screen) ----------
            property real intro: 0
            property real outro: 0
            NumberAnimation on intro { from: 0; to: 1; duration: 1300; easing.type: Easing.OutCubic; running: true }
            NumberAnimation on outro { id: outroAnim; running: false; from: 0; to: 1; duration: 640; easing.type: Easing.InOutCubic }
            Connections {
                target: root
                function onUnlockingChanged() { if (root.unlocking) outroDelay.start() }
            }
            Timer { id: outroDelay; interval: 180; onTriggered: outroAnim.start() }
            function stage(t0, t1) { return Math.max(0, Math.min(1, (intro - t0) / (t1 - t0))) }

            property real drift: 0
            SequentialAnimation on drift {
                loops: Animation.Infinite
                NumberAnimation { from: 0; to: 1; duration: 24000; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1; to: 0; duration: 24000; easing.type: Easing.InOutSine }
            }
            property real phase: 0
            FrameAnimation { running: root.busy; onTriggered: surf.phase += frameTime * 9 }

            // ----- wallpaper -----
            Image {
                id: wall
                anchors.fill: parent
                source: "file://" + root.themeDir + "/wallpaper"
                fillMode: Image.PreserveAspectCrop
                sourceSize { width: 1600; height: 900 }
                asynchronous: true
                cache: false
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: wall
                visible: wall.status === Image.Ready
                blurEnabled: true
                blurMax: 64
                blur: (surf.isMain ? 1 : 0.7) * surf.stage(0, 0.55) * (1 - surf.outro)
                brightness: -0.14 * surf.stage(0, 0.55) * (1 - surf.outro)
                scale: 1.03 + 0.04 * surf.drift + 0.10 * surf.outro
                transformOrigin: Item.Center
                opacity: 1 - surf.outro
            }
            Rectangle {
                anchors.fill: parent
                color: root.tint(Colours.bg, 0.45 * surf.stage(0, 0.5) * (1 - surf.outro))
            }
            // fade to black as we hand over to the session
            Rectangle { anchors.fill: parent; color: "black"; opacity: surf.outro }

            // ----- the login card (main monitor only) -----
            Item {
                id: content
                visible: surf.isMain
                anchors.fill: parent
                opacity: 1 - surf.outro
                scale: 1 + 0.06 * surf.outro
                transformOrigin: Item.Center

                // click anywhere empty: close the session menu
                MouseArea { anchors.fill: parent; onClicked: { root.sessionMenu = false; input.forceActiveFocus() } }

                // preview banner
                Rectangle {
                    visible: root.preview
                    anchors { top: parent.top; topMargin: 24; horizontalCenter: parent.horizontalCenter }
                    implicitWidth: pvText.implicitWidth + 28
                    implicitHeight: 34
                    radius: 17
                    color: root.tint(Colours.accent, 0.22)
                    border.width: 1
                    border.color: root.tint(Colours.accent, 0.5)
                    opacity: surf.stage(0.5, 1)
                    Text {
                        id: pvText
                        anchors.centerIn: parent
                        text: "󰈈   Preview mode — the password isn't checked · Esc to quit"
                        color: Colours.fg
                        font { family: root.font; pixelSize: 12 }
                    }
                }

                // hostname, top-left
                Text {
                    anchors { top: parent.top; left: parent.left; margins: 32 }
                    text: "󰣇  " + root.hostname
                    color: root.tint(Colours.fg, 0.6)
                    font { family: root.font; pixelSize: 14 }
                    opacity: surf.stage(0.5, 1)
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -30
                    spacing: 6

                    // clock
                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        opacity: surf.stage(0.15, 0.6)
                        transform: Translate { y: -40 * (1 - surf.stage(0.15, 0.6)) }
                        Repeater {
                            model: 5
                            Digit {
                                required property int index
                                ch: Qt.formatDateTime(clock.date, "HH:mm").charAt(index)
                                color: Colours.fg
                            }
                        }
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                        color: root.tint(Colours.fg, 0.75)
                        font { family: root.font; pixelSize: 20 }
                        opacity: surf.stage(0.28, 0.72)
                        transform: Translate { y: -24 * (1 - surf.stage(0.28, 0.72)) }
                    }

                    Item { implicitHeight: 40 }

                    // ----- password pill (identical behaviour to the lock screen) -----
                    Rectangle {
                        id: pill
                        Layout.alignment: Qt.AlignHCenter
                        // grows with the dots so they never run into the name (each dot is 9px + 8px gap)
                        readonly property real dotsW: Math.min(root.password.length, 22) * 17
                        implicitWidth: userBox.width + 26 + Math.max(260, dotsW + 40)
                        implicitHeight: 58
                        radius: height / 2
                        color: root.unlocking ? Colours.accent : flash.running ? root.tint(root.danger, 0.25) : root.surface
                        border.width: 1
                        border.color: root.unlocking ? Colours.accent
                                    : root.status !== "" ? root.danger
                                    : input.activeFocus ? root.tint(Colours.accent, 0.8) : root.line
                        Behavior on implicitWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 220 } }
                        Behavior on border.color { ColorAnimation { duration: 180 } }
                        opacity: surf.stage(0.42, 0.92)
                        scale: 0.92 + 0.08 * surf.stage(0.42, 0.92)
                        transform: Translate { id: shake; y: 30 * (1 - surf.stage(0.42, 0.92)) }
                        SequentialAnimation {
                            id: shakeAnim
                            NumberAnimation { target: shake; property: "x"; to: -14; duration: 50 }
                            NumberAnimation { target: shake; property: "x"; to: 14; duration: 70 }
                            NumberAnimation { target: shake; property: "x"; to: -9; duration: 60 }
                            NumberAnimation { target: shake; property: "x"; to: 6; duration: 60 }
                            NumberAnimation { target: shake; property: "x"; to: 0; duration: 50 }
                        }
                        Timer { id: flash; interval: 450 }
                        Connections {
                            target: root
                            function onShakeTickChanged() { shakeAnim.restart(); flash.restart() }
                        }

                        Item {
                            id: input
                            anchors.fill: parent
                            focus: surf.isMain
                            Component.onCompleted: if (surf.isMain) forceActiveFocus()

                            Keys.onPressed: e => {
                                if (root.busy || root.unlocking) { e.accepted = true; return }
                                const ctrl = e.modifiers & Qt.ControlModifier
                                if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.submit()
                                else if (e.key === Qt.Key_Backspace) root.password = ctrl ? "" : root.password.slice(0, -1)
                                else if (e.key === Qt.Key_Escape) {
                                    if (root.sessionMenu) root.sessionMenu = false
                                    else if (root.password !== "") root.password = ""
                                    else if (root.preview) Qt.quit()
                                }
                                // Tab: next session · Ctrl+←/→: switch user
                                else if (e.key === Qt.Key_Tab && root.sessions.length)
                                    root.sessionIdx = (root.sessionIdx + 1) % root.sessions.length
                                else if (ctrl && e.key === Qt.Key_Right && root.users.length)
                                    root.userIdx = (root.userIdx + 1) % root.users.length
                                else if (ctrl && e.key === Qt.Key_Left && root.users.length)
                                    root.userIdx = (root.userIdx - 1 + root.users.length) % root.users.length
                                else if (e.text.length === 1 && e.text.charCodeAt(0) >= 32) {
                                    root.password += e.text
                                    root.status = ""
                                }
                                e.accepted = true
                            }

                            MouseArea { anchors.fill: parent; onClicked: input.forceActiveFocus() }

                            // who's signing in: avatar + name on the left of the pill
                            Row {
                                id: userBox
                                anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                                spacing: 10
                                opacity: root.unlocking ? 0 : 1
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                                Rectangle {
                                    id: avatar
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 42; height: 42; radius: 21
                                    gradient: Gradient {
                                        GradientStop { position: 0; color: Qt.lighter(Colours.accent, 1.3) }
                                        GradientStop { position: 1; color: Qt.darker(Colours.accent, 1.35) }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.user.charAt(0).toUpperCase()
                                        color: root.surface
                                        font { family: root.font; pixelSize: 19; bold: true }
                                    }
                                    Connections {
                                        target: root
                                        function onUserChanged() { avatarPop.restart() }
                                    }
                                    SequentialAnimation {
                                        id: avatarPop
                                        NumberAnimation { target: avatar; property: "scale"; to: 0.8; duration: 90 }
                                        NumberAnimation { target: avatar; property: "scale"; to: 1; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
                                    }
                                    // more than one account: click to switch
                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: root.users.length > 1
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { root.userIdx = (root.userIdx + 1) % root.users.length; input.forceActiveFocus() }
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.user + (root.users.length > 1 ? "  󰅀" : "")
                                    color: Colours.fg
                                    font { family: root.font; pixelSize: 14; bold: true }
                                }
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 1; height: 26
                                    color: root.line
                                }
                            }

                            // password area: everything right of the divider
                            Item {
                                id: field
                                anchors { left: userBox.right; right: parent.right; top: parent.top; bottom: parent.bottom; leftMargin: 4; rightMargin: 18 }
                                clip: true
                            }

                            Text {
                                anchors.centerIn: field
                                visible: root.password.length === 0 && !root.unlocking
                                text: root.busy ? "Signing in…" : "󰌾   Password"
                                color: root.tint(Colours.fg, 0.45)
                                font { family: root.font; pixelSize: 14 }
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: root.unlocking
                                text: "󰄬"
                                color: Colours.bg
                                font { family: root.font; pixelSize: 24; bold: true }
                                scale: root.unlocking ? 1 : 0.3
                                Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack } }
                            }
                            Row {
                                parent: field
                                anchors.centerIn: parent
                                spacing: 8
                                visible: root.password.length > 0 && !root.unlocking
                                Repeater {
                                    model: Math.min(root.password.length, 22)
                                    Rectangle {
                                        id: dot
                                        required property int index
                                        width: 9; height: 9; radius: 4.5
                                        color: root.busy ? root.tint(Colours.accent, 0.6) : Colours.accent
                                        scale: 0
                                        Component.onCompleted: pop.start()
                                        NumberAnimation on scale { id: pop; running: false; from: 0; to: 1; duration: 260; easing.type: Easing.OutBack }
                                        transform: Translate { y: root.busy ? Math.sin(surf.phase - dot.index * 0.55) * 4 : 0 }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredHeight: 20
                        text: root.status
                        color: root.danger
                        font { family: root.font; pixelSize: 13 }
                        opacity: root.status !== "" ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                }

                // ----- bottom-left: session picker -----
                Item {
                    anchors { left: parent.left; bottom: parent.bottom; margins: 32 }
                    width: sessionChip.width
                    height: sessionChip.height
                    opacity: surf.stage(0.55, 1)
                    transform: Translate { y: 24 * (1 - surf.stage(0.55, 1)) }

                    Chip {
                        id: sessionChip
                        glyph: root.session?.type === "x11" ? "󰍹" : "󰖲"
                        label: (root.session?.name ?? "Session") + (root.sessions.length > 1 ? "   󰅃" : "")
                        armed: false
                        onClicked: root.sessionMenu = !root.sessionMenu
                    }

                    // menu that unfolds upwards
                    Rectangle {
                        id: menu
                        anchors { bottom: sessionChip.top; bottomMargin: 10; left: parent.left }
                        width: Math.max(220, menuCol.implicitWidth + 12)
                        height: (menuCol.implicitHeight + 12) * menuP
                        property real menuP: root.sessionMenu ? 1 : 0
                        Behavior on menuP { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
                        visible: menuP > 0.01
                        clip: true
                        radius: 16
                        color: root.surface
                        border.width: 1
                        border.color: root.line
                        Column {
                            id: menuCol
                            x: 6; y: 6
                            opacity: menu.menuP
                            Repeater {
                                model: root.sessions
                                Rectangle {
                                    id: opt
                                    required property var modelData
                                    required property int index
                                    readonly property bool cur: index === root.sessionIdx
                                    width: menu.width - 12
                                    height: 36
                                    radius: 10
                                    color: cur ? root.tint(Colours.accent, 0.2) : oma.containsMouse ? root.raised : "transparent"
                                    Row {
                                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                        spacing: 10
                                        Text {
                                            text: opt.modelData.type === "x11" ? "󰍹" : "󰖲"
                                            color: opt.cur ? Colours.accent : root.tint(Colours.fg, 0.6)
                                            font { family: root.font; pixelSize: 14 }
                                        }
                                        Text {
                                            text: opt.modelData.name
                                            color: Colours.fg
                                            font { family: root.font; pixelSize: 13; bold: opt.cur }
                                        }
                                        Text {
                                            text: opt.modelData.type === "x11" ? "X11" : ""
                                            color: root.tint(Colours.fg, 0.4)
                                            font { family: root.font; pixelSize: 10 }
                                        }
                                    }
                                    MouseArea {
                                        id: oma
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { root.sessionIdx = opt.index; root.sessionMenu = false; input.forceActiveFocus() }
                                    }
                                }
                            }
                        }
                    }
                }

                // ----- bottom-right: power (press twice to confirm) -----
                Row {
                    anchors { right: parent.right; bottom: parent.bottom; margins: 32 }
                    spacing: 10
                    opacity: surf.stage(0.6, 1)
                    transform: Translate { y: 24 * (1 - surf.stage(0.6, 1)) }
                    Repeater {
                        model: [
                            { g: "󰤄", label: "Sleep", cmd: ["systemctl", "suspend"] },
                            { g: "󰜉", label: "Restart", cmd: ["systemctl", "reboot"] },
                            { g: "󰐥", label: "Shut down", cmd: ["systemctl", "poweroff"] }
                        ]
                        Chip {
                            id: pw
                            required property var modelData
                            glyph: modelData.g
                            label: armed ? "Again to " + modelData.label.toLowerCase() : (hot ? modelData.label : "")
                            Timer { id: disarm; interval: 3000; onTriggered: pw.armed = false }
                            onClicked: {
                                if (armed) { armed = false; if (!root.preview) Quickshell.execDetached(modelData.cmd) }
                                else { armed = true; disarm.restart() }
                            }
                        }
                    }
                }

                // key hints
                Text {
                    anchors { bottom: parent.bottom; bottomMargin: 44; horizontalCenter: parent.horizontalCenter }
                    text: "Tab  session" + (root.users.length > 1 ? "   ·   Ctrl ←/→  user" : "")
                    color: root.tint(Colours.fg, 0.35)
                    font { family: root.font; pixelSize: 11 }
                    opacity: surf.stage(0.7, 1)
                }
            }
        }
    }
}
