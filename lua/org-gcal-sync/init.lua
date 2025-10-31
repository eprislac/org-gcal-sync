-- lua/org-gcal-sync/init.lua
local M = {}

M.config = {
  agenda_dir = nil,  -- Deprecated: now uses first org_roam_dir
  org_roam_dirs = {},
  enable_backlinks = true,
  auto_sync_on_save = true,
  calendars = { "primary" },
  sync_recurring_events = true,
  conflict_resolution = "newest",  -- "newest", "local", "remote", or "ask" (blocks sync)
  per_directory_calendars = {},
  webhook_port = nil,
  show_sync_status = false,
  background_sync_interval = 900000,  -- 15 minutes in milliseconds (0 to disable)
}

local _setup_done = false
local _sync_timer = nil

-- Auto-setup with defaults if not already setup
local function ensure_setup()
  if not _setup_done then
    M.setup()
  end
end

-- Default commands (will be overridden in setup)
M.sync = function()
  ensure_setup()
  if M._sync then M._sync() end
end
M.sync_background = function()
  ensure_setup()
  if M._sync_background then M._sync_background() end
end
M.export_single_file = function(filepath)
  ensure_setup()
  if M._export_single_file then M._export_single_file(filepath) end
end
M.import_gcal = function()
  ensure_setup()
  if M._import_gcal then M._import_gcal() end
end
M.export_org = function()
  ensure_setup()
  if M._export_org then M._export_org() end
end

