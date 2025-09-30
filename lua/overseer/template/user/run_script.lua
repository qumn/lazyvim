return {
  name = "run script",
  params = {
    cmd = { optional = true, type = "string", default = "python3" },
    cwd = { optional = true, type = "string" },
  },
  builder = function()
    local file = vim.fn.expand("%:p")
    local cmd = { file }
    if vim.bo.filetype == "go" then
      cmd = { "go", "run", file }
    elseif vim.bo.filetype == "python" then
      cmd = { "python3", file }
    end
    return {
      name = vim.fn.expand("%:t"),
      cmd = cmd,
      args = { vim.fn.expand("%:p") },
      cwd = vim.fn.expand("%:p:h"),
      components = {
        "display_duration",
        "on_exit_set_status",
        "on_complete_notify",
        "on_output_summarize",
        "on_result_diagnostics",
        { "open_output", direction = "dock" },
      },
    }
  end,
  condition = {
    filetype = { "python", "sh", "go" },
  },
}
