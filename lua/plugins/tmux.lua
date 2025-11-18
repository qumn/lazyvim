return {
  "mrjones2014/smart-splits.nvim",
  event = "BufRead",
  enable = not vim.g.neovide,
  init = function()
    local map = vim.keymap.set
    map("n", "<C-y>", require("smart-splits").move_cursor_left)
    map("n", "<C-n>", require("smart-splits").move_cursor_down)
    map("n", "<C-i>", require("smart-splits").move_cursor_up)
    map("n", "<C-o>", require("smart-splits").move_cursor_right)
    map("n", "<C-\\>", require("smart-splits").move_cursor_previous)
  end,
}
