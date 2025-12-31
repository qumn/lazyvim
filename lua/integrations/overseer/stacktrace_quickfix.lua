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
        item.bufnr = nil
        item.lnum = ud.lnum
        item.col = 1
        item.valid = 1
      end
    end
  end
end

local function parse_stacktrace_structure(lines, src_bufnr)
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
    ud.stacktrace_buf_lnum = lnum
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
            valid = 1,
            bufnr = src_bufnr,
            lnum = idx,
            col = 1,
            module = group_label,
            type = "E",
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
            valid = 1,
            bufnr = src_bufnr,
            lnum = idx,
            col = 1,
            module = group_label,
            type = "E",
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
            valid = 1,
            bufnr = src_bufnr,
            lnum = idx,
            col = 1,
            module = group_label,
            type = "E",
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
      local ud = { stacktrace_frame = true, class_name = class_name, location = location }
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
          valid = 1,
          bufnr = src_bufnr,
          lnum = idx,
          col = 1,
          module = group_label,
          type = "E",
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

local function move_to_next_caused_by(view, direction)
  if not view or not (view.win and view.win.win and vim.api.nvim_win_is_valid(view.win.win)) then
    return
  end
  local bufnr = view.win.buf
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(view.win.win)
  local start = cursor[1]
  local last = vim.api.nvim_buf_line_count(bufnr)

  local function is_caused_by_row(row)
    local info = view.renderer:at(row)
    local item = info and info.item or nil
    local qf = item and item.item or nil
    local ud = qf and qf.user_data or nil
    return info and info.first_line and ud and type(ud) == "table" and ud.stacktrace_caused_by == true
  end

  local function scan(from, to, step)
    for row = from, to, step do
      if is_caused_by_row(row) then
        vim.api.nvim_win_set_cursor(view.win.win, { row, 0 })
        return true
      end
    end
    return false
  end

  if direction > 0 then
    if scan(start + 1, last, 1) then
      return
    end
    scan(1, start - 1, 1)
  else
    if scan(start - 1, 1, -1) then
      return
    end
    scan(last, start + 1, -1)
  end
end

