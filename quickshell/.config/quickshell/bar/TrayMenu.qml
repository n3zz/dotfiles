import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

// Themed right-click menu for tray icons (replaces the plain Qt menu).
// Submenus open in place with a back row.
PopupWindow {
    id: pop

    property var trayItem: null
    property var stack: []      // open submenus
    readonly property var current: stack.length ? stack[stack.length - 1] : (trayItem?.menu ?? null)

    function openFor(icon, item) {
        if (visible && trayItem === item && !closeAnim.running) { close(); return }
        closeAnim.stop()
        trayItem = item
        stack = []
        anchor.item = icon
        anchor.updateAnchor()
        visible = true
        grabDelay.restart()
        card.opacity = 0
        card.y = 2
        card.scale = 0.96
        openAnim.restart()
    }
    function close() {
        grabbing = false
        if (visible && !closeAnim.running) closeAnim.restart()
    }

    // the grab only works once the popup is actually on screen, so start it a moment later
    property bool grabbing: false
    Timer { id: grabDelay; interval: 60; onTriggered: if (pop.visible) pop.grabbing = true }
    function label(t) {
        // dbusmenu uses "_" for keyboard mnemonics ("__" is a real underscore)
        return (t ?? "").replace(/__/g, "\u0001").replace(/_/g, "").replace(/\u0001/g, "_")
    }

    visible: false
    color: "transparent"
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    implicitWidth: 268
    implicitHeight: card.height + 16

    // click anywhere else to close
    HyprlandFocusGrab {
        windows: [pop]
        active: pop.grabbing
        onCleared: pop.close()
    }

    QsMenuOpener { id: opener; menu: pop.current }

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: card; property: "opacity"; to: 1; duration: 180 }
        NumberAnimation { target: card; property: "y"; to: 10; duration: 320; easing.type: Easing.OutQuint }
        NumberAnimation { target: card; property: "scale"; to: 1; duration: 320; easing.type: Easing.OutQuint }
    }
    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: card; property: "opacity"; to: 0; duration: 120 }
            NumberAnimation { target: card; property: "y"; to: 4; duration: 140; easing.type: Easing.InQuad }
        }
        ScriptAction { script: { pop.visible = false; pop.stack = [] } }
    }

    Rectangle {
        id: card
        x: 4
        y: 10
        width: pop.implicitWidth - 8
        height: col.implicitHeight + 12
        transformOrigin: Item.Top
        radius: 14
        color: Theme.surface
        border.width: 1
        border.color: Theme.line
        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
        clip: true

        Column {
            id: col
            x: 6
            y: 6
            width: card.width - 12

            // back to the parent menu
            Rectangle {
                visible: pop.stack.length > 0
                width: col.width
                height: 32
                radius: 9
                color: backMa.containsMouse ? Theme.raised : "transparent"
                Text {
                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    text: "󰁍   " + pop.label(pop.current?.text ?? "Back")
                    color: Theme.tint(Colours.fg, 0.7)
                    font { family: Theme.font; pixelSize: 12; bold: true }
                }
                MouseArea {
                    id: backMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pop.stack = pop.stack.slice(0, -1)
                }
            }
            Rectangle {
                visible: pop.stack.length > 0
                x: 6; width: col.width - 12; height: 9
                color: "transparent"
                Rectangle { anchors.centerIn: parent; width: parent.width; height: 1; color: Theme.tint(Colours.fg, 0.1) }
            }

            Repeater {
                model: opener.children.values

                Item {
                    id: entry
                    required property var modelData
                    width: col.width
                    height: modelData.isSeparator ? 9 : 32

                    // separator
                    Rectangle {
                        visible: entry.modelData.isSeparator
                        anchors.centerIn: parent
                        width: parent.width - 12
                        height: 1
                        color: Theme.tint(Colours.fg, 0.1)
                    }

                    Rectangle {
                        visible: !entry.modelData.isSeparator
                        anchors.fill: parent
                        radius: 9
                        color: ema.containsMouse && entry.modelData.enabled ? Theme.raised : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                        opacity: entry.modelData.enabled ? 1 : 0.4

                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            spacing: 10

                            // checkbox / radio state
                            Text {
                                readonly property int kind: entry.modelData.buttonType
                                readonly property bool on: entry.modelData.checkState === Qt.Checked
                                visible: kind !== QsMenuButtonType.None
                                text: kind === QsMenuButtonType.RadioButton ? (on ? "󰐾" : "󰄯") : (on ? "󰄲" : "󰄱")
                                color: on ? Colours.accent : Theme.tint(Colours.fg, 0.5)
                                font { family: Theme.font; pixelSize: 14 }
                            }
                            IconImage {
                                visible: (entry.modelData.icon ?? "") !== ""
                                source: entry.modelData.icon ?? ""
                                implicitSize: 16
                            }
                            Text {
                                Layout.fillWidth: true
                                text: pop.label(entry.modelData.text)
                                elide: Text.ElideRight
                                color: Colours.fg
                                font { family: Theme.font; pixelSize: 13 }
                            }
                            Text {
                                visible: entry.modelData.hasChildren
                                text: "󰅂"
                                color: Theme.tint(Colours.fg, 0.5)
                                font { family: Theme.font; pixelSize: 13 }
                            }
                        }

                        MouseArea {
                            id: ema
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: entry.modelData.enabled
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (entry.modelData.hasChildren) {
                                    pop.stack = pop.stack.concat([entry.modelData])
                                } else {
                                    entry.modelData.triggered()
                                    pop.close()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
