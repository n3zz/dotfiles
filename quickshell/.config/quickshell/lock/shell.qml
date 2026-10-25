import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Services.Mpris

// Lock screen (ext-session-lock). Starts locked; unlocks and exits on a correct password.
// If this process ever dies while locked, Hyprland keeps the session locked (solid colour) —
// it fails safe. With misc.allow_session_lock_restore you can relaunch it from a TTY.
ShellRoot {
    id: root

    readonly property string home: Quickshell.env("HOME")
    property string password: ""
    property bool busy: false
    property bool unlocking: false
    property string status: ""
    property int shakeTick: 0

    readonly property var player: {
        const ps = Mpris.players.values.filter(p => !p.dbusName.includes("playerctld"))
        return ps.find(p => p.isPlaying) ?? null
    }

    // matte palette from wal
    function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1) }
    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    readonly property color surface: Colours.bg
    readonly property color line: mix(Colours.bg, Colours.fg, 0.18)
    readonly property color danger: "#e5534b"
    readonly property string font: "JetBrainsMono Nerd Font"

    function submit() {
        if (busy || unlocking || password === "") return
        status = ""
        busy = true
        if (!pam.start()) {
            busy = false
            status = "Couldn't start authentication"
        }
    }

    function fail(msg) {
        password = ""
        status = msg
        shakeTick++
    }

    PamContext {
        id: pam
        config: "login"   // same PAM stack as your normal login

        onPamMessage: {
            if (responseRequired) respond(root.password)
            else if (message !== "") root.status = message
        }
        onCompleted: result => {
            root.busy = false
            if (result === PamResult.Success) {
                root.password = ""
                root.unlocking = true
                unlockTimer.start()
            } else {
                root.fail("Wrong password")
            }
        }
        onError: root.fail("Authentication error")
    }

    // let the outro play (tick, un-blur, zoom through), then release the lock and exit
    Timer {
        id: unlockTimer
        interval: 820
        onTriggered: {
            lock.locked = false
            Qt.callLater(Qt.quit)
        }
    }

    SystemClock { id: clock; precision: SystemClock.Seconds }

    // ---------- a digit that rolls over when it changes ----------
    component Digit: Item {
        id: d
        property string ch: "0"
        property string prev: ""       // what's rolling out
        property string last: ""       // what was showing before this change
        property real size: 112
        property color color: "white"
        property real roll: 1          // 0 → 1 while rolling

        implicitWidth: cur.implicitWidth
        implicitHeight: cur.implicitHeight
        clip: true

        onChChanged: {
            prev = last
            last = ch
            rollAnim.stop()
            roll = 0
            rollAnim.start()
        }
        NumberAnimation on roll { id: rollAnim; running: false; from: 0; to: 1; duration: 520; easing.type: Easing.OutQuint }

        Text {
            id: old
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

    WlSessionLock {
        id: lock
        locked: true

        WlSessionLockSurface {
            id: surf
            color: root.surface

            // ---------- choreography ----------
            // intro: 0 → 1 on lock; outro: 0 → 1 on successful unlock
            property real intro: 0
            property real outro: 0
            NumberAnimation on intro { from: 0; to: 1; duration: 1100; easing.type: Easing.OutCubic; running: true }
            NumberAnimation on outro {
                id: outroAnim
                running: false; from: 0; to: 1; duration: 640; easing.type: Easing.InOutCubic
            }
            Connections {
                target: root
                function onUnlockingChanged() { if (root.unlocking) outroDelay.start() }
            }
            Timer { id: outroDelay; interval: 180; onTriggered: outroAnim.start() }   // let the tick show first

            function stage(t0, t1) { return Math.max(0, Math.min(1, (intro - t0) / (t1 - t0))) }

            // slow drift so the background never looks frozen
            property real drift: 0
            SequentialAnimation on drift {
                loops: Animation.Infinite
                NumberAnimation { from: 0; to: 1; duration: 24000; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1; to: 0; duration: 24000; easing.type: Easing.InOutSine }
            }

            // ripple for the dots while the password is being checked
            property real phase: 0
            FrameAnimation {
                running: root.busy
                onTriggered: surf.phase += frameTime * 9
            }

            // ----- wallpaper: blurs in on lock, un-blurs and zooms through on unlock -----
            Image {
                id: wall
                anchors.fill: parent
                source: "file://" + root.home + "/.cache/current-wallpaper"
                fillMode: Image.PreserveAspectCrop
                sourceSize { width: 1600; height: 900 }
                asynchronous: true
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: wall
                visible: wall.status === Image.Ready
                blurEnabled: true
                blurMax: 64
                blur: surf.stage(0, 0.55) * (1 - surf.outro)
                brightness: -0.12 * surf.stage(0, 0.55) * (1 - surf.outro)
                scale: 1.03 + 0.04 * surf.drift + 0.10 * surf.outro
                transformOrigin: Item.Center
            }
            Rectangle {
                anchors.fill: parent
                color: root.tint(Colours.bg, 0.45 * surf.stage(0, 0.5) * (1 - surf.outro))
            }

            // ----- foreground -----
            Item {
                id: content
                anchors.fill: parent
                opacity: 1 - surf.outro
                scale: 1 + 0.06 * surf.outro
                transformOrigin: Item.Center

                ColumnLayout {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -40
                    spacing: 6

                    // clock: digits roll individually
                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        opacity: surf.stage(0.15, 0.6)
                        transform: Translate { y: -40 * (1 - surf.stage(0.15, 0.6)) }

                        Repeater {
                            model: 5   // H H : m m
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

                    Item { implicitHeight: 34 }

                    // ----- password pill -----
                    Rectangle {
                        id: pill
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 340 + Math.min(root.password.length, 22) * 2
                        implicitHeight: 54
                        radius: height / 2
                        color: root.unlocking ? Colours.accent
                             : flash.running ? root.tint(root.danger, 0.25) : root.surface
                        border.width: 1
                        border.color: root.unlocking ? Colours.accent
                                    : root.status !== "" ? root.danger
                                    : input.activeFocus ? root.tint(Colours.accent, 0.8) : root.line
                        Behavior on implicitWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 220 } }
                        Behavior on border.color { ColorAnimation { duration: 180 } }

                        opacity: surf.stage(0.38, 0.9)
                        scale: 0.92 + 0.08 * surf.stage(0.38, 0.9)

                        transform: Translate { id: shake; y: 30 * (1 - surf.stage(0.38, 0.9)) }
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
                            focus: true
                            Component.onCompleted: forceActiveFocus()

                            Keys.onPressed: e => {
                                if (root.busy || root.unlocking) { e.accepted = true; return }
                                if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.submit()
                                else if (e.key === Qt.Key_Backspace) {
                                    root.password = (e.modifiers & Qt.ControlModifier) ? "" : root.password.slice(0, -1)
                                } else if (e.key === Qt.Key_Escape) root.password = ""
                                else if (e.text.length === 1 && e.text.charCodeAt(0) >= 32) {
                                    root.password += e.text
                                    root.status = ""
                                }
                                e.accepted = true
                            }

                            MouseArea { anchors.fill: parent; onClicked: input.forceActiveFocus() }

                            // placeholder / checking
                            Text {
                                anchors.centerIn: parent
                                visible: root.password.length === 0 && !root.unlocking
                                text: root.busy ? "Checking…" : "󰌾   Enter password"
                                color: root.tint(Colours.fg, 0.45)
                                font { family: root.font; pixelSize: 14 }
                            }

                            // success tick
                            Text {
                                id: tick
                                anchors.centerIn: parent
                                visible: root.unlocking
                                text: "󰄬"
                                color: Colours.bg
                                font { family: root.font; pixelSize: 24; bold: true }
                                scale: root.unlocking ? 1 : 0.3
                                Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack } }
                            }

                            // dots: pop in, ripple while checking
                            Row {
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

                // ----- now playing -----
                Rectangle {
                    anchors { bottom: parent.bottom; bottomMargin: 48; horizontalCenter: parent.horizontalCenter }
                    visible: root.player !== null
                    implicitWidth: nowRow.implicitWidth + 32
                    implicitHeight: 40
                    radius: 20
                    color: root.surface
                    border.width: 1
                    border.color: root.line
                    opacity: surf.stage(0.55, 1)
                    transform: Translate { y: 24 * (1 - surf.stage(0.55, 1)) }

                    Row {
                        id: nowRow
                        anchors.centerIn: parent
                        spacing: 10
                        Text {
                            text: "󰎆"
                            color: Colours.accent
                            font { family: root.font; pixelSize: 15 }
                        }
                        Text {
                            text: (root.player?.trackTitle ?? "") + (root.player?.trackArtist ? "  ·  " + root.player.trackArtist : "")
                            color: Colours.fg
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, 420)
                            font { family: root.font; pixelSize: 13 }
                        }
                    }
                }
            }
        }
    }
}
