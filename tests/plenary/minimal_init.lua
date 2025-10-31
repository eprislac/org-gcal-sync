-- tests/plenary/minimal_init.lua
-- Add current directory to runtimepath
vim.o.runtimepath = vim.o.runtimepath .. ",."

-- Mock environment variables for tests
vim.env.GCAL_ORG_SYNC_CLIENT_ID = vim.env.GCAL_ORG_SYNC_CLIENT_ID or "test-client-id"
vim.env.GCAL_ORG_SYNC_CLIENT_SECRET = vim.env.GCAL_ORG_SYNC_CLIENT_SECRET or "test-client-secret"

-- Set up plenary if available
local ok, _ = pcall(require, "plenary")
if not ok then
  print("Warning: plenary.nvim not found. Some tests may fail.")
end

-- Initialize plugin
require("org-gcal-sync").setup({
  agenda_dir = vim.fn.tempname() .. "/agenda",
  org_dirs = {},
  enable_backlinks = true,
})
