import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

// Dashboard content that unfolds out of the clock pill (lives inside Bar.qml's hub)
Item {
    id: dash

    property var player: null
    signal closeRequested()

    readonly property string home: Quickshell.env("HOME")

    function run(cmd) {
        Quickshell.execDetached(cmd)
        dash.closeRequested()
    }

    implicitHeight: content.implicitHeight + 36

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // ----- calendar state -----
    property bool active: false            // true while the dashboard is open
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()

    function resetMonth() {
        const now = new Date()
        viewYear = now.getFullYear()
        viewMonth = now.getMonth()
    }
    function shiftMonth(delta) {
        const d = new Date(viewYear, viewMonth + delta, 1)
        viewYear = d.getFullYear()
        viewMonth = d.getMonth()
    }
    onActiveChanged: if (active) resetMonth()   // always open on the current month

    // 42 cells (6 weeks), Monday first
    readonly property var calendarDays: {
        const now = clock.date
        const first = new Date(viewYear, viewMonth, 1)
        const offset = (first.getDay() + 6) % 7
        const out = []
        for (let i = 0; i < 42; i++) {
            const d = new Date(viewYear, viewMonth, 1 - offset + i)
            out.push({
                day: d.getDate(),
                inMonth: d.getMonth() === viewMonth,
                today: d.getDate() === now.getDate() && d.getMonth() === now.getMonth()
                       && d.getFullYear() === now.getFullYear()
            })
        }
        return out
    }

    // ---------- building blocks ----------
    component Label: Text {
        color: Colours.fg
        font.family: Theme.font
        font.pixelSize: 13
    }

    component Card: Rectangle {
        default property alias content: col.data
        Layout.fillWidth: true
        implicitHeight: col.implicitHeight + 28
        radius: 16
        color: Theme.raised
        border.width: 0
        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 8
        }
    }

    component Meter: ColumnLayout {
        id: m
        property string label
        property real value
        property string detail
        property bool hot: false
        Layout.fillWidth: true
        spacing: 4
        RowLayout {
            Layout.fillWidth: true
            Label { text: m.label; color: Theme.tint(Colours.fg, 0.6) }
            Item { Layout.fillWidth: true }
            Label { text: m.detail; color: m.hot ? Theme.danger : Colours.fg }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 6
            radius: 3
            color: Theme.tint(Colours.fg, 0.10)
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, m.value / 100))
                height: parent.height
                radius: 3
                color: m.hot ? Theme.danger : Colours.accent
                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            }
        }
    }

    component Spark: Canvas {
        id: s
        property var samples: []
        property color stroke: Colours.accent
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        onSamplesChanged: requestPaint()
        onStrokeChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const n = s.samples.length
            if (n < 2) return
            const step = width / 59
            const rgb = Math.round(s.stroke.r * 255) + "," + Math.round(s.stroke.g * 255) + "," + Math.round(s.stroke.b * 255)
            ctx.beginPath()
            for (let i = 0; i < n; i++) {
                const x = width - (n - 1 - i) * step
                const y = height - 1 - (s.samples[i] / 100) * (height - 2)
                if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
            }
            ctx.strokeStyle = "rgb(" + rgb + ")"
            ctx.lineWidth = 2
            ctx.stroke()
            ctx.lineTo(width, height)
            ctx.lineTo(width - (n - 1) * step, height)
            ctx.closePath()
            ctx.fillStyle = "rgba(" + rgb + ",0.15)"
            ctx.fill()
        }
    }

    component Action: Rectangle {
        id: a
        property string glyph
        property string label
        signal clicked()
        Layout.fillWidth: true
        implicitHeight: 64
        radius: 14
        color: ma.containsMouse ? Theme.tint(Colours.accent, 0.28) : Theme.tint(Colours.fg, 0.06)
        Behavior on color { ColorAnimation { duration: 120 } }
        Column {
            anchors.centerIn: parent
            spacing: 4
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: a.glyph; font.pixelSize: 20 }
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: a.label; font.pixelSize: 11 }
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: a.clicked()
        }
    }

    RowLayout {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 20; rightMargin: 20; topMargin: 16 }
        spacing: 16

        // ----- left: clock, calendar, media -----
        ColumnLayout {
            Layout.preferredWidth: 300
            Layout.maximumWidth: 300
            Layout.alignment: Qt.AlignTop
            spacing: 12

            Label {
                text: Qt.formatDateTime(clock.date, "HH:mm")
                font.pixelSize: 44
                font.bold: true
            }
            Label {
                text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
                color: Theme.tint(Colours.fg, 0.6)
            }

            // hand-built calendar: Monday-first, 6 weeks, month navigation
            Card {
                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        text: "󰅁"
                        font.pixelSize: 15
                        color: Theme.tint(Colours.fg, prevMa.containsMouse ? 0.9 : 0.5)
                        MouseArea {
                            id: prevMa
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: dash.shiftMonth(-1)
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.formatDate(new Date(dash.viewYear, dash.viewMonth, 1), "MMMM yyyy")
                        font.bold: true
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: dash.resetMonth()   // click the title to jump back to today
                        }
                    }
                    Label {
                        text: "󰅂"
                        font.pixelSize: 15
                        color: Theme.tint(Colours.fg, nextMa.containsMouse ? 0.9 : 0.5)
                        MouseArea {
                            id: nextMa
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: dash.shiftMonth(1)
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    columnSpacing: 2
                    rowSpacing: 2

                    Repeater {
                        model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                        Label {
                            required property string modelData
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            font.pixelSize: 11
                            color: Theme.tint(Colours.fg, 0.45)
                        }
                    }

                    Repeater {
                        model: dash.calendarDays
                        Rectangle {
                            id: day
                            required property var modelData
                            readonly property bool isToday: modelData.today
                            Layout.fillWidth: true
                            implicitHeight: 28
                            radius: 14
                            color: isToday ? Colours.accent
                                 : dayMa.containsMouse ? Theme.tint(Colours.fg, 0.08) : "transparent"
                            Label {
                                anchors.centerIn: parent
                                text: day.modelData.day
                                font.pixelSize: 12
                                font.bold: day.isToday
                                color: day.isToday ? Colours.bg : Colours.fg
                                opacity: day.modelData.inMonth ? 1 : 0.28
                            }
                            MouseArea { id: dayMa; anchors.fill: parent; hoverEnabled: true }
                        }
                    }
                }
            }

            Card {
                visible: dash.player !== null

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    ClippingRectangle {
                        implicitWidth: 56
                        implicitHeight: 56
                        radius: 10
                        color: Theme.tint(Colours.fg, 0.08)
                        Image {
                            anchors.fill: parent
                            source: dash.player?.trackArtUrl ?? ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            Layout.fillWidth: true
                            text: dash.player?.trackTitle || "Unknown"
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Label {
                            Layout.fillWidth: true
                            text: dash.player?.trackArtist || dash.player?.identity || ""
                            color: Theme.tint(Colours.fg, 0.6)
                            elide: Text.ElideRight
                        }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 28
                    Label {
                        text: "󰒮"
                        font.pixelSize: 20
                        opacity: dash.player?.canGoPrevious ? 1 : 0.35
                        MouseArea { anchors.fill: parent; onClicked: if (dash.player?.canGoPrevious) dash.player.previous() }
                    }
                    Label {
                        text: dash.player?.isPlaying ? "󰏤" : "󰐊"
                        font.pixelSize: 26
                        color: Colours.accent
                        MouseArea { anchors.fill: parent; onClicked: if (dash.player?.canTogglePlaying) dash.player.togglePlaying() }
                    }
                    Label {
                        text: "󰒭"
                        font.pixelSize: 20
                        opacity: dash.player?.canGoNext ? 1 : 0.35
                        MouseArea { anchors.fill: parent; onClicked: if (dash.player?.canGoNext) dash.player.next() }
                    }
                }
            }
        }

        // ----- right: system, storage, actions -----
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 12

            Card {
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "  CPU"; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: Stats.cpu + "%  ·  " + Stats.cpuTemp + "°C"
                        color: Stats.cpuTemp >= 85 ? Theme.danger : Colours.fg
                    }
                }
                Spark { samples: Stats.cpuHist }

                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "󰢮  GPU"; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: Stats.gpu + "%  ·  " + Stats.gpuTemp + "°C"
                        color: Stats.gpuTemp >= 83 ? Theme.danger : Colours.fg
                    }
                }
                Spark { samples: Stats.gpuHist; stroke: Colours.muted }

                Meter { label: "Memory"; value: Stats.mem; detail: Stats.mem + "%"; hot: Stats.mem >= 90 }
                Meter { label: "VRAM"; value: Stats.vram; detail: Stats.vram + "%"; hot: Stats.vram >= 90 }
            }

            Card {
                Label { text: "󰋊  Storage"; font.bold: true }
                Repeater {
                    model: Stats.disks
                    Meter {
                        required property var modelData
                        label: modelData.mount
                        value: modelData.pct
                        detail: modelData.used + " / " + modelData.size + " GB"
                        hot: modelData.pct >= 90
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 4
                columnSpacing: 10
                rowSpacing: 10

                Action { glyph: "󰄀"; label: "Save clip"; onClicked: dash.run(["gsr-replay-save"]) }
                Action { glyph: "󰸉"; label: "Wallpaper"; onClicked: dash.run(["quickshell", "-p", dash.home + "/.config/quickshell/wallpick"]) }
                Action { glyph: "󰌾"; label: "Lock"; onClicked: dash.run(["hyprlock"]) }
                Action { glyph: "󰐥"; label: "Power"; onClicked: dash.run(["wlogout", "--protocol", "layer-shell"]) }
            }
        }
    }
}
