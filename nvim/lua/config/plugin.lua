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
  'https://github.com/ibhagwan/fzf-lua',
}

--------------------------------------------------------------------------------------------------- treesitter

-- Configure Treesitter after plugins are loaded
vim.api.nvim_create_autocmd('VimEnter', {
  callback = function()
    -- Check if parsers need to be installed (only once)
    local parser_install_file = vim.fn.stdpath('data') .. '/treesitter_parsers_installed'
    
    if vim.fn.filereadable(parser_install_file) == 0 then
      -- First time setup - install parsers
      local ok, install = pcall(require, 'nvim-treesitter.install')
      if ok then
        install.install({
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
        
        -- Create marker file to prevent reinstallation
        vim.fn.writefile({}, parser_install_file)
      end
    end
    
    -- Setup Treesitter configuration
    local ok, configs = pcall(require, 'nvim-treesitter.configs')
    if ok then
      configs.setup {
        -- Don't auto-install to prevent compilation on every load
        auto_install = false,
        
        -- Enable syntax highlighting
        highlight = {
          enable = true,
          -- Disable for large files to improve performance
          disable = function(lang, buf)
            local max_filesize = 100 * 1024 -- 100 KB
            local ok_stat, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
            if ok_stat and stats and stats.size > max_filesize then
              return true
            end
          end,
        },
        
        -- Enable better indentation
        indent = {
          enable = true,
        },
      }
    end
    
    -- Use bash parser for zsh files (no dedicated zsh parser exists)
    vim.treesitter.language.register('bash', 'zsh')
  end,
})

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
  ensure_installed 'yaml-language-server' -- yamlls
  ensure_installed 'roslyn' -- C#/.NET (via third-party registry)
  ensure_installed 'angular-language-server' -- angular
  ensure_installed 'csharpier' -- C# formatter
  ensure_installed 'sqlfmt' -- SQL formatter
  ensure_installed 'stylua' -- Lua formatter
  ensure_installed 'yamlfmt' -- YAML formatter
  ensure_installed 'terraform-ls' -- Terraform
  ensure_installed 'rust-analyzer' -- Rust
end)

------------------------------------------------------------------------------------------------------- snacks

-- Snacks setup (keeping everything except picker)
local Snacks = require 'snacks'
Snacks.setup {
  bigfile = {},
  dashboard = {},
  explorer = {},
  indent = {},
  input = {},
  -- picker = {}, -- REMOVED - using fzf-lua instead
  notifier = {},
  quickfile = {},
  scope = {},
  statuscolumn = {},
  words = {},
}

-- FZF-LUA keymaps (same bindings, working input!)
local map = vim.keymap.set

-- Top Pickers & Explorer
map('n', '<leader><space>', '<cmd>FzfLua files<cr>', { desc = 'Smart Find Files' })
map('n', '<leader>,', '<cmd>FzfLua buffers<cr>', { desc = 'Buffers' })
map('n', '<leader>/', '<cmd>FzfLua live_grep<cr>', { desc = 'Grep' })
map('n', '<leader>:', '<cmd>FzfLua command_history<cr>', { desc = 'Command History' })
map('n', '<leader>n', '<cmd>FzfLua<cr>', { desc = 'All Pickers' })
map('n', '<leader>e', function()
  Snacks.explorer()
end, { desc = 'File Explorer' })

-- find
map('n', '<leader>fb', '<cmd>FzfLua buffers<cr>', { desc = 'Buffers' })
map('n', '<leader>fc', function() 
  require('fzf-lua').files({ cwd = vim.fn.stdpath('config') })
end, { desc = 'Find Config File' })
map('n', '<leader>ff', '<cmd>FzfLua files<cr>', { desc = 'Find Files' })
map('n', '<leader>fg', '<cmd>FzfLua git_files<cr>', { desc = 'Find Git Files' })
map('n', '<leader>fp', '<cmd>FzfLua files<cr>', { desc = 'Projects' })
map('n', '<leader>fr', '<cmd>FzfLua oldfiles<cr>', { desc = 'Recent' })

-- git
map('n', '<leader>gb', '<cmd>FzfLua git_branches<cr>', { desc = 'Git Branches' })
map('n', '<leader>gl', '<cmd>FzfLua git_commits<cr>', { desc = 'Git Log' })
map('n', '<leader>gL', '<cmd>FzfLua git_bcommits<cr>', { desc = 'Git Log Line' })
map('n', '<leader>gs', '<cmd>FzfLua git_status<cr>', { desc = 'Git Status' })
map('n', '<leader>gS', '<cmd>FzfLua git_stash<cr>', { desc = 'Git Stash' })
map('n', '<leader>gd', '<cmd>FzfLua git_status<cr>', { desc = 'Git Diff (Hunks)' })
map('n', '<leader>gf', '<cmd>FzfLua git_bcommits<cr>', { desc = 'Git Log File' })

-- Grep / buffer lines
map('n', '<leader>sb', '<cmd>FzfLua blines<cr>', { desc = 'Buffer Lines' })
map('n', '<leader>sB', '<cmd>FzfLua grep_curbuf<cr>', { desc = 'Grep Open Buffers' })
map('n', '<leader>sg', '<cmd>FzfLua live_grep<cr>', { desc = 'Grep' })
map({ 'n', 'x' }, '<leader>sw', '<cmd>FzfLua grep_cword<cr>', { desc = 'Visual selection or word' })

-- search helpers
map('n', '<leader>s"', '<cmd>FzfLua registers<cr>', { desc = 'Registers' })
map('n', '<leader>s/', '<cmd>FzfLua search_history<cr>', { desc = 'Search History' })
map('n', '<leader>sa', '<cmd>FzfLua autocmds<cr>', { desc = 'Autocmds' })
map('n', '<leader>sc', '<cmd>FzfLua command_history<cr>', { desc = 'Command History' })
map('n', '<leader>sC', '<cmd>FzfLua commands<cr>', { desc = 'Commands' })
map('n', '<leader>sd', '<cmd>FzfLua diagnostics_workspace<cr>', { desc = 'Diagnostics' })
map('n', '<leader>sD', '<cmd>FzfLua diagnostics_document<cr>', { desc = 'Buffer Diagnostics' })
map('n', '<leader>sh', '<cmd>FzfLua help_tags<cr>', { desc = 'Help Pages' })
map('n', '<leader>sH', '<cmd>FzfLua highlights<cr>', { desc = 'Highlights' })
map('n', '<leader>si', '<cmd>FzfLua<cr>', { desc = 'All Pickers' })
map('n', '<leader>sj', '<cmd>FzfLua jumps<cr>', { desc = 'Jumps' })
map('n', '<leader>sk', '<cmd>FzfLua keymaps<cr>', { desc = 'Keymaps' })
map('n', '<leader>sl', '<cmd>FzfLua loclist<cr>', { desc = 'Location List' })
map('n', '<leader>sm', '<cmd>FzfLua marks<cr>', { desc = 'Marks' })
map('n', '<leader>sM', '<cmd>FzfLua manpages<cr>', { desc = 'Man Pages' })
map('n', '<leader>sp', '<cmd>FzfLua<cr>', { desc = 'All Pickers' })
map('n', '<leader>sq', '<cmd>FzfLua quickfix<cr>', { desc = 'Quickfix List' })
map('n', '<leader>sR', '<cmd>FzfLua resume<cr>', { desc = 'Resume' })
map('n', '<leader>su', '<cmd>FzfLua changes<cr>', { desc = 'Change List' })
map('n', '<leader>uC', '<cmd>FzfLua colorschemes<cr>', { desc = 'Colorschemes' })

-- LSP-related pickers
map('n', 'gd', '<cmd>FzfLua lsp_definitions<cr>', { desc = 'Goto Definition' })
map('n', 'gD', '<cmd>FzfLua lsp_declarations<cr>', { desc = 'Goto Declaration' })
map('n', 'gr', '<cmd>FzfLua lsp_references<cr>', { nowait = true, desc = 'References' })
map('n', 'gI', '<cmd>FzfLua lsp_implementations<cr>', { desc = 'Goto Implementation' })
map('n', 'gy', '<cmd>FzfLua lsp_typedefs<cr>', { desc = 'Goto Type Definition' })
map('n', '<leader>ss', '<cmd>FzfLua lsp_document_symbols<cr>', { desc = 'LSP Symbols' })
map('n', '<leader>sS', '<cmd>FzfLua lsp_workspace_symbols<cr>', { desc = 'LSP Workspace Symbols' })

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
  formatters_by_ft = { 
    lua = { 'stylua' }, 
    cs = { 'csharpier' },
    yaml = { 'yamlfmt' },
  },
  formatters = {
    csharpier = {
      command = "csharpier",
      args = { "format", "--write-stdout" },
      stdin = true,
    },
  },
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
