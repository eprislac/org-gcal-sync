-- Test that authentication failures don't delete local files
local utils = require("org-gcal-sync.utils")

describe("Authentication failure handling", function()
  local tmp = vim.fn.tempname()
  local agenda_dir = tmp .. "/agenda"
  local gcal_api
  local original_list_events

  before_each(function()
    vim.fn.mkdir(agenda_dir, "p")
    
    -- Configure utils
    utils.set_config({
      org_dirs = { agenda_dir },
      calendars = { "primary" },
      show_sync_status = false,
    })
    
    -- Mock gcal_api
    gcal_api = require("org-gcal-sync.gcal_api")
    original_list_events = gcal_api.list_events
  end)

  after_each(function()
    vim.fn.delete(tmp, "rf")
    gcal_api.list_events = original_list_events
  end)

  it("should not delete local files when token refresh fails", function()
    -- Create a local org file with GCAL_ID
    local test_file = agenda_dir .. "/important-meeting.org"
    vim.fn.writefile({
      "#+title: Important Meeting",
      "#+filetags: :gcal:",
      "",
      "* TODO Important Meeting",
      "  SCHEDULED: <2025-11-01 Fri 14:00>",
      "  :PROPERTIES:",
      "  :GCAL_ID: event_abc123",
      "  :GCAL_UPDATED: 2025-10-29T10:00:00Z",
      "  :CALENDAR_ID: primary",
      "  :END:",
      "",
      "Important notes about this meeting that should not be lost.",
    }, test_file)
    
    -- Verify file exists
    assert.equal(1, vim.fn.filereadable(test_file))
    
    -- Mock failed token refresh
    gcal_api.list_events = function(time_min, time_max, calendar_id)
      return nil, "Failed to refresh token: Invalid credentials"
    end
    
    -- Attempt to import (which should fail gracefully)
    utils.import_gcal()
    
    -- Verify file still exists and was NOT deleted
    assert.equal(1, vim.fn.filereadable(test_file), "File was deleted despite auth failure!")
    
    -- Verify file content is intact
    local content = vim.fn.readfile(test_file)
    local has_gcal_id = false
    local has_notes = false
    for _, line in ipairs(content) do
      if line:match(":GCAL_ID: event_abc123") then
        has_gcal_id = true
      end
      if line:match("Important notes") then
        has_notes = true
      end
    end
    assert.is_true(has_gcal_id, "GCAL_ID was lost")
    assert.is_true(has_notes, "File content was lost")
  end)
  
  it("should not delete files when API is unreachable", function()
    -- Create multiple files
    local files = {
      { name = "meeting1.org", id = "event1" },
      { name = "meeting2.org", id = "event2" },
      { name = "meeting3.org", id = "event3" },
    }
    
    for _, file_info in ipairs(files) do
      local filepath = agenda_dir .. "/" .. file_info.name
      vim.fn.writefile({
        "#+title: Meeting",
        "",
        "* TODO Meeting",
        "  SCHEDULED: <2025-11-01 Fri 10:00>",
        "  :PROPERTIES:",
        "  :GCAL_ID: " .. file_info.id,
        "  :END:",
      }, filepath)
    end
    
    -- Mock network error
    gcal_api.list_events = function(time_min, time_max, calendar_id)
      return nil, "Network error: Could not reach Google Calendar API"
    end
    
    -- Attempt to import
    utils.import_gcal()
    
    -- Verify all files still exist
    for _, file_info in ipairs(files) do
      local filepath = agenda_dir .. "/" .. file_info.name
      assert.equal(1, vim.fn.filereadable(filepath), 
        "File " .. file_info.name .. " was deleted despite network error!")
    end
  end)
  
  it("should not delete files when export fails due to auth error", function()
    -- Create a local org file
    local test_file = agenda_dir .. "/my-task.org"
    vim.fn.writefile({
      "#+title: My Task",
      "",
      "* TODO My Task",
      "  SCHEDULED: <2025-11-01 Fri 15:00>",
      "  :PROPERTIES:",
      "  :GCAL_ID: task_xyz789",
      "  :END:",
    }, test_file)
    
    -- Mock auth failure
    gcal_api.list_events = function(time_min, time_max, calendar_id)
      return nil, "Token expired. Please re-authenticate with :OrgGcalAuth"
    end
    
    -- Attempt to export
    utils.export_org()
    
    -- Verify file still exists
    assert.equal(1, vim.fn.filereadable(test_file), "File was deleted during failed export!")
  end)
  
  it("should properly delete files when sync succeeds but event is actually deleted", function()
    -- Create a file for an event that will not be in the API response
    local deleted_event_file = agenda_dir .. "/deleted-event.org"
    vim.fn.writefile({
      "#+title: Deleted Event",
      "",
      "* TODO Deleted Event",
      "  SCHEDULED: <2025-11-02 Sat 10:00>",
      "  :PROPERTIES:",
      "  :GCAL_ID: old_deleted_event",
      "  :END:",
    }, deleted_event_file)
    
    -- Create a file for an event that will be in the API response
    local kept_event_file = agenda_dir .. "/kept-event.org"
    vim.fn.writefile({
      "#+title: Kept Event",
      "",
      "* TODO Kept Event",
      "  SCHEDULED: <2025-11-01 Fri 14:00>",
      "  :PROPERTIES:",
      "  :GCAL_ID: current_event",
      "  :GCAL_UPDATED: 2025-10-29T10:00:00Z",
      "  :END:",
    }, kept_event_file)
    
    -- Mock successful API call with only one event
    gcal_api.list_events = function(time_min, time_max, calendar_id)
      return {
        {
          id = "current_event",
          summary = "Kept Event",
          start = { dateTime = "2025-11-01T14:00:00Z" },
          ["end"] = { dateTime = "2025-11-01T15:00:00Z" },
          updated = "2025-10-29T10:00:00Z",
        }
      }
    end
    
    -- Perform import
    utils.import_gcal()
    
    -- Verify deleted event file is gone
    assert.equal(0, vim.fn.filereadable(deleted_event_file), 
      "Deleted event file should have been removed")
    
    -- Verify kept event file still exists
    assert.equal(1, vim.fn.filereadable(kept_event_file), 
      "Kept event file should still exist")
  end)
end)
