local M = {}

local module_index_cache = {}

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
  if lv and lv.root then
    local ok, root = pcall(function()
      return (type(lv.root.get) == "function" and lv.root.get({ normalize = true })) or (type(lv.root) == "function" and lv.root())
    end)
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

function M.resolve_items_in_place(items, cwd)
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

return M

