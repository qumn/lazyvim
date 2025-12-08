-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
--
--
vim.opt.list = true
vim.opt.listchars = "tab:> ,trail:▫"
vim.opt.termguicolors = true

vim.g.gui_font_default_size = 18
vim.g.gui_font_size = vim.g.gui_font_default_size
vim.g.gui_font_face = "CaskaydiaCove Nerd Font"
vim.g.jumpoptions = "stack"
vim.g.snacks_animate = false
vim.g.root_spec =
  { "lsp", { ".git", "lua", "Cargo.toml", "pom.xml", "build.gradle", "go.mod", "package.json", "node_modules" }, "cwd" }

-- Detect OS name
vim.g.os_name = vim.loop.os_uname().sysname
