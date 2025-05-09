return {
  "aserowy/tmux.nvim",
  event = "BufRead",
  enable = not vim.g.neovide,
  opts = {
    copy_sync = {
      enable = false, -- 启动这个选项会使':'变得非常慢
    },
    navigation = {
      enable_default_keybindings = false,
    },
    resize = {
      enable_default_keybindings = true,
    },
  },
  init = function()
    local map = vim.keymap.set
      -- stylua: ignore start
      map("n", "<c-y>", function() require("tmux").move_left() end)
      map("n", "<c-n>", function() require("tmux").move_bottom() end)
      map("n", "<C-i>", function() require("tmux").move_top() end)
      map("n", "<c-o>", function() require("tmux").move_right() end)
    -- stylua: ignore end
  end,
}
