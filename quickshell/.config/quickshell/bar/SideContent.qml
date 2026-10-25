import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth

// Notification centre content that unfolds out of the right island (lives inside Bar.qml)
Item {
    id: side

    property bool open: false     // set by the bar; replays the entrance animations

    // newest first, grouped by app (group order = most recent notification)
    readonly property var groups: {
        const map = new Map()
        const list = Notifs.list.slice().reverse()
        for (const n of list) {
            const k = n.appName || "Other"
            if (!map.has(k)) map.set(k, [])
            map.get(k).push(n)
        }
        return Array.from(map, ([app, items]) => ({ app, items }))
    }
    readonly property bool hasWifi: Networking.devices.values.some(d => d.type === DeviceType.Wifi)
    readonly property var bt: Bluetooth.defaultAdapter

    component Label: Text {
        color: Colours.fg
        font.family: Theme.font
        font.pixelSize: 13
    }

    component Toggle: Rectangle {
        id: t
        property string glyph
        property string label
        property bool on: false
        property bool play: false     // flips true when the panel opens
        property int order: 0         // stagger position
        signal clicked()

        onPlayChanged: if (play) { glyphLabel.scale = 0.3; glyphLabel.rotation = -25; pop.restart() }
        SequentialAnimation {
            id: pop
            PauseAnimation { duration: 140 + t.order * 60 }
            ParallelAnimation {
                NumberAnimation { target: glyphLabel; property: "scale"; to: 1; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
                NumberAnimation { target: glyphLabel; property: "rotation"; to: 0; duration: 520; easing.type: Easing.OutBack }
            }
        }
        Layout.fillWidth: true
        implicitHeight: 58
        radius: 14
        color: on ? Theme.tint(Colours.accent, tma.containsMouse ? 0.45 : 0.35)
                  : Theme.tint(Colours.fg, tma.containsMouse ? 0.10 : 0.06)
        Behavior on color { ColorAnimation { duration: 160 } }
        Column {
            anchors.centerIn: parent
            spacing: 4
            Label { id: glyphLabel; anchors.horizontalCenter: parent.horizontalCenter; text: t.glyph; font.pixelSize: 18 }
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: t.label; font.pixelSize: 11 }
        }
        MouseArea {
            id: tma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: t.clicked()
        }
    }

    ColumnLayout {
        anchors { fill: parent; leftMargin: 16; rightMargin: 16; topMargin: 14; bottomMargin: 16 }
        spacing: 14

        // ----- quick toggles -----
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Toggle {

                play: side.open; order: 0
                glyph: Notifs.dnd ? "󰂛" : "󰂚"; label: "Silent"; on: Notifs.dnd
                onClicked: Notifs.dnd = !Notifs.dnd
            }
            Toggle {

                play: side.open; order: 1
                glyph: "󰅶"; label: "Caffeine"; on: Notifs.caffeine
                onClicked: Notifs.caffeine = !Notifs.caffeine
            }
            Toggle {

                play: side.open; order: 2
                glyph: "󰑋"; label: "Clips"; on: Stats.rec
                // enable/disable so the choice also sticks across logins
                onClicked: Quickshell.execDetached(["systemctl", "--user", Stats.rec ? "disable" : "enable",
                                                    "--now", "gpu-screen-recorder.service"])
            }
            Toggle {

                play: side.open; order: 3
                visible: side.hasWifi
                glyph: "󰖩"; label: "Wi-Fi"; on: Networking.wifiEnabled
                onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
            }
            Toggle {

                play: side.open; order: 4
                visible: side.bt !== null
                glyph: "󰂯"; label: "Bluetooth"; on: side.bt?.enabled ?? false
                onClicked: if (side.bt) side.bt.enabled = !side.bt.enabled
            }
        }

        // ----- tabs -----
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 40
            radius: 12
            color: Theme.raised

            // sliding highlight
            Rectangle {
                width: (parent.width - 8) / 2
                height: parent.height - 8
                y: 4
                x: Notifs.sidebarTab === "notifs" ? 4 : parent.width / 2
                radius: 9
                color: Theme.surface
                border.width: 1
                border.color: Theme.line
                Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
            }
            RowLayout {
                anchors.fill: parent
                spacing: 0
                Repeater {
                    model: [
                        { id: "notifs", label: "󰂚  Notifications" },
                        { id: "audio",  label: "󰕾  Audio" }
                    ]
                    Item {
                        id: tabItem
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Label {
                            anchors.centerIn: parent
                            text: tabItem.modelData.label
                                  + (tabItem.modelData.id === "notifs" && Notifs.count > 0 ? "  " + Notifs.count : "")
                            font.pixelSize: 12
                            font.bold: Notifs.sidebarTab === tabItem.modelData.id
                            color: Notifs.sidebarTab === tabItem.modelData.id ? Colours.fg : Theme.tint(Colours.fg, 0.55)
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifs.sidebarTab = tabItem.modelData.id
                        }
                    }
                }
            }
        }

        // ----- tab pages -----
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                id: notifPage
                anchors.fill: parent
                spacing: 14
                opacity: Notifs.sidebarTab === "notifs" ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 180 } }

                // ----- header -----
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "Notifications"; font.bold: true; font.pixelSize: 15 }
                    Label {
                        visible: Notifs.count > 0
                        text: Notifs.count
                        color: Theme.tint(Colours.fg, 0.5)
                    }
                    Item { Layout.fillWidth: true }
                    Label {
                        visible: Notifs.count > 0
                        text: "Clear all"
                        font.pixelSize: 12
                        color: clearMa.containsMouse ? Colours.accent : Theme.tint(Colours.fg, 0.6)
                        MouseArea {
                            id: clearMa
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifs.clearAll()
                        }
                    }
                }

                // ----- list -----
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        anchors.fill: parent
                        visible: Notifs.count > 0
                        clip: true
                        spacing: 14
                        boundsBehavior: Flickable.StopAtBounds
                        model: side.groups

                        // new entries slide in, removed ones collapse smoothly
                        add: Transition {
                            NumberAnimation { property: "x"; from: 24; duration: 320; easing.type: Easing.OutQuint }
                        }
                        displaced: Transition {
                            NumberAnimation { property: "y"; duration: 320; easing.type: Easing.OutQuint }
                        }

                        delegate: ColumnLayout {
                            id: grp
                            required property var modelData
                            required property int index

                            // staggered slide-in each time the panel opens
                            property real enter: 1
                            opacity: enter
                            transform: Translate { x: (1 - grp.enter) * 36 }
                            Connections {
                                target: side
                                function onOpenChanged() {
                                    if (!side.open) return
                                    grp.enter = 0
                                    enterAnim.restart()
                                }
                            }
                            SequentialAnimation {
                                id: enterAnim
                                PauseAnimation { duration: 160 + Math.min(grp.index, 6) * 55 }
                                NumberAnimation { target: grp; property: "enter"; to: 1; duration: 420; easing.type: Easing.OutQuint }
                            }
                            width: ListView.view.width
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                Label {
                                    text: grp.modelData.app
                                    font.bold: true
                                    font.pixelSize: 12
                                    color: Theme.tint(Colours.fg, 0.6)
                                }
                                Label {
                                    visible: grp.modelData.items.length > 1
                                    text: grp.modelData.items.length
                                    font.pixelSize: 11
                                    color: Theme.tint(Colours.fg, 0.4)
                                }
                                Item { Layout.fillWidth: true }
                                Label {
                                    text: "󰅖"
                                    font.pixelSize: 12
                                    color: Theme.tint(Colours.fg, gma.containsMouse ? 0.9 : 0.4)
                                    MouseArea {
                                        id: gma
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { for (const n of grp.modelData.items.slice()) n.dismiss() }
                                    }
                                }
                            }

                            Repeater {
                                model: grp.modelData.items
                                NotifCard {
                                    required property var modelData
                                    notif: modelData
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        visible: Notifs.count === 0
                        spacing: 6
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Notifs.dnd ? "󰂛" : "󰂚"
                            font.pixelSize: 34
                            color: Theme.tint(Colours.fg, 0.3)
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "All caught up"
                            color: Theme.tint(Colours.fg, 0.45)
                        }
                    }
                }
            }

            AudioContent {
                anchors.fill: parent
                opacity: Notifs.sidebarTab === "audio" ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 180 } }
            }
        }
    }
}
