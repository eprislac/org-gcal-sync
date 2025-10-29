-- tests/plenary/test_sync.lua
local utils = require("org-gcal-sync.utils")
local cfg = require("org-gcal-sync").config

describe("org-gcal-sync core sync", function()
  local tmp = vim.fn.tempname()
  local agenda_dir = tmp .. "/agenda"
  local roam_dir = tmp .. "/roam"

  before_each(function()
    vim.fn.mkdir(agenda_dir, "p")
    vim.fn.mkdir(roam_dir, "p")
    cfg.agenda_dir = agenda_dir
    cfg.org_roam_dirs = { roam_dir }
  end)

  after_each(function()
    vim.fn.delete(tmp, "rf")
  end)

  it("imports gcal event as org-roam note", function()
    vim.fn.system = function(cmd)
      if cmd:match("gcalcli agenda") then
        return "2025-11-01\t14:00\t15:00\tlink\tTeam Standup\tOffice\t"
      end
      return ""
    end

    utils.import_gcal()

    local files = vim.fn.glob(agenda_dir .. "/*.org", false, true)
    assert.equal(1, #files)
    local content = vim.fn.readfile(files[1])
    assert.truthy(content[1]:match("#+title: Team Standup"))
    assert.truthy(content[4]:match("SCHEDULED: <2025%-11%-01"))
  end)

  it("skips duplicate import", function()
    vim.fn.writefile({
      "#+title: Team Standup",
      "* Team Standup",
      "  SCHEDULED: <2025-11-01 14:00>",
    }, agenda_dir .. "/team-standup.org")

    vim.fn.system = function(cmd)
      return "2025-11-01\t14:00\t\t\tTeam Standup\t\t"
    end

    utils.import_gcal()
    local files = vim.fn.glob(agenda_dir .. "/*.org", false, true)
    assert.equal(1, #files)
  end)
end)
