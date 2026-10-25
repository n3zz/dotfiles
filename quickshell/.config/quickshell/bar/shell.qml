import QtQuick
import Quickshell

// One bar per monitor. Its clock pill unfolds into the dashboard / media player and its
// right island opens the notification centre. Toasts and the volume OSD appear once,
// on the focused monitor.
ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screenRef: modelData
        }
    }

    Popups {}
    Osd {}

    // Replace Quickshell's unstyled "configuration loaded" popup:
    // successful reloads (e.g. after a theme change) are silent, failures get a themed toast.
    Connections {
        target: Quickshell
        function onReloadCompleted() {
            Quickshell.inhibitReloadPopup()
        }
        function onReloadFailed(error: string) {
            Quickshell.inhibitReloadPopup()
            Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "Quickshell",
                                     "Bar reload failed", error])
        }
    }
}
