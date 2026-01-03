local M = {}

local state = {
  id = nil,
  hide = nil,
}

local function clear()
  state.id = nil
  state.hide = nil
end

local function safe_call(fn)
  if type(fn) ~= "function" then
    return true
  end
  return pcall(fn)
end

---@class integrations.layout.bottom.ToggleOpts
---@field id string
---@field open? fun()
---@field hide fun()
---@field is_open? fun(): boolean
---@field claim? boolean

---@param opts integrations.layout.bottom.ToggleOpts
---@return boolean opened
function M.toggle(opts)
  if type(opts) ~= "table" or type(opts.id) ~= "string" or opts.id == "" then
    return false
  end
  if type(opts.hide) ~= "function" then
    return false
  end

  if state.id == opts.id then
    if opts.claim then
      state.hide = opts.hide
      return true
    end
    if type(opts.is_open) == "function" then
      local ok, open_now = pcall(opts.is_open)
      if ok and not open_now then
        clear()
      else
        safe_call(opts.hide)
        clear()
        return false
      end
    else
      safe_call(opts.hide)
      clear()
      return false
    end
  end

  safe_call(state.hide)
  clear()

  local ok = safe_call(opts.open)
  if not ok then
    return false
  end

  state.id = opts.id
  state.hide = opts.hide
  return true
end

return M
