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
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/pwntester/octo.nvim.git',
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
  { '<leader>n', group = 'Nx', icon = '󱁤' },
  { '<leader>o', group = 'Octo', icon = '󰊤' },
  { '<leader>oi', group = 'Issue' },
  { '<leader>op', group = 'Pull Request' },
  { '<leader>oa', group = 'Assignee' },
  { '<leader>ol', group = 'Label' },
  { '<leader>oc', group = 'Comment' },
  { '<leader>or', group = 'Reaction' },
  { '<leader>ov', group = 'Review' },
  { '<leader>os', group = 'Suggestion' },
  { '<leader>og', group = 'Go to' },
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

require('roslyn').setup {
  filewatching = 'auto',
  broad_search = false,
  lock_target = false,
  fast_init = true,
}

-------------------------------------------------------------------------------------------------- tokyonight

require('tokyonight').setup {
  style = 'storm',
}

vim.cmd.colorscheme 'tokyonight-storm'

--------------------------------------------------------------------------------------------------------- octo

require('octo').setup {
  picker = 'snacks',
  enable_builtin = true,
  mappings_disable_default = true,
  pull_requests = {
    order_by = {
      field = 'UPDATED_AT',        -- CREATED_AT, UPDATED_AT, or COMMENTS
      direction = 'DESC'            -- DESC or ASC
    },
    always_select_remote_on_create = false,
    use_branch_name_as_title = false
  },
  issues = {
    order_by = {
      field = 'UPDATED_AT',         -- CREATED_AT, UPDATED_AT, or COMMENTS  
      direction = 'DESC'            -- DESC or ASC
    }
  },
  picker_config = {
    use_emojis = false,
    mappings = {
      open_in_browser = { lhs = '<C-b>', desc = 'open issue in browser' },
      copy_url = { lhs = '<C-y>', desc = 'copy url to system clipboard' },
      checkout_pr = { lhs = '<C-o>', desc = 'checkout pull request' },
      merge_pr = { lhs = '<C-r>', desc = 'merge pull request' },
    },
  },
  mappings = {
    issue = {
      issue_options = { lhs = '<CR>', desc = 'show issue options' },
      close_issue = { lhs = '<leader>oic', desc = 'close issue' },
      reopen_issue = { lhs = '<leader>oio', desc = 'reopen issue' },
      list_issues = { lhs = '<leader>oil', desc = 'list open issues on same repo' },
      reload = { lhs = '<leader>oir', desc = 'reload issue' },
      open_in_browser = { lhs = '<leader>oib', desc = 'open issue in browser' },
      copy_url = { lhs = '<leader>oiy', desc = 'copy url to system clipboard' },
      add_assignee = { lhs = '<leader>oaa', desc = 'add assignee' },
      remove_assignee = { lhs = '<leader>oad', desc = 'remove assignee' },
      create_label = { lhs = '<leader>olc', desc = 'create label' },
      add_label = { lhs = '<leader>ola', desc = 'add label' },
      remove_label = { lhs = '<leader>old', desc = 'remove label' },
      goto_issue = { lhs = '<leader>ogi', desc = 'navigate to a local repo issue' },
      add_comment = { lhs = '<leader>oca', desc = 'add comment' },
      delete_comment = { lhs = '<leader>ocd', desc = 'delete comment' },
      next_comment = { lhs = ']c', desc = 'go to next comment' },
      prev_comment = { lhs = '[c', desc = 'go to previous comment' },
      react_hooray = { lhs = '<leader>orp', desc = 'add/remove 🎉 reaction' },
      react_heart = { lhs = '<leader>orh', desc = 'add/remove ❤️ reaction' },
      react_eyes = { lhs = '<leader>ore', desc = 'add/remove 👀 reaction' },
      react_thumbs_up = { lhs = '<leader>or+', desc = 'add/remove 👍 reaction' },
      react_thumbs_down = { lhs = '<leader>or-', desc = 'add/remove 👎 reaction' },
      react_rocket = { lhs = '<leader>orr', desc = 'add/remove 🚀 reaction' },
      react_laugh = { lhs = '<leader>orl', desc = 'add/remove 😄 reaction' },
      react_confused = { lhs = '<leader>orc', desc = 'add/remove 😕 reaction' },
    },
    pull_request = {
      pr_options = { lhs = '<CR>', desc = 'show PR options' },
      checkout_pr = { lhs = '<leader>opo', desc = 'checkout PR' },
      merge_pr = { lhs = '<leader>opm', desc = 'merge PR' },
      list_commits = { lhs = '<leader>opc', desc = 'list PR commits' },
      list_changed_files = { lhs = '<leader>opf', desc = 'list PR changed files' },
      show_pr_diff = { lhs = '<leader>opd', desc = 'show PR diff' },
      add_reviewer = { lhs = '<leader>ova', desc = 'add reviewer' },
      remove_reviewer = { lhs = '<leader>ovd', desc = 'remove reviewer request' },
      close_issue = { lhs = '<leader>oic', desc = 'close PR' },
      reopen_issue = { lhs = '<leader>oio', desc = 'reopen PR' },
      list_issues = { lhs = '<leader>oil', desc = 'list open issues on same repo' },
      reload = { lhs = '<leader>opr', desc = 'reload PR' },
      open_in_browser = { lhs = '<leader>opb', desc = 'open PR in browser' },
      copy_url = { lhs = '<leader>opy', desc = 'copy url to system clipboard' },
      goto_file = { lhs = 'gf', desc = 'go to file' },
      add_assignee = { lhs = '<leader>oaa', desc = 'add assignee' },
      remove_assignee = { lhs = '<leader>oad', desc = 'remove assignee' },
      create_label = { lhs = '<leader>olc', desc = 'create label' },
      add_label = { lhs = '<leader>ola', desc = 'add label' },
      remove_label = { lhs = '<leader>old', desc = 'remove label' },
      goto_issue = { lhs = '<leader>ogi', desc = 'navigate to a local repo issue' },
      add_comment = { lhs = '<leader>oca', desc = 'add comment' },
      delete_comment = { lhs = '<leader>ocd', desc = 'delete comment' },
      next_comment = { lhs = ']c', desc = 'go to next comment' },
      prev_comment = { lhs = '[c', desc = 'go to previous comment' },
      react_hooray = { lhs = '<leader>orp', desc = 'add/remove 🎉 reaction' },
      react_heart = { lhs = '<leader>orh', desc = 'add/remove ❤️ reaction' },
      react_eyes = { lhs = '<leader>ore', desc = 'add/remove 👀 reaction' },
      react_thumbs_up = { lhs = '<leader>or+', desc = 'add/remove 👍 reaction' },
      react_thumbs_down = { lhs = '<leader>or-', desc = 'add/remove 👎 reaction' },
      react_rocket = { lhs = '<leader>orr', desc = 'add/remove 🚀 reaction' },
      react_laugh = { lhs = '<leader>orl', desc = 'add/remove 😄 reaction' },
      react_confused = { lhs = '<leader>orc', desc = 'add/remove 😕 reaction' },
      review_start = { lhs = '<leader>ovs', desc = 'start a review for the current PR' },
      review_resume = { lhs = '<leader>ovr', desc = 'resume a pending review for the current PR' },
    },
    review_thread = {
      goto_issue = { lhs = '<leader>ogi', desc = 'navigate to a local repo issue' },
      add_comment = { lhs = '<leader>oca', desc = 'add comment' },
      add_suggestion = { lhs = '<leader>osa', desc = 'add suggestion' },
      delete_comment = { lhs = '<leader>ocd', desc = 'delete comment' },
      next_comment = { lhs = ']c', desc = 'go to next comment' },
      prev_comment = { lhs = '[c', desc = 'go to previous comment' },
      select_next_entry = { lhs = ']q', desc = 'move to next changed file' },
      select_prev_entry = { lhs = '[q', desc = 'move to previous changed file' },
    },
    review_diff = {
      submit_review = { lhs = '<leader>ovs', desc = 'submit review' },
      discard_review = { lhs = '<leader>ovd', desc = 'discard review' },
      add_review_comment = { lhs = '<leader>oca', desc = 'add a new review comment' },
      add_review_suggestion = { lhs = '<leader>osa', desc = 'add a new review suggestion' },
      next_thread = { lhs = ']t', desc = 'move to next thread' },
      prev_thread = { lhs = '[t', desc = 'move to previous thread' },
      select_next_entry = { lhs = ']q', desc = 'move to next changed file' },
      select_prev_entry = { lhs = '[q', desc = 'move to previous changed file' },
      close_review_tab = { lhs = '<C-c>', desc = 'close review tab' },
    },
    file_panel = {
      next_entry = { lhs = 'j', desc = 'move to next changed file' },
      prev_entry = { lhs = 'k', desc = 'move to previous changed file' },
      select_entry = { lhs = '<cr>', desc = 'show selected changed file diffs' },
      select_next_entry = { lhs = ']q', desc = 'move to next changed file' },
      select_prev_entry = { lhs = '[q', desc = 'move to previous changed file' },
    },
    submit_win = {
      approve_review = { lhs = '<C-a>', desc = 'approve review', mode = { 'n', 'i' } },
      comment_review = { lhs = '<C-m>', desc = 'comment review', mode = { 'n', 'i' } },
      request_changes = { lhs = '<C-r>', desc = 'request changes review', mode = { 'n', 'i' } },
      close_review_tab = { lhs = '<C-c>', desc = 'close review tab', mode = { 'n', 'i' } },
    },
  },
}
