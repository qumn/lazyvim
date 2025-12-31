local M = {}

local module_index_cache = {}

local function safe_cmd(cmd)
  if type(cmd) ~= "string" or cmd == "" then
    return
  end
  pcall(function()
    vim.cmd(cmd)
  end)
end

local function read_file(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or type(lines) ~= "table" then
    return nil
  end
  return table.concat(lines, "\n")
end

local function strip_comments(text)
  if type(text) ~= "string" then
    return ""
  end
  text = text:gsub("/%*.-%*/", "")
  text = text:gsub("//[^\n]*", "")
  return text
end

local function path_exists(path)
  local uv = vim.uv or vim.loop
  return uv and uv.fs_stat(path) ~= nil
end

local function get_repo_root(cwd)
  local lv = rawget(_G, "LazyVim")
  if lv and lv.root and type(lv.root.get) == "function" then
    local ok, root = pcall(lv.root.get, { normalize = true })
    if ok and type(root) == "string" and root ~= "" then
      return root
    end
  end
  return (cwd and cwd ~= "") and cwd or vim.fn.getcwd()
end

local function normalize_module_path(m)
  if not m or m == "" then
    return nil
  end
  if m:sub(1, 1) == ":" then
    m = m:sub(2)
  end
  m = m:gsub(":", "/")
  return m
end

local function parse_maven_modules(repo_root)
  local pom = vim.fs.joinpath(repo_root, "pom.xml")
  local content = read_file(pom)
  if not content then
    return nil
  end

  local modules = {}
  for m in content:gmatch("<module>%s*([^<]+)%s*</module>") do
    m = vim.trim(m)
    if m ~= "" then
      table.insert(modules, m)
    end
  end
  return modules
end

local function parse_gradle_settings(repo_root)
  local settings = vim.fs.joinpath(repo_root, "settings.gradle")
  local settings_kts = vim.fs.joinpath(repo_root, "settings.gradle.kts")
  local path = settings
  local content = read_file(path)
  if not content then
    path = settings_kts
    content = read_file(path)
  end
  if not content then
    return nil
  end

  content = strip_comments(content)

  local project_dir_map = {}
  for proj, dir in
    content:gmatch(
      "project%s*%(%s*['\"](:[^'\"]+)['\"]%s*%)%s*%.%s*projectDir%s*=%s*file%s*%(%s*['\"]([^'\"]+)['\"]%s*%)"
    )
  do
    project_dir_map[proj] = dir
  end

  local modules = {}
  for args in content:gmatch("include%s*(%b())") do
    for m in args:gmatch("[\"']([^\"']+)[\"']") do
      if not m:find("includeBuild", 1, true) then
        table.insert(modules, m)
      end
    end
  end
  for line in content:gmatch("[^\n]+") do
    if line:match("^%s*include%s+") and not line:find("includeBuild", 1, true) then
      for m in line:gmatch("[\"']([^\"']+)[\"']") do
        table.insert(modules, m)
      end
    end
  end

  return { modules = modules, project_dir_map = project_dir_map }
end

local function build_source_roots(repo_root)
  local gradle = parse_gradle_settings(repo_root)
  local maven_modules = nil
  if not gradle then
    maven_modules = parse_maven_modules(repo_root)
  end

  local module_roots = { repo_root }

  if gradle then
    local seen = {}
    for _, raw in ipairs(gradle.modules or {}) do
      local key = raw
      if raw:sub(1, 1) ~= ":" then
        key = ":" .. raw
      end
      local dir = gradle.project_dir_map and gradle.project_dir_map[key] or nil
      local rel = dir or normalize_module_path(raw)
      if rel and rel ~= "" then
        local abs = vim.fs.joinpath(repo_root, rel)
        abs = vim.fs.normalize(abs)
        if not seen[abs] then
          seen[abs] = true
          table.insert(module_roots, abs)
        end
      end
    end
  elseif maven_modules and #maven_modules > 0 then
    local seen = {}
    for _, rel in ipairs(maven_modules) do
      local abs = vim.fs.joinpath(repo_root, rel)
      abs = vim.fs.normalize(abs)
      if not seen[abs] then
        seen[abs] = true
        table.insert(module_roots, abs)
      end
    end
  end

  local source_roots = {}
  local seen_src = {}
  for _, mr in ipairs(module_roots) do
    local main_java = vim.fs.joinpath(mr, "src", "main", "java")
    if not seen_src[main_java] and path_exists(main_java) then
      seen_src[main_java] = true
      table.insert(source_roots, main_java)
    end
    local test_java = vim.fs.joinpath(mr, "src", "test", "java")
    if not seen_src[test_java] and path_exists(test_java) then
      seen_src[test_java] = true
      table.insert(source_roots, test_java)
    end
  end

  return source_roots
end

local function get_module_index(repo_root)
  local cached = module_index_cache[repo_root]
  if cached then
    return cached
  end
  local index = {
    repo_root = repo_root,
    source_roots = build_source_roots(repo_root),
    resolve_cache = {},
  }
  module_index_cache[repo_root] = index
  return index
end

local function expected_java_suffix(class_name, file_name)
  local pkg = class_name and class_name:match("^(.*)%.[^.]+$") or nil
  if pkg and pkg ~= "" then
    return pkg:gsub("%.", "/") .. "/" .. file_name
  end
  return file_name
end

local function resolve_workspace_java_file(index, class_name, file_name)
  if not index or type(index) ~= "table" then
    return nil
  end
  if type(file_name) ~= "string" or file_name == "" then
    return nil
  end

  local suffix = expected_java_suffix(class_name, file_name)
  local cached = index.resolve_cache[suffix]
  if cached ~= nil then
    return cached == false and nil or cached
  end

  for _, sr in ipairs(index.source_roots or {}) do
    local candidate = vim.fs.joinpath(sr, suffix)
    if path_exists(candidate) then
      index.resolve_cache[suffix] = candidate
      return candidate
    end
  end

  index.resolve_cache[suffix] = false
  return nil
end

local function resolve_items_in_place(items, cwd)
  local repo_root = get_repo_root(cwd)
  local index = get_module_index(repo_root)

  for _, item in ipairs(items or {}) do
    local ud = item and item.user_data or nil
    if ud and type(ud) == "table" and ud.stacktrace_frame and ud.file_name and ud.lnum then
      local resolved = resolve_workspace_java_file(index, ud.class_name, ud.file_name)
      if resolved then
        item.filename = resolved
        ud.stacktrace_resolved = true
      end
    end
  end
end

local function parse_stacktrace_structure(lines)
  local items = {}
  local seq = 0
  local group_idx = 0
  local group_label
  local seen_frame = false
  local in_block = false

  local function push(item)
    seq = seq + 1
    item.nr = seq
    return item
  end

  local function stack_ud(ud, lnum)
    ud = (type(ud) == "table") and ud or {}
    ud.stacktrace_src_lnum = lnum
    return ud
  end

  for idx, line in ipairs(lines or {}) do
    local is_frame = line:match("^%s*at%s+") ~= nil
    local is_caused_by = line:match("^%s*Caused by:") ~= nil
    local is_suppressed = line:match("^%s*Suppressed:") ~= nil
    local is_ellipsis = line:match("^%s*%.%.%.%s+%d+%s+more%s*$") ~= nil
    local trimmed = vim.trim(line)

    local looks_like_exception = not is_frame
      and not is_caused_by
      and (
        line:match("^%s*Exception in thread") ~= nil
        or trimmed:match("^[%w%.$_]+Exception[:%s]") ~= nil
        or trimmed:match("^[%w%.$_]+Error[:%s]") ~= nil
        or trimmed:match("^[%w%.$_]+Throwable[:%s]") ~= nil
      )

    if looks_like_exception then
      if group_label == nil or seen_frame then
        group_idx = group_idx + 1
      end
      local max_len = 140
      if #trimmed > max_len then
        trimmed = trimmed:sub(1, max_len - 1) .. "…"
      end
      group_label = string.format("%d: %s", group_idx, trimmed)
      seen_frame = false
      in_block = true
    elseif is_caused_by then
      if group_label then
        in_block = true
        seen_frame = false
        table.insert(
          items,
          push({
            type = "E",
            module = group_label,
            text = vim.trim(line),
            user_data = stack_ud({ stacktrace_caused_by = true }, idx),
          })
        )
      end
    elseif is_ellipsis then
      if group_label then
        table.insert(
          items,
          push({
            type = "E",
            module = group_label,
            text = vim.trim(line),
            user_data = stack_ud({ stacktrace_ellipsis = true }, idx),
          })
        )
      end
    end

    if
      group_label
      and in_block
      and trimmed ~= ""
      and not looks_like_exception
      and not is_caused_by
      and not is_ellipsis
    then
      local is_indented = line:match("^%s+") ~= nil
      local treat_as_continuation = (not seen_frame) or is_indented or is_frame or is_suppressed
      if treat_as_continuation and not is_frame then
        local ud = nil
        if is_suppressed then
          ud = { stacktrace_suppressed = true }
        end
        table.insert(
          items,
          push({
            type = "E",
            module = group_label,
            text = line,
            user_data = stack_ud(ud, idx),
          })
        )
      end
      if seen_frame and not treat_as_continuation and not is_frame then
        in_block = false
      end
    end

    local fqn, location = line:match("^%s*at%s+([%w%.$_]+)%(([^)]+)%)")
    if fqn and location and group_label then
      local class_name = fqn:match("^(.+)%.([^.]+)$")
      local method = fqn:match("%.([^.]+)$")
      local file_name, lnum = location:match("^([^:]+):(%d+)$")
      local ud = { stacktrace_frame = true, stacktrace_resolved = false, class_name = class_name, location = location }
      if method and method ~= "" then
        ud.method = method
      end
      if file_name and lnum then
        ud.file_name = file_name
        ud.lnum = tonumber(lnum)
      end
      table.insert(
        items,
        push({
          type = "E",
          module = group_label,
          text = line,
          user_data = stack_ud(ud, idx),
        })
      )
      seen_frame = true
      in_block = true
    end
  end

  return items
end

local function looks_like_stacktrace_line(line)
  if type(line) ~= "string" then
    return false
  end
  if line:match("^%s*at%s+") then
    return true
  end
  if line:match("^%s*Caused by:") then
    return true
  end
  if line:match("^%s*Suppressed:") then
    return true
  end
  if line:match("^%s*%.%.%.%s+%d+%s+more%s*$") then
    return true
  end
  local trimmed = vim.trim(line)
  if trimmed:match("^Exception in thread") then
    return true
  end
  if trimmed:match("^[%w%.$_]+Exception[:%s]") then
    return true
  end
  if trimmed:match("^[%w%.$_]+Error[:%s]") then
    return true
  end
  if trimmed:match("^[%w%.$_]+Throwable[:%s]") then
    return true
  end
  return false
end

local function focus_trouble_on_stacktrace_lnum(view, cursor_lnum)
  if not (view and view.win and view.win.win and vim.api.nvim_win_is_valid(view.win.win)) then
    return
  end
  local bufnr = view.win.buf
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  if type(cursor_lnum) ~= "number" or cursor_lnum < 1 then
    return
  end

  local last = vim.api.nvim_buf_line_count(bufnr)
  local best_row = nil
  local best_diff = math.huge
  local best_side = 1

  for row = 1, last do
    local info = view.renderer and view.renderer:at(row) or nil
    local item = info and info.first_line and info.item or nil
    local qf = item and item.item or nil
    local ud = qf and qf.user_data or nil
    local stack_lnum = ud and type(ud) == "table" and ud.stacktrace_src_lnum or nil
    if stack_lnum then
      local diff = math.abs(stack_lnum - cursor_lnum)
      local side = (stack_lnum >= cursor_lnum) and 0 or 1
      if diff < best_diff or (diff == best_diff and side < best_side) then
        best_diff = diff
        best_side = side
        best_row = row
      end
    end
  end

  if best_row then
    pcall(vim.api.nvim_win_set_cursor, view.win.win, { best_row, 0 })
  end
end

local function hide_output_window(bufnr)
  local win = vim.api.nvim_get_current_win()
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end
  if vim.api.nvim_win_get_buf(win) ~= bufnr then
    return
  end
  if #vim.api.nvim_list_wins() > 1 then
    pcall(vim.api.nvim_win_close, win, true)
    return
  end
  safe_cmd("silent! keepalt buffer #")
end

local function bkey(ns, suffix)
  return ns .. "_" .. suffix
end

local function pick_jdtls_client()
  local clients = vim.lsp.get_clients({ name = "jdtls" })
  for _, c in ipairs(clients) do
    if c and c.name == "jdtls" then
      return c
    end
  end
  return nil
end

local function move_cursor_to_stacktrace_pos(win, wanted_line, method)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
  end
  local buf = vim.api.nvim_get_current_buf()
  local last = vim.api.nvim_buf_line_count(buf)
  if type(wanted_line) == "number" and wanted_line > 0 and wanted_line <= last then
    vim.api.nvim_win_set_cursor(0, { wanted_line, 0 })
    return wanted_line
  end
  if type(method) == "string" and method ~= "" and method ~= "<init>" then
    local pat = "\\V" .. vim.fn.escape(method, "\\")
    local found = vim.fn.search(pat, "nw")
    if found and found > 0 then
      vim.api.nvim_win_set_cursor(0, { found, 0 })
      return found
    end
  end
  local cur = vim.api.nvim_win_get_cursor(0)
  return cur and cur[1] or 1
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

local function resolve_frame_via_lsp(view, titem, action, done)
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

  local expected_path = class_name:gsub("%.", "/") .. ".java"

  local function on_opened(loc)
    if apply_resolved_location(loc, ud, titem) then
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

local function to_trouble_items(entries, placeholder_filename)
  local ok_item, TroubleItem = pcall(require, "trouble.item")
  if not ok_item or not TroubleItem then
    return {}
  end
  local items = {}
  placeholder_filename = placeholder_filename or "[stacktrace]"

  for _, e in ipairs(entries or {}) do
    local ud = e and e.user_data or nil
    local filename = (e and e.filename) or placeholder_filename
    local pos = { 1, 0 }
    if ud and type(ud) == "table" and ud.stacktrace_frame == true and ud.stacktrace_resolved == true and type(ud.lnum) == "number" then
      pos = { ud.lnum, 0 }
    end
    table.insert(
      items,
      TroubleItem.new({
        source = "stacktrace",
        filename = filename,
        pos = pos,
        end_pos = pos,
        item = e,
      })
    )
  end
  return items
end

local function build_session(opts)
  opts = opts or {}
  local bufnr = opts.bufnr
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return 0, nil
  end

  local ns = opts.namespace or "stacktrace"
  local cwd = opts.cwd or vim.fn.getcwd()

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local entries = parse_stacktrace_structure(lines)
  if #entries == 0 then
    return 0, nil
  end

  resolve_items_in_place(entries, cwd)

  local id = string.format("%s:%d", ns, bufnr)
  local placeholder = string.format("[stacktrace-%s]", ns)
  local trouble_items = to_trouble_items(entries, placeholder)

  local ok_src, src = pcall(require, "trouble.sources.stacktrace")
  if not ok_src or not src then
    return 0, nil
  end

  src.set(id, trouble_items, {
    resolve_frame = function(view, item, action, done)
      resolve_frame_via_lsp(view, item, action, done)
    end,
  })

  vim.b[bufnr][bkey(ns, "session_id")] = id
  vim.b[bufnr][bkey(ns, "last_line_count")] = vim.api.nvim_buf_line_count(bufnr)
  vim.b[bufnr][bkey(ns, "changedtick")] = vim.api.nvim_buf_get_changedtick(bufnr)

  return #trouble_items, id
end

function M.build_quickfix(opts)
  local count = build_session(opts)
  return count or 0
end

function M.build_and_open(opts)
  opts = opts or {}
  local bufnr = opts.bufnr
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return 0
  end

  local ns = opts.namespace or "stacktrace"
  local cursor_lnum = opts.cursor_lnum
  local cursor_line = nil
  if type(cursor_lnum) == "number" and cursor_lnum >= 1 then
    cursor_line = vim.api.nvim_buf_get_lines(bufnr, cursor_lnum - 1, cursor_lnum, false)[1]
  end

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
  local session_id = vim.b[bufnr][bkey(ns, "session_id")]

  local ok_src, src = pcall(require, "trouble.sources.stacktrace")
  if ok_src and src and session_id and src.sessions and src.sessions[session_id] then
    if vim.b[bufnr][bkey(ns, "last_line_count")] == line_count and vim.b[bufnr][bkey(ns, "changedtick")] == changedtick then
      local ok_trouble, trouble = pcall(require, "trouble")
      if ok_trouble and trouble then
        if opts.close_overseer ~= false then
          safe_cmd("silent! OverseerClose")
        end
        if opts.hide_output_window ~= false then
          hide_output_window(bufnr)
        end
        local view = trouble.open({ mode = "stacktrace", focus = true, params = { id = session_id } })
        if view and view.wait then
          view:wait(function()
            if cursor_lnum and cursor_line and looks_like_stacktrace_line(cursor_line) then
              focus_trouble_on_stacktrace_lnum(view, cursor_lnum)
            end
          end)
        end
        return 1
      end
    end
  end

  local built, id = build_session(opts)
  if not built or built == 0 or not id then
    return 0
  end

  local ok_trouble, trouble = pcall(require, "trouble")
  if not ok_trouble or not trouble then
    return built
  end

  if opts.close_overseer ~= false then
    safe_cmd("silent! OverseerClose")
  end
  if opts.hide_output_window ~= false then
    hide_output_window(bufnr)
  end

  local view = trouble.open({ mode = "stacktrace", focus = true, params = { id = id } })
  if view and view.wait then
    view:wait(function()
      if cursor_lnum and cursor_line and looks_like_stacktrace_line(cursor_line) then
        focus_trouble_on_stacktrace_lnum(view, cursor_lnum)
      end
    end)
  end

  return built
end

return M
