-- lua/org-gcal-sync/init.lua
local M = {}

M.config = {
  agenda_dir = vim.fn.stdpath("data") .. "/org-gcal/agenda",
  org_roam_dirs = {},
  enable_backlinks = true,
}

-- Default commands (will be overridden in setup)
M.sync = function() vim.notify("Sync not configured", vim.log.levels.WARN) end
M.import_gcal = M.sync
M.export_org = M.sync

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Create directory
  vim.fn.mkdir(M.config.agenda_dir, "p")

  -- Register commands
  vim.api.nvim_create_user_command("SyncOrgGcal", M.sync, { desc = "Sync org ↔ gcal" })
  vim.api.nvim_create_user_command("ImportGcal", M.import_gcal, { desc = "Import from gcal" })
  vim.api.nvim_create_user_command("ExportOrg", M.export_org, { desc = "Export to gcal" })

  -- Add to org-agenda
  vim.g.org_agenda_files = vim.g.org_agenda_files or {}
  local agenda_path = vim.fn.expand(M.config.agenda_dir) .. "/**/*.org"
  if not vim.tbl_contains(vim.g.org_agenda_files, agenda_path) then
    table.insert(vim.g.org_agenda_files, agenda_path)
  end

  -- Load real implementation
  local ok, utils = pcall(require, "org-gcal-sync.utils")
  if ok then
    utils.set_config(M.config)
    M.sync = utils.sync
    M.import_gcal = utils.import_gcal
    M.export_org = utils.export_org
  else
    vim.notify("org-gcal-sync: utils failed to load: " .. utils, vim.log.levels.ERROR)
  end
end

-- Manual health check
function M.checkhealth()
  vim.notify("checkhealth: use :checkhealth org_gcal_sync", vim.log.levels.INFO)
end

return M
