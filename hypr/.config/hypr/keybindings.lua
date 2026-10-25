---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

local menu = "rofi -show drun -theme " .. os.getenv("HOME") .. "/.config/rofi/launcher.rasi"
local terminal = "kitty"
local fileManager = "thunar"

-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
local closeWindowBind = hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.close())
-- closeWindowBind:set_enabled(false)

hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit")) -- dwindle only
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("$HOME/.config/hypr/theme-hypr.sh"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("$HOME/.config/hypr/theme-hypr.sh --random"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("pgrep -f '^quickshell -p .*/lock' || quickshell -p $HOME/.config/quickshell/lock"))

hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("pkill -f '^quickshell -p .*/power' || quickshell -p $HOME/.config/quickshell/power"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
	local key = i % 10 -- 10 maps to key 0
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Quickshell wallpaper picker (toggle)
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("pkill -f '^quickshell -p .*/wallpick' || quickshell -p $HOME/.config/quickshell/wallpick"))

-- Quickshell clipboard history (toggle)
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("pkill -f '^quickshell -p .*/clipboard' || quickshell -p $HOME/.config/quickshell/clipboard"))

-- Screenshots (grim + slurp + satty) — saved to ~/Pictures/Screenshots and copied to clipboard
local shot = os.getenv("HOME") .. "/.config/hypr/scripts/screenshot.sh"
hl.bind(mainMod .. " + SHIFT + X", hl.dsp.exec_cmd(shot .. " region"))
hl.bind(mainMod .. " + CTRL + X",  hl.dsp.exec_cmd(shot .. " output"))
hl.bind(mainMod .. " + ALT + X",   hl.dsp.exec_cmd(shot .. " window"))
hl.bind(mainMod .. " + SHIFT + Z", hl.dsp.exec_cmd(shot .. " edit"))

-- Clips: save the last 60s of the replay buffer (gpu-screen-recorder)
hl.bind(mainMod .. " + ALT + G", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/clip-save.sh"))

-- Workspace overview (toggle), like Win+Tab
hl.bind(mainMod .. " + Tab", hl.dsp.exec_cmd("pkill -f '^quickshell -p .*/overview' || quickshell -p $HOME/.config/quickshell/overview"))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("quickshell -p $HOME/.config/quickshell/bar ipc call ai toggle"))
