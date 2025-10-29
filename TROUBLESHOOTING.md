# Troubleshooting Guide

## Common Issues and Solutions

### Authentication Issues

#### "Missing GCAL_ORG_SYNC_CLIENT_ID or GCAL_ORG_SYNC_CLIENT_SECRET"

**Cause:** Environment variables not set or not accessible to Neovim.

**Solution:**
1. Add to your shell config (`.bashrc`, `.zshrc`, etc.):
   ```bash
   export GCAL_ORG_SYNC_CLIENT_ID="your-id.apps.googleusercontent.com"
   export GCAL_ORG_SYNC_CLIENT_SECRET="your-secret"
   ```
2. Reload shell: `source ~/.zshrc` (or restart terminal)
3. Verify: `echo $GCAL_ORG_SYNC_CLIENT_ID`
4. Restart Neovim

#### "No token found. Please authenticate first"

**Cause:** Haven't authenticated yet or token file was deleted.

**Solution:**
```vim
:OrgGcalAuth
```
Follow the authentication flow.

#### "Token expired. Please re-authenticate"

**Cause:** Token expired and refresh failed (rare).

**Solution:**
```vim
:OrgGcalAuth
```
This will generate a new token.

#### "Failed to refresh token"

**Cause:** Invalid client credentials or revoked access.

**Solution:**
1. Verify environment variables are correct
2. Check if app was disabled in Google Cloud Console
3. Re-authenticate: `:OrgGcalAuth`

### Sync Issues

#### Events not appearing in org files after ImportGcal

**Possible Causes & Solutions:**

1. **No events in date range**
   - Plugin fetches events from 7 days ago to 90 days in future
   - Check if events are in this range

2. **API call failed**
   - Check `:messages` for errors
   - Run `:checkhealth org-gcal-sync`

3. **Permission issues**
   - Ensure `agenda_dir` is writable
   - Check Neovim messages for file write errors

#### Org tasks not appearing in Google Calendar after ExportOrg

**Possible Causes & Solutions:**

1. **Invalid timestamp format**
   - Use format: `<YYYY-MM-DD HH:MM>`
   - Example: `<2025-11-01 14:00>`
   - Not: `<11/01/2025 2:00 PM>`

2. **No SCHEDULED or DEADLINE**
   - Events must have `SCHEDULED:` or `DEADLINE:` line
   - Example:
     ```org
     * Meeting
       SCHEDULED: <2025-11-01 10:00>
     ```

3. **Outside org_roam_dirs**
   - Check file is in one of the configured directories
   - Verify `org_roam_dirs` in setup

4. **API error**
   - Check `:messages` for detailed error
   - Verify internet connection

#### Duplicate events created

**Cause:** Event doesn't have `:GCAL_ID:` property.

**Solution:**
1. Manually add `:GCAL_ID:` from Google Calendar
2. Or delete duplicates and re-sync
3. Future syncs will track by ID

#### Updates not syncing

**Cause:** `:GCAL_UPDATED:` timestamp comparison.

**Solution:**
1. The version with the latest update wins
2. To force update: delete `:GCAL_UPDATED:` property
3. Run `:SyncOrgGcal`

### Health Check Failures

#### "plenary.nvim is not installed"

**Solution:**
Install plenary.nvim via your package manager:

```lua
-- lazy.nvim
{ "nvim-lua/plenary.nvim" }

-- packer
use "nvim-lua/plenary.nvim"
```

#### "Google Calendar API is not reachable"

**Possible Causes:**
1. No internet connection
2. Firewall blocking googleapis.com
3. Google services temporarily down

**Solution:**
1. Check internet connection
2. Try: `curl https://www.googleapis.com/calendar/v3/users/me/calendarList`
3. Check firewall/proxy settings

### Performance Issues

#### Sync takes a long time

**Causes:**
- Large number of events
- Slow internet connection
- Many org-roam directories to scan

**Solutions:**
1. Reduce date range (modify `time_min`/`time_max` in `gcal_api.lua`)
2. Limit `org_roam_dirs` to essential directories
3. Run sync less frequently
4. Consider splitting calendars

#### High API usage

**Solution:**
- Google Calendar API has generous quotas (1M queries/day)
- Each sync makes ~2-3 API calls
- Should not be an issue for normal usage
- If concerned, reduce sync frequency

### File Format Issues

#### Backlinks not created

**Causes:**
1. `enable_backlinks = false` in config
2. No mentions of event title in other notes
3. grep not finding matches

**Solutions:**
1. Enable backlinks:
   ```lua
   require("org-gcal-sync").setup({
     enable_backlinks = true,
   })
   ```
2. Ensure event title appears in other org files
3. Check grep is available: `which grep`

#### Properties not parsing correctly

**Cause:** Incorrect org-mode syntax.

**Solution:**
Properties must be in proper format:
```org
* Event Title
  SCHEDULED: <2025-11-01 10:00>
  :PROPERTIES:
  :GCAL_ID: abc123
  :LOCATION: Office
  :END:
```

Common mistakes:
- Missing `:PROPERTIES:` or `:END:`
- Extra spaces in property names
- Properties outside headline

### Debug Mode

Enable detailed logging:

```lua
-- In your config
vim.g.org_gcal_sync_debug = true
```

Then check:
```vim
:messages
```

### Getting Help

1. Run `:checkhealth org-gcal-sync`
2. Check `:messages` for errors
3. Review the [README](README.md)
4. Check [MIGRATION.md](MIGRATION.md) if upgrading
5. Open an issue on GitHub with:
   - Neovim version (`:version`)
   - Health check output
   - Error messages
   - Steps to reproduce

### Manual Token Reset

If you need to completely reset authentication:

```bash
rm ~/.local/share/nvim/org-gcal-sync/token.json
```

Then re-authenticate:
```vim
:OrgGcalAuth
```

### Verifying Configuration

Check your current configuration:

```vim
:lua print(vim.inspect(require("org-gcal-sync").config))
```

Check environment variables:

```vim
:lua print(vim.env.GCAL_ORG_SYNC_CLIENT_ID)
:lua print(vim.env.GCAL_ORG_SYNC_CLIENT_SECRET)
```

### Known Limitations

1. **Recurring events**: Not fully supported yet
2. **Multiple calendars**: Only "primary" calendar supported
3. **Timezones**: All times converted to UTC
4. **Event attachments**: Not synced
5. **Attendees**: Not synced

These may be addressed in future versions.
