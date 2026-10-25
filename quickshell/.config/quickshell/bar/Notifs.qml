pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Notifications

// Notification daemon + shared state for popups and the sidebar
Singleton {
    id: root

    property bool dnd: false
    property bool caffeine: false
    property var popups: []          // notifications currently shown as toasts
    property var times: ({})         // notification id -> arrival Date

    // sidebar: open on one monitor at a time
    property bool sidebarOn: false
    property string sidebarScreen: ""

    readonly property var list: server.trackedNotifications.values
    readonly property int count: list.length

    function toggleSidebar(screenName) {
        if (sidebarOn && sidebarScreen === screenName) {
            sidebarOn = false
        } else {
            sidebarScreen = screenName
            sidebarOn = true
        }
    }

    function removePopup(n) { root.popups = root.popups.filter(p => p !== n) }

    // Bring the sending app's window to the front (matches desktop entry / app name to window app id)
    function focusApp(n) {
        const keys = [n.desktopEntry, n.appName]
            .filter(k => k)
            .map(k => k.toLowerCase().replace(/\.desktop$/, ""))
        if (keys.length === 0) return false
        for (const t of ToplevelManager.toplevels.values) {
            const id = (t.appId ?? "").toLowerCase()
            if (id === "") continue
            if (keys.some(k => id === k || id.endsWith("." + k) || id.includes(k) || k.includes(id))) {
                t.activate()
                return true
            }
        }
        return false
    }

    // Click: run the app's own click action (e.g. open the Discord channel), then focus its window
    function open(n) {
        // read everything first: invoking a non-resident action destroys the notification
        const resident = n.resident
        let def = null
        const acts = n.actions ?? []
        for (let i = 0; i < acts.length; i++)
            if (acts[i].identifier === "default") { def = acts[i]; break }

        root.focusApp(n)
        root.sidebarOn = false
        root.removePopup(n)

        if (def) {
            def.invoke()
            if (resident) return      // app wants it kept in the history
        } else {
            n.dismiss()
        }
    }

    function clearAll() {
        for (const n of root.list.slice()) n.dismiss()
    }

    function ago(n) {
        const t = root.times[n.id]
        if (!t) return "earlier"
        const m = Math.floor((clock.date - t) / 60000)
        if (m < 1) return "now"
        if (m < 60) return m + "m"
        if (m < 1440) return Math.floor(m / 60) + "h"
        return Math.floor(m / 1440) + "d"
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true

            const t = Object.assign({}, root.times)
            t[n.id] = new Date()
            root.times = t

            const urgent = n.urgency === NotificationUrgency.Critical
            if (!n.lastGeneration && (!root.dnd || urgent))
                root.popups = [n].concat(root.popups).slice(0, 5)

            n.closed.connect(() => root.removePopup(n))
        }
    }

    // keybind: quickshell -p ~/.config/quickshell/bar ipc call notifs toggle
    IpcHandler {
        target: "notifs"
        function toggle(): void { root.toggleSidebar(Hyprland.focusedMonitor?.name ?? "") }
        function dnd(): void { root.dnd = !root.dnd }
    }
}
