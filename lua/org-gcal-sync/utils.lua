-- lua/org-gcal-sync/utils.lua
local M = {}
local gcal_api = require("org-gcal-sync.gcal_api")
local conflict = require("org-gcal-sync.conflict")
local dashboard = require("org-gcal-sync.dashboard")

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

M.make_key = function(title, time, event_id)
  if event_id then
    return event_id
  end
  return (title or ""):lower() .. "||" .. (norm_time(time) or "")
end

local function parse_gcal_datetime(dt)
  if not dt then return nil end
  if dt.dateTime then
    local ts = dt.dateTime:gsub("T", " "):gsub("[+-]%d%d:%d%d$", ""):gsub("Z$", "")
    return ts:match("^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d")
  elseif dt.date then
    return dt.date .. " 00:00"
  end
  return nil
end

M.get_gcal_events = function(calendar_id)
  local time_min = os.date("!%Y-%m-%dT%H:%M:%SZ", os.time() - 7 * 24 * 60 * 60)
  local time_max = os.date("!%Y-%m-%dT%H:%M:%SZ", os.time() + 90 * 24 * 60 * 60)
  
  local events, err = gcal_api.list_events(time_min, time_max, calendar_id)
  if not events then
    vim.notify("Failed to fetch events: " .. (err or "unknown error"), vim.log.levels.ERROR)
    if cfg.show_sync_status then
      dashboard.add_error("Failed to fetch events: " .. (err or "unknown error"))
    end
    return {}
  end

  local ev = {}
  for _, event in ipairs(events) do
    if event.summary then
      local instances = { event }
      
      if cfg.sync_recurring_events and event.recurrence then
        instances = gcal_api.expand_recurring_event(event, time_min, time_max)
      end
      
      for _, instance in ipairs(instances) do
        local ts = parse_gcal_datetime(instance.start)
        if ts then
          local key = M.make_key(instance.summary, ts, instance.id)
          ev[key] = {
            id = instance.id,
            title = instance.summary,
            timestamp = ts,
            location = instance.location or "",
            description = instance.description or "",
            updated = instance.updated,
            calendar_id = calendar_id or "primary",
            recurring_event_id = event.recurringEventId,
            recurrence = event.recurrence,
          }
        end
      end
    end
  end
  return ev
end

M.get_existing_roam_events = function()
  local map = {}
  local files = vim.fn.glob(cfg.agenda_dir .. "/*.org", false, true)
  for _, f in ipairs(files) do
    local lines = vim.fn.readfile(f)
    local title, ts, event_id, gcal_updated, calendar_id, file_modified = nil, nil, nil, nil, nil, nil
    for _, l in ipairs(lines) do
      local t = l:gsub("^%s*(.-)%s*$", "%1")
      if t:match("^%*+%s") and not title then
        title = t:match("^%*+%s+(.*)")
      elseif t:match("^SCHEDULED:") or t:match("^DEADLINE:") then
        ts = t:match("<([^>]+)>")
      elseif t:match("^:GCAL_ID:") then
        event_id = t:match("^:GCAL_ID:%s*(.+)%s*$")
      elseif t:match("^:GCAL_UPDATED:") then
        gcal_updated = t:match("^:GCAL_UPDATED:%s*(.+)%s*$")
      elseif t:match("^:CALENDAR_ID:") then
        calendar_id = t:match("^:CALENDAR_ID:%s*(.+)%s*$")
      end
    end
    
    if vim.fn.filereadable(f) == 1 then
      local stat = vim.loop.fs_stat(f)
      if stat then
        file_modified = os.date("!%Y-%m-%dT%H:%M:%SZ", stat.mtime.sec)
      end
    end
    
    if title and ts then
      local key = M.make_key(title, ts, event_id)
      map[key] = {
        path = f,
        title = title,
        timestamp = ts,
        event_id = event_id,
        gcal_updated = gcal_updated,
        calendar_id = calendar_id or "primary",
        modified = file_modified,
      }
    end
  end
  return map
end

