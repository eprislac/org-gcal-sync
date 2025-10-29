# org-gcal-sync

**Full bidirectional sync**: `org-roam` ↔ Google Calendar with **agenda integration**, **backlinks**, and **unit tests**.

---

## Features

- GCal → org-roam notes with `#+title`, `SCHEDULED`, `ROAM_REFS`
- org-roam tasks → GCal
- **Appears in `org-agenda`**
- **Backlinks** to any note mentioning the event
- **Duplicate-safe** with event ID tracking
- **Syncthing-ready**
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

---

## Prerequisites

- Neovim 0.9+
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [nvim-orgmode/orgmode](https://github.com/nvim-orgmode/orgmode)
- [org-roam.nvim](https://github.com/jmbuhr/org-roam.nvim)
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
      agenda_dir = "~/Syncthing/org/gcal",
      org_roam_dirs = { "~/Syncthing/org/personal", "~/Syncthing/org/work" },
      enable_backlinks = true,
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
- Headline title → Event summary
- `SCHEDULED` or `DEADLINE` → Event time
- `:LOCATION:` property → Event location
- Body text → Event description
- Updates existing events if they have a `:GCAL_ID:` property

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

Generated org files look like:

```org
#+title: Team Standup
#+filetags: :gcal:

* Team Standup
  SCHEDULED: <2025-11-01 14:00>
  :PROPERTIES:
  :GCAL_ID: abc123xyz
  :LOCATION: Conference Room A
  :GCAL_UPDATED: 2025-10-29T10:00:00Z
  :END:

  Discussion points for the daily standup meeting.
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
- Make sure the timestamp format is correct: `<YYYY-MM-DD HH:MM>`

### API rate limits
- Google Calendar API has quotas (usually 1,000,000 queries/day)
- The plugin batches requests efficiently, but be mindful with very large calendars

---

## License

MIT
