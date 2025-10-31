# org-gcal-sync
A Neovim plugin to synchronize Google Calendar events with org-mode notes,
featuring full bidirectional sync, agenda integration, and optional org-roam backlinks.

## Why?

I've been using orgmode in Neovim, and I wanted to be able to sync my agenda 
files. Google Calendar is my primary calendar service, so I built this plugin 
to bridge the gap. It allows me to keep my org notes and tasks in sync with my 
Google Calendar events, ensuring I never miss an important meeting or deadline.

---

## Features

- GCal → org notes with `#+title`, `SCHEDULED`, and optional `ROAM_REFS`
- org tasks → GCal
- **Appears in `org-agenda`**
- **Backlinks** to any note mentioning the event (requires org-roam)
- **Duplicate-safe** with event ID tracking
- **Unit tested**
- **Advanced sync**: Updates and deletions are synchronized bidirectionally
- **Direct Google Calendar API integration** (no external dependencies)
- **Auto-sync on save**: Automatically syncs when saving org files with scheduled events
- **Multiple calendars**: Sync with multiple Google Calendars
- **Recurring events**: Full support for recurring event patterns
- **Conflict resolution**: Smart conflict detection with interactive resolution UI
- **Sync dashboard**: Visual status dashboard with statistics
- **Per-directory calendars**: Map different org directories to different calendars
- **Webhook support**: Real-time sync via Google Calendar push notifications
- **Optional org-roam integration**: Works with or without org-roam

---

## Prerequisites

