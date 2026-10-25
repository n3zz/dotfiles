import QtQuick
import QtQuick.Layouts
import Quickshell

// AI chat that lives in the left slide-out panel (inside Bar.qml)
Item {
    id: ai

    property bool open: false
    property bool showHistory: false
    readonly property bool empty: Ai.msgs.length === 0 && !Ai.busy

    function focusInput() { input.forceActiveFocus() }
    function ago(t) {
        const m = Math.floor((Date.now() - t) / 60000)
        if (m < 1) return "now"
        if (m < 60) return m + "m"
        if (m < 1440) return Math.floor(m / 60) + "h"
        if (m < 10080) return Math.floor(m / 1440) + "d"
        return Qt.formatDate(new Date(t), "d MMM")
    }
    function css(c, a) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")"
    }

    // ---------- entrance: each section slides in a beat after the one above ----------
    property real t: 1
    function stage(i) {
        const x = Math.max(0, Math.min(1, (t - i * 0.09) / 0.55))
        return 1 - Math.pow(1 - x, 4)
    }
    NumberAnimation { id: enterAnim; target: ai; property: "t"; from: 0; to: 1; duration: 900 }
    onOpenChanged: if (open) { enterAnim.restart(); if (empty) emptyAnim.restart() }

    // empty-state chips pop in on their own clock
    property real et: 1
    NumberAnimation { id: emptyAnim; target: ai; property: "et"; from: 0; to: 1; duration: 900 }
    onEmptyChanged: if (empty) emptyAnim.restart()
    onShowHistoryChanged: if (!showHistory && empty) emptyAnim.restart()

    // ---------- building blocks ----------
    component Label: Text {
        color: Colours.fg
        font.family: Theme.font
        font.pixelSize: 13
    }

    // gradient tile with the ✦ glyph
    component Spark: Rectangle {
        id: sp
        property real size: 18
        property bool spinning: false
        property bool alert: false
        width: size; height: size
        implicitWidth: size; implicitHeight: size
        radius: size * 0.32
        gradient: Gradient {
            GradientStop { position: 0; color: sp.alert ? Qt.lighter(Theme.danger, 1.2) : Qt.lighter(Colours.accent, 1.3) }
            GradientStop { position: 1; color: sp.alert ? Qt.darker(Theme.danger, 1.3) : Qt.darker(Colours.accent, 1.35) }
        }
        Text {
            id: glyph
            anchors.centerIn: parent
            text: sp.alert ? "!" : "✦"
            color: Theme.surface
            font { family: Theme.font; pixelSize: sp.size * 0.56; bold: true }
            RotationAnimation on rotation {
                running: sp.spinning
                loops: Animation.Infinite
                from: 0; to: 360; duration: 1400
                onStopped: glyph.rotation = 0
            }
        }
    }

    // square icon button: hover plate, springy glyph, optional spin on click
    component IconBtn: Item {
        id: ib
        property string glyph
        property bool active: false
        property real spin: 0
        property int size: 14
        signal clicked()
        implicitWidth: 28
        implicitHeight: 28
        Rectangle {
            anchors.fill: parent
            radius: 9
            color: ib.active ? Theme.tint(Colours.accent, 0.18) : ibMa.containsMouse ? Theme.raised : "transparent"
            Behavior on color { ColorAnimation { duration: 140 } }
        }
        Text {
            id: ibg
            anchors.centerIn: parent
            text: ib.glyph
            font { family: Theme.font; pixelSize: ib.size }
            color: ib.active || ibMa.containsMouse ? Colours.accent : Theme.tint(Colours.fg, 0.6)
            Behavior on color { ColorAnimation { duration: 140 } }
            scale: ibMa.pressed ? 0.82 : ibMa.containsMouse ? 1.14 : 1
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
            Behavior on rotation { NumberAnimation { duration: 480; easing.type: Easing.OutBack } }
        }
        MouseArea {
            id: ibMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { if (ib.spin !== 0) ibg.rotation += ib.spin; ib.clicked() }
        }
    }

    // markdown text you can select and copy from
    component Md: TextEdit {
        readOnly: true
        selectByMouse: true
        wrapMode: TextEdit.Wrap
        textFormat: TextEdit.MarkdownText
        color: Colours.fg
        selectionColor: Theme.tint(Colours.accent, 0.45)
        selectedTextColor: Colours.fg
        font.family: Theme.font
        font.pixelSize: 13
        onLinkActivated: link => Qt.openUrlExternally(link)
    }

    ColumnLayout {
        anchors { fill: parent; leftMargin: 16; rightMargin: 16; topMargin: 16; bottomMargin: 14 }
        spacing: 12

        // ================= header =================
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            opacity: ai.stage(0)
            transform: Translate { x: (1 - ai.stage(0)) * -28 }

            // badge with a breathing halo while it's answering
            Item {
                implicitWidth: 38
                implicitHeight: 38
                Rectangle {
                    id: halo
                    anchors.centerIn: parent
                    width: 38; height: 38
                    radius: 13
                    color: Theme.tint(Colours.accent, 0.35)
                    opacity: 0
                    SequentialAnimation {
                        running: Ai.busy
                        loops: Animation.Infinite
                        onStopped: { halo.opacity = 0; halo.scale = 1 }
                        ParallelAnimation {
                            NumberAnimation { target: halo; property: "scale"; from: 1; to: 1.55; duration: 1100; easing.type: Easing.OutCubic }
                            NumberAnimation { target: halo; property: "opacity"; from: 0.7; to: 0; duration: 1100; easing.type: Easing.OutCubic }
                        }
                    }
                }
                Spark {
                    anchors.centerIn: parent
                    size: 38
                    spinning: Ai.busy
                }
            }

            ColumnLayout {
                spacing: 2
                Label { text: "Assistant"; font.bold: true; font.pixelSize: 16 }

                // status dot + model; click to cycle models
                Row {
                    id: modelRow
                    spacing: 7
                    readonly property bool down: Ai.backend === "ollama" && !Ai.ollamaUp
                    Rectangle {
                        id: dot
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7; height: 7; radius: 3.5
                        color: modelRow.down ? Theme.danger : Ai.backend === "ollama" ? "#3fb950" : Colours.accent
                        Behavior on color { ColorAnimation { duration: 200 } }
                        SequentialAnimation on opacity {
                            running: Ai.busy
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 500 }
                            NumberAnimation { to: 1; duration: 500 }
                            onStopped: dot.opacity = 1
                        }
                    }
                    Label {
                        id: modelName
                        text: (modelRow.down ? "ollama not running" : Ai.model)
                              + ((Ai.backend === "claude" ? Ai.claudeModels.length : Ai.ollamaModels.length) > 1 ? "  󰅀" : "")
                        font.pixelSize: 11
                        color: modelMa.containsMouse ? Colours.accent : Theme.tint(Colours.fg, 0.55)
                        Behavior on color { ColorAnimation { duration: 140 } }
                        // little slide whenever the model changes
                        onTextChanged: modelSwap.restart()
                        transform: Translate { id: modelShift }
                        SequentialAnimation {
                            id: modelSwap
                            ParallelAnimation {
                                NumberAnimation { target: modelShift; property: "y"; from: 6; to: 0; duration: 260; easing.type: Easing.OutQuint }
                                NumberAnimation { target: modelName; property: "opacity"; from: 0; to: 1; duration: 200 }
                            }
                        }
                        MouseArea {
                            id: modelMa
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Ai.cycleModel()
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Row {
                spacing: 2
                IconBtn {
                    glyph: Ai.showButton ? "󰐃" : "󰤰"
                    active: Ai.showButton
                    onClicked: Ai.showButton = !Ai.showButton
                }
                IconBtn {
                    glyph: "󰋚"
                    active: ai.showHistory
                    spin: -360
                    onClicked: ai.showHistory = !ai.showHistory
                }
                IconBtn {
                    glyph: "󰐕"
                    spin: 90
                    onClicked: { Ai.newChat(); ai.showHistory = false; ai.focusInput() }
                }
            }
        }

        // ================= Local | Claude =================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 36
            radius: 12
            color: Theme.raised
            opacity: ai.stage(1)
            transform: Translate { x: (1 - ai.stage(1)) * -28 }

            Rectangle {
                width: (parent.width - 8) / 2
                height: parent.height - 8
                y: 4
                x: Ai.backend === "ollama" ? 4 : parent.width / 2
                radius: 9
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.tint(Colours.accent, 0.30) }
                    GradientStop { position: 1; color: Theme.tint(Colours.accent, 0.16) }
                }
                border.width: 1
                border.color: Theme.tint(Colours.accent, 0.45)
                Behavior on x { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
            }
            RowLayout {
                anchors.fill: parent
                spacing: 0
                Repeater {
                    model: [{ id: "ollama", label: "󰍹   Local" }, { id: "claude", label: "✦   Claude" }]
                    Item {
                        id: seg
                        required property var modelData
                        readonly property bool on: Ai.backend === modelData.id
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Label {
                            anchors.centerIn: parent
                            text: seg.modelData.label
                            font.pixelSize: 12
                            font.bold: seg.on
                            color: seg.on ? Colours.fg : Theme.tint(Colours.fg, 0.5)
                            Behavior on color { ColorAnimation { duration: 200 } }
                            scale: seg.on ? 1 : 0.94
                            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Ai.setBackend(seg.modelData.id)
                        }
                    }
                }
            }
        }

        // ================= divider with a shine that runs while answering =================
        Item {
            Layout.fillWidth: true
            implicitHeight: 1
            opacity: ai.stage(2)
            clip: true
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.tint(Colours.accent, 0) }
                    GradientStop { position: 0.5; color: Theme.tint(Colours.accent, 0.35) }
                    GradientStop { position: 1; color: Theme.tint(Colours.accent, 0) }
                }
            }
            Rectangle {
                id: shine
                width: 90
                height: 1
                visible: Ai.busy
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.tint(Colours.accent, 0) }
                    GradientStop { position: 0.5; color: Qt.lighter(Colours.accent, 1.5) }
                    GradientStop { position: 1; color: Theme.tint(Colours.accent, 0) }
                }
                NumberAnimation on x {
                    running: Ai.busy
                    loops: Animation.Infinite
                    from: -90; to: shine.parent.width
                    duration: 1300
                    easing.type: Easing.InOutSine
                }
            }
        }

        // ================= conversation / history =================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            opacity: ai.stage(2)
            transform: Translate { x: (1 - ai.stage(2)) * -28 }

            // ---------- chat layer ----------
            Item {
                id: chatLayer
                anchors.fill: parent
                opacity: ai.showHistory ? 0 : 1
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 220 } }
                transform: Translate { x: ai.showHistory ? -24 : 0; Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } } }

                ListView {
                    id: chat
                    anchors.fill: parent
                    clip: true
                    spacing: 18
                    boundsBehavior: Flickable.StopAtBounds
                    model: Ai.msgs
                    visible: !ai.empty

                    // keep pinned to the bottom while text streams in, unless you've scrolled up
                    property bool follow: true
                    onMovementEnded: follow = atYEnd
                    function toEnd() { if (follow) Qt.callLater(() => chat.positionViewAtEnd()) }
                    onCountChanged: { follow = true; toEnd() }
                    Connections {
                        target: Ai
                        function onPartialChanged() { chat.toEnd() }
                        function onBusyChanged() { chat.toEnd() }
                    }

                    delegate: Item {
                        id: msg
                        required property var modelData
                        required property int index
                        readonly property bool mine: modelData.role === "user"
                        width: ListView.view.width
                        height: mine ? bubble.height : replyCol.height

                        // the message you just sent slides + fades in (the model is rebuilt on each
                        // message, so older ones and streamed replies just appear in place)
                        transform: Translate { id: shift }
                        Component.onCompleted: {
                            if (!mine || index !== Ai.msgs.length - 1 || Ai._seen.includes(modelData)) return
                            Ai._seen = [modelData]
                            opacity = 0
                            shift.x = 26
                            bubble.scale = 0.92
                            appear.start()
                        }
                        ParallelAnimation {
                            id: appear
                            NumberAnimation { target: msg; property: "opacity"; to: 1; duration: 220 }
                            NumberAnimation { target: shift; property: "x"; to: 0; duration: 420; easing.type: Easing.OutQuint }
                            NumberAnimation { target: bubble; property: "scale"; to: 1; duration: 420; easing.type: Easing.OutBack }
                        }

                        // ----- you: gradient bubble on the right -----
                        Rectangle {
                            id: bubble
                            visible: msg.mine
                            anchors.right: parent.right
                            transformOrigin: Item.BottomRight
                            width: Math.min(userText.implicitWidth, msg.width * 0.8) + 26
                            height: userText.height + 20
                            radius: 16
                            bottomRightRadius: 5
                            gradient: Gradient {
                                GradientStop { position: 0; color: Theme.tint(Colours.accent, 0.30) }
                                GradientStop { position: 1; color: Theme.tint(Colours.accent, 0.18) }
                            }
                            border.width: 1
                            border.color: Theme.tint(Colours.accent, 0.25)
                            Text {
                                id: userText
                                x: 13; y: 10
                                width: Math.min(implicitWidth, msg.width * 0.8)
                                text: msg.modelData.text
                                textFormat: Text.PlainText
                                wrapMode: Text.Wrap
                                color: Colours.fg
                                font { family: Theme.font; pixelSize: 13 }
                            }
                        }

                        // ----- assistant: avatar line, then the reply -----
                        HoverHandler { id: hov }
                        Column {
                            id: replyCol
                            visible: !msg.mine
                            width: parent.width
                            spacing: 6

                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Spark { size: 18; alert: msg.modelData.error }
                                Label {
                                    text: msg.modelData.error ? "Error" : (msg.modelData.model || "Assistant")
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: msg.modelData.error ? Theme.danger : Theme.tint(Colours.fg, 0.6)
                                }
                                Item { Layout.fillWidth: true }
                                IconBtn {
                                    id: copyBtn
                                    property bool copied: false
                                    visible: !msg.modelData.error
                                    implicitWidth: 24; implicitHeight: 24
                                    size: 12
                                    glyph: copied ? "󰄬" : "󰆏"
                                    active: copied
                                    opacity: hov.hovered || copied ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                    Timer { id: copiedT; interval: 1400; onTriggered: copyBtn.copied = false }
                                    onClicked: {
                                        Quickshell.execDetached(["wl-copy", msg.modelData.text])
                                        copied = true
                                        copiedT.restart()
                                    }
                                }
                            }
                            Md {
                                x: 26
                                width: parent.width - 26
                                text: msg.modelData.text
                                color: msg.modelData.error ? Theme.danger : Colours.fg
                            }
                        }
                    }

                    // ----- reply that is still streaming in -----
                    footer: Item {
                        id: liveItem
                        width: chat.width
                        height: Ai.busy ? liveCol.height + 18 : 0
                        visible: Ai.busy

                        // blinking block cursor at the end of the text
                        property bool caret: true
                        Timer {
                            interval: 520
                            repeat: true
                            running: Ai.busy && Ai.partial !== ""
                            onTriggered: liveItem.caret = !liveItem.caret
                        }

                        Column {
                            id: liveCol
                            y: 18
                            width: parent.width
                            spacing: 6
                            RowLayout {
                                width: parent.width
                                spacing: 8
                                Spark { size: 18; spinning: Ai.partial === "" }
                                Label {
                                    text: Ai.model
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: Theme.tint(Colours.fg, 0.6)
                                }
                                Item { Layout.fillWidth: true }
                            }
                            Md {
                                x: 26
                                width: parent.width - 26
                                visible: Ai.partial !== ""
                                text: Ai.partial + (liveItem.caret ? " ▍" : "")
                            }
                            // thinking: bouncing dots
                            Row {
                                x: 28
                                height: 18
                                spacing: 6
                                visible: Ai.partial === ""
                                Repeater {
                                    model: 3
                                    Rectangle {
                                        id: bdot
                                        required property int index
                                        y: 8
                                        width: 7; height: 7; radius: 3.5
                                        color: Colours.accent
                                        SequentialAnimation on y {
                                            running: Ai.busy && Ai.partial === ""
                                            loops: Animation.Infinite
                                            PauseAnimation { duration: bdot.index * 130 }
                                            NumberAnimation { to: 1; duration: 260; easing.type: Easing.OutQuad }
                                            NumberAnimation { to: 8; duration: 340; easing.type: Easing.OutBounce }
                                            PauseAnimation { duration: (2 - bdot.index) * 130 + 200 }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ---------- empty state ----------
                Column {
                    anchors.centerIn: parent
                    visible: ai.empty
                    spacing: 14

                    // badge with ripples, gently floating
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 96; height: 96
                        opacity: Math.min(1, ai.et * 3)
                        Repeater {
                            model: 2
                            Rectangle {
                                id: ripple
                                required property int index
                                anchors.centerIn: parent
                                width: 60; height: 60
                                radius: 20
                                color: "transparent"
                                border.width: 1.5
                                border.color: Colours.accent
                                opacity: 0
                                SequentialAnimation {
                                    running: ai.empty && ai.open && !ai.showHistory
                                    loops: Animation.Infinite
                                    PauseAnimation { duration: ripple.index * 1200 }
                                    ParallelAnimation {
                                        NumberAnimation { target: ripple; property: "scale"; from: 0.9; to: 1.6; duration: 2400; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: ripple; property: "opacity"; from: 0.55; to: 0; duration: 2400; easing.type: Easing.OutCubic }
                                    }
                                    PauseAnimation { duration: (1 - ripple.index) * 1200 }
                                }
                            }
                        }
                        Spark {
                            id: bigSpark
                            anchors.centerIn: parent
                            size: 60
                            scale: 0.6 + 0.4 * (1 - Math.pow(1 - Math.min(1, ai.et * 1.6), 3))
                            transform: Translate { id: floatT }
                            SequentialAnimation {
                                running: ai.empty && ai.open && !ai.showHistory
                                loops: Animation.Infinite
                                NumberAnimation { target: floatT; property: "y"; to: -4; duration: 1600; easing.type: Easing.InOutSine }
                                NumberAnimation { target: floatT; property: "y"; to: 4; duration: 1600; easing.type: Easing.InOutSine }
                            }
                        }
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "How can I help?"
                        font.pixelSize: 18
                        font.bold: true
                        opacity: Math.max(0, Math.min(1, (ai.et - 0.1) * 3))
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Ai.backend === "ollama" ? "Runs locally on your GPU" : "Sent to Anthropic's API"
                        font.pixelSize: 11
                        color: Theme.tint(Colours.fg, 0.4)
                        opacity: Math.max(0, Math.min(1, (ai.et - 0.2) * 3))
                    }

                    // suggestion chips: click to start a prompt
                    Flow {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(chatLayer.width, 380)
                        spacing: 8
                        Repeater {
                            model: [
                                { g: "󰆍", label: "Explain a command", p: "Explain what this command does: " },
                                { g: "󰒃", label: "Write a KQL query", p: "Write a KQL query for Microsoft Sentinel that " },
                                { g: "󰖲", label: "Hyprland help", p: "In my Hyprland Lua config, how do I " },
                                { g: "󰅚", label: "Fix an error", p: "Help me fix this error:\n" }
                            ]
                            Rectangle {
                                id: chip
                                required property var modelData
                                required property int index
                                readonly property real e: {
                                    const x = Math.max(0, Math.min(1, (ai.et - 0.25 - index * 0.08) / 0.45))
                                    return 1 - Math.pow(1 - x, 3)
                                }
                                width: chipRow.implicitWidth + 24
                                height: 32
                                radius: 16
                                color: chipMa.containsMouse ? Theme.tint(Colours.accent, 0.16) : Theme.raised
                                border.width: 1
                                border.color: chipMa.containsMouse ? Theme.tint(Colours.accent, 0.5) : Theme.line
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                opacity: e
                                scale: (0.85 + 0.15 * e) * (chipMa.pressed ? 0.94 : 1)
                                transform: Translate { y: (1 - chip.e) * 10 }
                                Row {
                                    id: chipRow
                                    anchors.centerIn: parent
                                    spacing: 7
                                    Label { text: chip.modelData.g; color: Colours.accent; font.pixelSize: 13 }
                                    Label { text: chip.modelData.label; font.pixelSize: 12 }
                                }
                                MouseArea {
                                    id: chipMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        input.text = chip.modelData.p
                                        input.cursorPosition = input.length
                                        ai.focusInput()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ---------- past chats ----------
            ListView {
                id: historyList
                anchors.fill: parent
                opacity: ai.showHistory ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 220 } }
                transform: Translate { x: ai.showHistory ? 0 : 24; Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } } }
                clip: true
                spacing: 4
                boundsBehavior: Flickable.StopAtBounds
                model: Ai.chats

                header: Text {
                    width: historyList.width
                    height: 30
                    text: Ai.chats.length ? "RECENT CHATS" : ""
                    color: Theme.tint(Colours.fg, 0.45)
                    font { family: Theme.font; pixelSize: 10; bold: true; letterSpacing: 1.2 }
                }

                delegate: Rectangle {
                    id: hrow
                    required property var modelData
                    required property int index
                    readonly property bool current: modelData.id === Ai.currentId
                    width: historyList.width
                    height: 50
                    radius: 12
                    color: current ? Theme.tint(Colours.accent, 0.16)
                         : hma.containsMouse ? Theme.raised : "transparent"
                    border.width: current ? 1 : 0
                    border.color: Theme.tint(Colours.accent, 0.35)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    // staggered slide-in each time the list is shown
                    opacity: 0
                    transform: Translate { id: hshift; x: 20 }
                    function play() { opacity = 0; hshift.x = 20; hIn.restart() }
                    Component.onCompleted: if (ai.showHistory) play()
                    Connections { target: ai; function onShowHistoryChanged() { if (ai.showHistory) hrow.play() } }
                    SequentialAnimation {
                        id: hIn
                        PauseAnimation { duration: Math.min(hrow.index, 8) * 35 }
                        ParallelAnimation {
                            NumberAnimation { target: hrow; property: "opacity"; to: 1; duration: 220 }
                            NumberAnimation { target: hshift; property: "x"; to: 0; duration: 380; easing.type: Easing.OutQuint }
                        }
                    }

                    MouseArea {
                        id: hma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { Ai.openChat(hrow.modelData.id); ai.showHistory = false }
                    }
                    Spark {
                        id: hspark
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        size: 22
                        opacity: hrow.current ? 1 : 0.55
                    }
                    Column {
                        anchors { left: hspark.right; right: del.left; leftMargin: 12; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        spacing: 3
                        Text {
                            width: parent.width
                            text: hrow.modelData.title
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            color: Colours.fg
                            font { family: Theme.font; pixelSize: 13; bold: hrow.current }
                        }
                        Text {
                            text: ai.ago(hrow.modelData.updated) + "  ·  " + hrow.modelData.msgs.length + " messages"
                            color: Theme.tint(Colours.fg, 0.4)
                            font { family: Theme.font; pixelSize: 10 }
                        }
                    }
                    IconBtn {
                        id: del
                        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        glyph: "󰆴"
                        size: 13
                        opacity: hma.containsMouse || delHover.hovered ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 140 } }
                        HoverHandler { id: delHover }
                        onClicked: Ai.deleteChat(hrow.modelData.id)
                    }
                }

                Column {
                    anchors.centerIn: parent
                    visible: Ai.chats.length === 0
                    spacing: 8
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: "󰋚"; font.pixelSize: 30; color: Theme.tint(Colours.fg, 0.3) }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: "No saved chats yet"; color: Theme.tint(Colours.fg, 0.45) }
                }
            }
        }

        // ================= input =================
        Item {
            Layout.fillWidth: true
            implicitHeight: box.implicitHeight
            opacity: ai.stage(3)
            transform: Translate { y: (1 - ai.stage(3)) * 16 }

            // soft focus glow
            Rectangle {
                anchors.fill: box
                anchors.margins: -4
                radius: box.radius + 4
                color: "transparent"
                border.width: 4
                border.color: Theme.tint(Colours.accent, 0.14)
                opacity: input.activeFocus && !Ai.busy ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 220 } }
            }

            Rectangle {
                id: box
                anchors { left: parent.left; right: parent.right }
                implicitHeight: Math.min(input.contentHeight, 140) + 26
                Behavior on implicitHeight { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
                radius: 18
                color: Theme.raised
                border.width: 1
                border.color: Ai.busy ? "transparent"
                            : input.activeFocus ? Theme.tint(Colours.accent, 0.55) : Theme.line
                Behavior on border.color { ColorAnimation { duration: 180 } }

                Flickable {
                    id: inputFlick
                    anchors { left: parent.left; right: sendBtn.left; top: parent.top; bottom: parent.bottom
                              leftMargin: 15; rightMargin: 8; topMargin: 13; bottomMargin: 13 }
                    contentHeight: input.contentHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    function ensureVisible(r) {
                        if (contentY >= r.y) contentY = r.y
                        else if (contentY + height <= r.y + r.height) contentY = r.y + r.height - height
                    }

                    TextEdit {
                        id: input
                        width: inputFlick.width
                        wrapMode: TextEdit.Wrap
                        color: Colours.fg
                        selectionColor: Theme.tint(Colours.accent, 0.45)
                        font.family: Theme.font
                        font.pixelSize: 13
                        onCursorRectangleChanged: inputFlick.ensureVisible(cursorRectangle)

                        function submit() {
                            if (Ai.busy || text.trim() === "") return
                            ai.showHistory = false
                            Ai.send(text)
                            text = ""
                        }
                        // Enter sends, Shift+Enter new line
                        Keys.onReturnPressed: event => {
                            if (event.modifiers & Qt.ShiftModifier) { event.accepted = false; return }
                            input.submit()
                        }
                        Keys.onEnterPressed: event => input.submit()

                        Text {
                            visible: input.text === ""
                            text: Ai.busy ? "Thinking…" : "Message " + (Ai.backend === "claude" ? "Claude" : "local model") + "…"
                            color: Theme.tint(Colours.fg, 0.35)
                            font: input.font
                        }
                    }
                }

                // send / stop
                Rectangle {
                    id: sendBtn
                    anchors { right: parent.right; rightMargin: 8; bottom: parent.bottom; bottomMargin: 8 }
                    width: 32; height: 32; radius: 11
                    readonly property bool ready: input.text.trim() !== ""
                    color: Ai.busy ? Theme.tint(Theme.danger, sendMa.containsMouse ? 0.35 : 0.22)
                         : ready ? (sendMa.containsMouse ? Qt.lighter(Colours.accent, 1.15) : Colours.accent)
                         : Theme.tint(Colours.fg, 0.08)
                    Behavior on color { ColorAnimation { duration: 180 } }
                    scale: sendMa.pressed ? 0.86 : (ready || Ai.busy) && sendMa.containsMouse ? 1.06 : 1
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                    Text {
                        anchors.centerIn: parent
                        text: Ai.busy ? "󰓛" : "󰁝"
                        font { family: Theme.font; pixelSize: 16 }
                        color: Ai.busy ? Theme.danger : sendBtn.ready ? Theme.surface : Theme.tint(Colours.fg, 0.35)
                        Behavior on color { ColorAnimation { duration: 180 } }
                        // arrow tilts up when there's something to send
                        rotation: Ai.busy ? 0 : sendBtn.ready ? 0 : 45
                        Behavior on rotation { NumberAnimation { duration: 380; easing.type: Easing.OutBack } }
                    }
                    MouseArea {
                        id: sendMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Ai.busy ? Ai.stop() : input.submit()
                    }
                }
            }

            // travelling glow round the border while it's answering
            Canvas {
                id: ring
                anchors.fill: box
                opacity: Ai.busy ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 250 } }
                property real angle: 0
                onAngleChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                FrameAnimation {
                    running: ring.visible
                    onTriggered: ring.angle = (ring.angle + frameTime * 3.2) % (Math.PI * 2)
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const g = ctx.createConicalGradient(width / 2, height / 2, angle)
                    const c = Colours.accent
                    g.addColorStop(0.00, ai.css(c, 1))
                    g.addColorStop(0.18, ai.css(c, 0.05))
                    g.addColorStop(0.50, ai.css(c, 0.55))
                    g.addColorStop(0.68, ai.css(c, 0.05))
                    g.addColorStop(1.00, ai.css(c, 1))
                    ctx.strokeStyle = g
                    ctx.lineWidth = 1.6
                    ctx.beginPath()
                    ctx.roundedRect(0.8, 0.8, width - 1.6, height - 1.6, box.radius - 0.8, box.radius - 0.8)
                    ctx.stroke()
                }
            }
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: -4
            text: "Enter to send · Shift+Enter new line · Esc to close"
            font.pixelSize: 10
            color: Theme.tint(Colours.fg, 0.3)
            opacity: ai.stage(4)
        }
    }
}
