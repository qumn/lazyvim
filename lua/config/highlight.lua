local M = {}
M.highlight = {
  BlinkCmpLabelDetail = { link = "Grey" },
  BlinkCmpLabelDescription = { link = "Orange" },

  TSVariable = { link = "Blue" },
  TSConstant = { fg = "#FFE082", bold = true },
  TSKeywordReturn = { bold = true, italic = true },
  TSConstBuiltin = { bold = true, italic = true },
  TSFuncBuiltin = { bold = true, italic = true },
  TSTypeBuiltin = { bold = true, italic = true },
  TSBoolean = { bold = true, italic = true },

  TSType = { bold = true },
  TSConstructor = { bold = true },
  TSOperator = { bold = true },

  TSInclude = { italic = true },
  TSVariableBuiltin = { italic = true },
  TSConditional = { italic = true },
  TSKeyword = { italic = true },
  TSKeywordFunction = { italic = true },
  TSComment = { italic = true },
  TSParameter = { italic = true },
  semshiBuiltin = { italic = true },

  InlayHint = { italic = true },
  LspInlayHint = { italic = true },

  DiffText = { link = { "Blue" }, bg = "#4a6a74", italic = true },
  DiffChange = { bg = "#3a515d" },

  ["@markup.quote.rst"] = { link = "markdownH1" },
  ["@string.special.url.rst"] = { link = { "@markup.link.url", "Grey" } },
  -- lsp semantic token
  -- stylua: ignore start
  ["@repeat"]               = { italic = true },
  ["@lsp.type.parameter"]   = { link   = "aqua" },
  ["@lsp.type.variable"]    = { link   = "Blue" },
  ["@lsp.type.class"]       = { bold   = true },
  ["@keyword"]              = { italic = true, bold   = true },
  ["@keyword.function"]     = { bold   = true, italic = true },
  ["@function.method.call"] = { italic = true },
  -- stylua: ignore end
}

function M.mod_hl(hl_name, opts)
  if type(opts) ~= "table" then
    return
  end

  local link = opts.link
  if link ~= nil and type(link) ~= "string" and type(link) ~= "table" and link ~= false then
    return
  end

  local merged = {}

  do
    local ok, cur = pcall(vim.api.nvim_get_hl, 0, { name = hl_name, link = false })
    if ok and type(cur) == "table" then
      merged = vim.tbl_deep_extend("force", merged, cur)
    end
  end

  local function add(name)
    if type(name) ~= "string" or name == "" or name == "NONE" then
      return
    end
    -- 关键：link=false -> 拿到最终展开后的样式，支持“嵌套 link”
    local ok, def = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
    if ok and type(def) == "table" then
      merged = vim.tbl_deep_extend("force", merged, def)
    end
  end

  if type(link) == "string" then
    add(link)
  elseif type(link) == "table" then
    for _, name in ipairs(link) do
      add(name)
    end
  else
    -- link=nil/false：不合并 link
  end

  local extra = vim.deepcopy(opts)
  extra.link = nil

  merged = vim.tbl_deep_extend("force", merged, extra)

  vim.api.nvim_set_hl(0, hl_name, merged)
end

function M.setup()
  for k, v in pairs(M.highlight) do
    M.mod_hl(k, v)
  end
  -- HACK: this semantic token is overriding the custom sql injection highlight
  vim.api.nvim_set_hl(0, "@lsp.type.string.rust", {})
end

return M
