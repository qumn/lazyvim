local M = {}

M._cache = {}

local function pick_jdtls_client()
  local clients = vim.lsp.get_clients({ name = "jdtls" })
  for _, c in ipairs(clients) do
    if c and c.name == "jdtls" then
      return c
    end
  end
  return nil
end

local function normalize_loc(loc)
  if not loc or type(loc) ~= "table" then
    return nil
  end
  if loc.uri and loc.range then
    return loc
  end
  if loc.targetUri then
    local range = loc.targetSelectionRange or loc.targetRange
    if range then
      return { uri = loc.targetUri, range = range }
    end
  end
  return nil
end

local function clamp_lnum_in_buf(buf, lnum)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return 1
  end
  if not vim.api.nvim_buf_is_loaded(buf) then
    pcall(vim.fn.bufload, buf)
  end
  local last = vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_line_count(buf) or 1
  lnum = tonumber(lnum) or 1
  lnum = math.min(math.max(lnum, 1), math.max(last, 1))
  return lnum
end

local function apply_resolved_location(loc, ud, titem)
  loc = normalize_loc(loc)
  if not loc then
    return false
  end
  local uri = loc.uri or loc.targetUri
  if type(uri) ~= "string" or uri == "" then
    return false
  end

  local target_buf = vim.uri_to_bufnr(uri)
  if not (target_buf and vim.api.nvim_buf_is_valid(target_buf)) then
    return false
  end

  local lnum = ud and ud.lnum or 1
  lnum = clamp_lnum_in_buf(target_buf, lnum)

  if titem then
    titem.buf = target_buf
    titem.pos = { lnum, 0 }
    titem.end_pos = { lnum, 0 }
    local name = vim.api.nvim_buf_get_name(target_buf)
    if type(name) == "string" and name ~= "" then
      titem.filename = name
    end
  end
  if ud and type(ud) == "table" then
    ud.stacktrace_resolved = true
  end
  return true
end

local function open_type_via_execute_command(client, class_name, ud, titem, done)
  done = done or function() end
  if not client or not class_name or class_name == "" then
    done(false)
    return
  end

  local cmds = client.server_capabilities
      and client.server_capabilities.executeCommandProvider
      and client.server_capabilities.executeCommandProvider.commands
    or {}

  local function pick_command()
    for _, c in ipairs(cmds or {}) do
      if type(c) == "string" and c:lower():find("opentype", 1, true) then
        return c
      end
    end
    for _, c in ipairs(cmds or {}) do
      local lower = type(c) == "string" and c:lower() or ""
      if lower ~= "" and lower:find("open", 1, true) and lower:find("type", 1, true) then
        return c
      end
    end
    return nil
  end

  local command = pick_command()
  if not command then
    done(false)
    return
  end

  local arg_variants = {
    { class_name },
    { { className = class_name } },
  }

  local function try_variant(j)
    if j > #arg_variants then
      done(false)
      return
    end
    client.request(
      "workspace/executeCommand",
      { command = command, arguments = arg_variants[j] },
      function(err, result)
        vim.schedule(function()
          if not err and result then
            local loc = normalize_loc(result) or (type(result) == "table" and normalize_loc(result[1]) or nil)
            if apply_resolved_location(loc, ud, titem) then
              if loc then
                M._cache[class_name] = loc
              end
              done(true)
              return
            end
          end
          try_variant(j + 1)
        end)
      end
    )
  end

  try_variant(1)
end

function M.resolve_location(titem, done)
  done = done or function() end
  local qf = titem and titem.item or nil
  local ud = qf and qf.user_data or nil
  if not (ud and type(ud) == "table" and ud.stacktrace_frame) then
    done(false)
    return
  end

  local client = pick_jdtls_client()
  if not client then
    done(false)
    return
  end

  local class_name = ud.class_name
  if type(class_name) ~= "string" or class_name == "" then
    done(false)
    return
  end
  class_name = class_name:gsub("%$.*$", "")
  local simple = class_name:match("([^.]+)$") or class_name
  if simple == "" then
    done(false)
    return
  end

  local cached = M._cache[class_name]
  if cached then
    if apply_resolved_location(cached, ud, titem) then
      done(true)
      return
    end
    M._cache[class_name] = nil
  end

  local expected_path = class_name:gsub("%.", "/") .. ".java"

  local function on_opened(loc)
    if apply_resolved_location(loc, ud, titem) then
      local normalized = normalize_loc(loc)
      if normalized then
        M._cache[class_name] = normalized
      end
      done(true)
    else
      done(false)
    end
  end

  local function pick_best_symbol(result)
    if type(result) ~= "table" then
      return nil
    end
    local best = nil
    for _, sym in ipairs(result) do
      local loc = normalize_loc(sym and sym.location or nil)
      local uri = loc and loc.uri or nil
      if uri then
        local score = 0
        if uri:find(expected_path, 1, true) then
          score = score + 300
        elseif uri:sub(-(#simple + 5)) == (simple .. ".java") then
          score = score + 200
        elseif uri:find(simple .. ".java", 1, true) then
          score = score + 150
        elseif uri:sub(-(#simple + 6)) == (simple .. ".class") then
          score = score + 100
        elseif uri:find(simple .. ".class", 1, true) then
          score = score + 80
        else
          score = score + 10
        end
        if score > 0 and (not best or score > best.score) then
          best = { score = score, loc = loc }
        end
      end
    end
    return best and best.loc or nil
  end

  local queries = { class_name }
  if simple ~= class_name then
    table.insert(queries, simple)
  end

  local function try_query(i)
    if i > #queries then
      open_type_via_execute_command(client, class_name, ud, titem, function(ok)
        done(ok)
      end)
      return
    end
    client.request("workspace/symbol", { query = queries[i] }, function(err, result)
      vim.schedule(function()
        if err then
          try_query(i + 1)
          return
        end
        local loc = pick_best_symbol(result)
        if not loc then
          try_query(i + 1)
          return
        end
        on_opened(loc)
      end)
    end)
  end

  try_query(1)
end

return M
