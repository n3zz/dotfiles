import QtQuick
import QtQuick.Layouts
import Quickshell

// Media pop-out: one swipeable page per player (Spotify, Zen, ...).
// Swipe/drag, scroll, or click the dots to switch; the page you land on becomes the active player.
Item {
    id: media

    property var players: []
    property var current: null
    property bool active: false
    signal chose(var player)

    implicitWidth: 460
    implicitHeight: 186

    // keep the shown page in sync with the active player (e.g. switched from the pill)
    function syncIndex() {
        const i = players.indexOf(current)
        if (i >= 0 && i !== pages.currentIndex) pages.currentIndex = i
    }
    onCurrentChanged: syncIndex()
    onPlayersChanged: syncIndex()
    onActiveChanged: if (active) syncIndex()

    ListView {
        id: pages
        anchors.fill: parent
        orientation: ListView.Horizontal
        snapMode: ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightMoveDuration: 380
        boundsBehavior: Flickable.StopAtBounds
        interactive: count > 1
        clip: true
        model: media.players

        onCurrentIndexChanged: {
            const p = media.players[currentIndex]
            if (p && p !== media.current) media.chose(p)
        }

        delegate: MediaPage {
            required property var modelData
            required property int index
            width: pages.width
            height: pages.height
            player: modelData
            active: media.active && index === pages.currentIndex
        }
    }

    // scroll wheel (or two-finger swipe) flips pages, without blocking clicks
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        property real acc: 0
        onWheel: wheel => {
            if (pages.count < 2) return
            acc += Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y) ? -wheel.angleDelta.x : -wheel.angleDelta.y
            if (acc > 100) { pages.incrementCurrentIndex(); acc = 0 }
            else if (acc < -100) { pages.decrementCurrentIndex(); acc = 0 }
        }
    }

    // page dots
    Row {
        anchors { bottom: parent.bottom; bottomMargin: 8; horizontalCenter: parent.horizontalCenter }
        spacing: 6
        visible: pages.count > 1
        Repeater {
            model: pages.count
            Rectangle {
                required property int index
                width: index === pages.currentIndex ? 16 : 6
                height: 6
                radius: 3
                color: index === pages.currentIndex ? Colours.accent : Theme.tint(Colours.fg, 0.3)
                Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pages.currentIndex = parent.index
                }
            }
        }
    }
}
