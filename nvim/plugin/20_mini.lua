local add, now, later = MiniDeps.add, MiniDeps.now, MiniDeps.later
add({ name = "mini.nvim" })

local choose_all = function()
	local mappings = MiniPick.get_picker_opts().mappings
	vim.api.nvim_input(mappings.mark_all .. mappings.choose_marked)
end

-- stylua: ignore start
now(function() require("mini.starter").setup() end)
now(function() require("mini.basics").setup({
  mappings = {
    windows = true
  }
}) end)
now(function() require("mini.icons").setup() end)
now(function() require("mini.tabline").setup() end)
now(function()
  local statusline = require("mini.statusline")
  statusline.setup()
  statusline.section_git = function() end
  statusline.section_filename = function() return Config.get_costco_path() end
  statusline.inactive = function() return Config.get_costco_path() end
end)
now(function()
	require("mini.notify").setup()
	vim.notify = require("mini.notify").make_notify()
end)

later(function() require('mini.git').setup() end)
later(function() require('mini.cursorword').setup() end)
later(function() require('mini.visits').setup() end)
later(function() require('mini.diff').setup() end)
later(function() require('mini.indentscope').setup() end)
later(function() require("mini.bufremove").setup() end)
later(function() require("mini.files").setup() end)
later(function() require("mini.ai").setup() end)
later(function() require("mini.comment").setup() end)
later(function() require("mini.extra").setup() end)
later(function() require("mini.surround").setup() end)
later(function() require("mini.colors").setup() end)
later(function() require("mini.pick").setup({
  mappings = {
    choose_all = { char = '<C-q>', func = choose_all },

    -- the original mapping is <C-space> which conflicts with tmux leader
    refine = '<C-]>',
  },
}) end)
-- stylua: ignore end

later(function()
	require("mini.completion").setup({
		lsp_completion = {
			source_func = "omnifunc",
			auto_setup = false,
			process_items = function(items, base)
				-- Don't show 'Text' and 'Snippet' suggestions
				items = vim.tbl_filter(function(x)
					return x.kind ~= 1 and x.kind ~= 15
				end, items)
				return MiniCompletion.default_process_items(items, base)
			end,
		},
		window = {
			info = { border = "double" },
			signature = { border = "double" },
		},
	})
	if vim.fn.has("nvim-0.11") == 1 then
		vim.opt.completeopt:append("fuzzy") -- Use fuzzy matching for built-in completion
	end
end)

later(function()
	local miniclue = require("mini.clue")
  --stylua: ignore
  miniclue.setup({
    clues = {
      Config.leader_group_clues,
      miniclue.gen_clues.builtin_completion(),
      miniclue.gen_clues.g(),
      miniclue.gen_clues.marks(),
      miniclue.gen_clues.registers(),
      miniclue.gen_clues.windows({ submode_resize = true }),
      miniclue.gen_clues.z(),
    },
    triggers = {
      { mode = 'n', keys = '<Leader>' }, -- Leader triggers
      { mode = 'x', keys = '<Leader>' },
      { mode = 'n', keys = [[\]] },      -- mini.basics
      { mode = 'n', keys = '[' },        -- mini.bracketed
      { mode = 'n', keys = ']' },
      { mode = 'x', keys = '[' },
      { mode = 'x', keys = ']' },
      { mode = 'i', keys = '<C-x>' },    -- Built-in completion
      { mode = 'n', keys = 'g' },        -- `g` key
      { mode = 'x', keys = 'g' },
      { mode = 'n', keys = "'" },        -- Marks
      { mode = 'n', keys = '`' },
      { mode = 'x', keys = "'" },
      { mode = 'x', keys = '`' },
      { mode = 'n', keys = '"' },        -- Registers
      { mode = 'x', keys = '"' },
      { mode = 'i', keys = '<C-r>' },
      { mode = 'c', keys = '<C-r>' },
      { mode = 'n', keys = '<C-w>' },    -- Window commands
      { mode = 'n', keys = 'z' },        -- `z` key
      { mode = 'x', keys = 'z' },
    },
    window = { config = { anchor = 'NW', border = 'double' } },
  })
end)
