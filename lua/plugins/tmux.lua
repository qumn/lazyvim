return {
  "mrjones2014/smart-splits.nvim",
  dependencies = { "pogyomo/submode.nvim" },
  event = "BufRead",
  enable = not vim.g.neovide,
  init = function()
    local map = vim.keymap.set
    map("n", "<C-y>", require("smart-splits").move_cursor_left)
    map("n", "<C-n>", require("smart-splits").move_cursor_down)
    map("n", "<C-i>", require("smart-splits").move_cursor_up)
    map("n", "<C-o>", require("smart-splits").move_cursor_right)
    map("n", "<C-\\>", require("smart-splits").move_cursor_previous)

    map("n", "<C-S-Y>", require("smart-splits").resize_left)
    map("n", "<C-S-N>", require("smart-splits").resize_down)
    map("n", "<C-S-I>", require("smart-splits").resize_up)
    map("n", "<C-S-O>", require("smart-splits").resize_right)

    map("n", "<C-w>y", require("smart-splits").swap_buf_left)
    map("n", "<C-w>n", require("smart-splits").swap_buf_down)
    map("n", "<C-w>i", require("smart-splits").swap_buf_up)
    map("n", "<C-w>o", require("smart-splits").swap_buf_right)

    -- Resize
    local submode = require("submode")
    submode.create("WinResize", {
      mode = "n",
      enter = "<C-w>r",
      leave = { "<Esc>", "q", "<C-c>" },
      hook = {
        on_enter = function()
          vim.notify("Use { y, n, i, o } or { <Left>, <Down>, <Up>, <Right> } to resize the window")
        end,
        on_leave = function()
          vim.notify("")
        end,
      },
      default = function(register)
        register("y", require("smart-splits").resize_left, { desc = "Resize left" })
        register("n", require("smart-splits").resize_down, { desc = "Resize down" })
        register("i", require("smart-splits").resize_up, { desc = "Resize up" })
        register("o", require("smart-splits").resize_right, { desc = "Resize right" })
        register("s", "<CMD>split<CR>", { desc = "Create horizontal split" })
        register("v", "<CMD>vsplit<CR>", { desc = "Create vertical split" })
        register("f", "<CMD>Telescope find_files<CR>", { desc = "Find files" })
        register("<Left>", require("smart-splits").resize_left, { desc = "Resize left" })
        register("<Down>", require("smart-splits").resize_down, { desc = "Resize down" })
        register("<Up>", require("smart-splits").resize_up, { desc = "Resize up" })
        register("<Right>", require("smart-splits").resize_right, { desc = "Resize right" })
      end,
    })
  end,
}
