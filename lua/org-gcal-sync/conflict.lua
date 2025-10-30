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
  local diff_lines = show_diff(local_event, remote_event)
  
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, diff_lines)
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
  vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
  
  local width = 80
  local height = #diff_lines + 6
  local win_opts = {
    relative = 'editor',
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = 'minimal',
    border = 'rounded',
    title = ' Conflict Resolution ',
    title_pos = 'center',
  }
  
  local winnr = vim.api.nvim_open_win(bufnr, true, win_opts)
  
  vim.api.nvim_buf_set_keymap(bufnr, 'n', 'l', '', {
    callback = function()
      vim.api.nvim_win_close(winnr, true)
      vim.g.org_gcal_conflict_choice = "local"
    end,
    noremap = true,
    silent = true,
  })
  
  vim.api.nvim_buf_set_keymap(bufnr, 'n', 'r', '', {
    callback = function()
      vim.api.nvim_win_close(winnr, true)
      vim.g.org_gcal_conflict_choice = "remote"
    end,
    noremap = true,
    silent = true,
  })
  
  vim.api.nvim_buf_set_keymap(bufnr, 'n', 'q', '', {
    callback = function()
      vim.api.nvim_win_close(winnr, true)
      vim.g.org_gcal_conflict_choice = "skip"
    end,
    noremap = true,
    silent = true,
  })
  
  local footer = {
    "",
    "Choose: [l] Keep Local  [r] Keep Remote  [q] Skip",
  }
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, footer)
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
  
  vim.fn.wait(30000, function()
    return vim.g.org_gcal_conflict_choice ~= nil
  end)
  
  local choice = vim.g.org_gcal_conflict_choice or "skip"
  vim.g.org_gcal_conflict_choice = nil
  
  if choice == "local" then
    return "local", local_event
  elseif choice == "remote" then
    return "remote", remote_event
  else
    return "skip", nil
  end
end

return M
