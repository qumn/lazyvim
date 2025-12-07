return {
  {
    "nvim-mini/mini.ai",
    event = "VeryLazy",
    opts = {
      mappings = {
        around = "a",
        inside = "r",

        around_next = "an",
        inside_next = "rn",
        around_last = "al",
        inside_last = "rl",
      },
    },
  },
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    enabled = false,
    config = function(_, _)
      -- discard default config
    end,
  },
}
