import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Clipboard history picker (cliphist). Type to search, ↑/↓ + Enter to copy,
// Delete removes the selected entry (when the search box is empty), Esc closes.
// A normal window: Hyprland floats it via a window rule on its title ("Clipboard").
FloatingWindow {
    id: win

    readonly property string home: Quickshell.env("HOME")
    property var entries: []
    readonly property var shown: {
        const q = search.text.toLowerCase()
        if (q === "") return entries
        return entries.filter(e => (e.text ?? e.info ?? "").toLowerCase().includes(q))
    }

    // matte palette from wal (same recipe as the bar's Theme.qml)
    function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1) }
    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    readonly property color surface: Colours.bg
    readonly property color raised: mix(Colours.bg, Colours.fg, 0.06)
    readonly property color line: mix(Colours.bg, Colours.fg, 0.18)
    readonly property string font: "JetBrainsMono Nerd Font"

    function copy(e) {
        if (!e) return
        Quickshell.execDetached(["bash", "-c", "printf '%s\\t\\n' \"$1\" | cliphist decode | wl-copy", "_", e.id])
        Qt.quit()
    }
    function remove(e) {
        if (!e) return
        Quickshell.execDetached(["bash", "-c", "printf '%s\\t\\n' \"$1\" | cliphist delete", "_", e.id])
        entries = entries.filter(x => x.id !== e.id)
    }
    function wipe() {
        Quickshell.execDetached(["cliphist", "wipe"])
        entries = []
    }

    title: "Clipboard"
    implicitWidth: 600
    implicitHeight: 560
    color: win.surface

    // click outside to close
    HyprlandFocusGrab {
        windows: [win]
        active: true
        onCleared: Qt.quit()
    }

    Process {
        command: ["bash", win.home + "/.config/quickshell/clipboard/clip-list.sh"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                try { win.entries = win.entries.concat([JSON.parse(line)]) } catch (e) {}
            }
        }
    }

    component Label: Text {
        color: Colours.fg
        font.family: win.font
        font.pixelSize: 13
        textFormat: Text.PlainText
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        color: win.surface

        ColumnLayout {
            anchors { fill: parent; margins: 16 }
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: 12
                    color: win.raised
                    border.width: 1
                    border.color: search.activeFocus ? win.tint(Colours.accent, 0.7) : "transparent"

                    Label {
                        id: icon
                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                        text: "󰅌"
                        font.pixelSize: 16
                        color: win.tint(Colours.fg, 0.6)
                    }
                    TextInput {
                        id: search
                        anchors { left: icon.right; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 14 }
                        color: Colours.fg
                        font.family: win.font
                        font.pixelSize: 14
                        clip: true
                        focus: true
                        onTextChanged: list.currentIndex = 0
                        Component.onCompleted: forceActiveFocus()

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Down) { list.incrementCurrentIndex(); event.accepted = true }
                            else if (event.key === Qt.Key_Up) { list.decrementCurrentIndex(); event.accepted = true }
                            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                win.copy(win.shown[list.currentIndex]); event.accepted = true
                            } else if (event.key === Qt.Key_Escape) {
                                if (search.text.length) search.text = ""; else Qt.quit()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Delete && search.text.length === 0) {
                                win.remove(win.shown[list.currentIndex]); event.accepted = true
                            } else if (event.key === Qt.Key_A && (event.modifiers & Qt.ControlModifier)) {
                                search.text = ""; event.accepted = true
                            }
                        }
                    }
                    Label {
                        anchors.fill: search
                        verticalAlignment: Text.AlignVCenter
                        visible: search.text.length === 0
                        text: "Search clipboard"
                        font.pixelSize: 14
                        color: win.tint(Colours.fg, 0.4)
                    }
                }

                Rectangle {
                    implicitWidth: clearLabel.implicitWidth + 24
                    implicitHeight: 44
                    radius: 12
                    color: clearMa.containsMouse ? Qt.rgba(0.9, 0.33, 0.29, 0.25) : win.raised
                    visible: win.entries.length > 0
                    Label { id: clearLabel; anchors.centerIn: parent; text: "Clear all"; font.pixelSize: 12 }
                    MouseArea {
                        id: clearMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.wipe()
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: list
                    anchors.fill: parent
                    clip: true
                    spacing: 6
                    model: win.shown
                    highlightMoveDuration: 140
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool isImage: modelData.img !== undefined
                        width: ListView.view.width
                        height: isImage ? 112 : Math.min(textItem.implicitHeight + 22, 66)
                        radius: 12
                        color: ListView.isCurrentItem ? win.tint(Colours.accent, 0.28)
                             : rowMa.containsMouse ? win.raised : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Label {
                            id: textItem
                            visible: !row.isImage
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
                            text: row.modelData.text ?? ""
                            wrapMode: Text.WrapAnywhere
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            visible: row.isImage
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            width: thumb.paintedWidth + 4
                            height: 92
                            radius: 8
                            color: win.raised
                            Image {
                                id: thumb
                                anchors.centerIn: parent
                                height: 88
                                width: 260
                                source: row.isImage ? "file://" + row.modelData.img : ""
                                sourceSize.height: 176
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }
                        }
                        Label {
                            visible: row.isImage
                            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                            text: "image"
                            font.pixelSize: 11
                            color: win.tint(Colours.fg, 0.45)
                        }

                        MouseArea {
                            id: rowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onEntered: list.currentIndex = row.index
                            onClicked: mouse => {
                                if (mouse.button === Qt.MiddleButton) win.remove(row.modelData)
                                else win.copy(row.modelData)
                            }
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    visible: win.shown.length === 0
                    spacing: 6
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "󰅌"
                        font.pixelSize: 34
                        color: win.tint(Colours.fg, 0.3)
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: win.entries.length === 0 ? "Clipboard is empty" : "No matches"
                        color: win.tint(Colours.fg, 0.45)
                    }
                }
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: "↑↓ select      ↵ copy      del remove      esc close"
                font.pixelSize: 11
                color: win.tint(Colours.fg, 0.45)
            }
        }
    }
}
