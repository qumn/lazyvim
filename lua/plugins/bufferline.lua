return {
  {
    "akinsho/bufferline.nvim",
    opts = function(_, opts)
      local jdt_uri = require("integrations.jdtls.uri")

      opts = opts or {}
      opts.options = opts.options or {}

      local prev = opts.options.name_formatter
      opts.options.name_formatter = function(buf)
        local label = jdt_uri.label(buf.path)
        if label then
          return label
        end
        if type(prev) == "function" then
          local ok, res = pcall(prev, buf)
          if ok and type(res) == "string" and res ~= "" then
            return res
          end
        end
      end

      return opts
    end,
  },
}
