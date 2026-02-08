return {
  'ibhagwan/fzf-lua',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  config = function()
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
        find_opts = [[-type f -not -path '*/\.git/*' -printf '%P\n']],
        fd_opts = [[--color=never --type f --hidden --follow --exclude .git]],
      },
      grep = {
        prompt = 'Rg❯ ',
        input_prompt = 'Grep For❯ ',
        rg_opts = '--column --line-number --no-heading --color=always --smart-case --max-columns=4096 -e',
      },
    }
  end,
  keys = {
    { '<leader><space>', '<cmd>FzfLua files<cr>', desc = 'Smart Find Files' },
    { '<leader>,', '<cmd>FzfLua buffers<cr>', desc = 'Buffers' },
    { '<leader>/', '<cmd>FzfLua live_grep<cr>', desc = 'Grep' },
    { '<leader>:', '<cmd>FzfLua command_history<cr>', desc = 'Command History' },
    {
      '<leader>n',
      function()
        vim.cmd 'messages'
      end,
      desc = 'Notification History',
    },
    { '<leader>e', '<cmd>FzfLua files<cr>', desc = 'File Explorer' },

    { '<leader>fb', '<cmd>FzfLua buffers<cr>', desc = 'Buffers' },
    {
      '<leader>fc',
      function()
        require('fzf-lua').files { cwd = vim.fn.stdpath 'config' }
      end,
      desc = 'Find Config File',
    },
    { '<leader>ff', '<cmd>FzfLua files<cr>', desc = 'Find Files' },
    { '<leader>fg', '<cmd>FzfLua git_files<cr>', desc = 'Find Git Files' },
    {
      '<leader>fp',
      function()
        -- Projects - can integrate with project.nvim or custom
        require('fzf-lua').files { cwd = '~/work/repos' } -- adjust path
      end,
      desc = 'Projects',
    },
    { '<leader>fr', '<cmd>FzfLua oldfiles<cr>', desc = 'Recent' },

    -- Git - FULL git integration!
    { '<leader>gb', '<cmd>FzfLua git_branches<cr>', desc = 'Git Branches' },
    { '<leader>gl', '<cmd>FzfLua git_commits<cr>', desc = 'Git Log' },
    { '<leader>gL', '<cmd>FzfLua git_bcommits<cr>', desc = 'Git Log Line' },
    { '<leader>gs', '<cmd>FzfLua git_status<cr>', desc = 'Git Status' },
    { '<leader>gS', '<cmd>FzfLua git_stash<cr>', desc = 'Git Stash' },
    { '<leader>gd', '<cmd>FzfLua git_status<cr>', desc = 'Git Diff (Hunks)' },
    { '<leader>gf', '<cmd>FzfLua git_bcommits<cr>', desc = 'Git Log File' },

    -- Search & Grep
    { '<leader>sb', '<cmd>FzfLua blines<cr>', desc = 'Buffer Lines' },
    { '<leader>sB', '<cmd>FzfLua grep_curbuf<cr>', desc = 'Grep Open Buffers' },
    { '<leader>sg', '<cmd>FzfLua live_grep<cr>', desc = 'Grep' },
    { '<leader>sw', '<cmd>FzfLua grep_cword<cr>', desc = 'Grep Word Under Cursor', mode = { 'n', 'x' } },

    -- Search Helpers - ALL covered!
    { '<leader>s"', '<cmd>FzfLua registers<cr>', desc = 'Registers' },
    { '<leader>s/', '<cmd>FzfLua search_history<cr>', desc = 'Search History' },
    { '<leader>sa', '<cmd>FzfLua autocmds<cr>', desc = 'Autocmds' },
    { '<leader>sc', '<cmd>FzfLua command_history<cr>', desc = 'Command History' },
    { '<leader>sC', '<cmd>FzfLua commands<cr>', desc = 'Commands' },
    { '<leader>sd', '<cmd>FzfLua diagnostics_workspace<cr>', desc = 'Diagnostics' },
    { '<leader>sD', '<cmd>FzfLua diagnostics_document<cr>', desc = 'Buffer Diagnostics' },
    { '<leader>sh', '<cmd>FzfLua help_tags<cr>', desc = 'Help Pages' },
    { '<leader>sH', '<cmd>FzfLua highlights<cr>', desc = 'Highlights' },
    {
      '<leader>si',
      function()
        -- Icons - custom implementation or use nvim-web-devicons
        require('fzf-lua').files { prompt = 'Icons❯ ', cwd = vim.fn.stdpath 'data' .. '/lazy/nvim-web-devicons' }
      end,
      desc = 'Icons',
    },
    { '<leader>sj', '<cmd>FzfLua jumps<cr>', desc = 'Jumps' },
    { '<leader>sk', '<cmd>FzfLua keymaps<cr>', desc = 'Keymaps' },
    { '<leader>sl', '<cmd>FzfLua loclist<cr>', desc = 'Location List' },
    { '<leader>sm', '<cmd>FzfLua marks<cr>', desc = 'Marks' },
    { '<leader>sM', '<cmd>FzfLua manpages<cr>', desc = 'Man Pages' },
    {
      '<leader>sp',
      function()
        -- Lazy plugins
        require('fzf-lua').files { cwd = vim.fn.stdpath 'data' .. '/lazy', prompt = 'Plugins❯ ' }
      end,
      desc = 'Search for Plugin Spec',
    },
    { '<leader>sq', '<cmd>FzfLua quickfix<cr>', desc = 'Quickfix List' },
    { '<leader>sR', '<cmd>FzfLua resume<cr>', desc = 'Resume' },
    {
      '<leader>su',
      function()
        -- Undo history - requires undotree plugin or custom
        vim.cmd 'UndotreeToggle' -- if you have undotree
      end,
      desc = 'Undo History',
    },
    { '<leader>uC', '<cmd>FzfLua colorschemes<cr>', desc = 'Colorschemes' },

    -- LSP - FULL LSP integration that works better than Snacks!
    { 'gd', '<cmd>FzfLua lsp_definitions<cr>', desc = 'Goto Definition' },
    { 'gD', '<cmd>FzfLua lsp_declarations<cr>', desc = 'Goto Declaration' },
    { 'grr', '<cmd>FzfLua lsp_references<cr>', desc = 'References' },
    { 'gri', '<cmd>FzfLua lsp_implementations<cr>', desc = 'Goto Implementation' },
    { 'gy', '<cmd>FzfLua lsp_typedefs<cr>', desc = 'Goto Type Definition' },
    { '<leader>ss', '<cmd>FzfLua lsp_document_symbols<cr>', desc = 'LSP Symbols' },
    { '<leader>sS', '<cmd>FzfLua lsp_workspace_symbols<cr>', desc = 'LSP Workspace Symbols' },
  },
}

