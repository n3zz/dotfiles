-- Reads a Hyprland Lua keybindings file and prints every bind as JSON for the cheatsheet.
-- It runs the file against a stand-in `hl` table that records each hl.bind() call,
-- so loops, variables and multi-line binds all work.
--   lua binds.lua ~/.config/hypr/keybindings.lua
--
-- Labels are worked out from the command. To name a bind yourself, end its line with
--   -- cheat: My label
-- (and optionally a category:  -- cheat: Apps / My label)

local path = arg[1]
local src = {}
for l in io.lines(path) do src[#src + 1] = l end

-- ---------- stand-in for Hyprland's API ----------
local function noop() end
local handle = setmetatable({}, { __index = function() return noop end })

-- hl.dsp.window.move({...}) -> { fn = "window.move", args = {...} }
local function dsp(name)
	return setmetatable({}, {
		__index = function(_, k) return dsp(name == "" and k or name .. "." .. k) end,
		__call = function(_, ...) return { fn = name, args = { ... } } end,
	})
end

local found = {}
hl = setmetatable({
	dsp = dsp(""),
	bind = function(keys, action, opts)
		local line = debug.getinfo(2, "l").currentline
		found[#found + 1] = { keys = keys, action = action or {}, opts = opts or {}, line = line }
		return handle
	end,
}, { __index = function() return function() return handle end end })

local ok, err = pcall(dofile, path)
if not ok then
	io.stderr:write("error: " .. tostring(err) .. "\n")
end

-- ---------- labels ----------
local function has(s, p) return s and s:find(p, 1, true) ~= nil end

local function describe(b)
	local fn, a = b.action.fn or "", b.action.args or {}
	local t = type(a[1]) == "table" and a[1] or {}
	if fn == "exec_cmd" then
		local c = tostring(a[1] or "")
		if c == "kitty" or c:match("^kitty%s") or has(c, "alacritty") or has(c, "foot") then return "Apps", "Terminal" end
		if has(c, "rofi") then return "Apps", "App launcher" end
		if has(c, "thunar") or has(c, "nautilus") or has(c, "dolphin") then return "Apps", "File manager" end
		if has(c, "ai toggle") then return "Apps", "AI assistant" end
		if has(c, "/clipboard") then return "Apps", "Clipboard history" end
		if has(c, "/cheatsheet") then return "Apps", "Keybind cheatsheet" end
		if has(c, "/overview") then return "Workspaces", "Workspace overview" end
		if has(c, "/lock") then return "System", "Lock screen" end
		if has(c, "/power") then return "System", "Power menu" end
		if has(c, "/wallpick") then return "System", "Wallpaper picker" end
		if has(c, "theme-hypr.sh --random") then return "System", "Random wallpaper" end
		if has(c, "theme-hypr.sh") then return "System", "Theme picker" end
		if has(c, "screenshot.sh") then
			local m = c:match("screenshot%.sh%s+(%w+)")
			local names = { region = "Screenshot region", output = "Screenshot screen",
				window = "Screenshot window", edit = "Screenshot + edit" }
			return "Capture", names[m] or "Screenshot"
		end
		if has(c, "clip-save") then return "Capture", "Save clip (last 60s)" end
		if has(c, "set-volume") then return "Media", has(c, "+") and "Volume up" or "Volume down" end
		if has(c, "set-mute") then return "Media", has(c, "SOURCE") and "Mute mic" or "Mute" end
		if has(c, "brightnessctl") then return "Media", has(c, "+") and "Brightness up" or "Brightness down" end
		if has(c, "playerctl next") then return "Media", "Next track" end
		if has(c, "playerctl previous") then return "Media", "Previous track" end
		if has(c, "play-pause") then return "Media", "Play / pause" end
		-- unknown command: show the program and its first argument
		local short = c:gsub("^.*/", ""):sub(1, 40)
		return "Other", "Run " .. short
	end
	if fn == "window.close" then return "Windows", "Close window" end
	if fn == "window.float" then return "Windows", "Toggle floating" end
	if fn == "window.pseudo" then return "Windows", "Pseudo-tile" end
	if fn == "window.fullscreen" then return "Windows", "Fullscreen" end
	if fn == "window.drag" then return "Windows", "Move window (drag)" end
	if fn == "window.resize" then return "Windows", "Resize window (drag)" end
	if fn == "layout" then return "Windows", "Toggle split" end
	if fn == "focus" and t.direction then return "Windows", "Focus " .. t.direction end
	if fn == "focus" and t.workspace then
		local w = t.workspace
		if w == "e+1" then return "Workspaces", "Next workspace" end
		if w == "e-1" then return "Workspaces", "Previous workspace" end
		return "Workspaces", "Go to workspace " .. tostring(w), "ws-go"
	end
	if fn == "window.move" and t.workspace then
		local w = tostring(t.workspace)
		if w:match("^special") then return "Workspaces", "Send window to scratchpad" end
		return "Workspaces", "Send window to workspace " .. w, "ws-move"
	end
	if fn == "workspace.toggle_special" then return "Workspaces", "Toggle scratchpad" end
	return "Other", fn ~= "" and fn or "?"
end

-- ---------- key names ----------
local nice = {
	SUPER = "Super", SHIFT = "Shift", CTRL = "Ctrl", CONTROL = "Ctrl", ALT = "Alt",
	Return = "Enter", Tab = "Tab", space = "Space", slash = "/", Escape = "Esc",
	left = "←", right = "→", up = "↑", down = "↓",
	["mouse:272"] = "Left drag", ["mouse:273"] = "Right drag",
	mouse_down = "Scroll ↓", mouse_up = "Scroll ↑",
	XF86AudioRaiseVolume = "Vol +", XF86AudioLowerVolume = "Vol −", XF86AudioMute = "Mute",
	XF86AudioMicMute = "Mic mute", XF86MonBrightnessUp = "Bright +", XF86MonBrightnessDown = "Bright −",
	XF86AudioNext = "Next", XF86AudioPrev = "Prev", XF86AudioPlay = "Play", XF86AudioPause = "Pause",
}
local function keycaps(s)
	local out = {}
	for raw in tostring(s):gmatch("[^+]+") do
		local part = raw:gsub("^%s+", ""):gsub("%s+$", "")   -- (loop variables are read-only in Lua 5.5)
		if part ~= "" then out[#out + 1] = nice[part] or (#part == 1 and part:upper() or part) end
	end
	return out
end

-- ---------- build the list (workspace 1..10 binds folded into one row each) ----------
local items, folded = {}, {}
for _, b in ipairs(found) do
	local cat, label, fold = describe(b)
	-- "-- cheat: Label" or "-- cheat: Category / Label" on the bind's line(s) wins
	for l = b.line, math.max(1, b.line - 4), -1 do
		local c = src[l] and src[l]:match("%-%-%s*cheat:%s*(.-)%s*$")
		if c then
			local cc, ll = c:match("^(.-)%s*/%s*(.+)$")
			if cc then cat, label = cc, ll else label = c end
			fold = nil
			break
		end
		if l < b.line and src[l] and src[l]:find("hl.bind", 1, true) then break end
	end

	local caps = keycaps(b.keys)
	if fold then
		if not folded[fold] then
			local mods = { table.unpack(caps, 1, #caps - 1) }
			mods[#mods + 1] = "1 … 0"
			folded[fold] = {
				cat = "Workspaces",
				label = fold == "ws-go" and "Go to workspace 1–10" or "Send window to workspace 1–10",
				keys = mods,
			}
			items[#items + 1] = folded[fold]
		end
	else
		-- same action on another key (e.g. Play and Pause): show both on one row
		local dup
		for _, it in ipairs(items) do
			if it.cat == cat and it.label == label then dup = it break end
		end
		if dup then
			dup.alt = dup.alt or {}
			dup.alt[#dup.alt + 1] = caps
		else
			items[#items + 1] = { cat = cat, label = label, keys = caps }
		end
	end
end

-- ---------- tiny JSON writer ----------
local function q(s)
	return '"' .. tostring(s):gsub('[%c"\\]', function(ch)
		if ch == '"' then return '\\"' elseif ch == "\\" then return "\\\\" end
		return string.format("\\u%04x", ch:byte())
	end) .. '"'
end
local function arr(t)
	local ks = {}
	for _, k in ipairs(t) do ks[#ks + 1] = q(k) end
	return "[" .. table.concat(ks, ",") .. "]"
end
local parts = {}
for _, it in ipairs(items) do
	-- combos: one or more key combinations for this action
	local combos = { arr(it.keys) }
	for _, a in ipairs(it.alt or {}) do combos[#combos + 1] = arr(a) end
	parts[#parts + 1] = "{" .. '"cat":' .. q(it.cat) .. ',"label":' .. q(it.label)
		.. ',"combos":[' .. table.concat(combos, ",") .. "]}"
end
io.write("[" .. table.concat(parts, ",") .. "]\n")
