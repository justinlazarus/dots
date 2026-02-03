vim.pack.add {
  'https://github.com/nvim-treesitter/nvim-treesitter',
  'https://github.com/williamboman/mason.nvim',
  'https://github.com/folke/snacks.nvim',
  'https://github.com/folke/which-key.nvim',
  'https://github.com/L3MON4D3/LuaSnip',
  'https://github.com/folke/lazydev.nvim',
  'https://github.com/saghen/blink.cmp',
  'https://github.com/seblyng/roslyn.nvim',
  'https://github.com/folke/tokyonight.nvim',
  'https://github.com/stevearc/conform.nvim',
  'https://github.com/lewis6991/gitsigns.nvim',
  'https://github.com/echasnovski/mini.statusline',
  'https://github.com/nvim-tree/nvim-web-devicons',
  'https://github.com/stevearc/oil.nvim',
}

--------------------------------------------------------------------------------------------------- treesitter

require('nvim-treesitter.install').install({
  'bash',
  'c_sharp',
  'css',
  'diff',
  'html',
  'javascript',
  'json',
  'lua',
  'markdown',
  'powershell',
  'tsx',
  'typescript',
  'vim',
  'vimdoc',
  'xml',
  'yaml',
}, { summary = false })

-- Use bash parser for zsh files (no dedicated zsh parser exists)
vim.treesitter.language.register('bash', 'zsh')

-------------------------------------------------------------------------------------------------------- mason

-- Mason manages LSP servers, DAP servers, linters, and formatters
-- Install LSP servers manually with :Mason or programmatically below
require('mason').setup {
  registries = {
    'github:mason-org/mason-registry',
    'github:Crashdummyy/mason-registry',
  },
}

-- Auto-install LSP servers
local function ensure_installed(server_name)
  local ok_reg, registry = pcall(require, 'mason-registry')
  if ok_reg then
    local ok_pkg, pkg = pcall(registry.get_package, server_name)
    if ok_pkg and pkg and not pkg:is_installed() then
      vim.notify('Installing ' .. server_name .. ' via Mason...', vim.log.levels.INFO)
      pkg:install()
    end
  end
end

-- Install LSP servers we need
vim.schedule(function()
  ensure_installed 'lua-language-server' -- lua_ls
  ensure_installed 'typescript-language-server' -- ts_ls
  ensure_installed 'json-lsp' -- jsonls
  ensure_installed 'roslyn' -- C#/.NET (via third-party registry)
  ensure_installed 'angular-language-server' -- angular
  ensure_installed 'csharpier' -- C# formatter
  ensure_installed 'sqlfmt' -- SQL formatter
  ensure_installed 'stylua' -- Lua formatter
  ensure_installed 'terraform-ls' -- Terraform
  ensure_installed 'rust-analyzer' -- Rust
end)

------------------------------------------------------------------------------------------------------- snacks

local Snacks = require 'snacks'
Snacks.setup {
  bigfile = {},
  dashboard = {},
  explorer = {},
  indent = {},
  input = {},
  picker = {},
  notifier = {},
  quickfile = {},
  scope = {},
  statuscolumn = {},
  words = {},
}

-- Snacks keymaps
local map = vim.keymap.set

-- Top Pickers & Explorer
map('n', '<leader><space>', function()
  Snacks.picker.smart()
end, { desc = 'Smart Find Files' })
map('n', '<leader>,', function()
  Snacks.picker.buffers()
end, { desc = 'Buffers' })
map('n', '<leader>/', function()
  Snacks.picker.grep()
end, { desc = 'Grep' })
map('n', '<leader>:', function()
  Snacks.picker.command_history()
end, { desc = 'Command History' })
map('n', '<leader>n', function()
  Snacks.picker.notifications()
end, { desc = 'Notification History' })
map('n', '<leader>e', function()
  Snacks.explorer()
end, { desc = 'File Explorer' })

-- find
map('n', '<leader>fb', function()
  Snacks.picker.buffers()
end, { desc = 'Buffers' })
map('n', '<leader>fc', function()
  Snacks.picker.files { cwd = vim.fn.stdpath 'config' }
end, { desc = 'Find Config File' })
map('n', '<leader>ff', function()
  Snacks.picker.files()
end, { desc = 'Find Files' })
map('n', '<leader>fg', function()
  Snacks.picker.git_files()
end, { desc = 'Find Git Files' })
map('n', '<leader>fp', function()
  Snacks.picker.projects()
end, { desc = 'Projects' })
map('n', '<leader>fr', function()
  Snacks.picker.recent()
end, { desc = 'Recent' })

