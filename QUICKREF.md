# Quick Reference

## Commands

| Command | Description |
|---------|-------------|
| `:OrgGcalAuth` | Authenticate with Google Calendar (first-time setup) |
| `:SyncOrgGcal` | Full bidirectional sync (export + import) |
| `:ImportGcal` | Import events from Google Calendar to org files |
| `:ExportOrg` | Export org tasks to Google Calendar |
| `:checkhealth org-gcal-sync` | Verify configuration and dependencies |

## File Format

### Generated Event Files

```org
#+title: Event Title
#+filetags: :gcal:

* Event Title
  SCHEDULED: <2025-11-01 14:00>
  :PROPERTIES:
  :GCAL_ID: abc123xyz
  :LOCATION: Conference Room A
  :GCAL_UPDATED: 2025-10-29T10:00:00Z
  :END:

  Event description goes here.
```

### Properties Reference

| Property | Description |
|----------|-------------|
| `:GCAL_ID:` | Google Calendar event ID (auto-generated, used for sync tracking) |
| `:LOCATION:` | Event location |
| `:GCAL_UPDATED:` | Last modification timestamp from Google Calendar |

## Environment Variables

```bash
# Required
export GCAL_ORG_SYNC_CLIENT_ID="your-client-id.apps.googleusercontent.com"
export GCAL_ORG_SYNC_CLIENT_SECRET="your-client-secret"
```

## Configuration Options

```lua
require("org-gcal-sync").setup({
  -- Where to store calendar event org files
  agenda_dir = "~/org/gcal",
  
  -- Your org-roam directories to scan for scheduled tasks
  org_roam_dirs = { "~/org/personal", "~/org/work" },
  
  -- Enable/disable automatic backlinks
  enable_backlinks = true,
  
  -- Auto-sync when saving org files with SCHEDULED/DEADLINE
  auto_sync_on_save = true,
})
```

## Workflow Examples

### Initial Setup

```vim
" 1. Set environment variables (in shell)
" 2. Start Neovim
" 3. Authenticate
:OrgGcalAuth

" 4. Import existing events
:ImportGcal
```

### Daily Usage

```vim
" Sync everything (recommended)
:SyncOrgGcal

" Or sync in parts:
:ExportOrg    " Send your org tasks to Google Calendar
:ImportGcal   " Get new Google Calendar events
```

### Creating Events

**Option 1: In org files**
```org
* Team Meeting
  SCHEDULED: <2025-11-01 10:00>
  :PROPERTIES:
  :LOCATION: Conference Room
  :END:
  
  Discuss project roadmap
```
Then run `:ExportOrg`

**Option 2: In Google Calendar**
- Create event in Google Calendar (web/mobile)
- Run `:ImportGcal` in Neovim

### Updating Events

Changes in either location will sync:
- Edit the org file and run `:SyncOrgGcal`
- Edit in Google Calendar and run `:SyncOrgGcal`

The event with the latest modification time wins.

### Deleting Events

**Delete from Google Calendar:**
- Delete in Google Calendar
- Run `:ImportGcal`
- The org file will be automatically deleted

**Delete from org:**
- Delete the org file
- The event remains in Google Calendar
- To delete from both: delete the event in Google Calendar

## Troubleshooting

### Check Health

```vim
:checkhealth org-gcal-sync
```

### Common Issues

| Issue | Solution |
|-------|----------|
| "No token found" | Run `:OrgGcalAuth` |
| "Token expired" | Run `:OrgGcalAuth` again |
| Events not syncing | Check `:checkhealth` and verify timestamp format `<YYYY-MM-DD HH:MM>` |
| Duplicate events | Ensure event has `:GCAL_ID:` property; delete duplicates and re-sync |

### Debug Mode

Add to your config for verbose logging:

```lua
vim.g.org_gcal_sync_debug = true
```

## Automation Ideas

### Auto-sync on Save (Built-in)

By default, the plugin automatically syncs when you save an org file that contains `SCHEDULED:` or `DEADLINE:` items. This is controlled by the `auto_sync_on_save` option:

```lua
require("org-gcal-sync").setup({
  auto_sync_on_save = true,  -- default, syncs on save
})
```

To disable auto-sync and sync manually:

```lua
require("org-gcal-sync").setup({
  auto_sync_on_save = false,  -- manual sync only
})
```

### Periodic Sync (every 5 minutes)

```lua
local timer = vim.loop.new_timer()
timer:start(300000, 300000, vim.schedule_wrap(function()
  require("org-gcal-sync").sync()
end))
```
