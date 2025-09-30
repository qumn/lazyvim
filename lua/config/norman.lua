-- the norman layout display

vim.g.upkey = "i"
vim.g.downkey = "n"
vim.g.leftkey = "y"
vim.g.rightkey = "o"

local del = vim.keymap.del

-- del({ "n", "t" }, "<C-h>")
-- del({ "n", "t" }, "<C-j>")
-- del({ "n", "t" }, "<C-k>")
-- del({ "n", "t" }, "<C-l>")
-- del("x", "i")
-- del("x", "in")
-- del("x", "il")
-- del("n", "yÞ")
-- del("n", "yiÞ")
-- del("n", "yaÞ")
-- del("n", "y")

vim.cmd([[
  " === norman keyboard layout
  nnoremap <nowait> y h
  " nnoremap n j
  " nnoremap i k
  nnoremap <nowait> o l

  vnoremap <nowait> y h
  vnoremap <nowait> n j
  vnoremap <nowait> i k
  vnoremap <nowait> o l

  onoremap <nowait> y h
  onoremap <nowait> n j
  onoremap <nowait> i k
  onoremap <nowait> o l
  xnoremap <nowait> i k

  " a workaround for the fact that `i` are used up in visual mode
  " vnoremap " i"
  vnoremap ( i)
  vnoremap [ i]
  vnoremap { i}
  onoremap o l
  xnoremap o l
  onoremap y h
  xnoremap y h

  noremap Y ^
  noremap O $
  noremap N J
  " noremap I K

  " map r <Nop>
  noremap r i
  noremap R I
  noremap l o
  noremap L O

  noremap j y
  noremap h n
  noremap H N
  noremap k r
  noremap K R
  nnoremap <c-l> <c-o>
  nnoremap <c-r> <c-i>
  nnoremap <c-u> <c-r>

  " jump between windows
  nnoremap <C-w>y <C-w>h
  nnoremap <C-w>n <C-w>j
  nnoremap <C-w>i <C-w>k
  nnoremap <C-w>o <C-w>l
  nnoremap <C-w>l <Cmd>wincmd o<CR>

  " nnoremap <C-y> <C-w>h
  " nnoremap <C-n> <C-w>j
  " nnoremap <C-i> <C-w>k
  " nnoremap <C-o> <C-w>l
  nnoremap <M-o> <Cmd>BufferLineCycleNext<CR>
  nnoremap <M-y> <Cmd>BufferLineCyclePrev<CR>
  nnoremap go <Cmd>BufferLineCycleNext<CR>
  nnoremap gy <Cmd>BufferLineCyclePrev<CR>

  xnoremap p pgvy

  " clear all mappings in select mode
  smapclear
  " tmapclear
]])

vim.keymap.set("n", "n", function()
  if vim.v.count > 0 then
    return "m'" .. vim.v.count .. "j"
  else
    return "gj"
  end
end, { noremap = true, expr = true })

vim.keymap.set("n", "i", function()
  if vim.v.count > 0 then
    return "m'" .. vim.v.count .. "k"
  else
    return "gk"
  end
end, { noremap = true, expr = true })
