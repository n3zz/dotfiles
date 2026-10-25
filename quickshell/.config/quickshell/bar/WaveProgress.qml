import QtQuick

// Android-style "squiggly" progress bar: a travelling sine wave for the played part,
// a flat line for the rest. The wave flattens when paused. Drag/click to seek.
Item {
    id: w

    property real progress: 0          // 0..1
    property bool playing: false
    property bool seekable: false
    property bool indeterminate: false   // no known length: full-width ripple, no thumb
    property color color: Colours.accent
    property color trackColor: Theme.tint(Colours.fg, 0.2)
    signal seek(real frac)

    implicitHeight: 22

    // wave shape
    property real wavelength: 22
    property real phase: 0
    property real amplitude: 3.2
    property real amp: playing ? amplitude : 0
    Behavior on amp { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

    // while dragging, show where the thumb will land
    property real dragFrac: -1
    readonly property real shown: dragFrac >= 0 ? dragFrac : Math.max(0, Math.min(1, progress))

    onShownChanged: canvas.requestPaint()
    onAmpChanged: canvas.requestPaint()
    onPhaseChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onIndeterminateChanged: canvas.requestPaint()

    function css(c, a) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + (a ?? c.a) + ")"
    }

    // move the wave along while playing
    FrameAnimation {
        running: w.playing && w.visible && w.amp > 0.05
        onTriggered: w.phase = (w.phase + frameTime * 5.5) % (Math.PI * 2)
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const mid = height / 2
            const pad = 2
            const x1 = w.indeterminate ? width - pad : pad + (width - 2 * pad) * w.shown
            const k = 2 * Math.PI / w.wavelength
            ctx.lineCap = "round"
            ctx.lineWidth = 3

            // remaining part: flat
            if (x1 + 7 < width - pad) {
                ctx.strokeStyle = w.css(w.trackColor)
                ctx.beginPath()
                ctx.moveTo(x1 + 7, mid)
                ctx.lineTo(width - pad, mid)
                ctx.stroke()
            }

            // played part: travelling sine wave (amplitude eases in from the start)
            if (x1 > pad + 1) {
                ctx.strokeStyle = w.indeterminate ? w.css(w.color, 0.55) : w.css(w.color)
                ctx.beginPath()
                for (let x = pad; x <= x1; x += 1) {
                    const ease = Math.min(1, (x - pad) / 10)
                    const y = mid + Math.sin(x * k - w.phase) * w.amp * ease
                    if (x === pad) ctx.moveTo(x, y)
                    else ctx.lineTo(x, y)
                }
                ctx.stroke()
            }

            // thumb: short vertical pill
            if (w.indeterminate) return
            ctx.fillStyle = w.css(w.color)
            ctx.beginPath()
            ctx.roundedRect(x1 - 2, mid - 8, 4, 16, 2, 2)
            ctx.fill()
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        enabled: w.seekable && !w.indeterminate
        cursorShape: Qt.PointingHandCursor
        function frac(x) { return Math.max(0, Math.min(1, x / w.width)) }
        onPressed: mouse => w.dragFrac = frac(mouse.x)
        onPositionChanged: mouse => { if (pressed) w.dragFrac = frac(mouse.x) }
        onReleased: {
            w.seek(w.dragFrac)
            w.dragFrac = -1
        }
        onCanceled: w.dragFrac = -1
    }
}
