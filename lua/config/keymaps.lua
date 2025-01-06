-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

require("config.norman")

-- if you only want these mappings for toggle term use term://*toggleterm#* instead
vim.keymap.set("v", "=", vim.lsp.buf.format, { silent = true })
vim.keymap.set("n", "==", vim.lsp.buf.format, { silent = true })

-- config for neovide
if vim.g.neovide then
  vim.cmd([[
    nmap <D-c> "+y
    vmap <D-c> "+y
    nmap <D-v> "+p
    inoremap <D-v> <c-r>+
    cnoremap <D-v> <c-r>+
    " use <c-r> to insert original character without triggering things like auto-pairs
    inoremap <D-r> <c-v>
  ]])
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
