vim.pack.add {
  'https://github.com/ibhagwan/fzf-lua',
}

local fzf = require 'fzf-lua'

fzf.setup {
  'default-title',
  winopts = {
    height = 0.85,
    width = 0.80,
    row = 0.35,
    col = 0.50,
    border = 'rounded',
    preview = {
      border = 'border',
      wrap = 'nowrap',
      hidden = 'nohidden',
    },
  },
  keymap = {
    fzf = {
      ['ctrl-q'] = 'select-all+accept',
      ['ctrl-u'] = 'unix-line-discard',
      ['ctrl-w'] = 'unix-word-rubout',
    },
  },
  git = {
    status = {
      prompt = 'GitStatus❯ ',
      preview_pager = 'delta --features=+side-by-side',
    },
    commits = {
      prompt = 'Commits❯ ',
      preview_pager = 'delta --features=+side-by-side',
    },
    bcommits = {
      prompt = 'BCommits❯ ',
      preview_pager = 'delta --features=+side-by-side',
    },
    branches = {
      prompt = 'Branches❯ ',
    },
  },
  lsp = {
    prompt_postfix = '❯ ',
    symbols = {
      symbol_style = 1,
      symbol_hl_prefix = 'CmpItemKind',
    },
  },
  files = {
    prompt = 'Files❯ ',
    fd_opts = [[--color=never --type f --hidden --follow --exclude .git]],
  },
  grep = {
    prompt = 'Rg❯ ',
    input_prompt = 'Grep For❯ ',
    -- Keep your existing rg_opts
    rg_opts = '--column --line-number --no-heading --color=always --smart-case --max-columns=4096 -e',
    rg_glob = true, -- ADD THIS: Enables the -- separator
    glob_separator = ' --', -- ADD THIS: Defines the separator
  },
}

local map = vim.keymap.set

-- Top Pickers & Explorer
map('n', '<leader><space>', '<cmd>FzfLua files<cr>', { desc = 'Smart Find Files' })
map('n', '<leader>,', '<cmd>FzfLua buffers<cr>', { desc = 'Buffers' })
map('n', '<leader>/', '<cmd>FzfLua live_grep_native<cr>', { desc = 'Grep' })
map('n', '<leader>:', '<cmd>FzfLua command_history<cr>', { desc = 'Command History' })
map('n', '<leader>n', '<cmd>FzfLua<cr>', { desc = 'All Pickers' })

-- Find
map('n', '<leader>fb', '<cmd>FzfLua buffers<cr>', { desc = 'Buffers' })
map('n', '<leader>fc', function()
  fzf.files { cwd = vim.fn.stdpath 'config' }
end, { desc = 'Find Config File' })
map('n', '<leader>ff', '<cmd>FzfLua files<cr>', { desc = 'Find Files' })
map('n', '<leader>fg', '<cmd>FzfLua git_files<cr>', { desc = 'Find Git Files' })
map('n', '<leader>fp', '<cmd>FzfLua files<cr>', { desc = 'Projects' })
map('n', '<leader>fr', '<cmd>FzfLua oldfiles<cr>', { desc = 'Recent' })

-- Git
map('n', '<leader>gb', '<cmd>FzfLua git_branches<cr>', { desc = 'Git Branches' })
map('n', '<leader>gl', '<cmd>FzfLua git_commits<cr>', { desc = 'Git Log' })
map('n', '<leader>gL', '<cmd>FzfLua git_bcommits<cr>', { desc = 'Git Log Line' })
map('n', '<leader>gs', '<cmd>FzfLua git_status<cr>', { desc = 'Git Status' })
map('n', '<leader>gS', '<cmd>FzfLua git_stash<cr>', { desc = 'Git Stash' })
map('n', '<leader>gd', '<cmd>FzfLua git_status<cr>', { desc = 'Git Diff (Hunks)' })
map('n', '<leader>gf', '<cmd>FzfLua git_bcommits<cr>', { desc = 'Git Log File' })

-- Search & Grep
map('n', '<leader>sb', '<cmd>FzfLua blines<cr>', { desc = 'Buffer Lines' })
map('n', '<leader>sB', '<cmd>FzfLua grep_curbuf<cr>', { desc = 'Grep Open Buffers' })
map('n', '<leader>sg', '<cmd>FzfLua live_grep<cr>', { desc = 'Grep' })
map({ 'n', 'x' }, '<leader>sw', '<cmd>FzfLua grep_cword<cr>', { desc = 'Visual selection or word' })

-- Search Helpers
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

-- LSP pickers
map('n', 'gd', '<cmd>FzfLua lsp_definitions<cr>', { desc = 'Goto Definition' })
map('n', 'gD', '<cmd>FzfLua lsp_declarations<cr>', { desc = 'Goto Declaration' })
map('n', 'grr', '<cmd>FzfLua lsp_references<cr>', { nowait = true, desc = 'References' })
map('n', 'gri', '<cmd>FzfLua lsp_implementations<cr>', { desc = 'Goto Implementation' })
map('n', 'gy', '<cmd>FzfLua lsp_typedefs<cr>', { desc = 'Goto Type Definition' })
map('n', '<leader>ss', '<cmd>FzfLua lsp_document_symbols<cr>', { desc = 'LSP Symbols' })
map('n', '<leader>sS', '<cmd>FzfLua lsp_workspace_symbols<cr>', { desc = 'LSP Workspace Symbols' })