local function ensure_trouble_caused_by_keymaps(view)
  if not view or not view.win or not view.win.buf then
    return
  end
  local bufnr = view.win.buf
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  if vim.b[bufnr].stacktrace_caused_by_maps then
    return
  end
  vim.b[bufnr].stacktrace_caused_by_maps = true

  local function get_main_win()
    if type(view.main) == "function" then
      local ok, main = pcall(view.main, view)
      local win = ok and main and main.win or 0
      if win and vim.api.nvim_win_is_valid(win) then
        return win
      end
    end
    return vim.api.nvim_get_current_win()
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

  local function show_location(client, loc)
    if not (client and loc) then
      return false
    end
    local enc = client.offset_encoding or "utf-16"
    local show_document = vim.lsp.util.show_document
    if type(show_document) == "function" then
      show_document(loc, enc, { reuse_win = true, focus = true })
      return true
    end
    return false
  end

  local function jump_to_location_like(client, loc)
    if not client or not loc then
      return false
    end
    if loc.uri and loc.range then
      return show_location(client, loc)
    end
    if type(loc) == "table" and #loc > 0 then
      local first = loc[1]
      if first and first.uri and first.range then
        return show_location(client, first)
      end
    end
    return false
  end

  local function can_preview_item(qf)
    if not qf then
      return false
    end
    if qf.filename and qf.filename ~= "" then
      return true
    end
    local qf_bufnr = qf.bufnr
    if qf_bufnr and vim.api.nvim_buf_is_valid(qf_bufnr) and not vim.b[qf_bufnr].stacktrace_scratch then
      if not vim.api.nvim_buf_is_loaded(qf_bufnr) then
        local name = vim.api.nvim_buf_get_name(qf_bufnr)
        if name:match("^jdt://") ~= nil or name:match("^jar:") ~= nil or name:match("^zipfile:") ~= nil then
          return false
        end
        return true
      end
      local wanted = tonumber(qf.lnum) or 1
      local last = vim.api.nvim_buf_line_count(qf_bufnr)
      return last >= math.max(wanted, 1)
    end
    return false
  end

  local function close_preview_if_open()
    local okp, Preview = pcall(require, "trouble.view.preview")
    if okp and Preview and Preview.is_open and Preview.is_open() then
      Preview.close()
      return true
    end
    return false
  end

  local function preview_item_in_main(titem)
    if not (titem and view and view.preview) then
      return
    end
    view:preview(titem)
  end

  local function jump_item(titem)
    if not (titem and view and view.jump) then
      return
    end
    local qf = titem and titem.item or nil
    local filename = qf and qf.filename or nil
    if type(filename) == "string" and filename ~= "" and vim.fn.filereadable(filename) == 1 then
      local win = get_main_win()
      if win and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_call(win, function()
          safe_cmd("normal! m'")
        end)
        vim.api.nvim_set_current_win(win)
      end

      safe_cmd("silent! keepalt keepjumps edit " .. vim.fn.fnameescape(filename))

      local pos = titem.pos or { qf and qf.lnum or 1, 0 }
      local lnum = tonumber(pos[1]) or 1
      local col = tonumber(pos[2]) or 0
      local last = vim.api.nvim_buf_line_count(0)
      lnum = math.min(math.max(lnum, 1), math.max(last, 1))
      pcall(vim.api.nvim_win_set_cursor, 0, { lnum, col })
      safe_cmd("norm! zzzv")
      return
    end

    pcall(view.jump, view, titem)
  end

  local function run_view_action(action, titem)
    if action == "preview" then
      if view.preview then
        close_preview_if_open()
        preview_item_in_main(titem)
        if view.win and view.win.focus then
          view.win:focus()
        end
      end
      return
    end
    if action == "jump" then
      if view.jump then
        jump_item(titem)
      end
    end
  end

  local function set_preview_for_current_item()
    if not (view and view.win and view.win.win and vim.api.nvim_win_is_valid(view.win.win)) then
      return
    end
    local at = (view.at and view:at()) or {}
    local item = at and at.item or nil
    local qf = item and item.item or nil
    if item and can_preview_item(qf) and view.preview then
      preview_item_in_main(item)
      return
    end
    close_preview_if_open()
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

  local function update_qf_item_after_open(qf, target_buf, target_lnum)
    if not qf then
      return
    end
    if not (target_buf and vim.api.nvim_buf_is_valid(target_buf)) then
      return
    end
    local list = vim.fn.getqflist({ all = true })
    local items = list and list.items or nil
    if type(items) ~= "table" then
      return
    end

    local ud = qf.user_data
    local wanted_class = ud and ud.class_name or nil
    local wanted_loc = ud and ud.location or nil

    local found = false
    for i, it in ipairs(items) do
      local iud = it.user_data
      local same_nr = (type(qf.nr) == "number" and type(it.nr) == "number" and it.nr == qf.nr)
      local same_ud = type(iud) == "table"
        and iud.stacktrace_frame == true
        and iud.class_name == wanted_class
        and iud.location == wanted_loc
      if same_nr or same_ud then
        items[i].bufnr = target_buf
        items[i].filename = nil
        items[i].lnum = target_lnum or 1
        items[i].col = 1
        items[i].valid = 1
        found = true
        break
      end
    end

    if found then
      vim.fn.setqflist({}, "r", { title = list.title, items = items })
      if view.refresh then
        view:refresh()
      end
    end
  end

  local function update_trouble_item_after_open(titem, target_buf, target_lnum)
    if not titem then
      return
    end
    if not (target_buf and vim.api.nvim_buf_is_valid(target_buf)) then
      return
    end
    titem.buf = target_buf
    titem.pos = { target_lnum or 1, 0 }
    titem.end_pos = { target_lnum or 1, 0 }
  end

  local function try_open_type_via_execute_command(client, qf, class_name, win, done)
    done = done or function() end
    if not client or not class_name or class_name == "" then
      done(false)
      return
    end
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_set_current_win(win)
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
              if win and vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_set_current_win(win)
              end
              if jump_to_location_like(client, result) then
                local target_buf = vim.api.nvim_get_current_buf()
                local ud = qf and qf.user_data or {}
                local target_lnum = move_cursor_to_stacktrace_pos(win, ud.lnum, ud.method)
                update_qf_item_after_open(qf, target_buf, target_lnum)
                done(true, target_buf, target_lnum)
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

  local function current_view_item()
    local at = (view.at and view:at()) or {}
    local item = at and at.item or nil
    return item, item and item.item or nil
  end

  local function open_stacktrace_frame_via_lsp(client, qf, titem, win, action)
    local ud = qf and qf.user_data or nil
    if not client or not ud or type(ud) ~= "table" then
      return false
    end
    local class_name = ud.class_name
    if type(class_name) ~= "string" or class_name == "" then
      return false
    end
    class_name = class_name:gsub("%$.*$", "")
    local exec_started = false
    local simple = class_name:match("([^.]+)$") or class_name
    if simple == "" then
      return false
    end

    local expected_path = class_name:gsub("%.", "/") .. ".java"

    local function on_opened(loc)
      if win and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_set_current_win(win)
      end
      show_location(client, loc)
      local target_buf = vim.api.nvim_get_current_buf()
      local target_lnum = move_cursor_to_stacktrace_pos(win, ud.lnum, ud.method)
      update_qf_item_after_open(qf, target_buf, target_lnum)
      update_trouble_item_after_open(titem, target_buf, target_lnum)
      run_view_action(action, titem)
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
        if not exec_started then
          exec_started = true
          try_open_type_via_execute_command(client, qf, class_name, win, function(ok2, target_buf, target_lnum)
            if ok2 then
              update_trouble_item_after_open(titem, target_buf, target_lnum)
              run_view_action(action, titem)
            end
          end)
        end
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

    return true
  end

  local function resolve_unresolved_frame(titem, qf, action)
    local ud = qf and qf.user_data or nil
    if not (ud and type(ud) == "table" and ud.stacktrace_frame) then
      return false
    end
    if can_preview_item(qf) then
      return false
    end
    local client = pick_jdtls_client()
    if not client then
      return false
    end
    local win = get_main_win()
    return open_stacktrace_frame_via_lsp(client, qf, titem, win, action)
  end

  vim.keymap.set("n", "]c", function()
    move_to_next_caused_by(view, 1)
  end, { buffer = bufnr, silent = true, desc = "Next caused by" })
  vim.keymap.set("n", "[c", function()
    move_to_next_caused_by(view, -1)
  end, { buffer = bufnr, silent = true, desc = "Prev caused by" })

  if not vim.b[bufnr].stacktrace_preview_autocmd then
    vim.b[bufnr].stacktrace_preview_autocmd = true
    vim.b[bufnr].stacktrace_auto_preview = true
    vim.api.nvim_create_autocmd("CursorMoved", {
      buffer = bufnr,
      callback = function()
        if vim.b[bufnr].stacktrace_auto_preview == true then
          set_preview_for_current_item()
        end
      end,
    })
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        if vim.b[bufnr].stacktrace_auto_preview == true then
          set_preview_for_current_item()
        end
      end
    end)
  end

  pcall(vim.keymap.del, "n", "P", { buffer = bufnr })
  vim.keymap.set("n", "P", function()
    vim.b[bufnr].stacktrace_auto_preview = not (vim.b[bufnr].stacktrace_auto_preview == true)
    if vim.b[bufnr].stacktrace_auto_preview ~= true then
      close_preview_if_open()
    else
      set_preview_for_current_item()
    end
  end, { buffer = bufnr, silent = true, nowait = true, desc = "Toggle stacktrace auto preview" })

  pcall(vim.keymap.del, "n", "p", { buffer = bufnr })
  vim.keymap.set("n", "p", function()
    local item, qf = current_view_item()
    if not item then
      return
    end
    if close_preview_if_open() then
      return
    end
    if resolve_unresolved_frame(item, qf, "preview") then
      return
    end
    if view.preview then
      preview_item_in_main(item)
    end
  end, { buffer = bufnr, silent = true, nowait = true, desc = "Preview stacktrace item" })

  pcall(vim.keymap.del, "n", "<CR>", { buffer = bufnr })
  vim.keymap.set("n", "<CR>", function()
    local item, qf = current_view_item()
    if not item then
      return
    end
    if resolve_unresolved_frame(item, qf, "jump") then
      return
    end
    if can_preview_item(qf) and view.jump then
      jump_item(item)
    end
  end, { buffer = bufnr, silent = true, nowait = true, desc = "Open stacktrace item" })
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
    local info = view.renderer:at(row)
    local item = info and info.first_line and info.item or nil
    local qf = item and item.item or nil
    local ud = qf and qf.user_data or nil
    local stack_lnum = ud and type(ud) == "table" and ud.stacktrace_buf_lnum or nil
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