local function generate_uuid()
  local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
  return string.gsub(template, '[xy]', function(c)
    local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format('%x', v)
  end)
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
    ":PROPERTIES:",
    ":ID: " .. generate_uuid(),
    ":END:",
    "#+title: " .. data.title,
    "#+filetags: :gcal:",
    "",
    "* " .. data.title,
    "  SCHEDULED: <" .. data.timestamp .. ">",
    "  :PROPERTIES:",
  }
  if data.event_id then
    table.insert(lines, "  :GCAL_ID: " .. data.event_id)
  end
  if data.calendar_id then
    table.insert(lines, "  :CALENDAR_ID: " .. data.calendar_id)
  end
  if data.location and data.location ~= "" then
    table.insert(lines, "  :LOCATION: " .. data.location)
  end
  if data.updated then
    table.insert(lines, "  :GCAL_UPDATED: " .. data.updated)
  end
  if data.recurring_event_id then
    table.insert(lines, "  :RECURRING_EVENT_ID: " .. data.recurring_event_id)
  end
  if data.recurrence then
    table.insert(lines, "  :RECURRENCE: " .. vim.json.encode(data.recurrence))
  end
  table.insert(lines, "  :END:")
  
  if data.description and data.description ~= "" then
    table.insert(lines, "")
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
  if cfg.show_sync_status then
    dashboard.set_in_progress(true)
  end
  local existing = M.get_existing_roam_events()
  
  local calendars = cfg.calendars or { "primary" }
  local total_imported = 0
  local total_updated = 0
  local total_deleted = 0
  local total_conflicts = 0
  
  for _, calendar_id in ipairs(calendars) do
    local gcal_events = M.get_gcal_events(calendar_id)
    
    if not gcal_events then
      vim.notify("Failed to fetch Google Calendar events from " .. calendar_id, vim.log.levels.ERROR)
      if cfg.show_sync_status then
        dashboard.add_error("Failed to fetch events from calendar: " .. calendar_id)
      end
      goto continue
    end

    local imported = 0
    local updated = 0

    -- Import new and update existing events
    for key, event in pairs(gcal_events) do
      local existing_event = existing[key]
      
      if not existing_event then
        local file = cfg.agenda_dir .. "/" .. slugify(event.title)
        local opts = {
          title = event.title,
          timestamp = event.timestamp,
          location = event.location,
          description = event.description,
          event_id = event.id,
          updated = event.updated,
          calendar_id = calendar_id,
          recurring_event_id = event.recurring_event_id,
          recurrence = event.recurrence,
        }
        local success, result = pcall(M.write_roam_event_note, file, opts)
        if success then
          imported = imported + 1
        else
          vim.notify('Failed to write roam event: ' .. tostring(result), vim.log.levels.ERROR)
          if cfg.show_sync_status then
            dashboard.add_error('Failed to write event: ' .. event.title)
          end
        end
      elseif existing_event and event.updated ~= existing_event.gcal_updated then
        local choice, resolved_event = conflict.resolve_conflict(
          existing_event,
          event,
          cfg.conflict_resolution or "ask"
        )
        
        if choice == "remote" then
          local opts = {
            title = event.title,
            timestamp = event.timestamp,
            location = event.location,
            description = event.description,
            event_id = event.id,
            updated = event.updated,
            calendar_id = calendar_id,
            recurring_event_id = event.recurring_event_id,
            recurrence = event.recurrence,
          }
          local success, result = pcall(M.write_roam_event_note, existing_event.path, opts)
          if success then
            updated = updated + 1
          else
            vim.notify('Failed to update roam event: ' .. tostring(result), vim.log.levels.ERROR)
            if cfg.show_sync_status then
              dashboard.add_error('Failed to update event: ' .. event.title)
            end
          end
        elseif choice == "skip" then
          total_conflicts = total_conflicts + 1
        end
      end
      
      existing[key] = nil
    end

    total_imported = total_imported + imported
    total_updated = total_updated + updated
    
    if cfg.show_sync_status then
      dashboard.set_calendar_stats(calendar_id, {
        total = imported + updated,
        last_sync = os.date("%Y-%m-%d %H:%M:%S"),
      })
    end
    
    ::continue::
  end

  -- Delete events that no longer exist in Google Calendar
  local deleted = 0
  for key, event in pairs(existing) do
    if event.event_id and vim.fn.filereadable(event.path) == 1 then
      vim.fn.delete(event.path)
      deleted = deleted + 1
    end
  end
  total_deleted = deleted

  if cfg.show_sync_status then
    dashboard.update_stats({
      imported = total_imported,
      updated = total_updated,
      deleted = total_deleted,
      conflicts = total_conflicts,
    })
    dashboard.set_in_progress(false)
  end

  local msg = string.format("Imported: %d, Updated: %d, Deleted: %d, Conflicts: %d", 
    total_imported, total_updated, total_deleted, total_conflicts)
  vim.notify(msg, vim.log.levels.INFO)
end

-- EXPORT ---------------------------------------------------------------------
local function parse_org_timestamp(ts_str)
  if not ts_str then return nil end
  local year, month, day, hour, min = ts_str:match("(%d%d%d%d)%-(%d%d)%-(%d%d)%s+(%d%d):(%d%d)")
  if not year then
    year, month, day = ts_str:match("(%d%d%d%d)%-(%d%d)%-(%d%d)")
    hour, min = "00", "00"
  end
  if not year then return nil end
  
  local timestamp = os.time({
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour),
    min = tonumber(min),
  })
  
  return os.date("!%Y-%m-%dT%H:%M:%SZ", timestamp)
end

