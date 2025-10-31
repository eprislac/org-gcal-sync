-- Test data preservation during sync
describe("Data Preservation Tests", function()
  local utils
  local test_file
  
  before_each(function()
    utils = require("org-gcal-sync.utils")
    test_file = vim.fn.tempname() .. ".org"
    
    -- Setup minimal config
    utils.set_config({
      org_roam_dirs = {vim.fn.tempname()},
      calendars = {"primary"},
      enable_backlinks = false,
    })
  end)
  
  after_each(function()
    if vim.fn.filereadable(test_file) == 1 then
      vim.fn.delete(test_file)
    end
  end)
  
  describe("Priority preservation", function()
    it("should preserve [#A] priority on update", function()
      -- Create file with priority
      local original = {
        ":PROPERTIES:",
        ":ID: test-id-123",
        ":END:",
        "#+title: Important Task",
        "",
        "* TODO [#A] Important Task",
        "  SCHEDULED: <2025-10-30 Thu 10:00>",
        "  :PROPERTIES:",
        "  :GCAL_ID: event123",
        "  :END:",
      }
      vim.fn.writefile(original, test_file)
      
      -- Update from Google Calendar
      utils.update_roam_event_note(test_file, {
        title = "Important Task (updated)",
        timestamp = "2025-10-30 Thu 11:00",
        event_id = "event123",
        updated = "2025-10-30T10:00:00Z",
      })
      
      -- Verify priority is preserved
      local result = vim.fn.readfile(test_file)
      local found_priority = false
      for _, line in ipairs(result) do
        if line:match("%[#A%]") then
          found_priority = true
          -- Title should be updated, but priority preserved
          assert.is_not_nil(line:match("TODO %[#A%]"))
          break
        end
      end
      assert.is_true(found_priority, "Priority [#A] should be preserved")
    end)
    
    it("should preserve [#B] and [#C] priorities", function()
      local original = {
        "* TODO [#B] Medium Priority",
        "  SCHEDULED: <2025-10-30 Thu 10:00>",
        "  :PROPERTIES:",
        "  :GCAL_ID: event456",
        "  :END:",
      }
      vim.fn.writefile(original, test_file)
      
      utils.update_roam_event_note(test_file, {
        title = "Medium Priority",
        timestamp = "2025-10-30 Thu 11:00",
        event_id = "event456",
      })
      
      local result = vim.fn.readfile(test_file)
      local has_priority_b = false
      for _, line in ipairs(result) do
        if line:match("%[#B%]") then
          has_priority_b = true
          break
        end
      end
      assert.is_true(has_priority_b, "Priority [#B] should be preserved")
    end)
  end)
  
  describe("Timespan preservation", function()
    it("should preserve time ranges (start--end)", function()
      local original = {
        "* TODO Team Meeting",
        "  SCHEDULED: <2025-10-30 Thu 10:00 .+1d>--<2025-10-30 Thu 11:00>",
        "  :PROPERTIES:",
        "  :GCAL_ID: meeting123",
        "  :END:",
      }
      vim.fn.writefile(original, test_file)
      
      utils.update_roam_event_note(test_file, {
        title = "Team Meeting",
        timestamp = "2025-10-30 Thu 10:00",
        event_id = "meeting123",
      })
      
      local result = vim.fn.readfile(test_file)
      local has_timespan = false
      for _, line in ipairs(result) do
        if line:match("%-%-<") then  -- Has time range
          has_timespan = true
          -- Just verify it has SCHEDULED
          assert.is_not_nil(line:match("SCHEDULED:"))
          break
        end
      end
      assert.is_true(has_timespan, "Time range should be preserved")
    end)
    
    it("should preserve repeaters in timespans", function()
      local original = {
        "* TODO Daily Standup",
        "  SCHEDULED: <2025-10-30 Thu 09:00 .+1d>--<2025-10-30 Thu 09:30>",
        "  :PROPERTIES:",
        "  :GCAL_ID: standup123",
        "  :END:",
      }
      vim.fn.writefile(original, test_file)
      
      utils.update_roam_event_note(test_file, {
        title = "Daily Standup",
        timestamp = "2025-10-30 Thu 09:00",
        event_id = "standup123",
      })
      
      local result = vim.fn.readfile(test_file)
      local has_repeater = false
      for _, line in ipairs(result) do
        if line:match("%.%+1d") then
          has_repeater = true
          break
        end
      end
      assert.is_true(has_repeater, "Repeater .+1d should be preserved")
    end)
  end)
  
  describe("Recurrence preservation", function()
    it("should preserve repeater syntax (.+1d)", function()
      local original = {
        "* TODO Take Meds",
        "  SCHEDULED: <2025-10-30 Thu 08:00 .+1d>",
        "  :PROPERTIES:",
        "  :GCAL_ID: meds123",
        "  :LAST_REPEAT: [2025-10-29 Wed 08:05]",
        "  :END:",
      }
      vim.fn.writefile(original, test_file)
      
      utils.update_roam_event_note(test_file, {
        title = "Take Meds",
        timestamp = "2025-10-30 Thu 08:00",
        event_id = "meds123",
      })
      
      local result = vim.fn.readfile(test_file)
      local has_repeater = false
      for _, line in ipairs(result) do
        if line:match("SCHEDULED:") and line:match("%.%+1d") then
          has_repeater = true
          break
        end
      end
      assert.is_true(has_repeater, "Daily repeater should be preserved")
    end)
    
    it("should preserve weekly repeater (.+1w)", function()
      local original = {
        "* TODO Weekly Review",
        "  SCHEDULED: <2025-10-30 Thu 17:00 .+1w>",
        "  :PROPERTIES:",
        "  :GCAL_ID: review123",
        "  :END:",
      }
      vim.fn.writefile(original, test_file)
      
      utils.update_roam_event_note(test_file, {
        title = "Weekly Review",
        timestamp = "2025-10-30 Thu 17:00",
        event_id = "review123",
      })
      
      local result = vim.fn.readfile(test_file)
      local has_weekly = false
      for _, line in ipairs(result) do
        if line:match("%.%+1w") then
          has_weekly = true
          break
        end
      end
      assert.is_true(has_weekly, "Weekly repeater should be preserved")
    end)
  end)
  
  describe("Custom properties preservation", function()
    it("should preserve LAST_REPEAT property", function()
      local original = {
        "* TODO Daily Task",
        "  SCHEDULED: <2025-10-30 Thu 10:00 .+1d>",
        "  :PROPERTIES:",
        "  :GCAL_ID: task123",
        "  :LAST_REPEAT: [2025-10-29 Wed 10:15]",
        "  :END:",
      }
      vim.fn.writefile(original, test_file)
      
      utils.update_roam_event_note(test_file, {
        title = "Daily Task",
        timestamp = "2025-10-30 Thu 10:00",
        event_id = "task123",
      })
      
      local result = vim.fn.readfile(test_file)
      local has_last_repeat = false
      for _, line in ipairs(result) do
        if line:match(":LAST_REPEAT:") then
          has_last_repeat = true
          break
        end
      end
      assert.is_true(has_last_repeat, "LAST_REPEAT property should be preserved")
    end)
    
    it("should preserve CATEGORY property", function()
      local original = {
        ":PROPERTIES:",
        ":CATEGORY: Health",
        ":END:",
        "* TODO Health Task",
        "  SCHEDULED: <2025-10-30 Thu 10:00>",
        "  :PROPERTIES:",
        "  :GCAL_ID: health123",
        "  :END:",
      }
      vim.fn.writefile(original, test_file)
      
      utils.update_roam_event_note(test_file, {
        title = "Health Task",
        timestamp = "2025-10-30 Thu 10:00",
        event_id = "health123",
      })
      
      local result = vim.fn.readfile(test_file)
      local has_category = false
      for _, line in ipairs(result) do
        if line:match(":CATEGORY: Health") then
          has_category = true
          break
        end
      end
      assert.is_true(has_category, "CATEGORY property should be preserved")
    end)
  end)
  
  describe("LOGBOOK preservation", function()
    it("should preserve LOGBOOK entries", function()
      local original = {
        "* TODO Task with History",
        "  SCHEDULED: <2025-10-30 Thu 10:00>",
        "  :PROPERTIES:",
        "  :GCAL_ID: history123",
        "  :END:",
        "  :LOGBOOK:",
        "  - State \"DONE\" from \"TODO\" [2025-10-29 Wed 10:30]",
        "  - State \"DONE\" from \"TODO\" [2025-10-28 Tue 10:25]",
        "  :END:",
      }
      vim.fn.writefile(original, test_file)
      
      utils.update_roam_event_note(test_file, {
        title = "Task with History",
        timestamp = "2025-10-30 Thu 10:00",
        event_id = "history123",
      })
      
      local result = vim.fn.readfile(test_file)
      local has_logbook = false
      for _, line in ipairs(result) do
        if line:match(":LOGBOOK:") then
          has_logbook = true
          break
        end
      end
      assert.is_true(has_logbook, "LOGBOOK should be preserved")
    end)
  end)
  
  describe("TODO keyword preservation", function()
    it("should preserve TODO keyword", function()
      local original = {
        "* TODO My Task",
        "  SCHEDULED: <2025-10-30 Thu 10:00>",
        "  :PROPERTIES:",
        "  :GCAL_ID: todo123",
        "  :END:",
      }
      vim.fn.writefile(original, test_file)
      
      utils.update_roam_event_note(test_file, {
        title = "My Task (updated)",
        timestamp = "2025-10-30 Thu 11:00",
        event_id = "todo123",
      })
      
      local result = vim.fn.readfile(test_file)
      local has_todo = false
      for _, line in ipairs(result) do
        if line:match("^%* TODO") then
          has_todo = true
          break
        end
      end
      assert.is_true(has_todo, "TODO keyword should be preserved")
    end)
    
    it("should preserve NEXT keyword", function()
      local original = {
        "* NEXT Urgent Task",
        "  SCHEDULED: <2025-10-30 Thu 10:00>",
        "  :PROPERTIES:",
        "  :GCAL_ID: next123",
        "  :END:",
      }
      vim.fn.writefile(original, test_file)
      
      utils.update_roam_event_note(test_file, {
        title = "Urgent Task",
        timestamp = "2025-10-30 Thu 10:00",
        event_id = "next123",
      })
      
      local result = vim.fn.readfile(test_file)
      local has_next = false
      for _, line in ipairs(result) do
        if line:match("^%* NEXT") then
          has_next = true
          break
        end
      end
      assert.is_true(has_next, "NEXT keyword should be preserved")
    end)
  end)
end)
