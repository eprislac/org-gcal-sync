# Advanced Features Guide

This guide covers the advanced features of org-gcal-sync.

## Table of Contents

1. [Multiple Calendar Support](#multiple-calendar-support)
2. [Recurring Events](#recurring-events)
3. [Conflict Resolution](#conflict-resolution)
4. [Sync Status Dashboard](#sync-status-dashboard)
5. [Per-Directory Calendar Mapping](#per-directory-calendar-mapping)
6. [Webhook Support (Real-time Sync)](#webhook-support)

---

## Multiple Calendar Support

### Overview

Sync with multiple Google Calendars simultaneously.

### Configuration

```lua
require("org-gcal-sync").setup({
  calendars = { "primary", "work@group.calendar.google.com", "personal@gmail.com" },
})
```

### List Available Calendars

```vim
:OrgGcalListCalendars
```

This will display all calendars you have access to with their IDs.

### How It Works

- Events from all configured calendars are imported
- The calendar ID is stored in the `:CALENDAR_ID:` property
- Events are created/updated in their respective calendars

---

## Recurring Events

### Overview

Support for Google Calendar recurring events with automatic expansion.

### Configuration

```lua
require("org-gcal-sync").setup({
  sync_recurring_events = true,  -- default: true
})
```

### How It Works

- Recurring events are automatically expanded into individual instances
- Each instance is stored as a separate org file
- The `:RECURRING_EVENT_ID:` property links instances to the parent event
- The `:RECURRENCE:` property stores the recurrence rule

### Example Org File

```org
#+title: Weekly Team Meeting
#+filetags: :gcal:

* Weekly Team Meeting
  SCHEDULED: <2025-11-01 10:00>
  :PROPERTIES:
  :GCAL_ID: abc123
  :CALENDAR_ID: primary
  :RECURRING_EVENT_ID: parent_event_id
  :RECURRENCE: ["RRULE:FREQ=WEEKLY;BYDAY=MO"]
  :END:
```

### Limitations

- Modifying recurrence rules must be done in Google Calendar
- Individual instance modifications are supported

---

## Conflict Resolution

### Overview

Handle conflicts when both local org files and Google Calendar events have been modified.

### Configuration

```lua
require("org-gcal-sync").setup({
  conflict_resolution = "ask",  -- Options: "ask", "local", "remote", "newest"
})
```

### Strategies

1. **ask** (default) - Show interactive UI for each conflict
2. **local** - Always keep local org file version
3. **remote** - Always keep Google Calendar version
4. **newest** - Keep the version with the latest modification time

### Interactive Resolution

When set to "ask", a conflict dialog appears:

```
=== CONFLICT DETECTED ===

Event: Team Meeting

LOCAL (Org File):
  Modified: 2025-10-29T14:30:00Z
  Title: Team Meeting
  Time: 2025-11-01 10:00
  Location: Conference Room A

REMOTE (Google Calendar):
  Modified: 2025-10-29T15:00:00Z
  Title: Team Meeting
  Time: 2025-11-01 10:00
  Location: Conference Room B

Choose: [l] Keep Local  [r] Keep Remote  [q] Skip
```

### Keyboard Shortcuts

- `l` - Keep local version
- `r` - Keep remote version
- `q` - Skip this conflict (don't sync)

---

## Sync Status Dashboard

### Overview

Visual dashboard showing sync statistics and status.

### Usage

```vim
:OrgGcalDashboard
```

Or enable auto-show after sync:

```lua
require("org-gcal-sync").setup({
  show_sync_status = true,  -- default: true
})
```

### Dashboard Features

```
╭─────────────────────────────────────────────────────────╮
│              Org-Gcal Sync Dashboard                    │
╰─────────────────────────────────────────────────────────╯

✓ Last sync: 2025-10-29 14:30:45

Statistics:
  ↓ Imported:  15 events
  ↑ Exported:  8 events
  ✎ Updated:   3 events
  ✗ Deleted:   2 events
  ⚠ Conflicts: 1 events

Per-Calendar Stats:
  primary:
    Events: 10
    Last sync: 2025-10-29 14:30:45
  work@group.calendar.google.com:
    Events: 5
    Last sync: 2025-10-29 14:30:45

Recent Errors:
  • 14:25:12 Failed to create event: Network timeout

Press 'q' to close, 'r' to refresh, 's' to sync now
```

### Keyboard Shortcuts

- `q` - Close dashboard
- `r` - Refresh dashboard
- `s` - Trigger sync and refresh

---

## Per-Directory Calendar Mapping

### Overview

Map different org directories to different Google Calendars.

### Configuration

```lua
require("org-gcal-sync").setup({
  org_dirs = {
    "~/org/work",
    "~/org/personal",
    "~/org/family",
  },
  per_directory_calendars = {
    ["~/org/work"] = "work@company.com",
    ["~/org/personal"] = "primary",
    ["~/org/family"] = "family@group.calendar.google.com",
  },
})
```

### How It Works

- Events from `~/org/work` are exported to `work@company.com`
- Events from `~/org/personal` are exported to `primary`
- Events from `~/org/family` are exported to `family@group.calendar.google.com`
- Unmapped directories default to `primary` calendar

### Use Cases

- Separate work and personal calendars
- Team-specific calendars
- Project-based calendar organization

---

## Webhook Support (Real-time Sync)

### Overview

Real-time synchronization using Google Calendar push notifications.

### Prerequisites

1. Public-facing server or ngrok tunnel
2. HTTPS endpoint (Google requires HTTPS for webhooks)
3. Port forwarding configured

### Configuration

```lua
require("org-gcal-sync").setup({
  webhook_port = 8080,
})
```

### Start Webhook Server

```vim
:OrgGcalWebhookStart
```

### Stop Webhook Server

```vim
:OrgGcalWebhookStop
```

### How It Works

1. Start the webhook server in Neovim
2. Google Calendar sends notifications when events change
3. Plugin automatically syncs on notification
4. No manual sync needed

### Setting Up with ngrok

```bash
# Start ngrok tunnel
ngrok http 8080

# Copy the HTTPS URL (e.g., https://abc123.ngrok.io)
```

Then configure:

```lua
require("org-gcal-sync").setup({
  webhook_port = 8080,
  webhook_public_host = "abc123.ngrok.io",
})
```

### Subscribing to Calendar Notifications

The plugin automatically subscribes to calendar notifications when the webhook server starts. Subscriptions last 7 days and are automatically renewed.

### Limitations

- Requires public HTTPS endpoint
- Webhooks expire after 7 days (auto-renewed if server running)
- Not suitable for offline-only setups

### Security Considerations

- Only expose webhook endpoint, not entire Neovim instance
- Use firewall rules to restrict access
- Validate webhook signatures (implemented in webhook.lua)
- Consider using VPN instead of public exposure

---

## Complete Example Configuration

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
      -- Basic settings
      agenda_dir = "~/org/gcal",
      org_roam_dirs = {
        "~/org/work",
        "~/org/personal",
      },
      
      -- Multiple calendars
      calendars = {
        "primary",
        "work@company.com",
        "family@group.calendar.google.com",
      },
      
      -- Per-directory mapping
      per_directory_calendars = {
        ["~/org/work"] = "work@company.com",
        ["~/org/personal"] = "primary",
      },
      
      -- Recurring events
      sync_recurring_events = true,
      
      -- Conflict resolution
      conflict_resolution = "ask",  -- or "local", "remote", "newest"
      
      -- Dashboard
      show_sync_status = true,
      
      -- Auto-sync
      auto_sync_on_save = true,
      enable_backlinks = true,
      
      -- Webhooks (optional)
      webhook_port = 8080,
    })
  end,
}
```

---

## Troubleshooting

### Multiple Calendars Not Syncing

- Run `:OrgGcalListCalendars` to verify calendar IDs
- Check that you have permission to access each calendar
- Verify calendar IDs in configuration are correct

### Recurring Events Creating Too Many Files

- Set `sync_recurring_events = false` to disable
- Adjust date range in `gcal_api.lua` for fewer instances
- Consider manual filtering

### Conflict Resolution UI Not Showing

- Check that `conflict_resolution = "ask"` is set
- Verify Neovim supports floating windows
- Check for errors in `:messages`

### Webhook Server Won't Start

- Check port is not already in use: `lsof -i :8080`
- Verify firewall allows incoming connections
- Check Neovim has permission to bind to port

### Dashboard Not Showing Stats

- Perform at least one sync first
- Check `show_sync_status = true` is set
- Try manually opening: `:OrgGcalDashboard`

---

## Performance Tips

### Large Number of Events

- Limit `calendars` to only necessary ones
- Reduce date range in sync functions
- Disable `sync_recurring_events` if not needed

### Frequent Syncs

- Use webhooks instead of auto-sync on save
- Increase sync interval for periodic syncs
- Use per-directory calendars to reduce scope

### Network Issues

- Implement retry logic (future enhancement)
- Check internet connectivity before sync
- Use local-first conflict resolution strategy
