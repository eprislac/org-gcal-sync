-- tests/plenary/test_sync.lua
local utils = require("org-gcal-sync.utils")
local cfg = require("org-gcal-sync").config

describe("org-gcal-sync core sync", function()
  local tmp = vim.fn.tempname()
  local agenda_dir = tmp .. "/agenda"
  local roam_dir = tmp .. "/roam"
  local gcal_api

  before_each(function()
    vim.fn.mkdir(agenda_dir, "p")
    vim.fn.mkdir(roam_dir, "p")
    cfg.agenda_dir = agenda_dir
    cfg.org_roam_dirs = { roam_dir }
    
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
          description = "",
          updated = "2025-10-29T10:00:00Z",
        }
      }
    end
    
    gcal_api.create_event = function(event_data)
      return {
        id = "new_event_id",
        summary = event_data.summary,
      }
    end
  end)

  after_each(function()
    vim.fn.delete(tmp, "rf")
  end)

  it("imports gcal event as org-roam note", function()
    utils.import_gcal()

    local files = vim.fn.glob(agenda_dir .. "/*.org", false, true)
    assert.equal(1, #files)
    local content = vim.fn.readfile(files[1])
    assert.truthy(content[1]:match("#+title: Team Standup"))
    assert.truthy(content[4]:match("SCHEDULED: <2025%-11%-01"))
    
    -- Check for GCAL_ID property
    local has_gcal_id = false
    for _, line in ipairs(content) do
      if line:match(":GCAL_ID: event123") then
        has_gcal_id = true
        break
      end
    end
    assert.truthy(has_gcal_id, "GCAL_ID property not found")
  end)

  it("skips duplicate import", function()
    vim.fn.writefile({
      "#+title: Team Standup",
      "#+filetags: :gcal:",
      "",
      "* Team Standup",
      "  SCHEDULED: <2025-11-01 14:00>",
      "  :PROPERTIES:",
      "  :GCAL_ID: event123",
      "  :GCAL_UPDATED: 2025-10-29T10:00:00Z",
      "  :END:",
    }, agenda_dir .. "/team-standup.org")

    utils.import_gcal()
    local files = vim.fn.glob(agenda_dir .. "/*.org", false, true)
    assert.equal(1, #files)
  end)
  
  it("updates existing event when gcal version is newer", function()
    vim.fn.writefile({
      "#+title: Team Standup",
      "#+filetags: :gcal:",
      "",
      "* Team Standup",
      "  SCHEDULED: <2025-11-01 14:00>",
      "  :PROPERTIES:",
      "  :GCAL_ID: event123",
      "  :GCAL_UPDATED: 2025-10-28T10:00:00Z",
      "  :END:",
    }, agenda_dir .. "/team-standup.org")

    utils.import_gcal()
    
    local files = vim.fn.glob(agenda_dir .. "/*.org", false, true)
    local content = vim.fn.readfile(files[1])
    
    local has_updated = false
    for _, line in ipairs(content) do
      if line:match(":GCAL_UPDATED: 2025%-10%-29T10:00:00Z") then
        has_updated = true
        break
      end
    end
    assert.truthy(has_updated, "Event was not updated")
  end)
  
  it("deletes local events that no longer exist in gcal", function()
    vim.fn.writefile({
      "#+title: Deleted Event",
      "#+filetags: :gcal:",
      "",
      "* Deleted Event",
      "  SCHEDULED: <2025-11-02 10:00>",
      "  :PROPERTIES:",
      "  :GCAL_ID: deleted_event",
      "  :END:",
    }, agenda_dir .. "/deleted-event.org")

    utils.import_gcal()
    
    local exists = vim.fn.filereadable(agenda_dir .. "/deleted-event.org")
    assert.equal(0, exists, "Deleted event file still exists")
  end)
end)
