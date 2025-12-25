local M = {}

local state = {
  id = nil,
  hide = nil,
}

function M.owner()
  return state.id
end

function M.clear(id)
  if state.id == id then
    state.id = nil
    state.hide = nil
  end
end

function M.register(id, hide)
  state.id = id
  state.hide = hide
end

function M.hide_other(id)
  if not state.hide or state.id == id then
    return
  end
  local ok = pcall(state.hide)
  if ok then
    state.id = nil
    state.hide = nil
  end
end

return M
