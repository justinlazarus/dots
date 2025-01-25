local add, now, later = MiniDeps.add, MiniDeps.now, MiniDeps.later

now(function()
	add("catppuccin/nvim")
	vim.cmd("colorscheme catppuccin-mocha")
	require("catppuccin").setup({
		default_integrations = false,
		integrations = {
			-- cmp = true,
			blink_cmp = true,
			markdown = true,
			mason = true,
			mini = { enabled = true },
			native_lsp = {
				enabled = true,
				virtual_text = {
					errors = { "italic" },
					hints = { "italic" },
					warnings = { "italic" },
					information = { "italic" },
					ok = { "italic" },
				},
				underlines = {
					errors = { "underline" },
					hints = { "underline" },
					warnings = { "underline" },
					information = { "underline" },
					ok = { "underline" },
				},
				inlay_hints = {
					background = true,
				},
			},
			semantic_tokens = true,
			treesitter = true,
			treesitter_context = true,
		},
	})
end)

now(function()
	add("neovim/nvim-lspconfig")

	local custom_on_attach = function(client, buf_id)
		vim.bo[buf_id].omnifunc = "v:lua.MiniCompletion.completefunc_lsp"
	end

	-- this csharp ls hasn't been added to mason yet
	add("seblj/roslyn.nvim")
	require("roslyn").setup()

	local lspconfig = require("lspconfig")

	-- Lua
	lspconfig.lua_ls.setup({
		on_attach = function(client, bufnr)
			custom_on_attach(client, bufnr)

			-- Reduce unnecessarily long list of completion triggers for better
			-- 'mini.completion' experience
			client.server_capabilities.completionProvider.triggerCharacters = { ".", ":" }

			-- Override global "Go to source" mapping with dedicated buffer-local
			local opts = { buffer = bufnr, desc = "Lua source definition" }
			vim.keymap.set("n", "<Leader>ls", function()
				return vim.lsp.buf.definition({ on_list = on_list })
			end, opts)
		end,
		settings = {
			Lua = {
				runtime = {
					-- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
					version = "LuaJIT",
					-- Setup your lua path
					path = vim.split(package.path, ";"),
				},
				diagnostics = {
					-- Get the language server to recognize common globals
					globals = { "vim", "describe", "it", "before_each", "after_each" },
					disable = { "need-check-nil" },
					-- Don't make workspace diagnostic, as it consumes too much CPU and RAM
					workspaceDelay = -1,
				},
				workspace = {
					-- Don't analyze code from submodules
					ignoreSubmodules = true,
				},
				-- Do not send telemetry data containing a randomized but unique identifier
				telemetry = {
					enable = false,
				},
			},
		},
	})

	-- typescript
	lspconfig.ts_ls.setup({ on_attach = custom_on_attach })

	-- go
	lspconfig.gopls.setup({ on_attach = custom_on_attach })
end)

later(function()
	add("stevearc/conform.nvim")
	require("conform").setup({
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
	})

	vim.api.nvim_create_user_command("FormatToggle", function(_)
		vim.g.disable_autoformat = not vim.g.disable_autoformat
		local state = vim.g.disable_autoformat and "disabled" or "enabled"
		vim.notify("Auto-save " .. state)
	end, {
		desc = "Toggle autoformat-on-save",
		bang = true,
	})
end)

later(function()
	add({
		source = "nvim-treesitter/nvim-treesitter",
		checkout = "master",
		hooks = {
			post_checkout = function()
				vim.cmd("TSUpdate")
			end,
		},
	})
	require("nvim-treesitter.configs").setup({
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
		textobjects = { enable = false },
		indent = {
			enable = true,
			disable = { "ruby", "markdown" },
		},
	})
end)

later(function()
	add("williamboman/mason.nvim")
	require("mason").setup()
end)

later(function()
	add("rachartier/tiny-inline-diagnostic.nvim")
	require("tiny-inline-diagnostic").setup()
end)
