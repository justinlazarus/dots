--------------------------------------------------------------------------------------------- OPTIONS
local opt = vim.opt

vim.b.disable_autoformat = false

vim.g.have_nerd_font = true
vim.o.autoindent = true
vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.o.foldcolumn = "0"
vim.o.foldenable = true
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
vim.o.foldtext = ""
vim.o.tabstop = 4
vim.o.termguicolors = true
vim.o.expandtab = true
vim.o.softtabstop = 4
vim.o.encoding = "utf-8"

opt.backspace = "indent,eol,start"
opt.breakindent = true
opt.clipboard = "unnamedplus"
opt.cursorline = true
opt.hlsearch = true
opt.ignorecase = true
opt.inccommand = "split"
opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
opt.mouse = "a"
opt.number = true
opt.relativenumber = true
opt.scrolloff = 10
opt.shiftwidth = 4
opt.showmode = false
opt.signcolumn = "yes"
opt.smartcase = true
opt.smartindent = true
opt.splitbelow = true
opt.splitright = true
opt.timeoutlen = 300
opt.undofile = true
opt.updatetime = 250

--------------------------------------------------------------------------------------------- KEYMAPS
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local map = vim.keymap

map.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- File and folder management
map.set("n", "<leader>fe", "<cmd>Oil<CR>", { desc = "[F]ilesystem [E]xplore" })

-- Diffview
map.set("n", "<leader>vh", "<cmd>DiffviewFileHistory<CR>", { desc = "[D]iffview [H]istory" })
map.set("n", "<leader>vf", "<cmd>DiffviewFileHistory %<CR>", { desc = "[D]iffview [F]ile History" })
map.set("n", "<leader>vc", "<cmd>DiffviewClose<CR>", { desc = "[D]iffview [C]lose" })

-- Buffer keymaps
map.set("n", "<leader>bd", "<cmd>bd<CR>", { desc = "[B]uffer [d]elete" })
map.set("n", "<leader>bf", function()
	vim.b.disable_autoformat = not vim.b.disable_autoformat
	print("Format on save " .. (vim.b.disable_autoformat and "disabled" or "enabled"))
end, { desc = "[B]uffer toggle [f]ormat on save" })

-- Diagnostic keymaps
map.set("n", "]d", function()
	vim.diagnostic.jump({ count = 1 })
end, { desc = "Next diagnostic message" })
map.set("n", "[d", function()
	vim.diagnostic.jump({ count = -1 })
end, { desc = "Previous diagnostic message" })
map.set("n", "<leader>e", vim.diagnostic.open_float, { desc = "Show diagnostic [E]rror messages" })
map.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })

