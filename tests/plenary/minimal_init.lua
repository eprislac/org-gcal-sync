-- tests/minimal_init.lua
vim.o.runtimepath = vim.o.runtimepath .. ",."
require("org-gcal-sync").setup()