local function open_trouble_quickfix(opts)
  opts = opts or {}
  local ok, trouble = pcall(require, "trouble")
  if ok then
    local view = trouble.open({
      mode = "quickfix",
      focus = true,
      follow = false,
      auto_preview = false,
      preview = { type = "main", scratch = true },
      formatters = {
        stacktrace_text = function(ctx)
          local qf = ctx and ctx.item and ctx.item.item or nil
          local text = qf and qf.text or (ctx and ctx.item and ctx.item.text) or ""
          local ud = qf and qf.user_data or nil
          text = text:gsub("^\t", "")

          local resolved = false
          if qf and qf.filename and qf.filename ~= "" then
            resolved = true
          elseif qf and qf.bufnr and vim.api.nvim_buf_is_valid(qf.bufnr) and not vim.b[qf.bufnr].stacktrace_scratch then
            resolved = true
          end

          if resolved and type(ud) == "table" and ud.stacktrace_frame then
            if text:match("^%s*at%s+") then
              local lnum = type(ud.lnum) == "number" and ud.lnum or nil
              text = text:gsub("%s*%b()%s*$", "")
              if lnum then
                text = text .. ":" .. tostring(lnum)
              end
            end
          end

          local hl = "TroubleStacktraceUnresolved"
          if type(ud) == "table" and ud.stacktrace_caused_by == true then
            hl = "TroubleStacktraceCausedBy"
          elseif type(ud) == "table" and ud.stacktrace_suppressed == true then
            hl = "TroubleStacktraceSuppressed"
          elseif text:match("^%s*Suppressed:") then
            hl = "TroubleStacktraceSuppressed"
          elseif text:match("^%s*%.%.%.%s+%d+%s+more%s*$") then
            hl = "TroubleStacktraceEllipsis"
          elseif type(ud) == "table" and ud.stacktrace_frame == true then
            hl = resolved and "TroubleStacktraceFrameResolved" or "TroubleStacktraceFrameUnresolved"
          elseif text:match("^%s*Caused by:") then
            hl = "TroubleStacktraceCausedBy"
          end
          return { text = text, hl = hl }
        end,
      },
      format = "{severity_icon|item.type:DiagnosticSignWarn} {stacktrace_text}",
      sorters = {
        stacktrace_order = function(obj)
          local it = obj and obj.item or nil
          return it and it.nr or math.huge
        end,
      },
      sort = { "stacktrace_order" },
      groups = {
        { "item.module", format = "{item.module} {count}" },
      },
    })
    vim.api.nvim_set_hl(0, "TroubleStacktraceFrameResolved", { link = "DiagnosticInfo", default = true })
    vim.api.nvim_set_hl(0, "TroubleStacktraceFrameUnresolved", { link = "TroubleSource", default = true })
    vim.api.nvim_set_hl(0, "TroubleStacktraceCausedBy", { link = "DiagnosticWarn", default = true })
    vim.api.nvim_set_hl(0, "TroubleStacktraceSuppressed", { link = "DiagnosticHint", default = true })
    vim.api.nvim_set_hl(0, "TroubleStacktraceEllipsis", { link = "Comment", default = true })
    vim.api.nvim_set_hl(0, "TroubleStacktraceUnresolved", { link = "TroubleSource", default = true })
    if view and view.wait then
      view:wait(function()
        ensure_trouble_caused_by_keymaps(view)
        if opts.cursor_lnum and opts.cursor_line and looks_like_stacktrace_line(opts.cursor_line) then
          focus_trouble_on_stacktrace_lnum(view, opts.cursor_lnum)
        end
      end)
    end
    return
  end
  safe_cmd("copen")
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

