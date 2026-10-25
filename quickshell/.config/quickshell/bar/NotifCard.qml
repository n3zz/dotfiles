import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

// One notification, used both for toasts (popup: true) and in the sidebar
Rectangle {
    id: card

    required property var notif
    property bool popup: false
    readonly property bool hovering: hover.hovered
    readonly property bool critical: notif !== null && notif.urgency === NotificationUrgency.Critical

    readonly property var extraActions: {
        const out = []
        const acts = notif?.actions ?? []
        for (let i = 0; i < acts.length; i++)
            if (acts[i].identifier !== "default") out.push(acts[i])
        return out
    }

    readonly property string iconSrc: {
        if (!notif) return ""
        if (notif.image) return notif.image
        const ic = notif.appIcon
        if (!ic) return ""
        if (ic.startsWith("/")) return "file://" + ic
        if (ic.includes("://")) return ic
        return Quickshell.iconPath(ic, true)
    }

    function activate() { if (notif) Notifs.open(notif) }

    implicitHeight: row.implicitHeight + 24
    radius: 16
    color: popup ? (hovering ? Theme.raised : Theme.surface) : (hovering ? Theme.raisedHover : Theme.raised)
    border.width: 1
    border.color: critical ? Theme.danger : (popup ? Theme.line : "transparent")
    Behavior on color { ColorAnimation { duration: 120 } }

    component Label: Text {
        color: Colours.fg
        font.family: Theme.font
        font.pixelSize: 13
        textFormat: Text.PlainText
    }

    HoverHandler { id: hover }

    // left click: open in the app; middle click: dismiss
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) card.notif.dismiss()
            else card.activate()
        }
    }

    RowLayout {
        id: row
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 12

        Item {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 36
            implicitHeight: 36

            ClippingRectangle {
                anchors.fill: parent
                radius: 10
                color: Theme.tint(Colours.fg, 0.08)
                Image {
                    anchors.fill: parent
                    visible: card.iconSrc !== ""
                    source: card.iconSrc
                    sourceSize { width: 72; height: 72 }
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            Label {
                anchors.centerIn: parent
                visible: card.iconSrc === ""
                text: "󰂚"
                font.pixelSize: 18
                color: Colours.accent
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Label {
                    Layout.fillWidth: true
                    text: card.notif?.appName || "Notification"
                    font.pixelSize: 11
                    color: Theme.tint(Colours.fg, 0.55)
                    elide: Text.ElideRight
                }
                Label {
                    text: card.notif ? Notifs.ago(card.notif) : ""
                    font.pixelSize: 11
                    color: Theme.tint(Colours.fg, 0.45)
                }
                Label {
                    text: "󰅖"
                    font.pixelSize: 13
                    color: Theme.tint(Colours.fg, closeMa.containsMouse ? 0.9 : 0.45)
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.notif.dismiss()
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                text: card.notif?.summary ?? ""
                font.bold: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.notif?.body ?? ""
                color: Theme.tint(Colours.fg, 0.72)
                wrapMode: Text.Wrap
                maximumLineCount: card.popup ? 3 : 4
                elide: Text.ElideRight
            }

            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 6
                visible: card.extraActions.length > 0
                spacing: 6

                Repeater {
                    model: card.extraActions
                    Rectangle {
                        id: btn
                        required property var modelData
                        implicitWidth: btnLabel.implicitWidth + 22
                        implicitHeight: 26
                        radius: 13
                        color: btnMa.containsMouse ? Theme.tint(Colours.accent, 0.35) : Theme.tint(Colours.fg, 0.08)
                        Label {
                            id: btnLabel
                            anchors.centerIn: parent
                            text: btn.modelData.text
                            font.pixelSize: 12
                        }
                        MouseArea {
                            id: btnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: btn.modelData.invoke()
                        }
                    }
                }
            }
        }
    }
}