map.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Window commands
map.set("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
map.set("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
map.set("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
map.set("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })

-- Highlight yanks
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
	callback = function()
		vim.highlight.on_yank()
	end,
})

--------------------------------------------------------------------------------------------- LAZY
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
end ---@diagnostic disable-next-line: undefined-field
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
	{
		"utilyre/barbecue.nvim",
		name = "barbecue",
		version = "*",
		dependencies = {
			"SmiteshP/nvim-navic",
			"nvim-tree/nvim-web-devicons", -- optional dependency
		},
		opts = {
			-- configurations go here
		},
	},
	{ "lukas-reineke/indent-blankline.nvim", main = "ibl", opts = {} },
	"tpope/vim-fugitive",
	"RaafatTurki/hex.nvim",
	{ "numToStr/Comment.nvim", opts = {} },

	--------------------------------------------------------------------------------------------- THEME
	{
		"folke/tokyonight.nvim",
		priority = 1000,
		init = function()
			vim.cmd.colorscheme("tokyonight-night")
			vim.cmd.hi("Comment gui=none")
		end,
	},

	--------------------------------------------------------------------------------------------- CONFORM
	{
		"stevearc/conform.nvim",
		opts = {
			notify_on_error = false,
			format_on_save = function(bufnr)
				local disable_filetypes = { c = true, cpp = true }
				if vim.b[bufnr].disable_autoformat then
					return
				end
				return {
					timeout_ms = 1000,
					lsp_fallback = not disable_filetypes[vim.bo[bufnr].filetype],
				}
			end,
			formatters_by_ft = {
				cs = { "csharpier" },
				lua = { "stylua" },
				typescript = { "prettier" },
				json = { "prettier" },
				yaml = { "prettier" },
				tf = { "terraform_fmt" },
				xml = { "xmlformatter" },
			},
		},
	},

	--------------------------------------------------------------------------------------------- GITSIGNS
	{
		"lewis6991/gitsigns.nvim",
		opts = {
			signs = {
				add = { text = "" },
				change = { text = "" },
				delete = { text = "" },
				topdelete = { text = "‾" },
				changedelete = { text = "" },
			},
		},
	},

	--------------------------------------------------------------------------------------------- WHICH-KEY
	{
		"folke/which-key.nvim",
		event = "VimEnter",
		config = function()
			require("which-key").setup()
			require("which-key").add({
				{ "<leader>d", group = "[D]ebug" },
				{ "<leader>s", group = "[S]earch" },
				{ "<leader>g", group = "[G]it" },
				{ "<leader>l", group = "[L]sp" },
				{ "<leader>b", group = "[B]uffer" },
				{ "<leader>f", group = "[F]ilesystem" },
			})
		end,
	},

	--------------------------------------------------------------------------------------------- OIL
	{
		"stevearc/oil.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			local detail = false
			require("oil").setup({
				default_file_explorer = true,
				view_options = {
					show_hidden = true,
				},
				keymaps = {
					["gd"] = {
						desc = "Toggle file detail view",
						callback = function()
							detail = not detail
							if detail then
								require("oil").set_columns({ "icon", "permissions", "size", "mtime" })
							else
								require("oil").set_columns({ "icon" })
							end
						end,
					},
					["g?"] = "actions.show_help",
					["<CR>"] = "actions.select",
					["<C-s>"] = {
						"actions.select",
						opts = { vertical = true },
						desc = "Open the entry in a vertical split",
					},
					["<C-h>"] = {
						"actions.select",
						opts = { horizontal = true },
						desc = "Open the entry in a horizontal split",
					},
					["<C-t>"] = { "actions.select", opts = { tab = true }, desc = "Open the entry in new tab" },
					["<C-p>"] = "actions.preview",
					["<C-c>"] = "actions.close",
					["<C-l>"] = "actions.refresh",
					["-"] = "actions.parent",
					["_"] = "actions.open_cwd",
					["`"] = "actions.cd",
					["~"] = { "actions.cd", opts = { scope = "tab" }, desc = ":tcd to the current oil directory" },
					["gs"] = "actions.change_sort",
					["gx"] = "actions.open_external",
					["g."] = "actions.toggle_hidden",
					["g\\"] = "actions.toggle_trash",
				},
			})
		end,
	},

	--------------------------------------------------------------------------------------------- MINI
	{
		"echasnovski/mini.nvim",
		config = function()
			require("mini.ai").setup({ n_lines = 500 })
			require("mini.surround").setup()
			local statusline = require("mini.statusline")
			statusline.setup({ use_icons = vim.g.have_nerd_font })
			statusline.section_git = function() end
			statusline.section_location = function()
				return "%2l:%-2v"
			end
			statusline.section_filename = function()
				return GetCostcoPath()
			end
			statusline.inactive = function()
				return GetCostcoPath()
			end
		end,
	},

	--------------------------------------------------------------------------------------------- HARPOON
	{
		"ThePrimeagen/harpoon",
		branch = "harpoon2",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			local harpoon = require("harpoon")
			local map = vim.keymap

			harpoon.setup()

			map.set("n", "<leader>ha", function()
				harpoon:list():add()
			end, { desc = "Harpoon [a]dd" })
			map.set("n", "<leader>hl", function()
				harpoon.ui:toggle_quick_menu(harpoon:list())
			end, { desc = "Harpoon [l]ist" })
			map.set("n", "<leader>h1", function()
				harpoon:list():select(1)
			end, { desc = "Harpoon [1]st" })
			map.set("n", "<leader>h2", function()
				harpoon:list():select(2)
			end, { desc = "Harpoon [2]st" })
			map.set("n", "<leader>h3", function()
				harpoon:list():select(3)
			end, { desc = "Harpoon [3]st" })
			map.set("n", "<leader>h4", function()
				harpoon:list():select(4)
			end, { desc = "Harpoon [4]st" })
			map.set("n", "<leader>hn", function()
				harpoon:list():next()
			end, { desc = "Harpoon toggle [n]ext" })
			map.set("n", "<leader>hp", function()
				harpoon:list():prev()
			end, { desc = "Harpoon toggle [p]revious" })
		end,
	},

	--------------------------------------------------------------------------------------------- LSP
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			"kevinhwang91/nvim-ufo",
			"williamboman/mason.nvim",
			"williamboman/mason-lspconfig.nvim",
			"WhoIsSethDaniel/mason-tool-installer.nvim",
			--"jmederosalvarado/roslyn.nvim",
			{
				"seblj/roslyn.nvim",
				ft = "cs",
				opts = {},
			},
			{ "RaafatTurki/hex.nvim", opts = {} },
			{ "j-hui/fidget.nvim", opts = {} },
			{ "folke/neodev.nvim", opts = {} },
		},
		config = function()
			local on_attach = function(_, bufnr)
				local tb = require("telescope.builtin")
				local map = function(keys, func, desc)
					vim.keymap.set("n", keys, func, { buffer = bufnr, desc = "LSP: " .. desc })
				end

				map("<leader>lt", tb.lsp_type_definitions, "[T]ype Definition")
				map("<leader>ld", tb.lsp_document_symbols, "[D]ocument Symbols")
				map("<leader>lw", tb.lsp_dynamic_workspace_symbols, "[W]orkspace Symbols")
				map("<leader>lr", vim.lsp.buf.rename, "[R]ename")
				map("<leader>la", vim.lsp.buf.code_action, "Code [A]ction")

				map("gd", tb.lsp_definitions, "[G]oto [D]efinition")
				map("gr", tb.lsp_references, "[G]oto [R]eferences")
				map("gI", tb.lsp_implementations, "[G]oto [I]mplementation")
				map("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")
				map("K", vim.lsp.buf.hover, "[K]over Documentation")

				--local client = vim.lsp.get_client_by_id(bufnr.)
				--if client and client.server_capabilities.documentHighlightProvider then
				--    vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
				--        buffer = bufnr,
				--        callback = vim.lsp.buf.document_highlight,
				--    })

				--    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
				--        buffer = bufnr,
				--        callback = vim.lsp.buf.clear_references,
				--    })
				--end
			end

			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
				callback = on_attach,
			})

			local capabilities = vim.lsp.protocol.make_client_capabilities()
			capabilities = vim.tbl_deep_extend("force", capabilities, require("cmp_nvim_lsp").default_capabilities())
			capabilities.workspace.didChangeWatchedFiles.dynamicRegistration = true
			--capabilities.textDocument.foldingRange = {
			--    dynamicRegistration = false,
			--    lineFoldingOnly = true,
			--}

			local servers = {
				lua_ls = {
					settings = {
						Lua = {
							completion = {
								callSnippet = "Replace",
							},
							diagnostics = { globals = { "vim" } },
						},
					},
				},
				--csharp_ls = {},
				--omnisharp = {
				--	cmd = { "omnisharp" },
				--	enable_roslyn_analyzers = true,
				--	analyze_open_documents_only = true,
				--	organize_imports_on_format = true,
				--	enable_import_completion = true,
				--},
				terraformls = {},
				ts_ls = {},
			}

			--require("ufo").setup()
			require("mason").setup()
			--require("mason-nvim-dap").setup()

			local ensure_installed = vim.tbl_keys(servers or {})
			vim.list_extend(ensure_installed, {
				"biome",
				"csharpier",
				"jq",
				"prettier",
				"stylua",
				"tflint",
				"tfsec",
				"ts-standard",
				"yamlfmt",
			})
			require("mason-tool-installer").setup({ ensure_installed = ensure_installed })

			require("mason-lspconfig").setup({
				handlers = {
					function(server_name)
						local server = servers[server_name] or {}
						-- This handles overriding only values explicitly passed
						-- by the server configuration above. Useful when disabling
						-- certain features of an LSP (for example, turning off formatting for tsserver)
						server.capabilities = vim.tbl_deep_extend("force", {}, capabilities, server.capabilities or {})
						require("lspconfig")[server_name].setup(server)
					end,
				},
			})
		end,
	},

	--------------------------------------------------------------------------------------------- TREESITTER
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		opts = {
			ensure_installed = {
				"bash",
				"c",
				"c_sharp",
				"html",
				"javascript",
				"lua",
				"luadoc",
				"markdown",
				"regex",
				"markdown_inline",
				"terraform",
				"toml",
				"typescript",
				"vim",
				"vimdoc",
				"yaml",
			},
			auto_install = true,
			highlight = {
				enable = true,
				additional_vim_regex_highlighting = { "ruby" },
			},
			indent = { enable = true, disable = { "ruby" } },
		},
		config = function(_, opts)
			require("nvim-treesitter.configs").setup(opts)
		end,
	},

	--------------------------------------------------------------------------------------------- TELESCOPE
	{
		"nvim-telescope/telescope.nvim",
		event = "VimEnter",
		branch = "0.1.x",
		dependencies = {
			"nvim-lua/plenary.nvim",
			{
				"nvim-telescope/telescope-fzf-native.nvim",
				build = "make",
				cond = function()
					return vim.fn.executable("make") == 1
				end,
			},
			{ "nvim-telescope/telescope-ui-select.nvim" },
			{ "nvim-tree/nvim-web-devicons", enabled = vim.g.have_nerd_font },
			{ "nvim-telescope/telescope-live-grep-args.nvim", version = "^1.0.0" },
		},
		config = function()
			require("telescope").setup({
				defaults = {
					prompt_prefix = "   ",
					path_display = { "smart" },
					selection_caret = " ",
					entry_prefix = " ",
					sorting_strategy = "ascending",
					layout_config = {
						horizontal = {
							prompt_position = "bottom",
							preview_width = 0.55,
						},
						width = 0.87,
						height = 0.80,
					},
					mappings = {
						n = { ["q"] = require("telescope.actions").close },
					},
				},
				pickers = {
					lsp_references = {
						fname_width = 30,
						show_line = false,
					},
					lsp_implementations = {
						path_display = { "truncate" },
					},
				},
			})

			pcall(require("telescope").load_extension, "fzf")
			pcall(require("telescope").load_extension, "ui-select")
			pcall(require("telescope").load_extension, "live_grep_args")

			local builtin = require("telescope.builtin")
			vim.keymap.set("n", "<leader>sh", builtin.help_tags, { desc = "[S]earch [H]elp" })
			vim.keymap.set("n", "<leader>sk", builtin.keymaps, { desc = "[S]earch [K]eymaps" })
			vim.keymap.set("n", "<leader>sf", builtin.find_files, { desc = "[S]earch [F]iles" })
			vim.keymap.set("n", "<leader>ss", builtin.builtin, { desc = "[S]earch [S]elect Telescope" })
			vim.keymap.set("n", "<leader>sw", builtin.grep_string, { desc = "[S]earch current [W]ord" })
			vim.keymap.set("n", "<leader>sd", builtin.diagnostics, { desc = "[S]earch [D]iagnostics" })
			vim.keymap.set("n", "<leader>sr", builtin.resume, { desc = "[S]earch [R]esume" })
			vim.keymap.set("n", "<leader>s.", builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
			vim.keymap.set("n", "<leader><leader>", builtin.buffers, { desc = "[ ] Find existing buffers" })

			vim.keymap.set("n", "<leader>sa", function()
				require("telescope").extensions.live_grep_args.live_grep_args()
			end, { desc = "[S]earch by grep [A]rgs" })

			vim.keymap.set("n", "<leader>/", function()
				builtin.current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
					winblend = 10,
					previewer = false,
				}))
			end, { desc = "[/] Fuzzily search in current buffer" })

			vim.keymap.set("n", "<leader>s/", function()
				builtin.live_grep({
					grep_open_files = true,
					prompt_title = "Live Grep in Open Files",
				})
			end, { desc = "[S]earch [/] in Open Files" })

			vim.keymap.set("n", "<leader>sn", function()
				builtin.find_files({ cwd = vim.fn.stdpath("config") })
			end, { desc = "[S]earch [N]eovim files" })

			vim.keymap.set("n", "<leader>gc", builtin.git_commits, { desc = "[G]it [C]ommits" })
			vim.keymap.set("n", "<leader>gs", builtin.git_status, { desc = "[G]it [S]tatus" })
			vim.keymap.set("n", "<leader>gb", builtin.git_branches, { desc = "[G]it [B]ranches" })
			vim.keymap.set("n", "<leader>gu", builtin.git_bcommits, { desc = "[G]it b[u]ffer commits" })
			vim.keymap.set("n", "<leader>gh", builtin.git_stash, { desc = "[G]it Stas[h]" })
			vim.keymap.set("n", "<leader>gf", builtin.git_files, { desc = "[G]it [F]iles" })
			vim.keymap.set("n", "<leader>gm", function()
				vim.cmd("Gvdiffsplit origin/main")
			end, { desc = "[G]it diff [m]ain" })
		end,
	},

	--------------------------------------------------------------------------------------------- COMPLETION
	{
		"hrsh7th/nvim-cmp",
		event = "InsertEnter",
		dependencies = {
			{
				"L3MON4D3/LuaSnip",
				build = (function()
					if vim.fn.has("win32") == 1 or vim.fn.executable("make") == 0 then
						return
					end
					return "make install_jsregexp"
				end)(),
				dependencies = {},
			},
			"saadparwaiz1/cmp_luasnip",
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-path",
		},
		config = function()
			local cmp = require("cmp")
			local luasnip = require("luasnip")
			luasnip.config.setup({})

			cmp.setup({
				snippet = {
					expand = function(args)
						luasnip.lsp_expand(args.body)
					end,
				},
				completion = { completeopt = "menu,menuone,noinsert" },

				mapping = cmp.mapping.preset.insert({
					["<C-n>"] = cmp.mapping.select_next_item(),
					["<C-p>"] = cmp.mapping.select_prev_item(),
					["<C-b>"] = cmp.mapping.scroll_docs(-4),
					["<C-f>"] = cmp.mapping.scroll_docs(4),
					["<C-y>"] = cmp.mapping.confirm({ select = true }),
					["<C-Space>"] = cmp.mapping.complete({}),
					["<C-l>"] = cmp.mapping(function()
						if luasnip.expand_or_locally_jumpable() then
							luasnip.expand_or_jump()
						end
					end, { "i", "s" }),
					["<C-h>"] = cmp.mapping(function()
						if luasnip.locally_jumpable(-1) then
							luasnip.jump(-1)
						end
					end, { "i", "s" }),
				}),
				sources = {
					{ name = "nvim_lsp" },
					{ name = "luasnip" },
					{ name = "path" },
				},
			})
		end,
	},
	------------------------------------------------------------------------------------------ MARKDOWN
	{
		"toppair/peek.nvim",
		event = { "VeryLazy" },
		build = "deno task --quiet build:fast",
		config = function()
			require("peek").setup()
			vim.api.nvim_create_user_command("PeekOpen", require("peek").open, {})
			vim.api.nvim_create_user_command("PeekClose", require("peek").close, {})
		end,
	},
	--------------------------------------------------------------------------------------------- NOICE
	{
		"folke/noice.nvim",
		enabled = true,
		event = "VeryLazy",
		dependencies = {
			"MunifTanjim/nui.nvim",
			"rcarriga/nvim-notify",
		},
		config = function()
			require("noice").setup({
				lsp = {
					override = {
						["vim.lsp.util.convert_input_to_markdown_lines"] = true,
						["vim.lsp.util.stylize_markdown"] = true,
						["cmp.entry.get_documentation"] = true,
					},
				},
				notify = {
					enabled = false,
				},
				presets = {
					bottom_search = true,
					command_palette = true,
					long_message_to_split = true,
					inc_rename = false,
					lsp_doc_border = true,
				},
			})
		end,
	},

	--------------------------------------------------------------------------------------------- MINI
	{
		"echasnovski/mini.nvim",
		config = function()
			require("mini.ai").setup({ n_lines = 500 })
			require("mini.surround").setup()
			local statusline = require("mini.statusline")
			statusline.setup({ use_icons = vim.g.have_nerd_font })
			statusline.section_git = function() end
			statusline.section_location = function()
				return "%2l:%-2v"
			end
			statusline.section_filename = function()
				return GetCostcoPath()
			end
			statusline.inactive = function()
				return GetCostcoPath()
			end
		end,
	},
})

--------------------------------------------------------------------------------------------- RANDOM FUNCS
function FindLastTokenIndex(tokens, target)
	for i = #tokens, 1, -1 do
		if tokens[i] == target then
			return i, tokens[i]
		end
	end
	return nil
end

function GetCostcoPath()
	local path = vim.fn.expand("%:p")
	local is_costco = path:find("intl%-depot") or false
	local tokens = {}
	local filename = ""
	local project = ""

	if not is_costco then
		return path
	end

	for token in path:gmatch("([^/]+)") do
		table.insert(tokens, token)
	end

	local last_intl = FindLastTokenIndex(tokens, "intl-depot")

	if #tokens <= last_intl + 2 then
		return path
	end

	local domain = tokens[last_intl + 1]
	if domain == "apps" or domain == "libs" then
		project = tokens[last_intl + 2]:gsub("Costco.I18N.Depot.", "")
	else
		project = tokens[last_intl + 2]
	end

	for i = last_intl + 3, #tokens do
		if i == #tokens then
			filename = filename .. tokens[i]
		else
			filename = filename .. tokens[i] .. "/"
		end
	end

	return string.format(" 󰟉   %s  %s  %s ", domain, project, filename)
end