-- git
map('n', '<leader>gb', function()
  Snacks.picker.git_branches()
end, { desc = 'Git Branches' })
map('n', '<leader>gl', function()
  Snacks.picker.git_log()
end, { desc = 'Git Log' })
map('n', '<leader>gL', function()
  Snacks.picker.git_log_line()
end, { desc = 'Git Log Line' })
map('n', '<leader>gs', function()
  Snacks.picker.git_status()
end, { desc = 'Git Status' })
map('n', '<leader>gS', function()
  Snacks.picker.git_stash()
end, { desc = 'Git Stash' })
map('n', '<leader>gd', function()
  Snacks.picker.git_diff()
end, { desc = 'Git Diff (Hunks)' })
map('n', '<leader>gf', function()
  Snacks.picker.git_log_file()
end, { desc = 'Git Log File' })

-- Grep / buffer lines
map('n', '<leader>sb', function()
  Snacks.picker.lines()
end, { desc = 'Buffer Lines' })
map('n', '<leader>sB', function()
  Snacks.picker.grep_buffers()
end, { desc = 'Grep Open Buffers' })
map('n', '<leader>sg', function()
  Snacks.picker.grep()
end, { desc = 'Grep' })
map({ 'n', 'x' }, '<leader>sw', function()
  Snacks.picker.grep_word()
end, { desc = 'Visual selection or word' })

-- search helpers
map('n', '<leader>s"', function()
  Snacks.picker.registers()
end, { desc = 'Registers' })
map('n', '<leader>s/', function()
  Snacks.picker.search_history()
end, { desc = 'Search History' })
map('n', '<leader>sa', function()
  Snacks.picker.autocmds()
end, { desc = 'Autocmds' })
map('n', '<leader>sc', function()
  Snacks.picker.command_history()
end, { desc = 'Command History' })
map('n', '<leader>sC', function()
  Snacks.picker.commands()
end, { desc = 'Commands' })
map('n', '<leader>sd', function()
  Snacks.picker.diagnostics()
end, { desc = 'Diagnostics' })
map('n', '<leader>sD', function()
  Snacks.picker.diagnostics_buffer()
end, { desc = 'Buffer Diagnostics' })
map('n', '<leader>sh', function()
  Snacks.picker.help()
end, { desc = 'Help Pages' })
map('n', '<leader>sH', function()
  Snacks.picker.highlights()
end, { desc = 'Highlights' })
map('n', '<leader>si', function()
  Snacks.picker.icons()
end, { desc = 'Icons' })
map('n', '<leader>sj', function()
  Snacks.picker.jumps()
end, { desc = 'Jumps' })
map('n', '<leader>sk', function()
  Snacks.picker.keymaps()
end, { desc = 'Keymaps' })
map('n', '<leader>sl', function()
  Snacks.picker.loclist()
end, { desc = 'Location List' })
map('n', '<leader>sm', function()
  Snacks.picker.marks()
end, { desc = 'Marks' })
map('n', '<leader>sM', function()
  Snacks.picker.man()
end, { desc = 'Man Pages' })
map('n', '<leader>sp', function()
  Snacks.picker.lazy()
end, { desc = 'Search for Plugin Spec' })
map('n', '<leader>sq', function()
  Snacks.picker.qflist()
end, { desc = 'Quickfix List' })
map('n', '<leader>sR', function()
  Snacks.picker.resume()
end, { desc = 'Resume' })
map('n', '<leader>su', function()
  Snacks.picker.undo()
end, { desc = 'Undo History' })
map('n', '<leader>uC', function()
  Snacks.picker.colorschemes()
end, { desc = 'Colorschemes' })

-- LSP-related pickers
map('n', 'gd', function()
  Snacks.picker.lsp_definitions()
end, { desc = 'Goto Definition' })
map('n', 'gD', function()
  Snacks.picker.lsp_declarations()
end, { desc = 'Goto Declaration' })
map('n', 'gr', function()
  Snacks.picker.lsp_references()
end, { nowait = true, desc = 'References' })
map('n', 'gI', function()
  Snacks.picker.lsp_implementations()
end, { desc = 'Goto Implementation' })
map('n', 'gy', function()
  Snacks.picker.lsp_type_definitions()
end, { desc = 'Goto Type Definition' })
map('n', '<leader>ss', function()
  Snacks.picker.lsp_symbols()
end, { desc = 'LSP Symbols' })
map('n', '<leader>sS', function()
  Snacks.picker.lsp_workspace_symbols()
end, { desc = 'LSP Workspace Symbols' })

