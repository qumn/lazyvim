-- parse ripgrep output lines (file:line:text) into endpoints.
local M = {}

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Split only on the first two ":" so text may contain ":" safely.
local function split_rg_line(s)
  local p1 = s:find(":", 1, true)
  if not p1 then
    return nil
  end
  local p2 = s:find(":", p1 + 1, true)
  if not p2 then
    return nil
  end

  local file = s:sub(1, p1 - 1)
  local line = tonumber(s:sub(p1 + 1, p2 - 1))
  local text = s:sub(p2 + 1)

  if not file or not line or not text then
    return nil
  end
  return file, line, text
end

-- Extract the first string literal "..." from the annotation line.
local function first_quoted(s)
  local a, b = s:find('"%g-"')
  if not a then
    return nil
  end
  return s:sub(a + 1, b - 1)
end

local function http_of(anno_trimmed)
  if anno_trimmed:find("^@GetMapping") then
    return "GET"
  end
  if anno_trimmed:find("^@PostMapping") then
    return "POST"
  end
  if anno_trimmed:find("^@PutMapping") then
    return "PUT"
  end
  if anno_trimmed:find("^@DeleteMapping") then
    return "DELETE"
  end
  if anno_trimmed:find("^@PatchMapping") then
    return "PATCH"
  end
  if anno_trimmed:find("^@RequestMapping") then
    return "ANY"
  end
  return ""
end

local function norm_path(p)
  if not p or p == "" then
    return ""
  end
  p = trim(p)
  if p == "" then
    return ""
  end
  if p:sub(1, 1) ~= "/" then
    p = "/" .. p
  end
  if #p > 1 then
    p = p:gsub("/+$", "")
  end
  return p
end

local function join_path(base, subp)
  base = norm_path(base)
  subp = norm_path(subp)

  if base ~= "" and subp ~= "" then
    return base .. subp
  elseif base ~= "" then
    return base
  elseif subp ~= "" then
    return subp
  else
    return "/"
  end
end

local function default_class_pred(raw)
  return raw:match("^@RequestMapping") ~= nil
end

local function parse_line(state, raw_line, class_pred)
  local file, lnum, raw = split_rg_line(raw_line)
  if not file then
    return nil
  end

  local t = trim(raw)

  if t:match("^@RequestMapping") and class_pred(raw, t) then
    state.base_by_file[file] = first_quoted(t) or ""
    return nil
  end

  if t:match("^@[%w]+Mapping") or t:match("^@RequestMapping") then
    local http = http_of(t)
    local subp = first_quoted(t) or ""
    local base = state.base_by_file[file] or ""
    local full = join_path(base, subp)

    local item = {
      file = file,
      lnum = lnum,
      http = http,
      path = full,
      text = t,
      base = base,
      sub = subp,
    }
    table.insert(state.results, item)
    return item
  end

  return nil
end

function M.parse_rg_lines(lines, opts)
  opts = opts or {}
  local class_pred = opts.class_level_pred or default_class_pred

  local state = {
    base_by_file = {},
    results = {},
  }

  for _, line in ipairs(lines) do
    parse_line(state, line, class_pred)
  end

  return state.results
end

function M.new_stream_state(opts)
  opts = opts or {}
  return {
    base_by_file = {},
    results = {},
    class_pred = opts.class_level_pred or default_class_pred,
  }
end

function M.ingest_line(state, raw_line)
  return parse_line(state, raw_line, state.class_pred)
end

return M