- Neovim 0.9+
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [nvim-orgmode/orgmode](https://github.com/nvim-orgmode/orgmode)
- [org-roam.nvim](https://github.com/jmbuhr/org-roam.nvim) (optional, for backlinks)
- Google Calendar API credentials (see setup below)

---

## Google Calendar API Setup

### 1. Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the **Google Calendar API**:
   - Navigate to "APIs & Services" > "Library"
   - Search for "Google Calendar API"
   - Click "Enable"

### 2. Create OAuth 2.0 Credentials

1. Go to "APIs & Services" > "Credentials"
2. Click "Create Credentials" > "OAuth client ID"
3. If prompted, configure the OAuth consent screen:
   - Choose "External" for user type
   - Fill in app name and your email
   - Add scope: `https://www.googleapis.com/auth/calendar`
4. For application type, select "Desktop app"
5. Give it a name (e.g., "org-gcal-sync")
6. Click "Create"
7. Download the credentials JSON or copy the Client ID and Client Secret

### 3. Set Environment Variables

Add these to your shell configuration (`.bashrc`, `.zshrc`, etc.):

```bash
export GCAL_ORG_SYNC_CLIENT_ID="your-client-id-here.apps.googleusercontent.com"
export GCAL_ORG_SYNC_CLIENT_SECRET="your-client-secret-here"
```

Reload your shell or restart Neovim to apply the changes.

---

## Install (lazy.nvim)

### With org-roam (recommended for backlinks)

```lua
{
  "eprislac/org-gcal-sync",
  dependencies = { 
    "nvim-lua/plenary.nvim",
    "nvim-orgmode/orgmode", 
    "jmbuhr/org-roam.nvim"  -- optional
  },
  config = function()
    require("org-gcal-sync").setup({
      org_dirs = { "~/org/personal", "~/org/work" },
      enable_backlinks = true,  -- requires org-roam
      auto_sync_on_save = true,
      
      -- Advanced features (optional)
      calendars = { "primary" },  -- Add more calendars: { "primary", "work@company.com" }
      sync_recurring_events = true,
      conflict_resolution = "ask",  -- "ask", "local", "remote", or "newest"
      show_sync_status = true,
      -- per_directory_calendars = { ["~/org/work"] = "work@company.com" },
      -- webhook_port = 8080,
    })
  end,
}
```

### Without org-roam (basic sync only)

```lua
{
  "eprislac/org-gcal-sync",
  dependencies = { 
    "nvim-lua/plenary.nvim",
    "nvim-orgmode/orgmode"
  },
  config = function()
    require("org-gcal-sync").setup({
      org_dirs = { "~/org" },
      enable_backlinks = false,  -- org-roam not available
      auto_sync_on_save = true,
    })
  end,
}
```

**See [ADVANCED_FEATURES.md](ADVANCED_FEATURES.md) for detailed configuration options.**

---

## Authentication

After installation and setting up environment variables:

1. Run `:OrgGcalAuth` in Neovim
2. Your browser will open to Google's OAuth consent page
3. Authorize the application
4. Copy the authorization code from the browser
5. Paste it into the Neovim prompt
6. Authentication token will be saved to `~/.local/share/nvim/org-gcal-sync/token.json`

The token will be automatically refreshed when needed.

---

## Usage

### Commands

- `:SyncOrgGcal` - Full bidirectional sync (export + import)
- `:ImportGcal` - Import events from Google Calendar to org files
- `:ExportOrg` - Export org tasks to Google Calendar
- `:OrgGcalAuth` - Authenticate with Google Calendar
- `:OrgGcalDashboard` - Show sync status dashboard
- `:OrgGcalListCalendars` - List available calendars
- `:OrgGcalWebhookStart` - Start webhook server for real-time sync
- `:OrgGcalWebhookStop` - Stop webhook server

### What Gets Synced

**From Google Calendar to Org:**
- Event title → `#+title` and headline
- Start time → `SCHEDULED`
- Location → `:LOCATION:` property
- Description → body text
- Event ID → `:GCAL_ID:` property (for tracking updates/deletions)
- Last modified time → `:GCAL_UPDATED:` property

**From Org to Google Calendar:**
- TODO/NEXT items with `SCHEDULED` or `DEADLINE` timestamps
- Scheduled TODOs → Google Calendar events (with times)
- Unscheduled TODOs → Google Tasks
- `:LOCATION:` property → Event location
- Body text → Event description
- Updates existing events if they have a `:GCAL_ID:` property

### Timestamp Formats

The plugin supports standard org-mode timestamp formats:

**Timed events (with specific time):**
```org
* TODO Take Blood Pressure
  SCHEDULED: <2025-10-30 Thu 10:00 .+1d>
```
→ Creates calendar event at **10:00 AM - 10:30 AM** (30-minute default duration)

**Timed events with time range:**
```org
* TODO Team Meeting
  SCHEDULED: <2025-10-30 Thu 14:00>--<2025-10-30 Thu 15:30>
```
→ Creates calendar event at **2:00 PM - 3:30 PM**

**All-day events (date only):**
```org
* TODO Review Documents
  SCHEDULED: <2025-10-30 Sat>
```
→ Creates **all-day** event on Oct 30

**Recurring events:**
```org
* TODO Daily Standup
  SCHEDULED: <2025-10-30 Thu 09:00 .+1d>
```
→ Repeats daily (`.+1d` = daily, `.+1w` = weekly, `.+1m` = monthly)

**Priority tags are supported:**
```org
* TODO [#A] High Priority Task
  SCHEDULED: <2025-10-30 Thu 10:00>
```

### Event Tracking

Events are tracked using:
1. Google Calendar Event ID (stored in `:GCAL_ID:`)
2. Fallback to title + timestamp matching

This ensures:
- Updates to events are synchronized correctly
- Events deleted from Google Calendar are removed from org files
- No duplicate events are created

---

## Health Check

Run `:checkhealth org-gcal-sync` to verify:
- Environment variables are set
- Google Calendar API is reachable
- plenary.nvim is installed

---

## File Format

**Example: Imported calendar event**
```org
:PROPERTIES:
:ID: 8b2c3d3e-9800-4186-80e5-d07ce7bc5327
:END:
#+title: Team Standup
#+filetags: :gcal:

* Team Standup
  SCHEDULED: <2025-11-01 Fri 14:00>--<2025-11-01 Fri 14:30>
  :PROPERTIES:
  :GCAL_ID: abc123xyz
  :LOCATION: Conference Room A
  :GCAL_UPDATED: 2025-10-29T10:00:00Z
  :END:

  Discussion points for the daily standup meeting.
```

**Example: TODO that syncs to calendar**
```org
:PROPERTIES:
:ID: 2F80BBB3-F46C-42E5-9831-C25DDCD060C0
:CATEGORY: Work
:END:
#+TITLE Daily Review
#+FILETAGS: #work #routine

* TODO [#A] Daily Review
  SCHEDULED: <2025-10-30 Thu 17:00 .+1d>--<2025-10-30 Thu 17:30>
  :PROPERTIES:
  :GCAL_ID: xyz789abc
  :LAST_REPEAT: [2025-10-29 Wed 17:25]
  :END:
  :LOGBOOK:
    - State "DONE" from "TODO" [2025-10-29 Wed 17:25]
  :END:

  Review tasks and plan tomorrow.
```

**Example: Unscheduled TODO that syncs to Google Tasks**
```org
* TODO [#B] Research new library
  :PROPERTIES:
  :GCAL_ID: task_def456
  :END:

  Look into the new data processing library for the project.
```

---

## Testing

Run tests with:

```bash
nvim --headless -c "PlenaryBustedDirectory tests/plenary { minimal_init = 'tests/minimal_init.lua' }"
```

Tests mock the Google Calendar API to avoid requiring actual credentials during testing.

---

## Troubleshooting

### "No token found" error
- Run `:OrgGcalAuth` to authenticate
- Check that environment variables are set correctly

### "Token expired" error
- The plugin should auto-refresh, but if it fails, run `:OrgGcalAuth` again

### Events not syncing
- Check `:checkhealth org-gcal-sync`
- Verify your org files have `SCHEDULED` or `DEADLINE` timestamps
- Make sure TODOs are marked with `TODO` or `NEXT` keywords
- Ensure timestamps follow org-mode format:
  - Timed: `<2025-10-30 Thu 10:00>` or `<2025-10-30 10:00>`
  - All-day: `<2025-10-30>` or `<2025-10-30 Thu>`
  - Range: `<2025-10-30 Thu 10:00>--<2025-10-30 Thu 11:00>`
  
### Events appearing as all-day when they shouldn't
- Make sure your timestamp includes a time: `<2025-10-30 Thu 10:00>`
- Date-only timestamps `<2025-10-30>` create all-day events by design
- Time ranges use `--` separator: `<START>--<END>`

### Duplicate events
- The plugin automatically detects and removes duplicates
- Check for events with the same `:GCAL_ID:` property
- Run `:SyncOrgGcal` to clean up duplicates automatically

### Tasks not appearing in Google Tasks
- Unscheduled TODOs sync to Google Tasks
- Make sure the TODO doesn't have a `SCHEDULED` or `DEADLINE` timestamp
- Scheduled TODOs go to Google Calendar, not Tasks

### API rate limits
- Google Calendar API has quotas (usually 1,000,000 queries/day)
- The plugin batches requests efficiently, but be mindful with very large calendars

---

## License

MIT