function M.export_org()
  if cfg.show_sync_status then
    dashboard.set_in_progress(true)
  end
  local gcal_events = {}
  
  for _, calendar_id in ipairs(cfg.calendars or { "primary" }) do
    local cal_events = M.get_gcal_events(calendar_id)
    for k, v in pairs(cal_events) do
      gcal_events[k] = v
    end
  end
  
  local added = 0
  local updated = 0
  local exported = 0
  local tasks_added = 0

  for _, base in ipairs(cfg.org_roam_dirs) do
    local calendar_id = cfg.per_directory_calendars[base] or "primary"
    
    local files = vim.fn.glob(vim.fn.expand(base) .. "/**/*.org", false, true)
    for _, f in ipairs(files) do
      local lines = vim.fn.readfile(f)
      local title, ts, event_id, location, description, is_todo = nil, nil, nil, "", "", false
      local in_properties = false
      
      for _, l in ipairs(lines) do
        local t = l:gsub("^%s*(.-)%s*$", "%1")
        if t:match("^%*+%s+TODO%s") or t:match("^%*+%s+NEXT%s") then
          is_todo = true
          title = t:match("^%*+%s+TODO%s+(.*)") or t:match("^%*+%s+NEXT%s+(.*)")
        elseif t:match("^%*+%s") and not title then
          title = t:match("^%*+%s+(.*)")
        elseif t:match("^SCHEDULED:") or t:match("^DEADLINE:") then
          ts = t:match("<([^>]+)>")
        elseif t == ":PROPERTIES:" then
          in_properties = true
        elseif t == ":END:" then
          in_properties = false
        elseif in_properties and t:match("^:GCAL_ID:") then
          event_id = t:match("^:GCAL_ID:%s*(.+)%s*$")
        elseif in_properties and t:match("^:LOCATION:") then
          location = t:match("^:LOCATION:%s*(.+)%s*$") or ""
        elseif not in_properties and not t:match("^[#:]") and not t:match("^%*") and t ~= "" then
          if description ~= "" then description = description .. "\n" end
          description = description .. t:gsub("^%s+", "")
        end
      end
      
      -- Handle TODOs with scheduled time -> Calendar
      if is_todo and title and ts then
        local start_time = parse_org_timestamp(ts)
        if not start_time then goto continue end
        
        local event_data = {
          summary = title,
          start = {
            dateTime = start_time,
            timeZone = "UTC",
          },
          ["end"] = {
            dateTime = os.date("!%Y-%m-%dT%H:%M:%SZ", os.time() + 3600),
            timeZone = "UTC",
          },
        }
        
        if location and location ~= "" then
          event_data.location = location
        end
        
        if description and description ~= "" then
          event_data.description = description
        end
        
        local key = M.make_key(title, ts, event_id)
        
        if event_id and gcal_events[event_id] then
          local result, err = gcal_api.update_event(event_id, event_data, calendar_id)
          if result then
            updated = updated + 1
            exported = exported + 1
          else
            vim.notify("Failed to update event: " .. (err or "unknown error"), vim.log.levels.WARN)
            if cfg.show_sync_status then
              dashboard.add_error("Failed to update: " .. title)
            end
          end
        elseif not gcal_events[key] then
          local result, err = gcal_api.create_event(event_data, calendar_id)
          if result then
            added = added + 1
            exported = exported + 1
            gcal_events[key] = true
          else
            vim.notify("Failed to create event: " .. (err or "unknown error"), vim.log.levels.WARN)
            if cfg.show_sync_status then
              dashboard.add_error("Failed to create: " .. title)
            end
          end
        end
      -- Handle TODOs without scheduled time -> Tasks
      elseif is_todo and title and not ts then
        local task_data = {
          title = title,
        }
        if description and description ~= "" then
          task_data.notes = description
        end
        
        local result, err = gcal_api.create_task(task_data)
        if result then
          tasks_added = tasks_added + 1
        else
          vim.notify("Failed to create task: " .. (err or "unknown error"), vim.log.levels.WARN)
          if cfg.show_sync_status then
            dashboard.add_error("Failed to create task: " .. title)
          end
        end
      end
      ::continue::
    end
  end

  if cfg.show_sync_status then
    dashboard.update_stats({
      exported = exported,
    })
    dashboard.set_in_progress(false)
  end

  local msg = string.format("Added: %d, Updated: %d, Tasks: %d", added, updated, tasks_added)
  vim.notify(msg, vim.log.levels.INFO)
end

function split_string(input_string, delimiter)
  local result = {}
  local start_index = 1
  local delimiter_start, delimiter_end = string.find(input_string, delimiter, start_index, true)

  while delimiter_start do
    table.insert(result, string.sub(input_string, start_index, delimiter_start - 1))
    start_index = delimiter_end + 1
    delimiter_start, delimiter_end = string.find(input_string, delimiter, start_index, true)
  end

  table.insert(result, string.sub(input_string, start_index))

  return result
end

function M.sync()
  M.export_org()
  M.import_gcal()
end

function M.delete_event(event_id)
  if not event_id then
    vim.notify("No event ID provided", vim.log.levels.ERROR)
    return false
  end
  
  local result, err = gcal_api.delete_event(event_id)
  if not result then
    vim.notify("Failed to delete event: " .. (err or "unknown error"), vim.log.levels.ERROR)
    return false
  end
  
  return true
end

return M
