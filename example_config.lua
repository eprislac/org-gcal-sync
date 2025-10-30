-- Example configuration for org-gcal-sync
-- Place this in your Neovim config (e.g., ~/.config/nvim/lua/plugins/org-gcal-sync.lua for lazy.nvim)

return {
  "eprislac/org-gcal-sync",
  dependencies = { 
    "nvim-lua/plenary.nvim",
    "nvim-orgmode/orgmode", 
    "jmbuhr/org-roam.nvim" 
  },
  opts = {
    -- Directories containing your org-roam notes
    -- First directory will be used for importing calendar events
    -- All directories will be scanned for TODOs to export
    org_roam_dirs = { 
      "~/Notes",  -- First dir used for calendar imports
      "~/org/work" 
    },
    
    -- Enable automatic backlinks to notes that mention calendar events
    enable_backlinks = true,
    
    -- Auto-sync when saving org files that contain SCHEDULED or DEADLINE
    -- Set to false if you prefer to sync manually
    auto_sync_on_save = true,
    
    -- Show dashboard after sync (default: false)
    -- show_sync_status = true,
    
    -- Note: agenda_dir is deprecated and no longer used
    -- Calendar events are now imported to the first org_roam_dir
  },
  
  -- Optional: Set up a periodic sync using a timer (every 5 minutes)
  -- Note: Not needed if auto_sync_on_save is enabled
  --[[
  config = function(_, opts)
    require("org-gcal-sync").setup(opts)
    
    local timer = vim.loop.new_timer()
    timer:start(300000, 300000, vim.schedule_wrap(function()
      require("org-gcal-sync").sync()
    end))
  end,
  ]]--
}
