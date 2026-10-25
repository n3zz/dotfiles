--- This is for autostart modules

hl.on("hyprland.start", function()
	hl.exec_cmd("awww-daemon")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("quickshell -p $HOME/.config/quickshell/bar")

	-- clipboard history for the Quickshell clipboard picker
	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)
