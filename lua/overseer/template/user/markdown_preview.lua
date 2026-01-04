return {
  name = "MarkdownPreview",
  builder = function()
    local file = vim.fn.expand("%:p")
    return {
      name = ("MarkdownPreview: %s"):format(vim.fn.fnamemodify(file, ":t")),
      cmd = { "sh", "-lc", "echo 'MarkdownPreview started'" },
      cwd = vim.fn.fnamemodify(file, ":h"),
      metadata = { bufnr = vim.api.nvim_get_current_buf(), file = file, overseer_auto_open_output = false },
      components = { "default", "markdown_preview" },
    }
  end,
  condition = {
    filetype = { "markdown" },
  },
}
