# Data Preservation in org-gcal-sync

## Smart Selective Sync

**The plugin intelligently syncs changes while preserving org-mode features.**

### What Updates from Google Calendar:
✅ Event title (if changed)  
✅ Event time/date (if changed)  
✅ Event location (if changed)  
✅ Google Calendar properties (GCAL_ID, GCAL_UPDATED)

### What NEVER Changes (Org-Specific):
❌ File-level properties (`:ID:`, `:CATEGORY:`)  
❌ Frontmatter (`#+TITLE`, `#+FILETAGS`)  
❌ Priority tags (`[#A]`, `[#B]`, `[#C]`)  
❌ TODO/NEXT keywords  
❌ LOGBOOK entries  
❌ Custom properties (`:LAST_REPEAT:`, etc.)  
❌ Repeaters (`.+1d`, `.+1w`) - unless time changed  
❌ Timespans (`<start>--<end>`) - format preserved

## How It Works

### Smart Timestamp Updates

**If Google Calendar time unchanged:**
```org
SCHEDULED: <2025-10-31 Thu 08:00 .+1d>--<2025-10-31 Thu 08:05>
```
→ Preserved exactly (including repeater, timespan, day name)

**If Google Calendar time changed to 09:00:**
```org
SCHEDULED: <2025-10-31 Thu 09:00 .+1d>--<2025-10-31 Thu 09:05>
```
→ Time updated, repeater and timespan format preserved

### Title Updates

**Headline preserves structure:**
```org
* TODO [#A] Old Title
```

**After Google Calendar title change:**
```org
* TODO [#A] New Title
```
→ TODO keyword and priority preserved, title updated

### Property Updates

**Only Google Calendar properties update:**
```org
:PROPERTIES:
:GCAL_ID: abc123           ← Updates if event ID changes
:GCAL_UPDATED: 2025-10-31  ← Updates with sync time
:LOCATION: New Location    ← Updates if location changes
:LAST_REPEAT: [...]        ← NEVER touched (org-specific)
:CATEGORY: Health          ← NEVER touched (org-specific)
:CUSTOM: value             ← NEVER touched (org-specific)
:END:
```

## Complete Example

### Your Local TODO File:
```org
:PROPERTIES:
:ID: 2F80BBB3-F46C-42E5-9831-C25DDCD060C0
:CATEGORY: Health
:END:
#+TITLE Take Blood Pressure  
#+FILETAGS: #health #routine

* TODO [#A] Take Blood Pressure
  SCHEDULED: <2025-10-31 Thu 08:00 .+1d>--<2025-10-31 Thu 08:05>
  :PROPERTIES:
  :GCAL_ID: abc123
  :LAST_REPEAT: [2025-10-30 Wed 08:05]
  :GCAL_UPDATED: 2025-10-30T12:00:00Z
  :LOCATION: Home
  :END:
  :LOGBOOK:
  - State "DONE" from "TODO" [2025-10-30 Wed 08:05]
  - State "DONE" from "TODO" [2025-10-29 Tue 08:02]
  :END:

  Take blood pressure and log results.
```

### Scenario 1: Title Changed in Google Calendar

**Google Calendar change:** "Take Blood Pressure" → "Take BP and Log"

**After sync:**
```org
:PROPERTIES:
:ID: 2F80BBB3-F46C-42E5-9831-C25DDCD060C0  ← Unchanged
:CATEGORY: Health                              ← Unchanged
:END:
#+TITLE Take Blood Pressure                   ← Unchanged (frontmatter preserved)
#+FILETAGS: #health #routine                   ← Unchanged

* TODO [#A] Take BP and Log                   ← Title updated
  SCHEDULED: <2025-10-31 Thu 08:00 .+1d>--<2025-10-31 Thu 08:05>  ← Unchanged
  :PROPERTIES:
  :GCAL_ID: abc123                             ← Unchanged
  :LAST_REPEAT: [2025-10-30 Wed 08:05]         ← Unchanged
  :GCAL_UPDATED: 2025-10-31T16:00:00Z          ← Updated
  :LOCATION: Home                              ← Unchanged
  :END:
  :LOGBOOK:                                    ← Unchanged
  - State "DONE" from "TODO" [2025-10-30 Wed 08:05]
  - State "DONE" from "TODO" [2025-10-29 Tue 08:02]
  :END:

  Take blood pressure and log results.         ← Unchanged
```

