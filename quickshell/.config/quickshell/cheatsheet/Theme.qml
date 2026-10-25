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

    // Some sites set media titles made of invisible filler characters; treat those as no title
    function trackTitle(p) {
        const t = p?.trackTitle ?? ""
        const visible = t.replace(/[\s\u3164\u115F\u1160\u2800\u200B-\u200D\u2060\uFEFF]/g, "")
        return visible === "" ? "" : t
    }
    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
    }
}
