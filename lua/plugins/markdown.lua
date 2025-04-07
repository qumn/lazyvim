return {
  "MeanderingProgrammer/render-markdown.nvim",
  opts = {
    checkbox = {
      enabled = true,
      render_modes = false,
      right_pad = 1,
      unchecked = {
        icon = "󰄱 ",
        highlight = "RenderMarkdownUnchecked",
        scope_highlight = nil,
      },
      checked = {
        icon = "󰱒 ",
        highlight = "RenderMarkdownChecked",
        scope_highlight = nil,
      },
      custom = {
        todo = {
          raw = "[-]",
          rendered = "󰥔 ",
          highlight = "RenderMarkdownTodo",
          scope_highlight = nil,
        },
      },
    },
  },
}
