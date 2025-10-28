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

  vim.api.nvim_create_user_command("SyncOrgGcal", M.sync, { desc = "Sync org-roam ↔ gcal + agenda" })
  vim.api.nvim_create_user_command("ImportGcal", M.import_gcal, { desc = "Import gcal → org-roam + agenda" })
  vim.api.nvim_create_user_command("ExportOrg", M.export_org, { desc = "Export org-roam → gcal" })

  -- Auto-include gcal dir in org-agenda
  if not vim.g.org_agenda_files then vim.g.org_agenda_files = {} end
  local gcal_path = vim.fn.expand(M.config.agenda_dir) .. "/" .. M.config.agenda_files_pattern
  if not vim.tbl_contains(vim.g.org_agenda_files, gcal_path) then
    table.insert(vim.g.org_agenda_files, gcal_path)
  end
end

-- Forward core functions
local utils = require("org-gcal-sync.utils")
M.import_gcal = utils.import_gcal
M.export_org = utils.export_org
M.sync = utils.sync

-- === CHECKHEALTH ===
function M.checkhealth()
  local health = vim.health or require("health")
  local start = health.start or health.report_start
  local ok = health.ok or health.report_ok
  local warn = health.warn or health.report_warn
  local error = health.error or health.report_error
  local info = health.info or health.report_info

  start("org-gcal-sync")

  -- 1. gcalcli
  local gcalcli = vim.fn.executable("gcalcli") == 1
  if not gcalcli then
    error("gcalcli not found in PATH. Install: pip install gcalcli")
  else
    ok("gcalcli found in PATH")
    local auth_check = vim.fn.system("gcalcli list 2>/dev/null | head -1")
    if vim.v.shell_error ~= 0 or auth_check:match("error") then
      warn("gcalcli not authenticated. Run: gcalcli init")
    else
      ok("gcalcli authenticated and working")
    end
  end

  -- 2. agenda_dir
  local dir = vim.fn.expand(M.config.agenda_dir)
  if vim.fn.isdirectory(dir) == 0 then
    error("agenda_dir does not exist: " .. dir)
  elseif vim.fn.filewritable(dir) ~= 2 then
    error("agenda_dir is not writable: " .. dir)
  else
    ok("agenda_dir exists and writable: " .. dir)
  end

  -- 3. org_roam_dirs
  if #M.config.org_roam_dirs == 0 then
    warn("org_roam_dirs is empty. Export will do nothing.")
  else
    local all_exist = true
    for _, d in ipairs(M.config.org_roam_dirs) do
      local path = vim.fn.expand(d)
      if vim.fn.isdirectory(path) == 0 then
        error("org_roam_dirs path missing: " .. path)
        all_exist = false
      end
    end
    if all_exist then
      ok("All org_roam_dirs exist")
    end
  end

  -- 4. orgmode
  if not pcall(require, "orgmode") then
    error("nvim-orgmode not loaded. Add to dependencies.")
  else
    ok("nvim-orgmode loaded")
  end

  -- 5. org-roam
  local has_roam = pcall(require, "org-roam")
  if not has_roam then
    warn("org-roam plugin not detected. Backlinks disabled.")
  else
    ok("org-roam plugin detected")
  end

  -- 6. backlinks
  if M.config.enable_backlinks and not has_roam then
    warn("enable_backlinks=true but org-roam not loaded. Backlinks disabled.")
  elseif M.config.enable_backlinks then
    ok("Backlinks enabled and supported")
  else
    info("Backlinks disabled in config")
  end

  -- 7. Syncthing (optional)
  local syncthing_hint = vim.fn.systemlist("command -v syncthing")
  if #syncthing_hint > 0 then
    ok("Syncthing binary found (optional)")
  else
    info("Syncthing not in PATH (optional, but recommended for multi-device sync)")
  end

  -- 8. Test write
  local test_file = dir .. "/.health-test.org"
  local test_content = {"* Health Test", "  SCHEDULED: <2099-01-01>"}
  vim.fn.writefile(test_content, test_file)
  if vim.fn.filereadable(test_file) == 1 then
    ok("Can write to agenda_dir")
    vim.fn.delete(test_file)
  else
    error("Failed to write test file in agenda_dir")
  end
end

return M
