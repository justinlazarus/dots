
------------------------------------------------------------------------------------- OPTIONS
vim.cmd("let g:netrw_liststyle = 3")

local opt = vim.opt

vim.g.have_nerd_font = true
vim.o.autoindent = true
vim.o.foldcolumn = "1"
vim.o.foldenable = true
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
vim.o.tabstop = 4
vim.o.termguicolors = true
vim.o.expandtab = true
vim.o.softtabstop = 4
vim.o.encoding = "utf-8"

opt.backspace = "indent,eol,start"
opt.breakindent = true
opt.clipboard = "unnamedplus"
opt.colorcolumn = "110"
opt.cursorline = true
opt.hlsearch = true
opt.ignorecase = true
opt.inccommand = "split"
opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
opt.mouse = "a"
opt.number = true
opt.relativenumber = true
opt.scrolloff = 10
opt.shiftwidth = 4
opt.showmode = false
opt.signcolumn = "yes"
opt.smartcase = true
opt.smartindent = true
opt.splitbelow = true
opt.splitright = true
opt.timeoutlen = 300
opt.undofile = true
opt.updatetime = 250

------------------------------------------------------------------------------------- KEYMAPS
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local map = vim.keymap

map.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- File and folder management
map.set("n", "<leader>fe", "<cmd>Oil<CR>", { desc = "[F]ilesystem [E]xplore" })

-- Diffview
map.set("n", "<leader>vh", "<cmd>DiffviewFileHistory<CR>", { desc = "[D]iffview [H]istory" })
map.set("n", "<leader>vf", "<cmd>DiffviewFileHistory %<CR>", { desc = "[D]iffview [F]ile History" })
map.set("n", "<leader>vc", "<cmd>DiffviewClose<CR>", { desc = "[D]iffview [C]lose" })

-- Buffer keymaps
map.set("n", "<leader>bd", "<cmd>bd<CR>", { desc = "[B]uffer [d]elete" })

-- Diagnostic keymaps
map.set("n", "]d", function()
	vim.diagnostic.jump({ count = 1 })
end, { desc = "Next diagnostic message" })
map.set("n", "[d", function()
	vim.diagnostic.jump({ count = -1 })
end, { desc = "Previous diagnostic message" })
map.set("n", "<leader>e", vim.diagnostic.open_float, { desc = "Show diagnostic [E]rror messages" })
map.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })

map.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Window commands
map.set("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
map.set("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
map.set("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
map.set("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })

-- Highlight yanks
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
	callback = function()
		vim.highlight.on_yank()
	end,
})

------------------------------------------------------------------------------------- LAZY
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
end ---@diagnostic disable-next-line: undefined-field
vim.opt.rtp:prepend(lazypath)

require("lazy").setup("djp.plugins")


