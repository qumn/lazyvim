return {
  desc = "Run :MarkdownPreview when the task starts",
  editable = false,
  serializable = false,
  constructor = function()
    return {
      on_start = function(_, task)
        vim.schedule(function()
          if vim.fn.exists(":MarkdownPreview") ~= 2 then
            vim.notify("MarkdownPreview command not found", vim.log.levels.WARN)
            return
          end

          local function run()
            vim.api.nvim_cmd({ cmd = "MarkdownPreview" }, {})
          end

          local bufnr = task.metadata and task.metadata.bufnr
          if type(bufnr) == "number" and vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_call(bufnr, function()
              pcall(run)
            end)
          else
            pcall(run)
          end
        end)
      end,
    }
  end,
}
