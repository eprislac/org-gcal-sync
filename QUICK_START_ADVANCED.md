# Quick Start: Advanced Features

This guide gets you started with the advanced features in under 5 minutes.

## Basic Setup (Already Done)

If you haven't already:
1. Set environment variables `GCAL_ORG_SYNC_CLIENT_ID` and `GCAL_ORG_SYNC_CLIENT_SECRET`
2. Run `:OrgGcalAuth` to authenticate
3. Run `:SyncOrgGcal` to test basic sync

## Feature Quick Starts

### 1. Multiple Calendars (2 minutes)

**Step 1:** List your calendars
```vim
:OrgGcalListCalendars
```

**Step 2:** Update your config
```lua
require("org-gcal-sync").setup({
  calendars = {
    "primary",
    "work@company.com",  -- Use IDs from step 1
  },
})
```

**Step 3:** Sync
```vim
:SyncOrgGcal
```

Done! Events from both calendars are now synced.

---

### 2. Conflict Resolution (30 seconds)

**Just add to config:**
```lua
require("org-gcal-sync").setup({
  conflict_resolution = "ask",  -- Shows UI when conflicts occur
})
```

When a conflict occurs, you'll see a popup:
- Press `l` to keep local version
- Press `r` to keep remote version
- Press `q` to skip

---

### 3. Sync Dashboard (15 seconds)

**Already enabled by default!**

Just run:
```vim
:OrgGcalDashboard
```

Or disable auto-show:
```lua
require("org-gcal-sync").setup({
  show_sync_status = false,  -- Don't auto-show after sync
})
```

---

### 4. Per-Directory Calendars (1 minute)

**Map work notes to work calendar:**

```lua
require("org-gcal-sync").setup({
  org_roam_dirs = {
    "~/org/work",
    "~/org/personal",
  },
  calendars = {
    "primary",
    "work@company.com",
  },
  per_directory_calendars = {
    ["~/org/work"] = "work@company.com",
    ["~/org/personal"] = "primary",
  },
})
```

Done! Work events go to work calendar, personal to primary.

---

### 5. Recurring Events (Already Enabled)

**No setup needed!** Recurring events are handled automatically.

To disable:
```lua
require("org-gcal-sync").setup({
  sync_recurring_events = false,
})
```

Recurring events will show:
```org
:PROPERTIES:
:RECURRING_EVENT_ID: parent_event_123
:RECURRENCE: ["RRULE:FREQ=WEEKLY;BYDAY=MO"]
:END:
```

---

### 6. Webhooks (Advanced - 5 minutes)

**Prerequisites:**
- Public HTTPS endpoint
- Use ngrok for testing

**Step 1:** Start ngrok
```bash
ngrok http 8080
```

Copy the HTTPS URL (e.g., `https://abc123.ngrok.io`)

**Step 2:** Configure webhook
```lua
require("org-gcal-sync").setup({
  webhook_port = 8080,
})
```

**Step 3:** Start webhook server
```vim
:OrgGcalWebhookStart
```

Done! Now changes in Google Calendar trigger automatic sync.

**To stop:**
```vim
:OrgGcalWebhookStop
```

---

## Complete Example Config

```lua
{
  "eprislac/org-gcal-sync",
  dependencies = { 
    "nvim-lua/plenary.nvim",
    "nvim-orgmode/orgmode", 
    "jmbuhr/org-roam.nvim" 
  },
  config = function()
    require("org-gcal-sync").setup({
      -- Basic
      agenda_dir = "~/org/gcal",
      org_roam_dirs = { "~/org/work", "~/org/personal" },
      enable_backlinks = true,
      auto_sync_on_save = true,
      
      -- Multiple calendars
      calendars = { "primary", "work@company.com" },
      
      -- Per-directory mapping
      per_directory_calendars = {
        ["~/org/work"] = "work@company.com",
        ["~/org/personal"] = "primary",
      },
      
      -- Recurring events (default: true)
      sync_recurring_events = true,
      
      -- Conflict resolution
      conflict_resolution = "ask",  -- or "local", "remote", "newest"
      
      -- Dashboard (default: true)
      show_sync_status = true,
      
      -- Webhooks (optional)
      -- webhook_port = 8080,
    })
  end,
}
```

---

## Troubleshooting

### "Calendar not found"
- Run `:OrgGcalListCalendars` to see available calendars
- Check spelling of calendar ID in config
- Verify you have access to the calendar

### Dashboard not showing
- Run `:OrgGcalDashboard` manually
- Perform at least one sync first
- Check `show_sync_status = true` in config

### Webhook server won't start
- Check port not in use: `lsof -i :8080`
- Try different port in config
- Check firewall settings

### Conflicts not showing UI
- Verify `conflict_resolution = "ask"`
- Check that events actually conflict (different content, same ID)
- Look for errors in `:messages`

---

## Next Steps

1. **Read the full guide:** `ADVANCED_FEATURES.md`
2. **Check examples:** `example_config.lua`
3. **Troubleshooting:** `TROUBLESHOOTING.md`
4. **Implementation details:** `IMPLEMENTATION_SUMMARY.md`

---

## Key Commands Reference

| Command | What It Does |
|---------|-------------|
| `:OrgGcalDashboard` | Show stats |
| `:OrgGcalListCalendars` | See available calendars |
| `:OrgGcalWebhookStart` | Start real-time sync |
| `:OrgGcalWebhookStop` | Stop real-time sync |
| `:SyncOrgGcal` | Manual sync |

---

## Tips

💡 **Start simple:** Enable features one at a time
💡 **Use dashboard:** Keep an eye on sync stats
💡 **Per-directory calendars:** Great for work/life separation
💡 **Webhooks:** Best for heavy calendar users
💡 **Conflicts:** Use "ask" strategy until you're comfortable

Happy syncing! 🎉
