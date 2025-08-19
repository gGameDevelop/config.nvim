return
{
	{
		"catppuccin/nvim",
		name = "catppuccin",
		lazy = false,
		priority = 1000,
		opts = {
			flavour = "mocha",
			no_italic = true,
			no_bold = true,
		},
	},
	{
		"rcarriga/nvim-notify",
		config = function ()
			vim.notify = require "notify"
		end
	},
	{
		"lukas-reineke/indent-blankline.nvim",
		main = "ibl",
		event = { "BufReadPre", "BufNewFile" },
		---@module "ibl"
		---@type ibl.config
		opts = {
			indent = {
				char = "╎",
			}
		}
	},
	{
		'nvim-lualine/lualine.nvim',
		dependencies = { 'nvim-tree/nvim-web-devicons' },
		opts = {
			options = {
				component_separators = { left = '', right = ''},
				section_separators = { left = '', right = ''},
				globalstatus = true,
			},
			sections = {
				lualine_a = {
					{
						'mode',
						fmt = function(str)
							return ' ' .. str
						end,
					}
				},
				lualine_b = {
					{
						'filename',
						file_status = true,
						newfile_status = false,
						path = 0,

						shorting_target = 40,
						symbols = {
							modified = '*',
							unnamed = '',
						}
					}
				},
				lualine_c = {
					{
						'lsp_status',
						icon = '',
						ignore_lsp = {},
					}
				},
				lualine_x = {
					{
						"filetype"
					}
				}
			}
		},
	},
	{
		"mason-org/mason.nvim",
		opts = {}
	},
	{
		'windwp/nvim-autopairs',
		event = "InsertEnter",
		opts = {}
	},
	{
		'hrsh7th/nvim-cmp',
		dependencies = {
			'hrsh7th/cmp-nvim-lsp',
		},
		event = "InsertEnter",
		config = function()
			local cmp = require'cmp'
			local kind_icons =
			{
				Text = "",
				Method = "",
				Function = "",
				Constructor = "",
				Field = "",
				Variable = "",
				Class = "",
				Interface = "",
				Module = "",
				Property = "",
				Unit = "",
				Value = "",
				Enum = "",
				Keyword = "",
				Snippet = "",
				Color = "",
				File = "",
				Reference = "",
				Folder = "",
				EnumMember = "",
				Constant = "",
				Struct = "",
				Event = "",
				Operator = "",
				TypeParameter = ""
			}

			cmp.setup({
				window = {
					completion = {
						border = { "┌", "─", "┐", "│", "┘", "─", "└", "│" },
						winhighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None",
					},
					documentation = {
						border = { "┌", "─", "┐", "│", "┘", "─", "└", "│" },
					},
				},
				mapping = cmp.mapping.preset.insert({
					['<C-b>'] = cmp.mapping.scroll_docs(-4),
					['<C-f>'] = cmp.mapping.scroll_docs(4),

					["<C-j>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
					["<C-k>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),

					['<C-Space>'] = cmp.mapping.complete(),
					['<C-e>'] = cmp.mapping.abort(),
					['<Tab>'] = cmp.mapping.confirm({ select = true }),
				}),
				sources = cmp.config.sources({
					{ name = 'nvim_lsp' },
				}),
				formatting = {
					fields = { "kind", "abbr", "menu" },
					format = function(entry, vim_item)
						-- Truncate the completion text to 50 chars
						vim_item.kind = (kind_icons[vim_item.kind] or "") .. " " .. vim_item.kind
						local max_width = 50
						if #vim_item.abbr > max_width then
							vim_item.abbr = vim_item.abbr:sub(1, max_width) .. "…"
						end
						return vim_item
					end,
				},
			})
		end
	},
	{
		"rcarriga/nvim-dap-ui",
		lazy = true,
		dependencies = {"mfussenegger/nvim-dap", "nvim-neotest/nvim-nio"},
		keys = {
			{ "<leader>db", "<cmd>DapToggleBreakpoint<CR>", desc = "DAP toggle breakpoint" },
			{ "<leader>dc", "<cmd>DapContinue<CR>", desc = "DAP continue" },
			{ "<leader>dov", "<cmd>DapStepOver<CR>", desc = "DAP step over" },
			{ "<leader>dou", "<cmd>DapStepOut<CR>", desc = "DAP step out" },
			{ "<leader>di", "<cmd>DapStepInto<CR>", desc = "DAP step into" },
		},
		config = function()
			local dap, dapui = require("dap"), require("dapui")

			dap.listeners.before.attach.dapui_config = function()
				dapui.open()
			end
			dap.listeners.before.launch.dapui_config = function()
				dapui.open()
			end
			dap.listeners.before.event_terminated.dapui_config = function()
				dapui.close()
			end
			dap.listeners.before.event_exited.dapui_config = function()
				dapui.close()
			end

			dap.adapters.cppdbg = {
				id = "cppdbg",
				type = "executable",
				command = "OpenDebugAD7.cmd",
				options = {
					detached = false,
				},
			}

			dap.configurations.cpp = {
				{
					name = "Launch file",
					type = "cppdbg",
					request = "launch",
					program = function()
						return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
					end,
					cwd = "${workspaceFolder}",
				},
			}

			dap.configurations.c = dap.configurations.cpp;

			vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DapBreakpoint", linehl = "", numhl = "" })
			vim.fn.sign_define("DapStopped", { text = "❭", texthl = "DapStopped", linehl = "", numhl = "" })
			vim.fn.sign_define(
				"DapBreakpointRejected",
				{ text = "◉", texthl = "DapBreakpointRejected", linehl = "", numhl = "" }
			)
		end,
	},
	{
		'stevearc/oil.nvim',
		---@module 'oil'
		---@type oil.SetupOpts
		opts = {},
		dependencies = { "nvim-tree/nvim-web-devicons" },
		lazy = false,
	},
	{
		"nvim-treesitter/nvim-treesitter",
		branch = 'master',
		event = { "BufReadPre", "BufNewFile" },
		config = function ()
			require	"nvim-treesitter.configs".setup {
				highlight = {
					enable = true,
				}
			}
		end
	},
	{
		'nvim-telescope/telescope.nvim',
		lazy = true,
		dependencies = { 'nvim-lua/plenary.nvim', "nvim-telescope/telescope-ui-select.nvim", "nvim-telescope/telescope-dap.nvim" },
		keys = {
			{'<leader>fpf', require('telescope.builtin').find_files},
			{'<leader>fpg', require('telescope.builtin').live_grep},
			{'<leader>fpb', require('telescope.builtin').buffers},
			{'<leader>fh', require('telescope.builtin').help_tags},
		},
		opts = {},
		config = function ()
			local telescope = require "telescope"
			telescope.load_extension('dap')
			telescope.load_extension("ui-select")
			vim.keymap.set("n", "<leader>fdc", require'telescope'.extensions.dap.commands)
			vim.keymap.set("n", "<leader>fdo", require'telescope'.extensions.dap.configurations)
			vim.keymap.set("n", "<leader>fdb", require'telescope'.extensions.dap.list_breakpoints)
			vim.keymap.set("n", "<leader>fdv", require'telescope'.extensions.dap.variables)
			vim.keymap.set("n", "<leader>fdf", require'telescope'.extensions.dap.frames)
		end
	},
	{
		"folke/trouble.nvim",
		lazy = true,
		opts = {},
		cmd = "Trouble",
		keys = {
			{
				"<leader>xx",
				"<cmd>Trouble diagnostics toggle<cr>",
				desc = "Diagnostics (Trouble)",
			},
			{
				"<leader>xX",
				"<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
				desc = "Buffer Diagnostics (Trouble)",
			},
			{
				"<leader>cs",
				"<cmd>Trouble symbols toggle focus=false<cr>",
				desc = "Symbols (Trouble)",
			},
			{
				"<leader>cl",
				"<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
				desc = "LSP Definitions / references / ... (Trouble)",
			},
			{
				"<leader>xL",
				"<cmd>Trouble loclist toggle<cr>",
				desc = "Location List (Trouble)",
			},
			{
				"<leader>xQ",
				"<cmd>Trouble qflist toggle<cr>",
				desc = "Quickfix List (Trouble)",
			},
		},
	},
	{
		"mbbill/undotree",
		lazy = true,
		keys = {
			{ "<leader><F5>", vim.cmd.UndotreeToggle }
		}
	},
	{
		"tpope/vim-surround",
	},
	{
		"folke/zen-mode.nvim",
		lazy = true,
		keys = {
			{ "<F4>", function ()
				require("zen-mode").toggle({
					window = {
						width = .80
					}
				}) end
			}
		},
		opts = {}
	},
	{
		'akinsho/toggleterm.nvim',
		lazy = false,
		version = "*",
		opts = {}
	}
}
