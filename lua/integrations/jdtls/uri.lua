local M = {}

function M.parse(uri)
  if type(uri) ~= "string" then
    return nil
  end
  if not vim.startswith(uri, "jdt://contents/") then
    return nil
  end

  local path = uri:gsub("^jdt://contents/", "")
  path = path:gsub("%?.*$", "")

  local jar, inner = path:match("^([^/]+)/(.+)$")
  if not jar or not inner then
    return nil
  end

  local tail = inner:match("([^/]+)$") or inner

  return {
    jar = jar,
    inner = inner,
    tail = tail,
    label = string.format("%s (%s)", tail, jar),
  }
end

function M.label(uri)
  local parsed = M.parse(uri)
  return parsed and parsed.label or nil
end

return M

