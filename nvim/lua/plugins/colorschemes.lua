return {

  {
    'catppuccin/nvim',
    priority = 1000,
    name = 'catppuccin',
    config = function()
      require('catppuccin').setup {
        flavour = 'mocha',
      }
      vim.api.nvim_command 'colorscheme catppuccin'
    end,
  },
  {
    'folke/tokyonight.nvim',
    priority = 1000,
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require('tokyonight').setup {
        styles = {
          comments = { italic = false },
        },
      }
      --vim.cmd.colorscheme 'tokyonight-night'
    end,
  },
}
