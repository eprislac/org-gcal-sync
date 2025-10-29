-- lua/health.lua
local M = {}

function M.check()
  local sync = require("org-gcal-sync")
  sync.checkhealth()
end

return M
