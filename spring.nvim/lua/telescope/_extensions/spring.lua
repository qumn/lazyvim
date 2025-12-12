local telescope = require("telescope")
local endpoints = require("spring.endpoints.telescope")

return telescope.register_extension({
  exports = {
    endpoints = endpoints.endpoints_picker,
  },
})
