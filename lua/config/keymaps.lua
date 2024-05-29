-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

require("config.norman")

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

function _G.set_terminal_keymaps()
  local opts = { buffer = 0 }
  vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], opts)
  -- vim.keymap.set('t', 'ni', [[<C-\><C-n>]], opts)
  vim.keymap.set("t", "<C-y>", [[<Cmd>wincmd h<CR>]], opts)
  vim.keymap.set("t", "<C-n>", [[<Cmd>wincmd j<CR>]], opts)
  -- vim.keymap.set('t', '<C-i>', [[<Cmd>wincmd k<CR>]], opts)
  vim.keymap.set("t", "<C-o>", [[<Cmd>wincmd l<CR>]], opts)
  -- vim.keymap.set('t', '<C-w>', [[<C-\><C-n><C-w>]], opts)
end

-- if you only want these mappings for toggle term use term://*toggleterm#* instead
vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")
