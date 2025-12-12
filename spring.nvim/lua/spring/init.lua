local M = {}

function M.setup(opts)
  M.opts = opts or {}
end

function M.endpoints(opts)
  require("telescope").extensions.spring.endpoints(opts or {})
end

return M
