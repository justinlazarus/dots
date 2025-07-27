return {
  'nvim-neotest/neotest',
  dependencies = {
    'nvim-neotest/nvim-nio',
    'nvim-lua/plenary.nvim',
    'antoinemadec/FixCursorHold.nvim',
    'nvim-treesitter/nvim-treesitter',
    'Issafalcon/neotest-dotnet',
  },
  config = function()
    require('neotest').setup {
      adapters = {
        require 'neotest-dotnet' {
          -- Here we can set options for neotest-dotnet
          dap = {
            -- Extra arguments for nvim-dap configuration
            -- See also: https://github.com/microsoft/debugpy/wiki/Debug-configuration-settings for debugpy options
            args = { '--port', '5000' },
            adapter_name = 'netcoredbg',
          },
          -- Let the test-discovery know about your custom attributes (otherwise tests will not be picked up)
          -- Note: Only custom attributes for non-parameterized tests should be added here. See the note about parameterized tests further down.
          custom_attributes = {
            xunit = { 'MyCustomFactAttribute' },
            nunit = { 'MyCustomTestAttribute' },
            mstest = { 'MyCustomTestMethodAttribute' },
          },
          -- Provide any additional "dotnet test" CLI commands here. These will be applied to ALL test runs performed via neotest. These need to be a table of strings, ideally with one key-value pair per string.
          dotnet_additional_args = {
            '--verbosity',
            'normal',
          },
          -- Tell neotest-dotnet to use either solution (requires .sln file) or project (requires .csproj or .fsproj file) as project root
          -- Note: If neovim is opened from the solution root, using "solution" as root_dir may cause issues with finding the relevant files since the adapter will look for a .sln file to find the project root
          -- In general, using "project" as root_dir should work better
          discovery_root = 'project', -- Default
        },
      },
      -- You can also set global neotest options here
      floating = {
        border = 'rounded',
        max_height = 0.6,
        max_width = 0.6,
        options = {},
      },
      highlights = {
        adapter_name = 'NeotestAdapterName',
        border = 'NeotestBorder',
        dir = 'NeotestDir',
        expand_marker = 'NeotestExpandMarker',
        failed = 'NeotestFailed',
        file = 'NeotestFile',
        focused = 'NeotestFocused',
        indent = 'NeotestIndent',
        marked = 'NeotestMarked',
        namespace = 'NeotestNamespace',
        passed = 'NeotestPassed',
        running = 'NeotestRunning',
        select_win = 'NeotestSelectWin',
        skipped = 'NeotestSkipped',
        target = 'NeotestTarget',
        test = 'NeotestTest',
        unknown = 'NeotestUnknown',
      },
    }
  end,
  keys = {
    -- Key mappings for neotest
    {
      '<leader>tt',
      function()
        require('neotest').run.run()
      end,
      desc = 'Run nearest test',
    },
    {
      '<leader>tf',
      function()
        require('neotest').run.run(vim.fn.expand '%')
      end,
      desc = 'Run current file tests',
    },
    {
      '<leader>td',
      function()
        require('neotest').run.run { strategy = 'dap' }
      end,
      desc = 'Debug nearest test',
    },
    {
      '<leader>ts',
      function()
        require('neotest').summary.toggle()
      end,
      desc = 'Toggle test summary',
    },
    {
      '<leader>to',
      function()
        require('neotest').output.open { enter = true }
      end,
      desc = 'Show test output',
    },
    {
      '<leader>tO',
      function()
        require('neotest').output_panel.toggle()
      end,
      desc = 'Toggle output panel',
    },
    {
      '<leader>tS',
      function()
        require('neotest').run.stop()
      end,
      desc = 'Stop running tests',
    },
  },
}
