local function term_nav(dir)
  return function(self)
    return self:is_floating() and "<c-" .. dir .. ">" or vim.schedule(function()
      vim.cmd.wincmd(dir)
    end)
  end
end

return {
  "folke/snacks.nvim",
  opts = {
    scope = { enable = false },
    picker = {
      win = {
        input = {
          keys = {
            ["<c-n>"] = { "list_down", mode = { "i", "n" } },
            ["<c-i>"] = { "list_up", mode = { "i", "n" } },
          },
        },
        list = {
          keys = {
            ["<c-n>"] = { "list_down", mode = { "i", "n" } },
            ["<c-i>"] = { "list_up", mode = { "i", "n" } },
          },
        },
      },
    },
    terminal = {
      win = {
        keys = {
          nav_h = { "<C-y>", term_nav("h"), desc = "Go to Left Window", expr = true, mode = "t" },
          nav_j = { "<C-n>", term_nav("j"), desc = "Go to Lower Window", expr = true, mode = "t" },
          nav_k = { "<C-i>", term_nav("k"), desc = "Go to Upper Window", expr = true, mode = "t" },
          nav_l = { "<C-o>", term_nav("l"), desc = "Go to Right Window", expr = true, mode = "t" },
          -- <C-i> equals <Tab> in terminals, so mapping only one affects both.
          -- Map them separately to keep <Tab> as <Tab>.
          tab = { "<Tab>", [[<Tab>]], desc = "Keep Tab is Tab", expr = true, mode = "t" },

          hide_slash = { "<C-/>", "hide", desc = "Hide Terminal", mode = { "t", "n" } },
          hide_underscore = { "<c-_>", "hide", desc = "which_key_ignore", mode = { "t", "n" } },
        },
      },
    },
  },
}
