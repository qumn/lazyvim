local defaults = {
  hl_http = {
    GET = "DiagnosticOk",
    POST = "DiagnosticWarn",
    PUT = "DiagnosticHint",
    DELETE = "DiagnosticError",
    PATCH = "TelescopeResultsOperator",
    ANY = "TelescopeResultsConstant",
  },
}

local M = {
  defaults = defaults,
  opts = vim.deepcopy(defaults),
}

function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
end

function M.get_opts(override)
  return vim.tbl_deep_extend("force", M.opts or vim.deepcopy(defaults), override or {})
end

function M.endpoints(opts)
  require("telescope").extensions.spring.endpoints(opts or {})
end

return M
