pragma Singleton
import QtQuick
import Quickshell

// Static style helpers. Colours come from the wal-generated Colours.qml.
Singleton {
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color danger: "#e5534b"

    // matte, fully opaque surfaces (derived from the wal palette)
    readonly property color surface: Colours.bg                      // islands, panels, toasts
    readonly property color raised: mix(Colours.bg, Colours.fg, 0.06) // cards inside panels
    readonly property color raisedHover: mix(Colours.bg, Colours.fg, 0.10)
    readonly property color line: mix(Colours.bg, Colours.fg, 0.18)   // crisp 1px borders

    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
    }
}
