-- lua/org-gcal-sync/conflict.lua
local M = {}

local function show_diff(local_event, remote_event)
  local lines = {
    "=== CONFLICT DETECTED ===",
    "",
    "Event: " .. (local_event.title or remote_event.title),
    "",
    "LOCAL (Org File):",
    "  Modified: " .. (local_event.modified or "unknown"),
    "  Title: " .. (local_event.title or ""),
    "  Time: " .. (local_event.timestamp or ""),
    "  Location: " .. (local_event.location or ""),
    "",
    "REMOTE (Google Calendar):",
    "  Modified: " .. (remote_event.updated or "unknown"),
    "  Title: " .. (remote_event.title or ""),
    "  Time: " .. (remote_event.timestamp or ""),
    "  Location: " .. (remote_event.location or ""),
    "",
  }
  
  if local_event.description ~= remote_event.description then
    table.insert(lines, "LOCAL Description:")
    if local_event.description and local_event.description ~= "" then
      -- Split multi-line descriptions
      for line in (local_event.description .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(lines, "  " .. line)
      end
    else
      table.insert(lines, "  (none)")
    end
    table.insert(lines, "")
    table.insert(lines, "REMOTE Description:")
    if remote_event.description and remote_event.description ~= "" then
      -- Split multi-line descriptions
      for line in (remote_event.description .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(lines, "  " .. line)
      end
    else
      table.insert(lines, "  (none)")
    end
  end
  
  return lines
end

function M.resolve_conflict(local_event, remote_event, strategy)
  if strategy == "local" then
    return "local", local_event
  elseif strategy == "remote" then
    return "remote", remote_event
  elseif strategy == "newest" then
    local local_time = vim.fn.strptime("%Y-%m-%dT%H:%M:%SZ", local_event.modified or "")
    local remote_time = vim.fn.strptime("%Y-%m-%dT%H:%M:%SZ", remote_event.updated or "")
    if local_time > remote_time then
      return "local", local_event
    else
      return "remote", remote_event
    end
  elseif strategy == "ask" then
    return M.ask_user(local_event, remote_event)
  end
  
  return "remote", remote_event
end

function M.ask_user(local_event, remote_event)
  -- In async context, we can't block for user input
  -- Log the conflict and default to "remote" (Google Calendar wins)
  vim.notify(
    string.format(
      "⚠️ Conflict detected for '%s' - using remote (Google Calendar) version. " ..
      "Set conflict_resolution='newest' or 'local' to auto-resolve.",
      local_event.title or remote_event.title
    ),
    vim.log.levels.WARN
  )
  
  -- Could optionally log details to a file for review
  local conflict_log = {
    "=== CONFLICT DETECTED ===",
    "Event: " .. (local_event.title or remote_event.title),
    "LOCAL Modified: " .. (local_event.modified or "unknown"),
    "REMOTE Modified: " .. (remote_event.updated or "unknown"),
    "Resolution: Using REMOTE (Google Calendar)",
    "",
  }
  
  -- Log to messages
  for _, line in ipairs(conflict_log) do
    vim.notify(line, vim.log.levels.DEBUG)
  end
  
  return "remote", remote_event
end

return M
