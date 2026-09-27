-- GLOBAL OPTIONS
--------------------------------------------------
local set = vim.opt

-- Leader --
-- Space leads; `\` stays free as the local leader for
-- filetype plugins. Set before any map is defined.
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Run project-local `.nvim.lua` files
vim.o.exrc = true

-- Required by render-markdown and obsidian
set.conceallevel = 2

-- Expand bash aliases in external commands
vim.o.shell = "bash"
vim.o.shellcmdflag = "-c"

-- Saving --
set.backup = false
set.swapfile = false
set.undofile = true

-- Line numbers --
set.nu = true
set.relativenumber = true
set.number = true

-- Default indentation (per-filetype overrides in autocmds)
set.tabstop = 4
set.shiftwidth = 4
set.softtabstop = 4
set.expandtab = true
set.autoindent = true

-- Reload files changed outside nvim
set.autoread = true

-- Search --
set.hlsearch = false
set.incsearch = true

-- Interface --
set.visualbell = true
set.termguicolors = true
set.scrolloff = 10
set.signcolumn = "yes"
set.showmode = false
set.showcmd = true
set.showmatch = true

-- Lines per wheel step, from Nix. Horizontal keeps the default
set.mousescroll = ("ver:%d,hor:6"):format(nixInfo(5, "settings", "mouse", "scroll_lines"))

-- The unnamed register is synced with `+`
set.clipboard = "unnamedplus"

-- Keep rumdl's cache in nvim's cache dir, otherwise the
-- linter creates a folder inside every project
vim.env.RUMDL_CACHE_DIR = vim.fn.stdpath("cache") .. "/rumdl"

-- Unused providers: skips a startup check each
vim.g["loaded_perl_provider"] = 0
vim.g["loaded_ruby_provider"] = 0
vim.g["loaded_node_provider"] = 0
vim.g["loaded_python3_provider"] = 0
