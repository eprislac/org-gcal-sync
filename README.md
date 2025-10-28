# org-gcal-sync

**Full bidirectional sync**: `org-roam` ↔ Google Calendar with **agenda integration**, **backlinks**, and **unit tests**.

---

## Features

- GCal → org-roam notes with `#+title`, `SCHEDULED`, `ROAM_REFS`
- org-roam tasks → GCal
- **Appears in `org-agenda`**
- **Backlinks** to any note mentioning the event
- **Duplicate-safe**
- **Syncthing-ready**
- **Unit tested**

---

## Install (lazy.nvim)

```lua
{
  "eprislac/org-gcal-sync",
  dependencies = { "nvim-orgmode/orgmode", "jmbuhr/org-roam.nvim" },
  config = function()
    require("org-gcal-sync").setup({
      agenda_dir = "~/Syncthing/org/gcal",
      org_roam_dirs = { "~/Syncthing/org/personal", "~/Syncthing/org/work" },
    })
  end,
}
```
## Testing
```bash
nvim --headless -c "PlenaryBustedDirectory tests/plenary { minimal_init = 'tests/minimal_init.lua' }"
```
