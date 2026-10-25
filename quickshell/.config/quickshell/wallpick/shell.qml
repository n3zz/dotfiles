import QtQuick
import QtQuick.Effects
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string wallDir: home + "/Wallpapers"
    readonly property var exts: ["jpg", "jpeg", "png", "webp"]
    property bool closing: false
    property string pending: ""

    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function currentPath() { return list.count > 0 ? files.get(list.currentIndex, "filePath") : "" }
    function applyCurrent() {
        const p = currentPath()
        if (p === "") return
        root.pending = p
        close()
    }
    function close() { if (!closing) { closing = true; outro.start() } }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell-wallpick"

    FolderListModel {
        id: files
        folder: "file://" + root.wallDir
        showDirs: false
        caseSensitive: false
        nameFilters: root.exts.map(e => "*" + search.text + "*." + e)
    }

    Item {
        id: stage
        anchors.fill: parent
        opacity: 0

        // ---------- live preview (crossfade) ----------
        Item {
            id: preview
            anchors.fill: parent
            property bool showA: true
            function show(p) {
                if (p === "") return
                const url = "file://" + p
                if (showA) { if (imgA.source == url) return; imgB.source = url }
                else       { if (imgB.source == url) return; imgA.source = url }
                showA = !showA
            }
            Image {
                id: imgA
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: root.width
                opacity: preview.showA ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 380; easing.type: Easing.InOutQuad } }
            }
            Image {
                id: imgB
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: root.width
                opacity: preview.showA ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 380; easing.type: Easing.InOutQuad } }
            }
        }

        // readability gradient
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0;  color: Qt.rgba(0, 0, 0, 0.35) }
                GradientStop { position: 0.5;  color: Qt.rgba(0, 0, 0, 0.10) }
                GradientStop { position: 1.0;  color: root.tint(Colours.bg, 0.92) }
            }
        }

        // click empty space to close, scroll to browse
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
            onWheel: (wheel) => {
                if (wheel.angleDelta.y < 0 || wheel.angleDelta.x < 0) list.incrementCurrentIndex()
                else list.decrementCurrentIndex()
            }
        }

        // ---------- search pill ----------
        Rectangle {
            id: pill
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 48 }
            width: 440; height: 48; radius: height / 2
            color: root.tint(Colours.bg, 0.55)
            border.width: 1
            border.color: search.activeFocus ? root.tint(Colours.accent, 0.6) : root.tint(Colours.fg, 0.14)

            Text {
                id: icon
                anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                text: "\uf002"
                color: root.tint(Colours.fg, 0.6)
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
            }
            TextInput {
                id: search
                anchors { left: icon.right; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 22 }
                color: Colours.fg
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
                clip: true
                focus: true
                onTextChanged: list.currentIndex = 0
                Keys.onLeftPressed: list.decrementCurrentIndex()
                Keys.onRightPressed: list.incrementCurrentIndex()
                Keys.onReturnPressed: root.applyCurrent()
                Keys.onEnterPressed: root.applyCurrent()
                Keys.onEscapePressed: { if (search.text.length) search.text = ""; else root.close() }
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_A && (event.modifiers & Qt.ControlModifier)) {
                        search.text = ""; event.accepted = true
                    }
                }
                Component.onCompleted: forceActiveFocus()
            }
            Text {
                anchors.fill: search
                verticalAlignment: Text.AlignVCenter
                visible: search.text.length === 0
                text: "Type to search wallpapers"
                color: root.tint(Colours.fg, 0.45)
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
            }
        }

        // ---------- name of selected ----------
        Text {
            anchors { bottom: list.top; horizontalCenter: parent.horizontalCenter; bottomMargin: 26 }
            text: list.count ? files.get(list.currentIndex, "fileBaseName") : "No matches"
            color: Colours.fg
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 18; bold: true }
        }

        // ---------- carousel ----------
        ListView {
            id: list
            readonly property int itemW: 320
            readonly property int itemH: 190

            anchors { left: parent.left; right: parent.right; bottom: hints.top; bottomMargin: 30 }
            height: 240
            orientation: ListView.Horizontal
            spacing: 22
            model: files
            cacheBuffer: 1600
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: width / 2 - itemW / 2
            preferredHighlightEnd: width / 2 + itemW / 2
            highlightMoveDuration: 260
            onCurrentIndexChanged: debounce.restart()
            onCountChanged: debounce.restart()

            delegate: Item {
                id: cell
                required property string filePath
                required property int index
                readonly property bool current: ListView.isCurrentItem

                width: list.itemW
                height: list.height
                z: current ? 1 : 0

                Item {
                    id: card
                    anchors.centerIn: parent
                    width: list.itemW
                    height: list.itemH
                    scale: cell.current ? 1.12 : 0.86
                    opacity: cell.current ? 1 : 0.55
                    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 260 } }

                    Image {
                        anchors.fill: parent
                        source: "file://" + cell.filePath
                        sourceSize.width: 640
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: mask
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1.0
                        }
                    }
                    Item {
                        id: mask
                        anchors.fill: parent
                        layer.enabled: true
                        visible: false
                        Rectangle { anchors.fill: parent; radius: 18; color: "black" }
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: 18
                        color: "transparent"
                        border.width: cell.current ? 2 : 1
                        border.color: cell.current ? Colours.accent : root.tint(Colours.fg, 0.15)
                    }
                }

                MouseArea {
                    anchors.fill: card
                    onClicked: { if (cell.current) root.applyCurrent(); else list.currentIndex = cell.index }
                }
            }
        }

        // ---------- hints ----------
        Text {
            id: hints
            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 36 }
            text: (list.count ? (list.currentIndex + 1) + " / " + list.count + "      " : "")
                  + "←/→ browse      ↵ apply      esc close"
            color: root.tint(Colours.fg, 0.5)
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
        }
    }

    Timer { id: debounce; interval: 120; onTriggered: preview.show(root.currentPath()) }

    ParallelAnimation {
        running: true
        NumberAnimation { target: stage; property: "opacity"; from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }
        NumberAnimation { target: list; property: "anchors.bottomMargin"; from: -40; to: 30; duration: 380; easing.type: Easing.OutCubic }
    }
    SequentialAnimation {
        id: outro
        NumberAnimation { target: stage; property: "opacity"; to: 0; duration: 200; easing.type: Easing.InCubic }
        ScriptAction { script: { if (root.pending !== "") Quickshell.execDetached([root.home + "/.config/hypr/theme-hypr.sh", "--set", root.pending]); Qt.quit() } }
    }
}
