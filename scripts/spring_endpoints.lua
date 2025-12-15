package.path = "./?/lua/?.lua;./?/lua/?/init.lua;" .. package.path

local core = require("spring.endpoints.core")

-- 从 stdin 读 rg 输出
local lines = {}
for line in io.lines() do
  table.insert(lines, line)
end

print("start parse")
local results = core.parse_rg_lines(lines)

for _, e in ipairs(results) do
  print(string.format("%s\t%d\t%s\t%s", e.file, e.lnum, e.http, e.path))
end
