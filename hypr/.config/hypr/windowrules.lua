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
  match = { class = "^steam$" },
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

