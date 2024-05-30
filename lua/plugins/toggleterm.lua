return {
  "akinsho/toggleterm.nvim",
  version = "*",
  keys = { "<C-t>" },
  opts = {
    open_mapping = [[<C-t>]],
    shell = "/bin/bash",
  },
  init = function()
    vim.cmd([[
    autocmd TermEnter term://*toggleterm#*
          \ tnoremap <silent><C-t> <Cmd>exe v:count1 . "ToggleTerm"<CR>
    ]])
  end,
}
