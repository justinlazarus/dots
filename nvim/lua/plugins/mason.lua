return {
  'williamboman/mason.nvim',
  dependencies = {
    'williamboman/mason-lspconfig.nvim',
  },
  config = function()
    require('mason').setup {
      registries = {
        'github:mason-org/mason-registry',
        'github:Crashdummyy/mason-registry', -- Required for Roslyn
      },
    }

      require('mason-lspconfig').setup {
        -- Only list lspconfig server names here. The Roslyn language server
        -- is provided via a custom registry and the `seblyng/roslyn.nvim` plugin,
        -- so we don't include it in `ensure_installed` for mason-lspconfig.
        ensure_installed = {
          'lua_ls',
        },
      }

      -- Ensure the Roslyn tool is installed via mason's registry (third-party).
      -- This uses the mason-registry API to install the 'roslyn' package if present.
      local ok_reg, registry = pcall(require, 'mason-registry')
      if ok_reg then
        local ok_pkg, roslyn_pkg = pcall(registry.get_package, 'roslyn')
        if ok_pkg and roslyn_pkg and not roslyn_pkg:is_installed() then
          roslyn_pkg:install()
        end
      end

  end,
}