local function ensure_stacktrace_buf(src_bufnr, ns)
  if not src_bufnr or not vim.api.nvim_buf_is_valid(src_bufnr) then
    return nil
  end
  vim.b[src_bufnr] = vim.b[src_bufnr] or {}
  local key = bkey(ns, "stacktrace_buf")
  local existing = vim.b[src_bufnr][key]
  if existing and vim.api.nvim_buf_is_valid(existing) then
    return existing
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].filetype = "log"
  vim.bo[buf].modifiable = false
  vim.b[buf].stacktrace_scratch = true
  vim.b[src_bufnr][key] = buf
  return buf
end

local function set_stacktrace_buf_lines(bufnr, lines)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines or {})
  vim.bo[bufnr].modifiable = false
end

function M.build_quickfix(opts)
  opts = opts or {}
  local bufnr = opts.bufnr
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return 0
  end

  local ns = opts.namespace or "stacktrace"
  local cwd = opts.cwd or vim.fn.getcwd()
  local title = opts.title or "stacktrace"

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local stacktrace_buf = ensure_stacktrace_buf(bufnr, ns)
  if not stacktrace_buf then
    return 0
  end
  set_stacktrace_buf_lines(stacktrace_buf, lines)

  local items = parse_stacktrace_structure(lines, stacktrace_buf)
  if #items == 0 then
    return 0
  end

  resolve_items_in_place(items, cwd)

  local prev_nr = vim.fn.getqflist({ nr = 0 }).nr
  vim.fn.setqflist({}, " ", { title = title, items = items })
  local info = vim.fn.getqflist({ nr = 0, id = 0 })
  vim.b[bufnr][bkey(ns, "qf_nr")] = info.nr
  vim.b[bufnr][bkey(ns, "qf_id")] = info.id
  vim.b[bufnr][bkey(ns, "qf_last_line_count")] = vim.api.nvim_buf_line_count(bufnr)
  vim.b[bufnr][bkey(ns, "qf_changedtick")] = vim.api.nvim_buf_get_changedtick(bufnr)
  if prev_nr and prev_nr ~= info.nr then
    safe_cmd(tostring(prev_nr) .. "chistory")
  end

  return #items
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
  local stacktrace_buf = ensure_stacktrace_buf(bufnr, ns)
  if
    vim.b[bufnr][bkey(ns, "qf_nr")]
    and vim.b[bufnr][bkey(ns, "qf_last_line_count")] == line_count
    and vim.b[bufnr][bkey(ns, "qf_changedtick")] == changedtick
    and stacktrace_buf
  then
    local qf_nr = vim.b[bufnr][bkey(ns, "qf_nr")]
    if qf_nr then
      if opts.close_overseer ~= false then
        safe_cmd("silent! OverseerClose")
      end
      if opts.hide_output_window ~= false then
        hide_output_window(bufnr)
      end
      safe_cmd(tostring(qf_nr) .. "chistory")
      open_trouble_quickfix({ cursor_lnum = cursor_lnum, cursor_line = cursor_line })
      return 1
    end
  end

  local built = M.build_quickfix(opts)
  if not built or built == 0 then
    return 0
  end

  local qf_nr = vim.b[bufnr][bkey(ns, "qf_nr")]
  if not qf_nr then
    return 0
  end

  if opts.close_overseer ~= false then
    safe_cmd("silent! OverseerClose")
  end
  if opts.hide_output_window ~= false then
    hide_output_window(bufnr)
  end

  safe_cmd(tostring(qf_nr) .. "chistory")
  open_trouble_quickfix({ cursor_lnum = cursor_lnum, cursor_line = cursor_line })
  return built
end

return M
