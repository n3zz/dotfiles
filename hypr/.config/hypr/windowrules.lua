-- Windows-style app rules

-- Vesktop: always solid
hl.window_rule({
  name    = "vesktop-opaque",
  match   = { class = "^vesktop$" },
  opacity = "1.0 override 1.0 override 1.0 override",
  no_blur = true,
})

-- LibreOffice (all apps): always solid
hl.window_rule({
  name    = "libreoffice-opaque",
  match   = { class = "^(libreoffice-.*|soffice)$" },
  opacity = "1.0 override 1.0 override 1.0 override",
  no_blur = true,
})

-- Steam: chats/dialogs float small (chat titles = friend names, so match the class)
hl.window_rule({
  name  = "steam-popups",
  match = { class = "^steam$", title = "^([^n]|n([^o]|o([^t]|t([^i]|i([^f]|f([^i]|i([^c]|c([^a]|a([^t]|t([^i]|i([^o]|o([^n]|n([^t]|t([^o]|o([^a]|a([^s]|s([^t]|t([^s])))))))))))))))))).*$" }, -- any title except toasts/empty
  float = true,
  size  = "720 520",
  persistent_size = true,
})

-- Steam friends list: narrow column
hl.window_rule({
  name  = "steam-friends",
  match = { class = "^steam$", title = "^Friends List$" },
  float = true,
  size  = "360 760",
  persistent_size = true,
})

-- Steam main client + Big Picture: keep tiled
hl.window_rule({
  name  = "steam-main",
  match = { class = "^steam$", title = "^(Steam|Steam Big Picture Mode)$" },
  tile  = true,
})


-- Quickshell wallpaper picker
hl.layer_rule({ match = { namespace = "quickshell-wallpick" }, blur = true, ignore_alpha = 0.2 })

-- Steam toasts: small, no focus stealing, top-right of the monitor
hl.window_rule({
  name     = "steam-toasts",
  match    = { class = "^steam$", title = "^notificationtoasts_.*$" },
  float    = true,
  no_focus = true,
  pin      = true,
  move     = "monitor_w - window_w - 16 60",
})

-- Steam's untitled helper windows: float, but leave their size alone
hl.window_rule({
  name  = "steam-helpers",
  match = { class = "^steam$", title = "^$" },
  float = true,
})
