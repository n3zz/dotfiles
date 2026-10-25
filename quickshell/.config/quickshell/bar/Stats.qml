pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared system stats, fed by scripts/sysstats.sh (one process for all monitors)
Singleton {
    id: root

    property int cpu: 0
    property int cpuTemp: 0
    property int mem: 0
    property int gpu: 0
    property int gpuTemp: 0
    property int vram: 0
    property string net: ""
    property bool rec: false     // gpu-screen-recorder replay buffer running
    property var cpuHist: []
    property var gpuHist: []
    property var disks: []   // [{ mount, pct, used, size }]

    readonly property var rootDisk: disks.find(d => d.mount === "/") ?? disks[0] ?? null

    function push(arr, v) {
        const a = arr.slice(-59)
        a.push(v)
        return a
    }

    Process {
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/bar/scripts/sysstats.sh"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                let d
                try { d = JSON.parse(data) } catch (e) { return }
                if (d.disks !== undefined) { root.disks = d.disks; return }
                root.cpu = d.cpu
                root.cpuTemp = d.ctemp
                root.mem = d.mem
                root.gpu = d.gpu
                root.gpuTemp = d.gtemp
                root.vram = d.vram
                root.net = d.net
                root.rec = d.rec === 1
                root.cpuHist = root.push(root.cpuHist, d.cpu)
                root.gpuHist = root.push(root.gpuHist, d.gpu)
            }
        }
    }
}
