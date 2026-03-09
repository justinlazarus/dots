vim.pack.add {
  'https://github.com/nvim-treesitter/nvim-treesitter',
  'https://github.com/williamboman/mason.nvim',
  'https://github.com/folke/which-key.nvim',
  'https://github.com/folke/lazydev.nvim',
  'https://github.com/saghen/blink.cmp',
  'https://github.com/justinlazarus/roslyn.nvim',
  'https://github.com/folke/tokyonight.nvim',
  'https://github.com/stevearc/conform.nvim',
  'https://github.com/lewis6991/gitsigns.nvim',
  'https://github.com/echasnovski/mini.statusline',
  'https://github.com/nvim-tree/nvim-web-devicons',
  'https://github.com/stevearc/oil.nvim',
  'https://github.com/mfussenegger/nvim-dap',
  'https://github.com/rcarriga/nvim-dap-ui',
  'https://github.com/nvim-neotest/nvim-nio',
  'https://github.com/nvim-treesitter/nvim-treesitter-context',
  'https://github.com/nvim-treesitter/nvim-treesitter-textobjects',
}

--------------------------------------------------------------------------------------------------- treesitter
local ok, configs = pcall(require, 'nvim-treesitter.configs')
if ok then
  configs.setup {
    ensure_installed = {
      'bash',
      'c_sharp',
      'css',
      'diff',
      'html',
      'javascript',
      'json',
      'lua',
      'markdown',
      'tsx',
      'typescript',
      'vim',
      'vimdoc',
      'angular',
      'xml',
      'yaml',
      'toml',
      'dockerfile',
      'sql',
    },
    sync_install = false,
    auto_install = true,

    highlight = {
      enable = true,
      disable = function(_, buf)
        local max_filesize = 100 * 1024 -- 100 KB
        local ok_stat, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(buf))
        if ok_stat and stats and stats.size > max_filesize then
          return true
        end
      end,
    },
    indent = { enable = true },
  }
end

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
  ensure_installed 'yaml-language-server' -- yamlls
  ensure_installed 'roslyn' -- C#/.NET (via third-party registry)
  ensure_installed 'angular-language-server' -- angular
  ensure_installed 'eslint-lsp' -- eslint
  ensure_installed 'prettier' -- TS/JS/HTML formatter
  ensure_installed 'csharpier' -- C# formatter
  ensure_installed 'sqlfmt' -- SQL formatter
  ensure_installed 'stylua' -- Lua formatter
  ensure_installed 'yamlfmt' -- YAML formatter
  if vim.fn.executable 'terraform' == 1 then
    ensure_installed 'terraform-ls'
  end
  if vim.fn.executable 'rustc' == 1 then
    ensure_installed 'rust-analyzer'
  end
  if vim.fn.executable 'go' == 1 then
    ensure_installed 'gopls'
  end
  ensure_installed 'netcoredbg' -- C# debugger
  ensure_installed 'dockerfile-language-server' -- dockerls
  ensure_installed 'bash-language-server' -- bashls
  ensure_installed 'sql-language-server' -- sqlls
end)

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
  { '<leader>b', group = 'Buffer' },
  { '<leader>d', group = 'Debug' },
  { '<leader>u', group = 'UI' },
  { '<leader>h', group = 'Hunk' },
  { '<leader>o', group = 'Nx', icon = '󱁤' },
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

---------------------------------------------------------------------------------------------- treesitter-context

require('treesitter-context').setup { enable = true, multiline_threshold = 4 }

--------------------------------------------------------------------------------------- treesitter-textobjects

require('nvim-treesitter-textobjects').setup { select = { lookahead = true } }

local select_textobject = require('nvim-treesitter-textobjects.select').select_textobject
for _, mode in ipairs { 'x', 'o' } do
  vim.keymap.set(mode, 'am', function()
    select_textobject '@function.outer'
  end, { desc = 'Around method/function' })
  vim.keymap.set(mode, 'im', function()
    select_textobject '@function.inner'
  end, { desc = 'Inside method/function' })
end

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
    typescript = { 'prettier' },
    javascript = { 'prettier' },
    html = { 'prettier' },
    htmlangular = { 'prettier' },
  },
  formatters = {
    csharpier = {
      inherit = false,
      command = 'csharpier',
      args = { 'format', '--write-stdout' },
      stdin = true,
    },
  },
}

vim.keymap.set('n', '<leader>bf', function()
  require('conform').format { async = true, lsp_format = 'fallback' }
end, { desc = 'Format buffer' })

vim.keymap.set('n', '<leader>bd', function()
  Snacks.bufdelete()
end, { desc = 'Delete buffer' })

-- Toggle format-on-save
vim.keymap.set('n', '<leader>bF', function()
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

require('roslyn').setup { fast_init = true }

-------------------------------------------------------------------------------------------------- tokyonight

require('tokyonight').setup {
  style = 'storm',
}

vim.cmd.colorscheme 'tokyonight-storm'
