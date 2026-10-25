import QtQuick
import Quickshell

// One bar per monitor. Its clock pill unfolds into the dashboard and its right
// island unfolds into the notification centre. Toasts appear once, on the focused monitor.
ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screenRef: modelData
        }
    }

    Popups {}
}
