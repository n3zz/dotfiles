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

    // let the fade-out play, then release the lock and exit
    Timer {
        id: unlockTimer
        interval: 380
        onTriggered: {
            lock.locked = false
            Qt.callLater(Qt.quit)
        }
    }

    SystemClock { id: clock; precision: SystemClock.Seconds }

    WlSessionLock {
        id: lock
        locked: true

        WlSessionLockSurface {
            id: surf
            color: root.surface

            Item {
                id: content
                anchors.fill: parent
                opacity: root.unlocking ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 340; easing.type: Easing.InOutQuad } }

                // ----- blurred wallpaper -----
                Image {
                    id: wall
                    anchors.fill: parent
                    source: "file://" + root.home + "/.cache/current-wallpaper"
                    fillMode: Image.PreserveAspectCrop
                    sourceSize { width: 1280; height: 720 }   // blurred anyway, keep it cheap
                    asynchronous: true
                    visible: false
                }
                MultiEffect {
                    anchors.fill: parent
                    source: wall
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 64
                    brightness: -0.12
                    visible: wall.status === Image.Ready
                }
                Rectangle {
                    anchors.fill: parent
                    color: root.tint(Colours.bg, 0.45)
                }

                // ----- clock, date, password -----
                ColumnLayout {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -40
                    spacing: 6

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.formatDateTime(clock.date, "HH:mm")
                        color: Colours.fg
                        font { family: root.font; pixelSize: 112; bold: true }
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                        color: root.tint(Colours.fg, 0.75)
                        font { family: root.font; pixelSize: 20 }
                    }

                    Item { implicitHeight: 34 }

                    // password pill (custom input so every monitor shares one password)
                    Rectangle {
                        id: pill
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 340
                        implicitHeight: 54
                        radius: height / 2
                        color: root.surface
                        border.width: 1
                        border.color: root.status !== "" ? root.danger
                                    : input.activeFocus ? root.tint(Colours.accent, 0.8) : root.line
                        Behavior on border.color { ColorAnimation { duration: 160 } }

                        transform: Translate { id: shake; x: 0 }
                        SequentialAnimation {
                            id: shakeAnim
                            NumberAnimation { target: shake; property: "x"; to: -12; duration: 50 }
                            NumberAnimation { target: shake; property: "x"; to: 12; duration: 70 }
                            NumberAnimation { target: shake; property: "x"; to: -8; duration: 60 }
                            NumberAnimation { target: shake; property: "x"; to: 6; duration: 60 }
                            NumberAnimation { target: shake; property: "x"; to: 0; duration: 50 }
                        }
                        Connections {
                            target: root
                            function onShakeTickChanged() { shakeAnim.restart() }
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

                            Text {
                                anchors.centerIn: parent
                                visible: root.password.length === 0
                                text: root.busy ? "Checking…" : "󰌾   Enter password"
                                color: root.tint(Colours.fg, 0.45)
                                font { family: root.font; pixelSize: 14 }
                            }
                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                visible: root.password.length > 0
                                Repeater {
                                    model: Math.min(root.password.length, 22)
                                    Rectangle {
                                        width: 9; height: 9; radius: 4.5
                                        color: root.busy ? root.tint(Colours.fg, 0.4) : Colours.accent
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
