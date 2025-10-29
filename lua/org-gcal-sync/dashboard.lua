-- lua/org-gcal-sync/dashboard.lua
local M = {}

M.sync_stats = {
  last_sync = nil,
  imported = 0,
  exported = 0,
  updated = 0,
  deleted = 0,
  conflicts = 0,
  errors = {},
  in_progress = false,
  calendars = {},
}

function M.update_stats(stats)
  M.sync_stats.last_sync = os.date("%Y-%m-%d %H:%M:%S")
  M.sync_stats.imported = stats.imported or 0
  M.sync_stats.exported = stats.exported or 0
  M.sync_stats.updated = stats.updated or 0
  M.sync_stats.deleted = stats.deleted or 0
  M.sync_stats.conflicts = stats.conflicts or 0
  if stats.errors then
    vim.list_extend(M.sync_stats.errors, stats.errors)
  end
end

function M.set_calendar_stats(calendar_id, stats)
  M.sync_stats.calendars[calendar_id] = stats
end

function M.set_in_progress(value)
  M.sync_stats.in_progress = value
end

function M.show()
  local lines = {
    "╭─────────────────────────────────────────────────────────╮",
    "│              Org-Gcal Sync Dashboard                    │",
    "╰─────────────────────────────────────────────────────────╯",
    "",
  }
  
  if M.sync_stats.in_progress then
    table.insert(lines, "🔄 Sync in progress...")
  elseif M.sync_stats.last_sync then
    table.insert(lines, "✓ Last sync: " .. M.sync_stats.last_sync)
  else
    table.insert(lines, "⚠ No sync performed yet")
  end
  
  table.insert(lines, "")
  table.insert(lines, "Statistics:")
  table.insert(lines, string.format("  ↓ Imported:  %d events", M.sync_stats.imported))
  table.insert(lines, string.format("  ↑ Exported:  %d events", M.sync_stats.exported))
  table.insert(lines, string.format("  ✎ Updated:   %d events", M.sync_stats.updated))
  table.insert(lines, string.format("  ✗ Deleted:   %d events", M.sync_stats.deleted))
  
  if M.sync_stats.conflicts > 0 then
    table.insert(lines, string.format("  ⚠ Conflicts: %d events", M.sync_stats.conflicts))
  end
  
  if next(M.sync_stats.calendars) then
    table.insert(lines, "")
    table.insert(lines, "Per-Calendar Stats:")
    for calendar_id, stats in pairs(M.sync_stats.calendars) do
      table.insert(lines, string.format("  %s:", calendar_id))
      table.insert(lines, string.format("    Events: %d", stats.total or 0))
      if stats.last_sync then
        table.insert(lines, string.format("    Last sync: %s", stats.last_sync))
      end
    end
  end
  
  if #M.sync_stats.errors > 0 then
    table.insert(lines, "")
    table.insert(lines, "Recent Errors:")
    for i = math.max(1, #M.sync_stats.errors - 4), #M.sync_stats.errors do
      table.insert(lines, "  • " .. M.sync_stats.errors[i])
    end
  end
  
  table.insert(lines, "")
  table.insert(lines, "Press 'q' to close, 'r' to refresh, 's' to sync now")
  
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
  vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(bufnr, 'filetype', 'org-gcal-dashboard')
  
  local width = 60
  local height = math.min(#lines + 2, vim.o.lines - 4)
  local win_opts = {
    relative = 'editor',
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = 'minimal',
    border = 'rounded',
  }
  
  local winnr = vim.api.nvim_open_win(bufnr, true, win_opts)
  
  vim.api.nvim_buf_set_keymap(bufnr, 'n', 'q', '', {
    callback = function()
      vim.api.nvim_win_close(winnr, true)
    end,
    noremap = true,
    silent = true,
  })
  
  vim.api.nvim_buf_set_keymap(bufnr, 'n', 'r', '', {
    callback = function()
      vim.api.nvim_win_close(winnr, true)
      M.show()
    end,
    noremap = true,
    silent = true,
  })
  
  vim.api.nvim_buf_set_keymap(bufnr, 'n', 's', '', {
    callback = function()
      vim.api.nvim_win_close(winnr, true)
      vim.cmd("SyncOrgGcal")
      vim.defer_fn(function()
        M.show()
      end, 1000)
    end,
    noremap = true,
    silent = true,
  })
end

function M.add_error(error_msg)
  table.insert(M.sync_stats.errors, os.date("%H:%M:%S") .. " " .. error_msg)
  if #M.sync_stats.errors > 50 then
    table.remove(M.sync_stats.errors, 1)
  end
end

return M
