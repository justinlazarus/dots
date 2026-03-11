vim.pack.add {
  'https://github.com/nvim-treesitter/nvim-treesitter',
  'https://github.com/williamboman/mason.nvim',
  'https://github.com/folke/which-key.nvim',
  'https://github.com/folke/lazydev.nvim',
  'https://github.com/saghen/blink.cmp',
  'https://github.com/justinlazarus/roslyn.nvim',
  'https://github.com/catppuccin/nvim',
  'https://github.com/stevearc/conform.nvim',
  'https://github.com/lewis6991/gitsigns.nvim',
  'https://github.com/nvim-lualine/lualine.nvim',
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

------------------------------------------------------------------------------------------------------- lualine

-- Custom catppuccin theme override to match tmux bar bg
local custom_theme = require('catppuccin.utils.lualine')('mocha')
custom_theme.normal.c = { bg = '#1e1e2e', fg = '#cdd6f4' }
custom_theme.inactive.a = { bg = '#1e1e2e', fg = '#89b4fa' }
custom_theme.inactive.b = { bg = '#1e1e2e', fg = '#585b70', gui = 'bold' }
custom_theme.inactive.c = { bg = '#1e1e2e', fg = '#6c7086' }

require('lualine').setup {
  options = {
    theme = custom_theme,
    section_separators = '',
    component_separators = '',
    globalstatus = true,
  },
  sections = {
    lualine_a = { 'mode' },
    lualine_b = { 'diagnostics' },
    lualine_c = { { 'filename', path = 4 } },
    lualine_x = { 'lsp_progress', 'filetype' },
    lualine_y = { 'progress' },
    lualine_z = { 'location' },
  },
  inactive_sections = {
    lualine_c = { { 'filename', path = 4 } },
    lualine_x = { 'location' },
  },
}

-- Padding below tabline
vim.o.winbar = ' '

-- Fix all tabline-related highlight backgrounds after lualine loads
vim.api.nvim_create_autocmd({ 'ColorScheme', 'VimEnter' }, {
  callback = function()
    vim.schedule(function()
      local base = '#1e1e2e'
      vim.api.nvim_set_hl(0, 'TabLineFill', { bg = base })
      -- Fix lualine's internal tabline transition highlights
      for _, name in ipairs(vim.fn.getcompletion('lualine_c_', 'highlight')) do
        local hl = vim.api.nvim_get_hl(0, { name = name })
        hl.bg = tonumber('1e1e2e', 16)
        vim.api.nvim_set_hl(0, name, hl)
      end
    end)
  end,
})

-- Hide tabline when only one buffer is listed
local function update_tabline()
  local listed = vim.tbl_filter(function(b)
    return vim.bo[b].buflisted
  end, vim.api.nvim_list_bufs())
  vim.o.showtabline = #listed > 1 and 2 or 0
end

vim.api.nvim_create_autocmd({ 'BufAdd', 'BufDelete', 'BufWipeout', 'VimEnter' }, {
  callback = function()
    vim.schedule(update_tabline)
  end,
})

------------------------------------------------------------------------------------------------------- roslyn

require('roslyn').setup {
  filewatching = 'auto',
  broad_search = false,
  lock_target = false,
  fast_init = true,
}

-------------------------------------------------------------------------------------------------- catppuccin

require('catppuccin').setup {
  flavour = 'mocha',
  custom_highlights = function(colors)
    return {
      TabLineFill = { bg = colors.base },
    }
  end,
}

vim.cmd.colorscheme 'catppuccin-mocha'

--------------------------------------------------------------------------------------------------------- octo

-- Custom goto file function for Octo PR diffs (defined before setup)
_G.octo_goto_file = function()
  local bufnr = vim.api.nvim_get_current_buf()
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  
  -- Check if we're in an Octo buffer
  if not string.match(bufname, 'octo://') then
    -- Fall back to default gf behavior
    local ok, err = pcall(function()
      vim.cmd('normal! gf')
    end)
    if not ok then
      vim.notify('Could not find file: ' .. tostring(err), vim.log.levels.WARN)
    end
    return
  end
  
  -- Get current line number in the diff
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  
  -- Search backwards for the diff header to find the file path
  local file_path = nil
  for i = cursor_line, math.max(1, cursor_line - 500), -1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
    if line then
      -- Try multiple patterns to match file paths
      local path = line:match('^%+%+%+ b/(.+)$')  -- +++ b/path/to/file
        or line:match('^%-%-%- a/(.+)$')          -- --- a/path/to/file
        or line:match('^diff %-%-git a/[^%s]+ b/(.+)$')  -- diff --git a/... b/path
        or line:match('^diff %-%-git a/(.+) b/')  -- diff --git a/path b/...
      
      if path then
        file_path = path:gsub('%s+$', '')  -- Trim trailing whitespace
        break
      end
    end
  end
  
  if not file_path then
    -- Debug: show some context
    local context = {}
    for i = math.max(1, cursor_line - 10), math.min(total_lines, cursor_line + 2) do
      local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
      if line then
        table.insert(context, string.format('%d: %s', i, line:sub(1, 80)))
      end
    end
    -- Write to a temp file so we can see it
    local debug_file = '/tmp/octo_debug.txt'
    local f = io.open(debug_file, 'w')
    if f then
      f:write('Buffer: ' .. bufname .. '\n')
      f:write('Cursor line: ' .. cursor_line .. '\n')
      f:write('Context:\n' .. table.concat(context, '\n'))
      f:close()
      vim.notify('Could not find file path. Debug written to ' .. debug_file, vim.log.levels.ERROR)
      vim.cmd('edit ' .. debug_file)
    else
      vim.notify('Could not find file path in diff', vim.log.levels.ERROR)
    end
    return
  end
  
  -- Try to determine the line number from the diff hunk header
  local target_line = nil
  for i = cursor_line, math.max(1, cursor_line - 100), -1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
    if line then
      -- Match hunk header like: @@ -10,5 +10,7 @@
      local old_start, old_count, new_start, new_count = line:match('^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@')
      if new_start then
        -- Calculate offset from hunk start to cursor
        local offset = 0
        for j = i + 1, cursor_line do
          local hunk_line = vim.api.nvim_buf_get_lines(bufnr, j - 1, j, false)[1]
          if hunk_line then
            local first_char = hunk_line:sub(1, 1)
            -- Count lines that exist in the new file (+ and context lines, not -)
            if first_char ~= '-' and first_char ~= '\\' then
              offset = offset + 1
            end
          end
        end
        target_line = tonumber(new_start) + offset - 1
        break
      end
    end
  end
  
  -- Open the file
  local git_root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
  if not git_root or git_root == '' then
    vim.notify('Not in a git repository', vim.log.levels.ERROR)
    return
  end
  
  local full_path = git_root .. '/' .. file_path
  
  if vim.fn.filereadable(full_path) == 1 then
    vim.cmd('edit ' .. vim.fn.fnameescape(full_path))
    if target_line and target_line > 0 then
      vim.api.nvim_win_set_cursor(0, {target_line, 0})
      vim.cmd('normal! zz')  -- Center the line on screen
    end
    vim.notify('Opened ' .. file_path .. (target_line and (':' .. target_line) or ''), vim.log.levels.INFO)
  else
    vim.notify('File not found: ' .. full_path, vim.log.levels.ERROR)
  end
end

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

-- Map to jump from diff to actual file in Octo buffers
-- Works in both PR view and review diff view
vim.api.nvim_create_autocmd({'FileType', 'BufEnter'}, {
  pattern = {'octo', 'octo_*', '*'},
  callback = function(ev)
    local bufname = vim.api.nvim_buf_get_name(ev.buf)
    -- Check if it's an Octo buffer by name (review diffs don't have octo filetype)
    if string.match(bufname, 'octo://') then
      vim.keymap.set('n', '<leader>of', '<cmd>lua _G.octo_goto_file()<CR>', 
        { buffer = ev.buf, desc = 'Open file from diff', noremap = true, silent = false })
    end
  end,
})
