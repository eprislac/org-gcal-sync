# Migration Guide

## Migrating from gcalcli to Google Calendar API

If you were using a previous version of org-gcal-sync that relied on gcalcli, follow these steps to migrate to the new API-based version.

### 1. Remove gcalcli (Optional)

The plugin no longer requires gcalcli. You can uninstall it if you're not using it elsewhere:

```bash
# If installed via pip
pip uninstall gcalcli

# If installed via package manager, use your system's method
```

### 2. Set Up Google Calendar API Credentials

Follow the instructions in the [README.md](README.md#google-calendar-api-setup) to:
1. Create a Google Cloud Project
2. Enable the Google Calendar API
3. Create OAuth 2.0 credentials
4. Set environment variables

### 3. Update Your Configuration

Your existing configuration should continue to work. The setup remains the same:

```lua
require("org-gcal-sync").setup({
  agenda_dir = "~/Syncthing/org/gcal",
  org_roam_dirs = { "~/Syncthing/org/personal", "~/Syncthing/org/work" },
  enable_backlinks = true,
})
```

### 4. Authenticate

Run the new authentication command in Neovim:

```vim
:OrgGcalAuth
```

This will:
- Open your browser to Google's OAuth consent page
- Prompt you to authorize the application
- Save the access token for future use

### 5. Initial Sync

After authentication, run:

```vim
:SyncOrgGcal
```

This will:
- Add `:GCAL_ID:` properties to existing events
- Ensure all events are properly tracked
- Synchronize any changes

### 6. Benefits of the New Version

- **No external dependencies**: No need to install or maintain gcalcli
- **Better sync**: Updates and deletions are now synchronized
- **Event tracking**: Events are tracked by ID, preventing duplicates
- **More reliable**: Direct API access is faster and more stable
- **Better error messages**: See exactly what went wrong

### Troubleshooting

#### My existing events don't have GCAL_ID properties

The first sync after migration will:
1. Match existing org events to Google Calendar by title and timestamp
2. Add the `:GCAL_ID:` property automatically
3. Future syncs will use the ID for accurate tracking

If you have duplicate events after the first sync, you can:
- Manually delete duplicates
- Remove all events from `agenda_dir` and re-import from Google Calendar

#### Token refresh issues

If you see "Token expired" errors:
- Run `:OrgGcalAuth` again to re-authenticate
- Check that your refresh token is properly saved
- Verify environment variables are set correctly

#### Events not syncing

Run `:checkhealth org-gcal-sync` to verify:
- Environment variables are set
- API is reachable
- plenary.nvim is installed
