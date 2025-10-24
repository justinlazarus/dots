return {
  'echasnovski/mini.statusline',
  version = false,
  opts = {
    -- Content of statusline as functions which return statusline string. See
    -- `:h statusline` and code of default contents (used instead of `nil`).
    content = {
      -- Content for active window - custom function to exclude git info
      active = function()
        local mode, mode_hl = require('mini.statusline').section_mode({ trunc_width = 120 })
        local git = '' -- Empty string to exclude git info
        local diff = '' -- Empty string to exclude git diff info
        local diagnostics = require('mini.statusline').section_diagnostics({ trunc_width = 75 })
        local lsp = require('mini.statusline').section_lsp({ trunc_width = 75 })
        local filename = require('mini.statusline').section_filename({ trunc_width = 80 })
        local fileinfo = require('mini.statusline').section_fileinfo({ trunc_width = 120 })
        local location = require('mini.statusline').section_location({ trunc_width = 75 })
        local search = require('mini.statusline').section_searchcount({ trunc_width = 75 })

        return require('mini.statusline').combine_groups({
          { hl = mode_hl,                  strings = { mode } },
          { hl = 'MiniStatuslineDevinfo',  strings = { git, diff, diagnostics, lsp } },
          '%<', -- Mark general truncate point
          { hl = 'MiniStatuslineFilename', strings = { filename } },
          '%=', -- End left alignment
          { hl = 'MiniStatuslineFileinfo', strings = { fileinfo } },
          { hl = mode_hl,                  strings = { search, location } },
        })
      end,
      -- Content for inactive window(s)
      inactive = nil,
    },

    -- Whether to use icons by default
    use_icons = true,
  },
}
