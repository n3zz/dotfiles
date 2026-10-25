import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string wallDir: home + "/Wallpapers"

    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    function apply(path) {
        Quickshell.execDetached([home + "/.config/hypr/theme-hypr.sh", "--set", path])
        Qt.quit()
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell-wallpick"

    // dim backdrop, click to close
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.3)
        MouseArea { anchors.fill: parent; onClicked: Qt.quit() }
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.7, 1400)
        height: Math.min(parent.height * 0.72, 840)
        radius: 22
        color: root.tint(Colours.bg, 0.72)
        border.width: 1
        border.color: root.tint(Colours.fg, 0.12)

        MouseArea { anchors.fill: parent } // swallow clicks inside the panel

        Text {
            id: header
            anchors { top: parent.top; left: parent.left; margins: 22 }
            text: "Wallpapers"
            color: Colours.fg
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 20; bold: true }
        }
        Text {
            anchors { verticalCenter: header.verticalCenter; right: parent.right; rightMargin: 22 }
            text: (grid.currentIndex + 1) + " / " + grid.count + "   ↵ apply   esc close"
            color: root.tint(Colours.fg, 0.55)
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
        }

        GridView {
            id: grid
            anchors {
                top: header.bottom; bottom: parent.bottom; left: parent.left; right: parent.right
                margins: 14; topMargin: 16
            }
            clip: true
            focus: true
            keyNavigationWraps: true
            cellWidth: Math.floor(width / 4)
            cellHeight: Math.floor(cellWidth * 0.62)
            highlightMoveDuration: 120

            model: FolderListModel {
                id: files
                folder: "file://" + root.wallDir
                nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp"]
                caseSensitive: false
                showDirs: false
            }

            delegate: Item {
                id: cell
                required property string filePath
                required property int index
                readonly property bool current: GridView.isCurrentItem

                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 8
                    radius: 14
                    clip: true
                    color: root.tint(Colours.fg, 0.06)
                    border.width: cell.current ? 2 : 0
                    border.color: Colours.accent
                    scale: cell.current ? 1.0 : 0.95
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                    Image {
                        anchors.fill: parent
                        anchors.margins: 3
                        source: "file://" + cell.filePath
                        sourceSize.width: 480
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        opacity: status === Image.Ready ? (cell.current ? 1.0 : 0.75) : 0
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: grid.currentIndex = cell.index
                    onClicked: root.apply(cell.filePath)
                }
            }

            Keys.onReturnPressed: root.apply(files.get(currentIndex, "filePath"))
            Keys.onEnterPressed: root.apply(files.get(currentIndex, "filePath"))
            Keys.onEscapePressed: Qt.quit()
            Component.onCompleted: forceActiveFocus()
        }
    }
}
