-- vim.cmd([[
--   " overwrite the default man key mapping for j
--   nnoremap <silent> <buffer> j y
-- ]])
vim.g.no_man_maps = 1
vim.cmd([[
  nnoremap <silent> <buffer> gO            :lua require'man'.show_toc()<CR>
  nnoremap <silent> <buffer> <2-LeftMouse> :Man<CR>
  nnoremap <silent> <buffer> <nowait> q :lclose<CR>:q!<CR>
]])
