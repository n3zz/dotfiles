-- Fallback for any monitor not listed above
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

hl.config({
	misc = { disable_hyprland_logo = true, disable_splash_rendering = true },
	animations = { enabled = false },
})
hl.env("XCURSOR_SIZE", "24")

-- Show the login screen; when it hands over to your session, close this Hyprland
hl.on("hyprland.start", function()
	hl.exec_cmd("sh -c 'quickshell -p /etc/greetd/greeter; pkill -x Hyprland'")
end)
