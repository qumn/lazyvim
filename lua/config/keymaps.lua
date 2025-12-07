-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

require("config.norman")

vim.keymap.set("v", "=", vim.lsp.buf.format, { silent = true })
vim.keymap.set("n", "==", vim.lsp.buf.format, { silent = true })

-- config for neovide
if vim.g.neovide then
  vim.api.nvim_set_keymap("v", "<sc-c>", '"+y', { noremap = true })
  vim.api.nvim_set_keymap("n", "<sc-v>", 'l"+P', { noremap = true })
  vim.api.nvim_set_keymap("v", "<sc-v>", '"+P', { noremap = true })
  -- vim.api.nvim_set_keymap("c", "<sc-v>", '<C-o>l<C-o>"+<C-o>P<C-o>l', { noremap = true })
  vim.api.nvim_set_keymap("c", "<sc-v>", "<C-r>+", { noremap = true })
  vim.api.nvim_set_keymap("i", "<sc-v>", '<ESC>l"+Pli', { noremap = true })
  vim.api.nvim_set_keymap("t", "<sc-v>", '<C-\\><C-n>"+Pi', { noremap = true })
end

-- Keymaps
vim.keymap.set("n", "<C-=>", function()
  ResizeGuiFont(1)
end)
vim.keymap.set("n", "<C-->", function()
  ResizeGuiFont(-1)
end)

-- gui specialize config
RefreshGuiFont = function()
  vim.opt.guifont = string.format("%s:h%s", vim.g.gui_font_face, vim.g.gui_font_size)
end

ResizeGuiFont = function(delta)
  vim.g.gui_font_size = vim.g.gui_font_size + delta
  RefreshGuiFont()
end

ResetGuiFont = function()
  vim.g.gui_font_size = vim.g.gui_font_default_size
  RefreshGuiFont()
end

-- Call function on startup to set default value
ResetGuiFont()
