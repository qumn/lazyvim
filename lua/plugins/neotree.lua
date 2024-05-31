return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    filesystem = {
      group_empty_dirs = true,
      scan_mode = "deep",
    },
    window = {
      mappings = {
        ["i"] = "noop",
        ["o"] = {
          "open",
          nowait = true,
        },
        ["oc"] = "noop",
        ["od"] = "noop",
        ["og"] = "noop",
        ["om"] = "noop",
        ["on"] = "noop",
        ["os"] = "noop",
        ["ot"] = "noop",
      },
    },
  },
}