function M.setup(opts)
  if _setup_done then return end
  _setup_done = true
  
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  
  -- Set default agenda_dir if not specified and no roam_dirs
  if not M.config.agenda_dir and #M.config.org_roam_dirs == 0 then
    M.config.agenda_dir = vim.fn.stdpath("data") .. "/org-gcal/agenda"
  end
  
  -- Create agenda_dir if it's still used
  if M.config.agenda_dir then
    vim.fn.mkdir(M.config.agenda_dir, "p")
  end

  -- Register commands
  vim.api.nvim_create_user_command("SyncOrgGcal", function() M.sync() end, { desc = "Sync org ↔ gcal (full)" })
  vim.api.nvim_create_user_command("SyncOrgGcalBackground", function() M.sync_background() end, { desc = "Background full sync" })
  vim.api.nvim_create_user_command("ImportGcal", function() M.import_gcal() end, { desc = "Import from gcal" })
  vim.api.nvim_create_user_command("ExportOrg", function() M.export_org() end, { desc = "Export to gcal" })
  vim.api.nvim_create_user_command("OrgGcalAuth", function()
    local gcal_api = require("org-gcal-sync.gcal_api")
    gcal_api.authenticate()
  end, { desc = "Authenticate with Google Calendar" })
  vim.api.nvim_create_user_command("OrgGcalDashboard", function()
    local dashboard = require("org-gcal-sync.dashboard")
    dashboard.show()
  end, { desc = "Show sync dashboard" })
  vim.api.nvim_create_user_command("OrgGcalWebhookStart", function()
    local webhook = require("org-gcal-sync.webhook")
    webhook.start(M.config.webhook_port and { port = M.config.webhook_port } or nil)
  end, { desc = "Start webhook server" })
  vim.api.nvim_create_user_command("OrgGcalWebhookStop", function()
    local webhook = require("org-gcal-sync.webhook")
    webhook.stop()
  end, { desc = "Stop webhook server" })
  vim.api.nvim_create_user_command("OrgGcalListCalendars", function()
    local gcal_api = require("org-gcal-sync.gcal_api")
    local calendars, err = gcal_api.list_calendars()
    if not calendars then
      vim.notify("Failed to list calendars: " .. (err or "unknown"), vim.log.levels.ERROR)
      return
    end
    
    local lines = { "Available Calendars:", "" }
    for _, cal in ipairs(calendars) do
      table.insert(lines, string.format("  %s: %s", cal.id, cal.summary))
    end
    
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
    vim.api.nvim_open_win(bufnr, true, {
      relative = 'editor',
      width = 60,
      height = math.min(#lines + 2, 20),
      col = (vim.o.columns - 60) / 2,
      row = (vim.o.lines - math.min(#lines + 2, 20)) / 2,
      style = 'minimal',
      border = 'rounded',
    })
  end, { desc = "List available calendars" })
  
  vim.api.nvim_create_user_command("OrgGcalStopBackgroundSync", function()
    M.stop_background_sync()
  end, { desc = "Stop background sync timer" })
  
  vim.api.nvim_create_user_command("OrgGcalRestartBackgroundSync", function(opts)
    local interval = tonumber(opts.args)
    if interval then
      M.restart_background_sync(interval * 60000)  -- Convert minutes to milliseconds
    else
      M.restart_background_sync(M.config.background_sync_interval)
    end
  end, { nargs = "?", desc = "Restart background sync (optionally with new interval in minutes)" })
  
  -- Add roam dirs to org_agenda_files instead of agenda_dir
  if #M.config.org_roam_dirs > 0 then
    vim.g.org_agenda_files = vim.g.org_agenda_files or {}
    for _, roam_dir in ipairs(M.config.org_roam_dirs) do
      local agenda_path = vim.fn.expand(roam_dir) .. "/**/*.org"
      if not vim.tbl_contains(vim.g.org_agenda_files, agenda_path) then
        table.insert(vim.g.org_agenda_files, agenda_path)
      end
    end
  end

  -- Auto-sync on save if file contains SCHEDULED or DEADLINE
  if M.config.auto_sync_on_save then
    vim.api.nvim_create_autocmd("BufWritePost", {
      pattern = "*.org",
      callback = function()
        local filepath = vim.fn.expand("%:p")
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        for _, line in ipairs(lines) do
          if line:match("SCHEDULED:") or line:match("DEADLINE:") then
            -- Sync only this file for speed
            vim.defer_fn(function()
              vim.notify("🔄 Syncing current file...", vim.log.levels.INFO)
              M.export_single_file(filepath)
            end, 100)
            break
          end
        end
      end,
      desc = "Auto-sync single org file on save if it contains scheduled/deadline items"
    })
  end

  -- Load real implementation
  local ok, utils = pcall(require, "org-gcal-sync.utils")
  if ok then
    utils.set_config(M.config)
    M._sync = utils.sync
    M._sync_background = utils.sync_background
    M._export_single_file = utils.export_single_file
    M._import_gcal = utils.import_gcal
    M._export_org = utils.export_org
  else
    vim.notify("org-gcal-sync: utils failed to load: " .. utils, vim.log.levels.ERROR)
  end
  
  -- Setup background sync timer if enabled
  if M.config.background_sync_interval > 0 then
    if _sync_timer then
      _sync_timer:stop()
      _sync_timer:close()
    end
    
    _sync_timer = vim.loop.new_timer()
    _sync_timer:start(
      M.config.background_sync_interval,  -- Initial delay
      M.config.background_sync_interval,  -- Repeat interval
      vim.schedule_wrap(function()
        vim.notify("🔄 Background sync started...", vim.log.levels.DEBUG)
        M.sync_background()
      end)
    )
    
    local minutes = math.floor(M.config.background_sync_interval / 60000)
    vim.notify(
      string.format("✓ Background sync enabled (every %d minutes)", minutes),
      vim.log.levels.INFO
    )
  end
end

-- Stop background sync timer
function M.stop_background_sync()
  if _sync_timer then
    _sync_timer:stop()
    _sync_timer:close()
    _sync_timer = nil
    vim.notify("Background sync stopped", vim.log.levels.INFO)
  end
end

-- Restart background sync timer with new interval
function M.restart_background_sync(interval_ms)
  M.stop_background_sync()
  if interval_ms and interval_ms > 0 then
    M.config.background_sync_interval = interval_ms
    
    _sync_timer = vim.loop.new_timer()
    _sync_timer:start(
      interval_ms,
      interval_ms,
      vim.schedule_wrap(function()
        vim.notify("🔄 Background sync started...", vim.log.levels.DEBUG)
        M.sync_background()
      end)
    )
    
    local minutes = math.floor(interval_ms / 60000)
    vim.notify(
      string.format("✓ Background sync restarted (every %d minutes)", minutes),
      vim.log.levels.INFO
    )
  end
end

-- Manual health check
function M.checkhealth()
  vim.notify("checkhealth: use :checkhealth org_gcal_sync", vim.log.levels.INFO)
end

return M
