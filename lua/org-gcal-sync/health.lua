-- lua/health.lua
local M = {}
local health = require('vim.health')
function M.check()
  health.start('OrgGcalSync')
  local gcalcli_exists = vim.fn.executable('gcalcli') == 1
  if gcalcli_exists then
    health.ok('gcalcli is installed and executable')
  else
    health.error(
      'gcalcli was not found in your path',
      {
	'OrgGcalSync requires gcalcli to function correctly.',
	'Please ensure it is installed and available in your system path'
      }
    )
  end
  -- local sync = require("org-gcal-sync")
  -- sync.checkhealth()
end

return M
