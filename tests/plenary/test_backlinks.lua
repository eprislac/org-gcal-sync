-- tests/plenary/test_backlinks.lua
local utils = require("org-gcal-sync.utils")
local cfg = require("org-gcal-sync").config

describe("org-gcal-sync backlinks", function()
  local tmp = vim.fn.tempname()
  local agenda_dir = tmp .. "/agenda"
  local roam_dir = tmp .. "/roam"
  local event_file = agenda_dir .. "/team-standup.org"
  local note_file = roam_dir .. "/project-x.org"
  local gcal_api

  before_each(function()
    vim.fn.mkdir(agenda_dir, "p")
    vim.fn.mkdir(roam_dir, "p")

    cfg.agenda_dir = agenda_dir
    cfg.org_roam_dirs = { roam_dir }
    cfg.enable_backlinks = true

    -- Create a note that mentions the event
    vim.fn.writefile({
      "* Project X",
      "We have Team Standup every day.",
    }, note_file)

    -- Mock gcal_api
    gcal_api = require("org-gcal-sync.gcal_api")
    gcal_api.list_events = function(time_min, time_max)
      return {
        {
          id = "event123",
          summary = "Team Standup",
          start = { dateTime = "2025-11-01T14:00:00Z" },
          ["end"] = { dateTime = "2025-11-01T15:00:00Z" },
          location = "Office",
          description = "Daily sync",
          updated = "2025-10-29T10:00:00Z",
        }
      }
    end
  end)

  after_each(function()
    vim.fn.delete(tmp, "rf")
  end)

  it("adds ROAM_REFS to existing note mentioning the event", function()
    utils.import_gcal()

    local content = vim.fn.readfile(note_file)
    local has_ref = false
    local ref_line = nil

    for _, line in ipairs(content) do
      if line:match(":ROAM_REFS:") then
        has_ref = true
        ref_line = line
        break
      end
    end

    assert.truthy(has_ref, "ROAM_REFS property was not added")
    assert.truthy(ref_line:match("team%-standup.org"), "Backlink path missing")
  end)

  it("does not duplicate ROAM_REFS on re-import", function()
    -- First import
    utils.import_gcal()
    -- Second import (idempotent)
    utils.import_gcal()

    local content = vim.fn.readfile(note_file)
    local ref_count = 0
    for _, line in ipairs(content) do
      if line:match(":ROAM_REFS:") then
        ref_count = ref_count + 1
      end
    end

    assert.equal(1, ref_count, "ROAM_REFS duplicated on re-import")
  end)

  it("adds ROAM_REFS inside PROPERTIES block if missing", function()
    -- Create note without PROPERTIES
    vim.fn.writefile({
      "* Daily Sync",
      "Team Standup is critical.",
    }, roam_dir .. "/daily.org")

    utils.import_gcal()

    local content = vim.fn.readfile(roam_dir .. "/daily.org")
    local in_prop = false
    local has_refs = false
    for _, line in ipairs(content) do
      local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")
      if trimmed == ":PROPERTIES:" then in_prop = true end
      if in_prop and trimmed == ":END:" then in_prop = false end
      if in_prop and trimmed:match("^:ROAM_REFS:") then has_refs = true end
    end

    assert.truthy(has_refs, "ROAM_REFS not added in new PROPERTIES block")
  end)

  it("respects enable_backlinks = false", function()
    cfg.enable_backlinks = false
    vim.fn.writefile({
      "* Project Y",
      "Team Standup mentioned.",
    }, roam_dir .. "/proj-y.org")

    utils.import_gcal()

    local content = vim.fn.readfile(roam_dir .. "/proj-y.org")
    for _, line in ipairs(content) do
      assert.is_false(line:match(":ROAM_REFS:"), "ROAM_REFS added when disabled")
    end
  end)
end)
