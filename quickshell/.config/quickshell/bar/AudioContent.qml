import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

// Volume mixer tab of the notification centre:
// output + input device (pick from list), and a slider per app playing audio.
Item {
    id: mixer

    readonly property var audioNodes: Pipewire.nodes.values.filter(n => n.audio !== null)
    readonly property var sinks: audioNodes.filter(n => !n.isStream && n.isSink)
    readonly property var sources: audioNodes.filter(n => !n.isStream && !n.isSink)
    readonly property var playback: audioNodes.filter(n => n.isStream && !n.isSink)
    readonly property var recording: audioNodes.filter(n => n.isStream && n.isSink)

    // volume/properties are only valid for bound nodes
    PwObjectTracker { objects: mixer.audioNodes }

    component Label: Text {
        color: Colours.fg
        font.family: Theme.font
        font.pixelSize: 13
        textFormat: Text.PlainText
    }

    // ---------- slider bound to a node's volume ----------
    component VolumeSlider: Item {
        id: vs
        property var node: null
        readonly property var audio: node?.audio ?? null
        readonly property real value: audio ? Math.min(1, audio.volume) : 0
        readonly property bool muted: audio?.muted ?? false

        function setFromX(x) {
            if (!audio) return
            audio.volume = Math.max(0, Math.min(1, x / width))
            if (audio.muted && audio.volume > 0) audio.muted = false
        }

        Layout.fillWidth: true
        implicitHeight: 18

        Rectangle {
            id: trackBg
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 6
            radius: 3
            color: Theme.raised

            Rectangle {
                width: parent.width * vs.value
                height: parent.height
                radius: 3
                color: vs.muted ? Theme.tint(Colours.fg, 0.3) : Colours.accent
                Behavior on width { enabled: !drag.pressed; NumberAnimation { duration: 120 } }
            }
        }
        Rectangle {
            x: trackBg.width * vs.value - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: drag.pressed || drag.containsMouse ? 16 : 12
            height: width
            radius: width / 2
            color: vs.muted ? Theme.mix(Colours.bg, Colours.fg, 0.5) : Colours.accent
            border.width: 2
            border.color: Theme.surface
            Behavior on width { NumberAnimation { duration: 120 } }
        }
        MouseArea {
            id: drag
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => vs.setFromX(mouse.x - 6)
            onPositionChanged: mouse => { if (pressed) vs.setFromX(mouse.x - 6) }
            onWheel: wheel => {
                if (!vs.audio) return
                vs.audio.volume = Math.max(0, Math.min(1, vs.audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)))
            }
        }
    }

    // ---------- mute toggle ----------
    component MuteButton: Rectangle {
        id: mb
        property var node: null
        property string onGlyph: "󰕾"
        property string offGlyph: "󰝟"
        readonly property bool muted: node?.audio?.muted ?? false
        implicitWidth: 32
        implicitHeight: 32
        radius: 10
        color: muted ? Theme.tint(Theme.danger, 0.22) : (mma.containsMouse ? Theme.raisedHover : Theme.raised)
        Behavior on color { ColorAnimation { duration: 120 } }
        Label {
            anchors.centerIn: parent
            text: mb.muted ? mb.offGlyph : mb.onGlyph
            font.pixelSize: 15
            color: mb.muted ? Theme.danger : Colours.fg
        }
        MouseArea {
            id: mma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (mb.node?.audio) mb.node.audio.muted = !mb.node.audio.muted
        }
    }

    // ---------- device card: current default + expandable picker ----------
    component DeviceCard: Rectangle {
        id: dc
        property string title
        property string glyph
        property string mutedGlyph
        property var current: null
        property var devices: []
        property bool isOutput: true
        property bool expanded: false

        function nodeName(n) { return n ? (n.nickname || n.description || n.name) : "None" }

        Layout.fillWidth: true
        implicitHeight: dcCol.implicitHeight + 24
        radius: 16
        color: Theme.raised
        Behavior on implicitHeight { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
        clip: true

        ColumnLayout {
            id: dcCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Label { text: dc.title; font.bold: true; font.pixelSize: 12; color: Theme.tint(Colours.fg, 0.6) }
                Item { Layout.fillWidth: true }
                Label {
                    text: dc.current?.audio ? Math.round(dc.current.audio.volume * 100) + "%" : ""
                    font.pixelSize: 12
                    color: Theme.tint(Colours.fg, 0.6)
                }
            }

            // device name: click to choose another device
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 34
                radius: 10
                color: pickMa.containsMouse ? Theme.raisedHover : Theme.surface
                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
                    Label {
                        Layout.fillWidth: true
                        text: dc.nodeName(dc.current)
                        elide: Text.ElideRight
                    }
                    Label {
                        visible: dc.devices.length > 1
                        text: dc.expanded ? "󰅃" : "󰅀"
                        color: Theme.tint(Colours.fg, 0.6)
                    }
                }
                MouseArea {
                    id: pickMa
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: dc.devices.length > 1
                    cursorShape: Qt.PointingHandCursor
                    onClicked: dc.expanded = !dc.expanded
                }
            }

            // device list
            ColumnLayout {
                Layout.fillWidth: true
                visible: dc.expanded
                spacing: 2
                Repeater {
                    model: dc.devices
                    Rectangle {
                        id: devRow
                        required property var modelData
                        readonly property bool isCurrent: modelData === dc.current
                        Layout.fillWidth: true
                        implicitHeight: 32
                        radius: 8
                        color: isCurrent ? Theme.tint(Colours.accent, 0.25)
                             : devMa.containsMouse ? Theme.raisedHover : "transparent"
                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            Label {
                                Layout.fillWidth: true
                                text: dc.nodeName(devRow.modelData)
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                            Label { visible: devRow.isCurrent; text: "󰄬"; color: Colours.accent }
                        }
                        MouseArea {
                            id: devMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (dc.isOutput) Pipewire.preferredDefaultAudioSink = devRow.modelData
                                else Pipewire.preferredDefaultAudioSource = devRow.modelData
                                dc.expanded = false
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                MuteButton { node: dc.current; onGlyph: dc.glyph; offGlyph: dc.mutedGlyph }
                VolumeSlider { node: dc.current }
            }
        }
    }

    // ---------- per-app row ----------
    component AppRow: RowLayout {
        id: ar
        property var node: null
        readonly property var props: node?.properties ?? {}
        readonly property string appName: props["application.name"] || node?.description || node?.name || "App"
        readonly property string icon: {
            const ic = props["application.icon-name"] || props["application.process.binary"] || ""
            return ic ? Quickshell.iconPath(ic, true) : ""
        }
        Layout.fillWidth: true
        spacing: 12

        Item {
            implicitWidth: 32
            implicitHeight: 32
            Rectangle { anchors.fill: parent; radius: 10; color: Theme.surface }
            Image {
                anchors.centerIn: parent
                width: 22; height: 22
                visible: ar.icon !== ""
                source: ar.icon
                sourceSize { width: 44; height: 44 }
            }
            Label {
                anchors.centerIn: parent
                visible: ar.icon === ""
                text: "󰎆"
                font.pixelSize: 15
                color: Colours.accent
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            RowLayout {
                Layout.fillWidth: true
                Label {
                    Layout.fillWidth: true
                    text: ar.appName
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                }
                Label {
                    text: ar.node?.audio ? Math.round(ar.node.audio.volume * 100) + "%" : ""
                    font.pixelSize: 11
                    color: Theme.tint(Colours.fg, 0.55)
                }
            }
            Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: ar.props["media.name"] ?? ""
                font.pixelSize: 11
                color: Theme.tint(Colours.fg, 0.5)
                elide: Text.ElideRight
            }
            VolumeSlider { node: ar.node }
        }

        MuteButton { node: ar.node; Layout.alignment: Qt.AlignBottom }
    }

    // ---------- layout ----------
    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            width: parent.width
            spacing: 12

            DeviceCard {
                title: "Output"
                glyph: "󰕾"
                mutedGlyph: "󰝟"
                isOutput: true
                current: Pipewire.defaultAudioSink
                devices: mixer.sinks
            }

            DeviceCard {
                title: "Input"
                glyph: "󰍬"
                mutedGlyph: "󰍭"
                isOutput: false
                current: Pipewire.defaultAudioSource
                devices: mixer.sources
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: appsCol.implicitHeight + 24
                radius: 16
                color: Theme.raised

                ColumnLayout {
                    id: appsCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                    spacing: 14

                    Label { text: "Apps"; font.bold: true; font.pixelSize: 12; color: Theme.tint(Colours.fg, 0.6) }

                    Repeater {
                        model: mixer.playback
                        AppRow { required property var modelData; node: modelData }
                    }

                    Label {
                        visible: mixer.playback.length === 0
                        text: "Nothing is playing audio"
                        font.pixelSize: 12
                        color: Theme.tint(Colours.fg, 0.45)
                    }

                    // apps currently using the microphone
                    Label {
                        visible: mixer.recording.length > 0
                        Layout.topMargin: 4
                        text: "Recording"
                        font.bold: true
                        font.pixelSize: 12
                        color: Theme.tint(Colours.fg, 0.6)
                    }
                    Repeater {
                        model: mixer.recording
                        AppRow { required property var modelData; node: modelData }
                    }
                }
            }
        }
    }
}
