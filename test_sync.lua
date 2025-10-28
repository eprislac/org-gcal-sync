-- lua/org-gcal-sync/init.lua

local M = {}

M.config = {
  agenda_dir = vim.fn.stdpath("data") .. "/org-gcal/agenda",
  org_files = {},
}

--- Setup the plugin
--- @param opts table Configuration options
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  vim.api.nvim_create_user_command("SyncOrgGcal", M.sync, { desc = "Synchronize org tasks with gcal" })
  vim.api.nvim_create_user_command("ImportGcal", M.import_gcal, { desc = "Import gcal agenda to org" })
  vim.api.nvim_create_user_command("ExportOrg", M.export_org, { desc = "Export org tasks to gcal" })
end

--- Import gcal agenda to org file
function M.import_gcal()
  local dir = M.config.agenda_dir
  vim.fn.mkdir(dir, "p")
  local file = dir .. "/gcal.org"
  local cmd = "gcalcli agenda --tsv"
  local output = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify("gcalcli agenda failed: " .. output, vim.log.levels.ERROR)
    return
  end
  local lines = {}
  for line in output:gmatch("[^\n\r]+") do
    -- Split by tabs: date\tstart\tend\tlink\ttitle\tlocation\tdescription
    local date, start_time, end_time, link, title, location, description = line:match("^(.-)\t(.-)\t(.-)\t(.-)\t(.-)\t(.-)\t(.*)$")
    if date and title and title ~= "" then
      table.insert(lines, "* " .. title)
      local timestamp = "<" .. date
      if start_time ~= "" then
        timestamp = timestamp .. " " .. start_time
      end
      timestamp = timestamp .. ">"
      table.insert(lines, "  SCHEDULED: " .. timestamp)
      if location and location ~= "" then
        table.insert(lines, "  :PROPERTIES:")
        table.insert(lines, "  :LOCATION: " .. location)
        table.insert(lines, "  :END:")
      end
      if description and description ~= "" then
        table.insert(lines, "  " .. description:gsub("\n", "\n  "))
      end
      table.insert(lines, "")
    end
  end
  local content = table.concat(lines, "\n")
  vim.fn.writefile(vim.split(content, "\n"), file)
  vim.notify("Imported gcal to " .. file)
end

--- Export org tasks to gcal
function M.export_org()
  local org_files = M.config.org_files
  if #org_files == 0 then
    vim.notify("No org_files configured in setup", vim.log.levels.WARN)
    return
  end
  local added = 0
  for _, org_file in ipairs(org_files) do
    if vim.fn.filereadable(org_file) == 0 then
      goto continue
    end
    local lines = vim.fn.readfile(org_file)
    local in_block = false
    local title = ""
    local scheduled = nil
    local deadline = nil
    for _, line in ipairs(lines) do
      local trimmed = line:gsub("^%s*(.-)%s*$", "%1")
      if trimmed:match("^%*+%s") then
        -- Process previous block
        if in_block and title ~= "" and (scheduled or deadline) then
          local when = scheduled or deadline
          local cmd = string.format('gcalcli add --title "%s" --when "%s"', title, when)
          local res = vim.fn.system(cmd)
          if vim.v.shell_error == 0 then
            added = added + 1
          else
            vim.notify("Failed to add '" .. title .. "': " .. res, vim.log.levels.WARN)
          end
        end
        -- Start new block
        in_block = true
        title = trimmed:match("^%*+%s+(.*)")
        scheduled = trimmed:match("SCHEDULED:%s*<([^>]+)>") or nil
        deadline = trimmed:match("DEADLINE:%s*<([^>]+)>") or nil
      elseif in_block and trimmed ~= "" then
        scheduled = scheduled or trimmed:match("SCHEDULED:%s*<([^>]+)>")
        deadline = deadline or trimmed:match("DEADLINE:%s*<([^>]+)>")
      end
    end
    -- Process last block
    if in_block and title ~= "" and (scheduled or deadline) then
      local when = scheduled or deadline
      local cmd = string.format('gcalcli add --title "%s" --when "%s"', title, when)
      local res = vim.fn.system(cmd)
      if vim.v.shell_error == 0 then
        added = added + 1
      else
        vim.notify("Failed to add '" .. title .. "': " .. res, vim.log.levels.WARN)
      end
    end
    ::continue::
  end
  vim.notify("Exported " .. added .. " tasks to gcal")
end

--- Synchronize: export then import
function M.sync()
  M.export_org()
  M.import_gcal()
end

return M

