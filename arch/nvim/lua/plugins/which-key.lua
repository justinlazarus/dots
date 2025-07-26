return {
  'folke/which-key.nvim',
  event = 'VimEnter',
  opts = {
    delay = 500,
    icons = {
      mappings = vim.g.have_nerd_font,
      keys = {},
    },
    spec = {
      { '<leader>s', group = '[S]earch' },
      { '<leader>t', group = '[T]oggle' },
      { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
    },
  },
}
