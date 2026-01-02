local M = {}

---@class integrations.overseer.stacktrace.UserData
---@field stacktrace_src_lnum integer
---@field stacktrace_frame? boolean
---@field stacktrace_resolved? boolean
---@field stacktrace_caused_by? boolean
---@field stacktrace_suppressed? boolean
---@field stacktrace_ellipsis? boolean
---@field class_name? string
---@field method? string
---@field location? string
---@field file_name? string
---@field lnum? integer

---@class integrations.overseer.stacktrace.Entry
---@field nr integer
---@field type "E"
---@field module string Group label for Trouble (one exception block).
---@field text string
---@field user_data? integrations.overseer.stacktrace.UserData

local function trim(s)
  return (type(s) == "string") and vim.trim(s) or ""
end

---@param lines? string[]
---@return integrations.overseer.stacktrace.Entry[]
function M.parse(lines)
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
    local trimmed = trim(line)

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
            text = line,
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
            text = line,
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

---@param line string?
function M.looks_like_stacktrace_line(line)
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
  local trimmed = trim(line)
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

return M