-----------------------------------------------------------------------------------------------------which-key

local wk = require 'which-key'
wk.setup {
  preset = 'modern',
}

-- Register groups for better organization
wk.add {
  { '<leader>f', group = 'Find' },
  { '<leader>g', group = 'Git' },
  { '<leader>s', group = 'Search' },
  { '<leader>c', group = 'Code' },
  { '<leader>d', group = 'Dotnet/NX' },
  { '<leader>t', group = 'Toggle' },
  { '<leader>u', group = 'UI' },
  { '<leader>h', group = 'Hunk' },
  { '<leader>j', group = 'Journal' },
}

---------------------------------------------------------------------------------------------------------- oil

require('oil').setup {
  default_file_explorer = true,
  view_options = { show_hidden = true },
}

-------------------------------------------------------------------------------------------------------- blink

require('blink.cmp').setup {
  enabled = function()
    return vim.bo.filetype ~= 'markdown'
  end,
  fuzzy = {
    implementation = 'lua',
  },
}

------------------------------------------------------------------------------------------------------ conform

require('conform').setup {
  notify_on_error = false,
  format_on_save = function(bufnr)
    -- Check if format-on-save is disabled globally or for this buffer
    if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
      return nil
    end

    -- Skip formatting for specific filetypes
    local disable_filetypes = { c = true, cpp = true }
    if disable_filetypes[vim.bo[bufnr].filetype] then
      return nil
    end

    return { timeout_ms = 3000, lsp_format = 'fallback' }
  end,
  formatters_by_ft = { lua = { 'stylua' }, cs = { 'csharpier' } },
}

vim.keymap.set('n', '<leader>cf', function()
  require('conform').format { async = true, lsp_format = 'fallback' }
end, { desc = 'Format buffer' })

-- Toggle format-on-save
vim.keymap.set('n', '<leader>tf', function()
  vim.g.disable_autoformat = not vim.g.disable_autoformat
  if vim.g.disable_autoformat then
    vim.notify('Format-on-save disabled', vim.log.levels.INFO)
  else
    vim.notify('Format-on-save enabled', vim.log.levels.INFO)
  end
end, { desc = 'Toggle format-on-save' })

----------------------------------------------------------------------------------------------------- gitsigns

require('gitsigns').setup {
  signs = {
    add = { text = '+' },
    change = { text = '~' },
    delete = { text = '_' },
    topdelete = { text = '‾' },
    changedelete = { text = '~' },
  },
}

---------------------------------------------------------------------------------------------- mini.statusline

require('mini.statusline').setup {
  content = {
    active = function()
      local mode, mode_hl = require('mini.statusline').section_mode { trunc_width = 120 }
      local diagnostics = require('mini.statusline').section_diagnostics { trunc_width = 75 }
      local lsp = require('mini.statusline').section_lsp { trunc_width = 75 }
      local filename = require('mini.statusline').section_filename { trunc_width = 80 }
      local fileinfo = require('mini.statusline').section_fileinfo { trunc_width = 120 }
      local location = require('mini.statusline').section_location { trunc_width = 75 }
      local search = require('mini.statusline').section_searchcount { trunc_width = 75 }
      return require('mini.statusline').combine_groups {
        { hl = mode_hl, strings = { mode } },
        { hl = 'MiniStatuslineDevinfo', strings = { '', '', diagnostics, lsp } },
        '%<',
        { hl = 'MiniStatuslineFilename', strings = { filename } },
        '%=',
        { hl = 'MiniStatuslineFileinfo', strings = { fileinfo } },
        { hl = mode_hl, strings = { search, location } },
      }
    end,
    inactive = nil,
  },
  use_icons = true,
}

------------------------------------------------------------------------------------------------------- roslyn

require('roslyn').setup {}

-------------------------------------------------------------------------------------------------- tokyonight

require('tokyonight').setup {
  style = 'storm',
}

vim.cmd.colorscheme 'tokyonight-storm'
