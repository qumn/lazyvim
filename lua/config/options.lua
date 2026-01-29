-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
--
--
vim.opt.list = true
vim.opt.listchars = "tab:> ,trail:▫"
vim.opt.termguicolors = true
vim.opt.jumpoptions = "stack"
vim.opt.termguicolors = true

vim.g.gui_font_default_size = 18
vim.g.gui_font_size = vim.g.gui_font_default_size
vim.g.gui_font_face = "CaskaydiaCove Nerd Font"
vim.g.jumpoptions = "stack"
vim.g.snacks_animate = false
vim.g.overseer_exit_wait_ms = 0
vim.g.copilot_enabled = true

-- vim.g.root_spec =
--   { "lsp", { ".git", "lua", "Cargo.toml", "pom.xml", "build.gradle", "go.mod", "package.json", "node_modules" }, "cwd" }
-- In a nested, multi-level directory layout, including markers like pom.xml or Cargo.toml will make the root detector
-- pick the nearest (closest) project root, which can cause the detected root to jump between submodules.
vim.g.root_spec = { "lsp", { ".git" }, "cwd" }

-- Detect OS name
vim.g.os_name = vim.loop.os_uname().sysname

vim.g.ssh = vim.env.SSH_TTY ~= nil or vim.env.SSH_CONNECTION ~= nil or vim.env.SSH_CLIENT ~= nil

-- Use OSC52 clipboard when connected over SSH
if vim.g.ssh then
  vim.g.clipboard = "osc52"
  vim.opt.clipboard = "unnamedplus"
end

-- Enable this option to avoid conflicts with Prettier.
vim.g.lazyvim_prettier_needs_config = true

vim.filetype.add({
  extension = {
    drawio = "xml",
  },
})

require("config.folding")
