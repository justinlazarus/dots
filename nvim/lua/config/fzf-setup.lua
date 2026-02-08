-- Complete fzf-lua configuration to replace Snacks picker
-- Now with proper bat integration for beautiful previews

vim.pack.add {
  'https://github.com/ibhagwan/fzf-lua',
  'https://github.com/nvim-tree/nvim-web-devicons',
}

local fzf = require('fzf-lua')

fzf.setup({
  'telescope',  -- Use telescope-like defaults
  winopts = {
    height = 0.85,
    width = 0.80,
    border = 'rounded',
    preview = {
      default = 'bat',  -- Now we have bat installed!
    },
  },
  previewers = {
    bat = {
      cmd = "/opt/homebrew/bin/bat",
      args = "--style=numbers,changes --color always --theme TwoDark",
    },
    builtin = {
      syntax = true,          -- Fallback to builtin if bat fails
      syntax_limit_l = 0,     
      syntax_limit_b = 1024*1024,
    },
  },
  keymap = {
    fzf = {
      ["ctrl-q"] = "select-all+accept",
      ["ctrl-u"] = "unix-line-discard", -- Clear entire line - WORKS!
      ["ctrl-w"] = "unix-word-rubout",  -- Delete word backwards - WORKS!
    },
  },
  files = {
    cmd = "/opt/homebrew/bin/fd",
    fd_opts = [[--color=never --type f --hidden --follow --exclude .git]],
  },
  grep = {
    cmd = "/opt/homebrew/bin/rg",
    rg_opts = "--column --line-number --no-heading --color=always --smart-case --max-columns=4096",
    silent = true,
  },
})