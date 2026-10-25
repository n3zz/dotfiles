------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/

hl.monitor({
	output = "DP-3",
	mode = "1920x1080@144",
	position = "0x0",
	scale = 1,
})

hl.monitor({
	output = "DP-4",
	mode = "2560x1440@164.84",
	position = "1920x0",
	scale = 1,
})

hl.monitor({ output = "HDMI-A-3", mode = "2560x1600@70", position = "4480x0", scale = 2 })
