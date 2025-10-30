-- lua/org-gcal-sync/init.lua
local M = {}

M.config = {
  agenda_dir = vim.fn.stdpath("data") .. "/org-gcal/agenda",
  org_roam_dirs = {},
  enable_backlinks = true,
  auto_sync_on_save = true,
  calendars = { "primary" },
  sync_recurring_events = true,
  conflict_resolution = "ask",
  per_directory_calendars = {},
  webhook_port = nil,
  show_sync_status = false,
}

local _setup_done = false

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
  
  vim.fn.mkdir(M.config.agenda_dir, "p")

  -- Register commands
  vim.api.nvim_create_user_command("SyncOrgGcal", function() M.sync() end, { desc = "Sync org ↔ gcal" })
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
  
  vim.g.org_agenda_files = vim.g.org_agenda_files or {}
  local agenda_path = vim.fn.expand(M.config.agenda_dir) .. "/**/*.org"
  if not vim.tbl_contains(vim.g.org_agenda_files, agenda_path) then
    table.insert(vim.g.org_agenda_files, agenda_path)
  end

  -- Auto-sync on save if file contains SCHEDULED or DEADLINE
  if M.config.auto_sync_on_save then
    vim.api.nvim_create_autocmd("BufWritePost", {
      pattern = "*.org",
      callback = function()
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        for _, line in ipairs(lines) do
          if line:match("SCHEDULED:") or line:match("DEADLINE:") then
            vim.schedule(function()
              M.sync()
            end)
            break
          end
        end
      end,
      desc = "Auto-sync org-gcal on save if file contains scheduled/deadline items"
    })
  end

  -- Load real implementation
  local ok, utils = pcall(require, "org-gcal-sync.utils")
  if ok then
    utils.set_config(M.config)
    M._sync = utils.sync
    M._import_gcal = utils.import_gcal
    M._export_org = utils.export_org
  else
    vim.notify("org-gcal-sync: utils failed to load: " .. utils, vim.log.levels.ERROR)
  end
end

-- Manual health check
function M.checkhealth()
  vim.notify("checkhealth: use :checkhealth org_gcal_sync", vim.log.levels.INFO)
end

return M
