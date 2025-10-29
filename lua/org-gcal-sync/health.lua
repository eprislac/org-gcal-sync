-- lua/org-gcal-sync/health.lua
local M = {}
local health = require('vim.health')

function M.check()
  health.start('OrgGcalSync')
  
  -- Check environment variables
  local client_id = vim.env.GCAL_ORG_SYNC_CLIENT_ID
  local client_secret = vim.env.GCAL_ORG_SYNC_CLIENT_SECRET
  
  if client_id and client_id ~= "" then
    health.ok('GCAL_ORG_SYNC_CLIENT_ID is set')
  else
    health.error(
      'GCAL_ORG_SYNC_CLIENT_ID environment variable is not set',
      {
        'OrgGcalSync requires Google Calendar API credentials to function.',
        'Please set the GCAL_ORG_SYNC_CLIENT_ID environment variable.',
        'See README for instructions on obtaining credentials.'
      }
    )
  end
  
  if client_secret and client_secret ~= "" then
    health.ok('GCAL_ORG_SYNC_CLIENT_SECRET is set')
  else
    health.error(
      'GCAL_ORG_SYNC_CLIENT_SECRET environment variable is not set',
      {
        'OrgGcalSync requires Google Calendar API credentials to function.',
        'Please set the GCAL_ORG_SYNC_CLIENT_SECRET environment variable.',
        'See README for instructions on obtaining credentials.'
      }
    )
  end
  
  -- Check if Google Calendar API is reachable
  local ok, gcal_api = pcall(require, "org-gcal-sync.gcal_api")
  if ok then
    local reachable = gcal_api.check_api_reachable()
    if reachable then
      health.ok('Google Calendar API is reachable')
    else
      health.warn(
        'Google Calendar API is not reachable',
        {
          'Check your internet connection.',
          'The API may be temporarily unavailable.'
        }
      )
    end
  else
    health.error('Failed to load gcal_api module: ' .. tostring(gcal_api))
  end
  
  -- Check for plenary dependency
  local has_plenary = pcall(require, "plenary.curl")
  if has_plenary then
    health.ok('plenary.nvim is installed')
  else
    health.error(
      'plenary.nvim is not installed',
      {
        'OrgGcalSync requires plenary.nvim for HTTP requests.',
        'Install it via your package manager.'
      }
    )
  end
  
  local sync = require("org-gcal-sync")
  sync.checkhealth()
end

return M
