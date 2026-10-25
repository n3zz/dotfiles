import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth

// Notification centre content that unfolds out of the right island (lives inside Bar.qml)
Item {
    id: side

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
        signal clicked()
        Layout.fillWidth: true
        implicitHeight: 58
        radius: 14
        color: on ? Theme.tint(Colours.accent, tma.containsMouse ? 0.45 : 0.35)
                  : Theme.tint(Colours.fg, tma.containsMouse ? 0.10 : 0.06)
        Behavior on color { ColorAnimation { duration: 160 } }
        Column {
            anchors.centerIn: parent
            spacing: 4
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: t.glyph; font.pixelSize: 18 }
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
                glyph: Notifs.dnd ? "󰂛" : "󰂚"; label: "Silent"; on: Notifs.dnd
                onClicked: Notifs.dnd = !Notifs.dnd
            }
            Toggle {
                glyph: "󰅶"; label: "Caffeine"; on: Notifs.caffeine
                onClicked: Notifs.caffeine = !Notifs.caffeine
            }
            Toggle {
                visible: side.hasWifi
                glyph: "󰖩"; label: "Wi-Fi"; on: Networking.wifiEnabled
                onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
            }
            Toggle {
                visible: side.bt !== null
                glyph: "󰂯"; label: "Bluetooth"; on: side.bt?.enabled ?? false
                onClicked: if (side.bt) side.bt.enabled = !side.bt.enabled
            }
        }

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
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220 }
                    NumberAnimation { property: "x"; from: 24; duration: 320; easing.type: Easing.OutQuint }
                }
                displaced: Transition {
                    NumberAnimation { property: "y"; duration: 320; easing.type: Easing.OutQuint }
                }

                delegate: ColumnLayout {
                    id: grp
                    required property var modelData
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
}
