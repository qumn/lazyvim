---@type table<number, string>
local cache = {}

local function get_crate_name()
  if vim.bo.filetype ~= "rust" then
    return ""
  end
  local buf = vim.api.nvim_get_current_buf()
  if cache[buf] then
    return cache[buf]
  end
  -- 获取当前文件的路径
  local current_file = vim.fn.expand("%:p:h")

  -- 查找包含 Cargo.toml 的目录，即 crate 根目录
  local cargo_toml = vim.fn.findfile("Cargo.toml", current_file .. ";")
  if cargo_toml == "" then
    return "[No Crate]" -- 未找到 Cargo.toml
  end

  -- 解析 Cargo.toml 文件，获取 crate 名称
  local crate_name = ""
  for line in io.lines(cargo_toml) do
    if line:match('^name%s*=%s*".*"$') then
      crate_name = line:match('^name%s*=%s*"(.*)"$')
      break
    end
  end

  local ret = crate_name ~= "" and crate_name or "[Unknown Crate]"
  cache[buf] = ret
  return ret
end

return {
  "nvim-lualine/lualine.nvim",
  optional = true,
  opts = function(_, opts)
    local crate_name = {
      function()
        return "󱉭 " .. get_crate_name()
      end,
      cond = function()
        return vim.bo.filetype == "rust" and type(get_crate_name()) == "string"
      end,
      color = { fg = Snacks.util.color("Special") },
    }
    table.insert(opts.sections.lualine_c, 1, crate_name)
  end,
}