### Scenario 2: Time Changed in Google Calendar

**Google Calendar change:** 08:00 → 09:00

**After sync:**
```org
* TODO [#A] Take Blood Pressure                ← Unchanged
  SCHEDULED: <2025-10-31 Thu 09:00 .+1d>--<2025-10-31 Thu 09:05>  ← Time updated, format preserved
  :PROPERTIES:
  :GCAL_ID: abc123
  :LAST_REPEAT: [2025-10-30 Wed 08:05]         ← Unchanged
  :GCAL_UPDATED: 2025-10-31T16:00:00Z          ← Updated
  :END:
  :LOGBOOK:                                    ← Unchanged
  ...
```

### Scenario 3: Location Changed in Google Calendar

**Google Calendar change:** "Home" → "Clinic"

**After sync:**
```org
* TODO [#A] Take Blood Pressure
  SCHEDULED: <2025-10-31 Thu 08:00 .+1d>--<2025-10-31 Thu 08:05>
  :PROPERTIES:
  :GCAL_ID: abc123
  :LOCATION: Clinic                            ← Updated
  :LAST_REPEAT: [2025-10-30 Wed 08:05]         ← Unchanged
  :END:
```

## What's Protected

### File-Level Properties (NEVER Updated)
```org
:PROPERTIES:
:ID: ...
:CATEGORY: ...
:CUSTOM: ...
:END:
```
These are org-roam/org-specific, not Google Calendar related.

### Frontmatter (NEVER Updated)
```org
#+TITLE ...
#+FILETAGS ...
#+AUTHOR ...
```
Org-mode metadata, separate from event title.

### LOGBOOK (NEVER Updated)
```org
:LOGBOOK:
- State "DONE" from "TODO" [timestamp]
:END:
```
Org-mode state tracking, not synced to Google Calendar.

### Priority Tags (NEVER Removed)
```org
* TODO [#A] ...
```
Org-specific, preserved in headline even if title changes.

### Repeaters (Preserved in Format)
```org
SCHEDULED: <2025-10-31 Thu 08:00 .+1d>
```
If time changes: `<2025-10-31 Thu 09:00 .+1d>` (repeater kept)

### Timespans (Preserved in Format)
```org
SCHEDULED: <2025-10-31 Thu 08:00>--<2025-10-31 Thu 08:30>
```
If start changes: end time adjusted to maintain duration.

## Bidirectional Sync

### Export (Org → Google Calendar)
- Sends TODO items to Google Calendar
- Includes title, time, location, description
- Stores GCAL_ID for tracking

### Import (Google Calendar → Org)
- Updates title if changed
- Updates time/date if changed  
- Updates location if changed
- **Preserves all org-specific features**

## Summary

**What syncs FROM Google Calendar:**
- Event title (headline text only)
- Event time/date (timestamp value only)
- Event location (property value only)
- Event description (body text only)

**What NEVER changes:**
- File structure
- Frontmatter
- File-level properties
- LOGBOOK
- Priority tags
- TODO/NEXT keywords
- Custom properties
- Timestamp formats (repeaters, timespans, day names)

**Philosophy:** Google Calendar controls the "what" and "when". Org-mode controls the "how" (priorities, repeaters, state tracking, organization).

You get the best of both worlds! 🎉

## How Sync Works Now

### Export (Org → Google Calendar)

**What happens:**
1. Plugin scans your org-roam directories for TODO items
2. Exports them to Google Calendar with proper times
3. Stores `:GCAL_ID:` in your org file to track the sync

**Your local file:**
```org
* TODO [#A] Take Meds
  SCHEDULED: <2025-10-31 Thu 08:00 .+1d>--<2025-10-31 Thu 08:05>
  :PROPERTIES:
  :GCAL_ID: abc123
  :LAST_REPEAT: [2025-10-30 Wed 08:05]
  :END:
```

**Syncs to Google Calendar as:**
- Event: "Take Meds"
- Time: 08:00 - 08:05
- Recurring: Daily

**Local file remains UNCHANGED** ✅

### Import (Google Calendar → Org)

**What happens:**
1. Fetches events from Google Calendar
2. **Checks if event already exists locally** (by GCAL_ID)
3. **If exists AND is a TODO → SKIP UPDATE** (local is source of truth)
4. **If exists AND is pure calendar event → Update**
5. **If new → Create new org file**

