pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// AI sidebar state + backends.
//  Local:  Ollama on localhost:11434 (streams NDJSON)
//  Claude: Anthropic Messages API (streams SSE); key read from ~/.config/anthropic/key
// Requests run through curl, so nothing blocks the bar, and the API key never appears in `ps`.
Singleton {
    id: root

    // ---------- settings ----------
    readonly property var claudeModels: ["claude-haiku-5-5", "claude-sonnet-5-5", "claude-opus-5-5"]
    readonly property string keyFile: Quickshell.env("HOME") + "/.config/anthropic/key"
    readonly property string basePrompt:
        "You are a concise assistant living in a desktop sidebar. Keep answers short and direct. " +
        "Put commands and code in fenced code blocks. Use markdown sparingly."
    readonly property string systemPrompt: basePrompt
        + (context.trim() !== "" ? "\n\nAbout the user and their setup:\n" + context.trim() : "")

    // ---------- personal context: ~/.config/anthropic/context.md (re-read when you edit it) ----------
    property string context: ""
    FileView {
        path: Quickshell.env("HOME") + "/.config/anthropic/context.md"
        watchChanges: true
        printErrors: false
        onLoaded: root.context = text()
        onLoadFailed: root.context = ""
        onFileChanged: reload()
    }

    // ---------- settings, remembered across restarts ----------
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/quickshell-ai.json"
        blockLoading: true
        printErrors: false
        onAdapterUpdated: writeAdapter()
        JsonAdapter {
            id: cfg
            property bool showButton: true
            property string backend: "ollama"           // "ollama" | "claude"
            property string ollamaModel: ""
            property string claudeModel: "claude-haiku-5-5"
        }
    }
    property alias showButton: cfg.showButton
    property alias backend: cfg.backend
    property alias ollamaModel: cfg.ollamaModel
    property alias claudeModel: cfg.claudeModel
    readonly property string model: backend === "claude" ? claudeModel : (ollamaModel || "no model")

    // ---------- saved chats: ~/.local/state/quickshell-ai-chats.json ----------
    FileView {
        id: chatFile
        path: Quickshell.env("HOME") + "/.local/state/quickshell-ai-chats.json"
        blockLoading: true
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoaded: root.restore()
        JsonAdapter {
            id: hist
            property var chats: []          // [{ id, backend, title, updated, msgs }], newest first
            property var currentBy: ({})    // open chat per backend: { ollama: id, claude: id }
            property string current: ""     // (old single-list format, migrated on load)
        }
    }
    property var msgs: []                   // current chat: [{ role, text, error, model }]

    // Local and Claude keep separate chat lists; switching backend swaps to that side's chat
    function chatBackend(c) {
        if (c.backend) return c.backend
        // chats saved before the split: guess from which model answered
        return (c.msgs ?? []).some(m => (m.model ?? "").startsWith("claude")) ? "claude" : "ollama"
    }
    readonly property var chats: (hist.chats ?? []).filter(c => chatBackend(c) === backend)
    readonly property string currentId: (hist.currentBy ?? {})[backend] ?? ""
    function setCurrent(id) {
        const m = Object.assign({}, hist.currentBy ?? {})
        m[backend] = id
        hist.currentBy = m
    }

    function restore() {
        // one-time move from the old format
        if (hist.current !== "") {
            const old = (hist.chats ?? []).find(c => c.id === hist.current)
            const cur = hist.current
            hist.current = ""
            if (old) {
                const m = Object.assign({}, hist.currentBy ?? {})
                m[chatBackend(old)] = cur
                hist.currentBy = m
            }
        }
        const c = (hist.chats ?? []).find(c => c.id === currentId)
        msgs = c ? c.msgs : []
    }
    function persist() {
        if (!msgs.length) return
        const now = Date.now()
        const id = currentId || String(now)
        const old = hist.chats.find(c => c.id === id)
        const first = msgs.find(m => m.role === "user")
        const title = old?.title ?? (first ? first.text.split("\n")[0].slice(0, 48) : "Chat")
        hist.chats = [{ id: id, backend: backend, title: title, updated: now, msgs: msgs }]
            .concat(hist.chats.filter(c => c.id !== id))
            .slice(0, 100)
        setCurrent(id)
    }
    function newChat() {
        stop()
        setCurrent("")
        msgs = []
    }
    function openChat(id) {
        stop()
        setCurrent(id)
        restore()
    }
    function deleteChat(id) {
        if (id === currentId) newChat()
        hist.chats = hist.chats.filter(c => c.id !== id)
    }

    property bool open: false
    property string screenName: ""
    property bool busy: false
    property string partial: ""          // reply being streamed in
    property var ollamaModels: []        // installed local models
    property bool ollamaUp: false
    property bool _stopping: false
    property string _active: ""          // backend of the request in flight
    property string _activeModel: ""
    property var _seen: []               // last message already animated in

    function toggle(s) {
        if (open && screenName === s) open = false
        else { screenName = s; open = true }
    }
    onOpenChanged: if (open) refreshModels()

    function setBackend(b) {
        if (b === backend) return
        stop()
        backend = b
        restore()
    }
    // click the model name: cycle through installed / available models
    function cycleModel() {
        const list = backend === "claude" ? claudeModels : ollamaModels
        if (list.length < 2) return
        const cur = backend === "claude" ? claudeModel : ollamaModel
        const next = list[(Math.max(0, list.indexOf(cur)) + 1) % list.length]
        if (backend === "claude") claudeModel = next
        else ollamaModel = next
    }
    function clear() { newChat() }
    function stop() {
        if (!busy) return
        _stopping = true
        req.running = false
        finish(partial !== "" ? partial + "\n\n*— stopped*" : "*Stopped.*", false)
    }

    function send(text) {
        text = (text ?? "").trim()
        if (text === "" || busy) return
        if (backend === "ollama" && !ollamaModel) {
            msgs = msgs.concat([{ role: "user", text: text, error: false },
                                { role: "assistant", error: true,
                                  text: "No local model found. Install one with:\n```\nollama pull llama3.2\n```" }])
            persist()
            refreshModels()
            return
        }
        msgs = msgs.concat([{ role: "user", text: text, error: false }])
        persist()

        // last 20 turns, skipping errors; must start with a user turn
        const hist = msgs.slice(-20)
            .filter(m => !m.error && m.text !== "")
            .map(m => ({ role: m.role, content: m.text }))
        while (hist.length && hist[0].role !== "user") hist.shift()

        partial = ""
        busy = true
        _stopping = false
        _active = backend
        _activeModel = model

        if (backend === "claude") {
            const body = JSON.stringify({
                model: claudeModel, max_tokens: 2048, stream: true,
                system: systemPrompt, messages: hist
            })
            const script =
                'k=$(cat "$1" 2>/dev/null) && [ -n "$k" ] || ' +
                '{ echo \'{"type":"error","error":{"message":"No API key. Save it to ~/.config/anthropic/key"}}\'; exit 0; }; ' +
                'printf "x-api-key: %s\\n" "$k" | exec curl -sN --max-time 300 https://api.anthropic.com/v1/messages ' +
                '-H @- -H "anthropic-version: 2023-06-01" -H "content-type: application/json" -d "$2"'
            req.command = ["sh", "-c", script, "sh", keyFile, body]
        } else {
            const body = JSON.stringify({
                model: ollamaModel, stream: true, keep_alive: "2m",   // frees VRAM soon after, for gaming
                messages: [{ role: "system", content: systemPrompt }].concat(hist)
            })
            req.command = ["curl", "-sN", "--max-time", "300", "http://localhost:11434/api/chat",
                           "-H", "Content-Type: application/json", "-d", body]
        }
        req.running = true
    }

    function finish(text, isError) {
        busy = false
        partial = ""
        msgs = msgs.concat([{ role: "assistant", text: text, error: isError, model: _activeModel }])
        persist()
    }

    function handle(line) {
        let s = line.trim()
        if (s === "" || s.startsWith("event:")) return
        if (s.startsWith("data:")) s = s.slice(5).trim()
        let j
        try { j = JSON.parse(s) } catch (e) { return }
        if (!busy) return

        if (j.error) {
            const m = typeof j.error === "string" ? j.error : (j.error.message ?? "Unknown error")
            _stopping = true
            req.running = false
            finish((partial ? partial + "\n\n" : "") + "⚠ " + m, true)
            return
        }
        if (_active === "ollama") {
            if (j.message?.content) partial += j.message.content
            if (j.done) finish(partial, false)
        } else {
            if (j.type === "content_block_delta" && j.delta?.text) partial += j.delta.text
            else if (j.type === "message_stop") finish(partial, false)
        }
    }

    Process {
        id: req
        stdout: SplitParser { onRead: line => root.handle(line) }
        onExited: (code, status) => {
            if (root._stopping || !root.busy) return
            if (root.partial !== "") { root.finish(root.partial, false); return }
            root.finish(root._active === "ollama"
                ? "⚠ Couldn't reach Ollama on localhost:11434. Start it with:\n```\nsudo systemctl enable --now ollama\n```"
                : "⚠ Request failed (curl exit " + code + "). Check your connection.", true)
        }
    }

    // installed Ollama models
    function refreshModels() { if (!tags.running) tags.running = true }
    Process {
        id: tags
        command: ["curl", "-s", "--max-time", "2", "http://localhost:11434/api/tags"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const names = (JSON.parse(text).models ?? []).map(m => m.name)
                    root.ollamaModels = names
                    root.ollamaUp = true
                    if (names.length && !names.includes(root.ollamaModel)) root.ollamaModel = names[0]
                } catch (e) {
                    root.ollamaUp = false
                }
            }
        }
    }
    Component.onCompleted: refreshModels()

    // keybind: quickshell -p ~/.config/quickshell/bar ipc call ai toggle
    IpcHandler {
        target: "ai"
        function toggle(): void { root.toggle(Hyprland.focusedMonitor?.name ?? "") }
        function clear(): void { root.clear() }
        function button(): void { root.showButton = !root.showButton }
    }
}
