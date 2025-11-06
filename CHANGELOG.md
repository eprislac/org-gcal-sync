# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Changed
- **BREAKING**: Replaced gcalcli dependency with direct Google Calendar API integration
- Authentication now uses OAuth 2.0 with environment variables (`GCAL_ORG_SYNC_CLIENT_ID` and `GCAL_ORG_SYNC_CLIENT_SECRET`)
- Health check now validates API credentials and connectivity instead of gcalcli binary

### Added
- Direct Google Calendar API support via plenary.nvim's curl wrapper
- Event tracking using Google Calendar event IDs (`:GCAL_ID:` property)
- Update synchronization - changes to events are now synced bidirectionally
- Deletion synchronization - events deleted in Google Calendar are removed from org files
- `:GCAL_UPDATED:` property to track last modification time
- New `:OrgGcalAuth` command for OAuth authentication
- Automatic token refresh when access token expires
- Comprehensive setup documentation in README
- Example configuration file
- **Auto-sync on save** - Automatically syncs when saving org files containing SCHEDULED/DEADLINE items (configurable via `auto_sync_on_save` option)
- **Multiple calendar support** - Sync with multiple Google Calendars simultaneously
- **Recurring event support** - Full support for Google Calendar recurring events with automatic expansion
- **Conflict resolution UI** - Interactive conflict resolution with multiple strategies (ask, local, remote, newest)
- **Sync status dashboard** - Visual dashboard showing sync statistics, per-calendar stats, and recent errors
- **Per-directory calendar mapping** - Map different org-roam directories to different calendars
- **Webhook support** - Real-time sync using Google Calendar push notifications (experimental)

### Improved
- Event matching now uses event IDs for more reliable tracking
- Bidirectional sync now handles updates and deletions
- Export function now updates existing events instead of creating duplicates
- Better error messages with detailed API error information
- Tests now mock Google Calendar API calls instead of gcalcli

### Removed
- gcalcli dependency (no longer needed)
- Shell command execution for calendar operations

### Fixed
- Event export now correctly handles event metadata (location, description)
- Timezone handling improved with UTC conversion
- Property parsing in org files more robust
- **CRITICAL**: Authentication failures no longer cause deletion of local files - sync now aborts safely when Google API is unreachable or token refresh fails
