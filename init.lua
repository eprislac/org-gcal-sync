-- lua/org-gcal-sync/init.lua
local M = {}

M.config = {
  agenda_dir = vim.fn.stdpath("data") .. "/org-gcal/agenda",
  org_roam_dirs = {},
  slug_func = nil,
  enable_backlinks = true,
  agenda_files_pattern = "**/*.org",  -- for orgmode agenda_files
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  vim.fn.mkdir(M.config.agenda_dir, "p")

  vim.api.nvim_create_user_command("SyncOrgGcal", M.sync, { desc = "Sync org-roam ↔ gcal + agenda" })
  vim.api.nvim_create_user_command("ImportGcal", M.import_gcal, { desc = "Import gcal → org-roam + agenda" })
  vim.api.nvim_create_user_command("ExportOrg", M.export_org, { desc = "Export org-roam → gcal" })

  -- Auto-include gcal dir in org-agenda
  if not vim.g.org_agenda_files then
    vim.g.org_agenda_files = {}
  end
  local gcal_path = vim.fn.expand(M.config.agenda_dir) .. "/" .. M.config.agenda_files_pattern
  if not vim.tbl_contains(vim.g.org_agenda_files, gcal_path) then
    table.insert(vim.g.org_agenda_files, gcal_path)
  end
end

-- Forward to utils
M.import_gcal = require("org-gcal-sync.utils").import_gcal
M.export_org = require("org-gcal-sync.utils").export_org
M.sync = require("org-gcal-sync.utils").sync
M.get_gcal_events = require("org-gcal-sync.utils").get_gcal_events
M.get_existing_roam_events = require("org-gcal-sync.utils").get_existing_roam_events
M.write_roam_event_note = require("org-gcal-sync.utils").write_roam_event_note

return M
