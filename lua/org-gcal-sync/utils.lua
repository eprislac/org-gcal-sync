-- lua/org-gcal-sync/utils.lua
local M = {}

-- We'll get config from init.lua later
local cfg = {}

-- === CONFIG INJECTION ===
function M.set_config(config)
  cfg = config
end

-- Helpers --------------------------------------------------------------------
local function norm_time(ts)
  return ts and ts:gsub("^(%d%d%d%d%-%d%d%-%d%d)%s+(%d?%d:%d%d).*", "%1 %2") or nil
end

M.make_key = function(title, time)
  return (title or ""):lower() .. "||" .. (norm_time(time) or "")
end

M.get_gcal_events = function()
  local out = vim.fn.system("gcalcli agenda --tsv --nodetail 2>/dev/null || true")
  local ev = {}
  for line in out:gmatch("[^\r\n]+") do
    local date, start, _, _, title = line:match("^(.-)\t(.-)\t.-%t.-%t(.-)$")
    if title and title ~= "" then
      ev[M.make_key(title, date .. " " .. (start ~= "" and start or "00:00"))] = true
    end
  end
  return ev
end

M.get_existing_roam_events = function()
  local map = {}
  local files = vim.fn.glob(cfg.agenda_dir .. "/*.org", false, true)
  for _, f in ipairs(files) do
    local lines = vim.fn.readfile(f)
    local title, ts = nil, nil
    for _, l in ipairs(lines) do
      local t = l:gsub("^%s*(.-)%s*$", "%1")
      if t:match("^%*+%s") and not title then
        title = t:match("^%*+%s+(.*)")
      elseif t:match("^SCHEDULED:") or t:match("^DEADLINE:") then
        ts = t:match("<([^>]+)>")
      end
    end
    if title and ts then map[M.make_key(title, ts)] = f end
  end
  return map
end

local function slugify(title)
  if cfg.slug_func then return cfg.slug_func(title) end
  return title
    :lower()
    :gsub("[^%w%s-]", "")
    :gsub("%s+", "-")
    :gsub("-+", "-")
    :gsub("^-+", "")
    :gsub("-+$", "")
    .. ".org"
end

local function find_mentioning_notes(title)
  local dirs = cfg.org_roam_dirs
  if #dirs == 0 then return {} end
  local pattern = vim.fn.shellescape(title)
  local cmd = string.format('grep -iFl %s %s 2>/dev/null || true', pattern, table.concat(vim.tbl_map(vim.fn.expand, dirs), " "))
  local out = vim.fn.system(cmd)
  local files = {}
  for f in out:gmatch("[^\r\n]+") do
    if vim.fn.filereadable(f) == 1 then table.insert(files, f) end
  end
  return files
end

local function add_backlink(note_path, event_file)
  local lines = vim.fn.readfile(note_path)
  local new_lines = {}
  local in_prop = false
  local has_ref = false

  for _, line in ipairs(lines) do
    local t = line:gsub("^%s*(.-)%s*$", "%1")
    if t == ":PROPERTIES:" then in_prop = true end
    if in_prop and t == ":END:" then
      in_prop = false
      if not has_ref then
        table.insert(new_lines, "  :ROAM_REFS: " .. vim.fn.fnameescape("file:" .. event_file))
        has_ref = true
      end
    end
    if in_prop and t:match("^:ROAM_REFS:") then
      has_ref = true
      if not t:find(vim.fn.fnameescape(event_file), 1, true) then
        line = line .. " " .. vim.fn.fnameescape("file:" .. event_file)
      end
    end
    table.insert(new_lines, line)
  end

  if not has_ref then
    local insert_at = 1
    for i, l in ipairs(lines) do
      if l:match("^%*+%s") then insert_at = i; break end
    end
    table.insert(new_lines, insert_at, "  :PROPERTIES:")
    table.insert(new_lines, insert_at + 1, "  :ROAM_REFS: " .. vim.fn.fnameescape("file:" .. event_file))
    table.insert(new_lines, insert_at + 2, "  :END:")
  end

  vim.fn.writefile(new_lines, note_path)
end

M.write_roam_event_note = function(path, data)
  local lines = {
    "#+title: " .. data.title,
    "#+filetags: :gcal:",
    "",
    "* " .. data.title,
    "  SCHEDULED: <" .. data.timestamp .. ">",
  }
  if data.location and data.location ~= "" then
    table.insert(lines, "  :PROPERTIES:")
    table.insert(lines, "  :LOCATION: " .. data.location)
    table.insert(lines, "  :END:")
  end
  if data.description and data.description ~= "" then
    vim.list_extend(lines, vim.split("  " .. data.description:gsub("\n", "\n  "), "\n"))
  end
  table.insert(lines, "")
  vim.fn.writefile(lines, path)

  if cfg.enable_backlinks then
    local mentions = find_mentioning_notes(data.title)
    for _, note in ipairs(mentions) do
      if note ~= path then add_backlink(note, path) end
    end
  end
end

-- IMPORT ---------------------------------------------------------------------
function M.import_gcal()
  local existing = M.get_existing_roam_events()
  local out = vim.fn.system("gcalcli agenda --tsv 2>/dev/null || true")
  if vim.v.shell_error ~= 0 then
    vim.notify("gcalcli failed", vim.log.levels.ERROR)
    return
  end
  vim.notify(out, vim.log.levels.INFO)
  local imported = 0
  for line in out:gmatch("[^\r\n]+") do
    vim.notify(line, vim.log.levels.INFO)
    local start_date, start_time, end_date, end_time, title, location, description =
      line:match("^(.-)\t(.-)\t(.-)\t(.-)\t(.-)\t(.-)\t(.*)$")
    if not (start_date and title and title ~= "") then goto continue end

    local ts = start_date .. (start_time ~= "" and " " .. start_time or "")
    local key = M.make_key(title, ts)
    if existing[key] then goto continue end

    local file = cfg.agenda_dir .. "/" .. slugify(title)
    M.write_roam_event_note(file, {
      title = title,
      timestamp = ts,
      location = location,
      description = description,
    })
    imported = imported + 1
    ::continue::
  end

  vim.notify("Imported " .. imported .. " events", vim.log.levels.INFO)
end

-- EXPORT ---------------------------------------------------------------------
function M.export_org()
  local gcal = M.get_gcal_events()
  local added = 0

  for _, base in ipairs(cfg.org_roam_dirs) do
    local files = vim.fn.glob(vim.fn.expand(base) .. "/**/*.org", false, true)
    for _, f in ipairs(files) do
      local lines = vim.fn.readfile(f)
      local title, ts = nil, nil
      for _, l in ipairs(lines) do
        local t = l:gsub("^%s*(.-)%s*$", "%1")
        if t:match("^%*+%s") and not title then
          title = t:match("^%*+%s+(.*)")
        elseif t:match("^SCHEDULED:") or t:match("^DEADLINE:") then
          ts = t:match("<([^>]+)>")
        end
      end
      if title and ts then
        local key = M.make_key(title, ts)
        if not gcal[key] then
          local cmd = string.format('gcalcli add --title %s --when %s', vim.fn.shellescape(title), vim.fn.shellescape(ts))
          if vim.fn.system(cmd) == "" then
            added = added + 1
            gcal[key] = true
          end
        end
      end
    end
  end

  vim.notify("Exported " .. added .. " tasks", vim.log.levels.INFO)
end

function M.sync()
  M.export_org()
  M.import_gcal()
end

return M
