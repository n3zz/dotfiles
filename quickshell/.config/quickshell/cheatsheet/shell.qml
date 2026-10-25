import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Keybind cheatsheet: reads ~/.config/hypr/keybindings.lua (via binds.lua) every time it opens,
// so new binds show up on their own. Toggle: Super + /
ShellRoot {
    id: shell

    property var items: []
    property string error: ""
    property string query: ""
    property bool loaded: false

    readonly property var order: ["Apps", "Windows", "Workspaces", "Capture", "Media", "System", "Other"]
    readonly property var icons: ({
        Apps: "󰀻", Windows: "󰖲", Workspaces: "󰕰", Capture: "󰄀", Media: "󰝚", System: "󰒓", Other: "󰘳"
    })

    // filtered + grouped, then spread over three columns (each group goes to the shortest column)
    readonly property var groups: {
        const q = query.trim().toLowerCase()
        const match = it => q === "" || it.label.toLowerCase().includes(q) || it.cat.toLowerCase().includes(q)
            || it.combos.some(c => c.join(" ").toLowerCase().includes(q))
        const out = []
        for (const cat of order) {
            const list = items.filter(it => (order.includes(it.cat) ? it.cat : "Other") === cat && match(it))
            if (list.length) out.push({ cat: cat, items: list })
        }
        return out
    }
    readonly property int shownCount: groups.reduce((n, g) => n + g.items.length, 0)
    readonly property var columns: {
        const cols = [[], [], []], h = [0, 0, 0]
        groups.forEach((g, i) => {
            const c = h.indexOf(Math.min(...h))
            cols[c].push({ cat: g.cat, items: g.items, index: i })
            h[c] += g.items.length + 2.5
        })
        return cols
    }

    Process {
        running: true
        command: ["lua", Qt.resolvedUrl("binds.lua").toString().replace("file://", ""),
                  Quickshell.env("HOME") + "/.config/hypr/keybindings.lua"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { shell.items = JSON.parse(text) } catch (e) { shell.error = "Couldn't read keybindings.lua" }
                shell.loaded = true
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") shell.error = text.trim() }
        onExited: code => { if (code !== 0 && shell.error === "") shell.error = "lua exited with code " + code + " (is the lua package installed?)" }
    }

    // ---------- open / close motion ----------
    property real shown: 0          // dim + card
    property real t: 0              // stagger clock for the category cards
    function stage(i) {
        const x = Math.max(0, Math.min(1, (t - 0.12 - i * 0.07) / 0.5))
        return 1 - Math.pow(1 - x, 4)
    }
    ParallelAnimation {
        id: openAnim
        running: true
        NumberAnimation { target: shell; property: "shown"; to: 1; duration: 380; easing.type: Easing.OutQuint }
        NumberAnimation { target: shell; property: "t"; to: 1; duration: 1000 }
    }
    SequentialAnimation {
        id: closeAnim
        NumberAnimation { target: shell; property: "shown"; to: 0; duration: 170; easing.type: Easing.InQuad }
        ScriptAction { script: Qt.quit() }
    }
    function close() { if (!closeAnim.running) { openAnim.stop(); closeAnim.start() } }

    PanelWindow {
        id: win
        // open on the monitor you're working on
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-cheatsheet"

        // dim backdrop: click to close
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.5 * shell.shown)
            MouseArea { anchors.fill: parent; onClicked: shell.close() }
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(1080, win.width - 160)
            height: Math.min(body.contentHeight + 170, win.height - 140)   // 170 = header, divider, footer + margins
            Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
            radius: 26
            color: Theme.surface
            border.width: 1
            border.color: Theme.line
            clip: true
            opacity: shell.shown
            scale: 0.95 + 0.05 * shell.shown
            transform: Translate { y: (1 - shell.shown) * 16 }

            MouseArea { anchors.fill: parent }   // clicks inside don't close it

            // ----- header: title + search -----
            RowLayout {
                id: header
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 22 }
                height: 46
                spacing: 14

                Rectangle {
                    implicitWidth: 42; implicitHeight: 42
                    radius: 13
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.lighter(Colours.accent, 1.3) }
                        GradientStop { position: 1; color: Qt.darker(Colours.accent, 1.35) }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "󰌌"
                        color: Theme.surface
                        font { family: Theme.font; pixelSize: 22 }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: "Keybinds"
                        color: Colours.fg
                        font { family: Theme.font; pixelSize: 19; bold: true }
                    }
                    Text {
                        text: shell.error !== "" ? shell.error
                            : !shell.loaded ? "Reading keybindings.lua…"
                            : shell.query === "" ? shell.items.length + " shortcuts"
                            : shell.shownCount + " of " + shell.items.length + " match"
                        color: shell.error !== "" ? Theme.danger : Theme.tint(Colours.fg, 0.5)
                        font { family: Theme.font; pixelSize: 11 }
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                // search
                Rectangle {
                    implicitWidth: 300
                    implicitHeight: 40
                    radius: 14
                    color: Theme.raised
                    border.width: 1
                    border.color: search.activeFocus ? Theme.tint(Colours.accent, 0.55) : Theme.line
                    Behavior on border.color { ColorAnimation { duration: 160 } }
                    Text {
                        id: glass
                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                        text: "󰍉"
                        color: search.text !== "" ? Colours.accent : Theme.tint(Colours.fg, 0.45)
                        font { family: Theme.font; pixelSize: 15 }
                    }
                    TextInput {
                        id: search
                        anchors { left: glass.right; leftMargin: 10; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                        focus: true
                        color: Colours.fg
                        selectionColor: Theme.tint(Colours.accent, 0.45)
                        font { family: Theme.font; pixelSize: 13 }
                        clip: true
                        onTextChanged: shell.query = text
                        Keys.onEscapePressed: {
                            if (text !== "") text = ""
                            else shell.close()
                        }
                        Text {
                            visible: search.text === ""
                            text: "Search binds…"
                            color: Theme.tint(Colours.fg, 0.35)
                            font: search.font
                        }
                    }
                }
            }

            // thin accent divider
            Rectangle {
                id: divider
                anchors { top: header.bottom; topMargin: 16; left: parent.left; right: parent.right; leftMargin: 22; rightMargin: 22 }
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.tint(Colours.accent, 0) }
                    GradientStop { position: 0.5; color: Theme.tint(Colours.accent, 0.35) }
                    GradientStop { position: 1; color: Theme.tint(Colours.accent, 0) }
                }
            }

            // ----- the three columns of category cards -----
            Flickable {
                id: body
                anchors { top: divider.bottom; topMargin: 16; left: parent.left; right: parent.right; bottom: footer.top; leftMargin: 22; rightMargin: 22 }
                contentHeight: colsRow.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: colsRow
                    width: body.width
                    spacing: 14
                    Repeater {
                        model: shell.columns
                        Column {
                            id: col
                            required property var modelData
                            width: (colsRow.width - 28) / 3
                            spacing: 14
                            Repeater {
                                model: col.modelData
                                Rectangle {
                                    id: group
                                    required property var modelData
                                    readonly property real e: shell.stage(modelData.index)
                                    width: col.width
                                    height: groupCol.height + 26
                                    radius: 18
                                    color: Theme.raised
                                    border.width: 1
                                    border.color: Theme.tint(Colours.fg, 0.06)
                                    opacity: e
                                    transform: Translate { y: (1 - group.e) * 22 }

                                    Column {
                                        id: groupCol
                                        x: 14; y: 13
                                        width: parent.width - 28
                                        spacing: 4

                                        // category title
                                        RowLayout {
                                            width: parent.width
                                            height: 26
                                            spacing: 8
                                            Text {
                                                text: shell.icons[group.modelData.cat] ?? "󰘳"
                                                color: Colours.accent
                                                font { family: Theme.font; pixelSize: 15 }
                                            }
                                            Text {
                                                text: group.modelData.cat.toUpperCase()
                                                color: Colours.accent
                                                font { family: Theme.font; pixelSize: 11; bold: true; letterSpacing: 1.4 }
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: group.modelData.items.length
                                                color: Theme.tint(Colours.fg, 0.35)
                                                font { family: Theme.font; pixelSize: 11 }
                                            }
                                        }

                                        // rows
                                        Repeater {
                                            model: group.modelData.items
                                            Rectangle {
                                                id: row
                                                required property var modelData
                                                width: groupCol.width
                                                height: 34
                                                radius: 9
                                                color: rowHover.hovered ? Theme.raisedHover : "transparent"
                                                Behavior on color { ColorAnimation { duration: 100 } }
                                                HoverHandler { id: rowHover }

                                                Text {
                                                    anchors { left: parent.left; leftMargin: 6; right: caps.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                                    text: row.modelData.label
                                                    elide: Text.ElideRight
                                                    color: Colours.fg
                                                    font { family: Theme.font; pixelSize: 13 }
                                                }

                                                // key caps: combos separated by "/"
                                                Row {
                                                    id: caps
                                                    anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                                                    spacing: 6
                                                    Repeater {
                                                        model: row.modelData.combos
                                                        Row {
                                                            id: combo
                                                            required property var modelData
                                                            required property int index
                                                            spacing: 4
                                                            Text {
                                                                visible: combo.index > 0
                                                                anchors.verticalCenter: parent.verticalCenter
                                                                text: "/"
                                                                color: Theme.tint(Colours.fg, 0.3)
                                                                font { family: Theme.font; pixelSize: 12 }
                                                            }
                                                            Repeater {
                                                                model: combo.modelData
                                                                // a key: face on top of a slightly darker base, like a real keycap
                                                                Item {
                                                                    id: key
                                                                    required property var modelData
                                                                    readonly property bool mod: ["Super", "Shift", "Ctrl", "Alt"].includes(modelData)
                                                                    width: Math.max(24, keyText.implicitWidth + 14)
                                                                    height: 24
                                                                    Rectangle {
                                                                        anchors.fill: parent
                                                                        radius: 6
                                                                        color: Theme.mix(Theme.surface, Qt.rgba(0, 0, 0, 1), 0.35)
                                                                    }
                                                                    Rectangle {
                                                                        width: parent.width
                                                                        height: parent.height - 2
                                                                        radius: 6
                                                                        color: key.mod ? Theme.tint(Colours.accent, 0.20) : Theme.surface
                                                                        border.width: 1
                                                                        border.color: key.mod ? Theme.tint(Colours.accent, 0.45) : Theme.line
                                                                        Text {
                                                                            id: keyText
                                                                            anchors.centerIn: parent
                                                                            text: key.modelData
                                                                            color: key.mod ? Colours.accent : Colours.fg
                                                                            font { family: Theme.font; pixelSize: 11; bold: true }
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // nothing matches
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 40
                    visible: shell.loaded && shell.shownCount === 0 && shell.error === ""
                    spacing: 8
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "󰍉"
                        color: Theme.tint(Colours.fg, 0.3)
                        font { family: Theme.font; pixelSize: 32 }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No binds match “" + shell.query + "”"
                        color: Theme.tint(Colours.fg, 0.5)
                        font { family: Theme.font; pixelSize: 13 }
                    }
                }
            }

            // ----- footer -----
            Text {
                id: footer
                anchors { bottom: parent.bottom; bottomMargin: 14; horizontalCenter: parent.horizontalCenter }
                height: 22
                verticalAlignment: Text.AlignBottom
                text: "Type to search  ·  Esc to close  ·  end a bind's line with  -- cheat: Name  to rename it"
                color: Theme.tint(Colours.fg, 0.3)
                font { family: Theme.font; pixelSize: 10 }
            }
        }
    }
}
