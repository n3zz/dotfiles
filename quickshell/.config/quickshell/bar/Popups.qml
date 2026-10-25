import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Toast stack, top-right of whichever monitor has focus
PanelWindow {
    id: win

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    anchors { top: true; right: true }
    margins { top: 54; right: 12 }
    implicitWidth: 380
    implicitHeight: Math.max(1, stack.implicitHeight)
    // no toasts while the notification centre is open — they land straight in the list
    visible: Notifs.popups.length > 0 && !Notifs.sidebarOn
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifs"

    ColumnLayout {
        id: stack
        width: parent.width
        spacing: 10

        Repeater {
            // ScriptModel diffs the list, so existing toasts keep their timers
            model: ScriptModel { values: Notifs.popups }

            NotifCard {
                id: toast
                required property var modelData
                notif: modelData
                popup: true
                Layout.fillWidth: true

                opacity: 0
                transform: Translate { id: slide; x: 24 }
                Component.onCompleted: appear.start()
                ParallelAnimation {
                    id: appear
                    NumberAnimation { target: toast; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutCubic }
                    NumberAnimation { target: slide; property: "x"; to: 0; duration: 260; easing.type: Easing.OutQuint }
                }

                // hide after the app's timeout (default 5s); hovering pauses it; critical stays
                Timer {
                    interval: toast.notif.expireTimeout > 0 ? toast.notif.expireTimeout * 1000 : 5000
                    running: !toast.critical && !toast.hovering
                    onTriggered: {
                        const n = toast.notif
                        Notifs.removePopup(n)
                        if (n.transient) n.expire()
                    }
                }
            }
        }
    }
}
