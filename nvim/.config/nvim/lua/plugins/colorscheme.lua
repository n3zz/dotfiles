local function get_theme()
  local f = io.open(vim.fn.expand("~/.cache/wal/nvim-colorscheme"), "r")
  if f then
    local name = f:read("*l")
    f:close()
    if name == "neopywal" or name == "tokyonight" or name == "dracula" then
      return name
    end
  end
  return "tokyonight"
end

return {
  { "RedsXDD/neopywal.nvim", lazy = true },

  {
    "folke/tokyonight.nvim",
    opts = { style = "storm" },
  },
  { "Mofiqul/dracula.nvim" },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = get_theme(),
    },
  },
}