**Example scenarios:**

**Scenario 1: TODO exists locally**
```
Google Calendar: "Take Meds" updated to 09:00
Local org file: Has TODO, priority, repeater
→ SKIP import, local file unchanged ✅
```

**Scenario 2: Pure calendar event**
```
Google Calendar: "Doctor Appointment" moved to 3pm  
Local org file: No TODO keyword, no priority, no repeater
→ Update org file with new time ✅
```

**Scenario 3: New event**
```
Google Calendar: New "Team Meeting" event
Local: Doesn't exist
→ Create new org file ✅
```

## What Gets Preserved (100%)

When you have a TODO file like this:

```org
:PROPERTIES:
:ID: 2F80BBB3-F46C-42E5-9831-C25DDCD060C0
:CATEGORY: Health
:END:
#+TITLE Take Blood Pressure  
#+FILETAGS: #health #routine

* TODO [#A] Take Blood Pressure
  SCHEDULED: <2025-10-31 Thu 10:00 .+1d>--<2025-10-31 Thu 10:05>
  :PROPERTIES:
  :GCAL_ID: abc123
  :LAST_REPEAT: [2025-10-30 Wed 10:15]
  :CUSTOM_FIELD: my-value
  :END:
  :LOGBOOK:
  - State "DONE" from "TODO" [2025-10-30 Wed 10:15]
  - State "DONE" from "TODO" [2025-10-29 Tue 10:12]
  :END:

  Take blood pressure and log results.
```

**After ANY number of syncs with Google Calendar:**

✅ **File-level properties preserved:**
- `:ID:`
- `:CATEGORY:`
- `#+TITLE`
- `#+FILETAGS`

✅ **Headline preserved:**
- `TODO` keyword
- `[#A]` priority
- Title text

✅ **Timestamp preserved:**
- Timespan `10:00--10:05`
- Repeater `.+1d`
- Day name `Thu`

✅ **Properties preserved:**
- `:GCAL_ID:` (updated)
- `:LAST_REPEAT:`
- `:CUSTOM_FIELD:`
- ANY custom property

✅ **LOGBOOK preserved:**
- All state changes
- Complete history

✅ **Body text preserved**

**NOTHING is lost!** 🎉

## When Exporting to Google Calendar

### Priorities → Google Calendar

**Priority tags are sent if supported:**
- `[#A]` → Might map to "High" priority (if supported by API)
- `[#B]` → Might map to "Medium" priority
- `[#C]` → Might map to "Low" priority

**Note:** Google Calendar has limited priority support. If it doesn't support priorities, they're preserved locally but not synced.

### Timespans → Google Calendar

Time ranges ARE synced to Google Calendar:
```org
SCHEDULED: <2025-10-30 Thu 14:00>--<2025-10-30 Thu 15:30>
```
→ Google Calendar: Event from 14:00 to 15:30 ✓

### Repeaters → Google Calendar

**Simple repeaters:**
- `.+1d` → Daily repeat
- `.+1w` → Weekly repeat  
- `.+1m` → Monthly repeat

**Note:** Google Calendar uses RRULE format. Complex org-mode repeaters might not sync perfectly. The local repeater is always preserved.

## Test Coverage

All data preservation is covered by comprehensive tests in:
```
tests/data_preservation_spec.lua
```

**11 tests covering:**
- Priority preservation (`[#A]`, `[#B]`, `[#C]`)
- Timespan preservation (`<start>--<end>`)
- Repeater preservation (`.+1d`, `.+1w`)
- Custom property preservation
- LOGBOOK preservation
- TODO/NEXT keyword preservation

**Run tests:**
```bash
nvim --headless -c "PlenaryBustedDirectory tests/data_preservation_spec.lua { minimal_init = 'tests/minimal_init.lua' }"
```

## Example: Before and After

### Before Sync
```org
:PROPERTIES:
:ID: 2F80BBB3-F46C-42E5-9831-C25DDCD060C0
:CATEGORY: Health
:END:
#+TITLE Take Blood Pressure
#+FILETAGS: #health

* TODO [#A] Take Blood Pressure
  SCHEDULED: <2025-10-30 Thu 10:00 .+1d>--<2025-10-30 Thu 10:05>
  :PROPERTIES:
  :GCAL_ID: abc123
  :LAST_REPEAT: [2025-10-29 Wed 10:15]
  :END:
  :LOGBOOK:
  - State "DONE" from "TODO" [2025-10-29 Wed 10:15]
  :END:

  Take blood pressure and record results.
```

