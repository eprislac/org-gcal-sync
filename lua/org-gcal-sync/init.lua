-- lua/org-gcal-sync/init.lua
local M = {}

M.config = {
  agenda_dir = vim.fn.stdpath("data") .. "/org-gcal/agenda",
  org_roam_dirs = {},
  slug_func = nil,
  enable_backlinks = true,
  agenda_files_pattern = "**/*.org",
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  vim.fn.mkdir(M.config.agenda_dir, "p")
  vim.api.nvim_create_user_command("SyncOrgGcal", M.sync, { desc = "Sync org-roam to gcal + agenda" })
  vim.api.nvim_create_user_command("ImportGcal", M.import_gcal, { desc = "Import gcal to org-roam + agenda" })
  vim.api.nvim_create_user_command("ExportOrg", M.export_org, { desc = "Export org-roam to gcal" })

  -- Auto-include in org-agenda
  vim.g.org_agenda_files = vim.g.org_agenda_files or {}
  local gcal_path = vim.fn.expand(M.config.agenda_dir) .. "/" .. M.config.agenda_files_pattern
  if not vim.tbl_contains(vim.g.org_agenda_files, gcal_path) then
    table.insert(vim.g.org_agenda_files, gcal_path)
  end

  local utils = require("org-gcal-sync.utils")
  utils.set_config(M.config)

  M.import_gcal = utils.import_gcal
  M.export_org = utils.export_org
  M.sync = utils.sync
end

-- -- === CHECKHEALTH (for manual :lua require("org-gcal-sync").checkhealth()) ===
-- function M.checkhealth()
--   local health = vim.health or require("health")
--   local start = health.start or health.report_start
--   local ok = health.ok or health.report_ok
--   local warn = health.warn or health.report_warn
--   local err = health.error or health.report_error
--   local info = health.info or health.report_info
--
--   start("org-gcal-sync")
--
--   -- 1. gcalcli
--   if vim.fn.executable("gcalcli") ~= 1 then
--     err("gcalcli not found in PATH. Install: pip install gcalcli")
--   else
--     ok("gcalcli found in PATH")
--     local auth_out = vim.fn.system("gcalcli list 2>/dev/null")
--     if vim.v.shell_error ~= 0 or auth_out:match("error") or auth_out == "" then
--       warn("gcalcli not authenticated. Run: gcalcli init")
--     else
--       ok("gcalcli authenticated")
--     end
--   end
--
--   -- 2. agenda_dir
--   local dir = vim.fn.expand(M.config.agenda_dir)
--   if vim.fn.isdirectory(dir) == 0 then
--     err("agenda_dir missing: " .. dir .. " (create it or set in setup)")
--   elseif vim.fn.filewritable(dir) ~= 2 then
--     err("agenda_dir not writable: " .. dir)
--   else
--     ok("agenda_dir OK: " .. dir)
--   end
--
--   -- 3. org_roam_dirs
--   if #M.config.org_roam_dirs == 0 then
--     warn("org_roam_dirs empty — exports will skip")
--   else
--     local all_ok = true
--     for _, d in ipairs(M.config.org_roam_dirs) do
--       local path = vim.fn.expand(d)
--       if vim.fn.isdirectory(path) == 0 then
--         err("org_roam_dir missing: " .. path)
--         all_ok = false
--       end
--     end
--     if all_ok then ok("All org_roam_dirs OK") end
--   end
--
--   -- 4. Dependencies
--   if not pcall(require, "orgmode") then
--     err("nvim-orgmode not installed/loaded")
--   else
--     ok("nvim-orgmode loaded")
--   end
--
--   local has_roam = pcall(require, "org-roam") or pcall(require, "roam")  -- flexible
--   if not has_roam then
--     warn("org-roam not detected (backlinks may fail)")
--   else
--     ok("org-roam detected")
--   end
--
--   -- 5. Backlinks
--   if M.config.enable_backlinks and not has_roam then
--     warn("enable_backlinks=true but no org-roam — disabling")
--   elseif M.config.enable_backlinks then
--     ok("Backlinks enabled")
--   else
--     info("Backlinks disabled")
--   end
--
--   -- 6. Syncthing (optional)
--   if vim.fn.executable("syncthing") == 1 then
--     ok("Syncthing found (optional)")
--   else
--     info("Syncthing not in PATH (recommended for multi-device)")
--   end
--
--   -- 7. Write test
--   local test_file = dir .. "/.health-test-" .. vim.fn.reltimestr(vim.fn.reltime()) .. ".org"
--   vim.fn.writefile({"* Test", "  SCHEDULED: <2099-01-01>"}, test_file)
--   if vim.fn.filereadable(test_file) == 1 then
--     ok("agenda_dir writable")
--     vim.fn.delete(test_file)
--   else
--     err("Failed to write test file")
--   end
-- end
--
-- return M