### After Sync ✅
```org
:PROPERTIES:
:ID: 2F80BBB3-F46C-42E5-9831-C25DDCD060C0
:CATEGORY: Health                              ← PRESERVED
:END:
#+TITLE Take Blood Pressure
#+FILETAGS: #health

* TODO [#A] Take Blood Pressure                ← PRESERVED TODO + [#A]
  SCHEDULED: <2025-10-30 Thu 10:00 .+1d>--<2025-10-30 Thu 10:05>  ← PRESERVED timespan + repeater
  :PROPERTIES:
  :GCAL_ID: abc123                             ← Updated from GCal
  :GCAL_UPDATED: 2025-10-30T15:00:00Z          ← Updated from GCal
  :LAST_REPEAT: [2025-10-29 Wed 10:15]         ← PRESERVED
  :END:
  :LOGBOOK:                                    ← PRESERVED
  - State "DONE" from "TODO" [2025-10-29 Wed 10:15]
  :END:

  Take blood pressure and record results.      ← PRESERVED
```

**Everything is preserved!** 🎉

## Configuration

No configuration needed - data preservation is automatic.

The plugin:
- ✅ Always preserves local org-mode features
- ✅ Updates from Google Calendar selectively
- ✅ Never overwrites existing files completely
- ✅ Treats local org file as source of truth for org-specific features

## Authentication Failure Protection

**Critical Safety Feature:** The plugin will NEVER delete your local files if it cannot authenticate with Google Calendar.

### What Happens on Auth Failure

If the Google token fails to refresh or expires:
- ✅ Sync is aborted immediately
- ✅ All local files are preserved
- ✅ Clear error message is shown
- ✅ No deletion of any local data

**Example scenario:**
```
Your token expires → Plugin tries to sync → Auth fails
→ Error: "Failed to refresh token: Invalid credentials"
→ Sync aborted, NO files deleted ✅
```

### Before the Fix (Dangerous!)

Previously, if authentication failed:
- ❌ API would return empty event list
- ❌ Plugin would think all events were deleted from Google Calendar
- ❌ Plugin would delete ALL local .org files with GCAL_ID properties
- ❌ You could lose important data!

### After the Fix (Safe!)

Now, if authentication fails:
- ✅ API returns `nil` instead of empty list
- ✅ Plugin detects the error condition
- ✅ Plugin aborts sync immediately
- ✅ No files are touched
- ✅ User is prompted to re-authenticate

### Test Coverage

This critical safety feature is tested in:
```
tests/plenary/test_auth_failure.lua
```

**4 tests covering:**
- Token refresh failure
- Network errors
- API unreachable
- Normal deletion still works when sync succeeds

## Troubleshooting

### "My priorities disappeared!"

Check if you're using an old version. Update to latest:
```bash
:Lazy update org-gcal-sync
```

### "My repeaters are gone!"

The plugin now preserves all SCHEDULED/DEADLINE lines completely. If they're missing:
1. Check the file wasn't manually edited
2. Run tests to verify: `nvim --headless -c "PlenaryBustedDirectory tests/data_preservation_spec.lua ..."`

### "Timespans not showing in Google Calendar"

Timespans ARE exported to Google Calendar as start/end times. However:
- Local org file always keeps the full `<start>--<end>` format
- Google Calendar shows them as event duration
- Reimporting won't lose the timespan

### "Authentication failed and I got an error"

This is GOOD! The plugin is protecting your data:
1. Don't panic - your files are safe
2. Re-authenticate: `:OrgGcalAuth`
3. Try syncing again: `:SyncOrgGcal`

The plugin will never delete your files if it can't reach Google Calendar.

## Summary

**Philosophy:** Your org files are the source of truth for org-mode features. Google Calendar is for time/date synchronization only.

**What syncs bidirectionally:**
- Event title
- Event time/date
- Event location
- Event description

**What stays local (preserved):**
- Priority tags
- Time ranges (timespans)
- Repeaters
- Custom properties
- LOGBOOK entries
- File-level metadata

This ensures you get the best of both worlds: org-mode power + Google Calendar convenience! 🚀
