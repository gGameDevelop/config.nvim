local M = {}

local mod_cache = nil
local std_lib = nil

local function identify_go_dir(custom_args, on_complete)
	local cmd = { 'go', 'env', custom_args.envvar_id }
	vim.system(cmd, { text = true }, function(output)
		local res = vim.trim(output.stdout or '')
		if output.code == 0 and res ~= '' then
			if custom_args.custom_subdir and custom_args.custom_subdir ~= '' then
				res = res .. custom_args.custom_subdir
			end
			on_complete(res)
		else
			vim.schedule(function()
				vim.notify(
					('[gopls] identify ' .. custom_args.envvar_id .. ' dir cmd failed with code %d: %s\n%s'):format(
						output.code,
						vim.inspect(cmd),
						output.stderr
					)
				)
			end)
			on_complete(nil)
		end
	end)
end

local function get_std_lib_dir()
	if std_lib and std_lib ~= '' then
		return std_lib
	end

	identify_go_dir({ envvar_id = 'GOROOT', custom_subdir = '/src' }, function(dir)
		if dir then
			std_lib = dir
		end
	end)
	return std_lib
end

local function get_mod_cache_dir()
	if mod_cache and mod_cache ~= '' then
		return mod_cache
	end

	identify_go_dir({ envvar_id = 'GOMODCACHE' }, function(dir)
		if dir then
			mod_cache = dir
		end
	end)
	return mod_cache
end

local function get_root_dir(fname)
	if mod_cache and fname:sub(1, #mod_cache) == mod_cache then
		local clients = vim.lsp.get_clients({ name = 'gopls' })
		if #clients > 0 then
			return clients[#clients].config.root_dir
		end
	end
	if std_lib and fname:sub(1, #std_lib) == std_lib then
		local clients = vim.lsp.get_clients({ name = 'gopls' })
		if #clients > 0 then
			return clients[#clients].config.root_dir
		end
	end
	return vim.fs.root(fname, 'go.work') or vim.fs.root(fname, 'go.mod') or vim.fs.root(fname, '.git')
end


M.on_attach = function (_, bufnr)
	local function opts(desc)
		return { buffer = bufnr, remap=false, desc = "LSP " .. desc }
	end

	vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts "Go to declaration")
	vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts "Go to definition")
	vim.keymap.set("n", "<leader>wa", vim.lsp.buf.add_workspace_folder, opts "Add workspace folder")
	vim.keymap.set("n", "<leader>wr", vim.lsp.buf.remove_workspace_folder, opts "Remove workspace folder")
	vim.keymap.set("n", "<leader>wl", function()
	  print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
	end, opts "List workspace folders")
	vim.keymap.set("n", "<leader>D", vim.lsp.buf.type_definition, opts "Go to type definition")
	vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts "Code action")
	vim.keymap.set("n", "grr", vim.lsp.buf.references, opts "References")
	vim.keymap.set("n", "grn", vim.lsp.buf.rename, opts "Rename")
	vim.keymap.set("i", "<C-k>", vim.lsp.buf.signature_help, opts "Signature help")
	vim.keymap.set("n", "[d", function ()
		vim.diagnostic.jump({count=-1, float=true})
	end, opts "Go to next diagnostic")
	vim.keymap.set("n", "]d", function ()
		vim.diagnostic.jump({count=1, float=true})
	end, opts "Go to prev diagnostic")
end

M.lua_ls =
{
	cmd = { "lua-language-server" },
	filetypes = { "lua" },
	root_markers = {
		".luarc.json",
		".luarc.jsonc",
		".luacheckrc",
		".stylua.toml",
		"stylua.toml",
		"selene.toml",
		"selene.yml",
		".git",
	},
	settings = {
		Lua = {
			workspace = {
				checkThirdParty = false,
				library = {
					vim.fn.expand "$VIMRUNTIME/lua",
					vim.fn.stdpath "data" .. "/lazy/lazy.nvim/lua/lazy",
					"${3rd}/luv/library",
				}
			}
		}
	},
	on_attach = M.on_attach
}

M.clangd =
{
	cmd = { "clangd", "--all-scopes-completion=false", "--header-insertion=never", "--background-index=false", "--fallback-style=Microsoft" },
	filetypes = { "c", "cpp", "objc", "objcpp", "cuda", "proto" },
	root_markers = {
		".clangd",
		".clang-tidy",
		".clang-format",
		"compile_commands.json",
		"compile_flags.txt",
		"configure.ac",
		".git",
	},
	capabilities = {
		textDocument = {
			completion = {
				editsNearCursor = true,
			},
		},
		offsetEncoding = { "utf-8", "utf-16" },
	},
	---@param client vim.lsp.Client
	---@param init_result ClangdInitializeResult
	on_init = function(client, init_result)
		if init_result.offsetEncoding then
			client.offset_encoding = init_result.offsetEncoding
		end
	end,
	on_attach = function(_, bufnr)
		local function switch_source_header(bufnr)
			local method_name = "textDocument/switchSourceHeader"
			local client = vim.lsp.get_clients({ bufnr = bufnr, name = "clangd" })[1]
			if not client then
				return vim.notify(("method %s is not supported by any servers active on the current buffer"):format(method_name))
			end
			local params = vim.lsp.util.make_text_document_params(bufnr)
			client.request(method_name, params, function(err, result)
				if err then
					error(tostring(err))
				end
				if not result then
					vim.notify("corresponding file cannot be determined")
					return
				end
				vim.cmd.edit(vim.uri_to_fname(result))
			end, bufnr)
		end

		local function symbol_info()
			local bufnr = vim.api.nvim_get_current_buf()
			local clangd_client = vim.lsp.get_clients({ bufnr = bufnr, name = "clangd" })[1]
			if not clangd_client or not clangd_client.supports_method "textDocument/symbolInfo" then
				return vim.notify("Clangd client not found", vim.log.levels.ERROR)
			end
			local win = vim.api.nvim_get_current_win()
			local params = vim.lsp.util.make_position_params(win, clangd_client.offset_encoding)
			clangd_client.request("textDocument/symbolInfo", params, function(err, res)
				if err or #res == 0 then
					-- Clangd always returns an error, there is not reason to parse it
					return
				end
				local container = string.format("container: %s", res[1].containerName) ---@type string
				local name = string.format("name: %s", res[1].name) ---@type string
				vim.lsp.util.open_floating_preview({ name, container }, "", {
					height = 2,
					width = math.max(string.len(name), string.len(container)),
					focusable = false,
					focus = false,
					border = "single",
					title = "Symbol Info",
				})
			end, bufnr)
		end

		vim.api.nvim_buf_create_user_command(bufnr, "LspClangdSwitchSourceHeader", function()
			switch_source_header(bufnr)
		end, { desc = "Switch between source/header" })

		vim.api.nvim_buf_create_user_command(bufnr, "LspClangdShowSymbolInfo", function()
			symbol_info()
		end, { desc = "Show symbol info" })

		vim.keymap.set("n", "<leader>sh", "<cmd>LspClangdSwitchSourceHeader<CR>")

		vim.keymap.set("n", "<leader>si", "<cmd>LspClangdShowSymbolInfo<CR>")

		M.on_attach(_, bufnr)
	end,
}

M.glsl_analyzer =
{
	cmd = { "glsl_analyzer" },
	filetypes = { "glsl", "vert", "tesc", "tese", "frag", "geom", "comp" },
	root_markers = { ".git" },

	on_attach = M.on_attach
}

M.pylsp =
{
	cmd = { 'pylsp' },
	filetypes = { 'python' },
	root_markers = {
		'pyproject.toml',
		'setup.py',
		'setup.cfg',
		'requirements.txt',
		'Pipfile',
		'.git',
	},
}

M.pyright =
{
	cmd = { "pyright-langserver", "--stdio" },
	filetypes = { "python" },
	root_markers = {
		"pyproject.toml",
		"setup.py",
		"setup.cfg",
		"requirements.txt",
		"Pipfile",
		"pyrightconfig.json",
		".git",
	},
	settings = {
		python = {
			analysis = {
				autoSearchPaths = true,
				useLibraryCodeForTypes = true,
				diagnosticMode = "openFilesOnly",
			},
		},
	},
	on_attach = function(client, bufnr)
		local function set_python_path(path)
			local clients = vim.lsp.get_clients {
				bufnr = vim.api.nvim_get_current_buf(),
				name = "pyright",
			}
			for _, client in ipairs(clients) do
				if client.settings then
					client.settings.python = vim.tbl_deep_extend("force", client.settings.python, { pythonPath = path })
				else
					client.config.settings = vim.tbl_deep_extend("force", client.config.settings, { python = { pythonPath = path } })
				end
				client.notify("workspace/didChangeConfiguration", { settings = nil })
			end
		end

		vim.api.nvim_buf_create_user_command(bufnr, "LspPyrightOrganizeImports", function()
			client:exec_cmd({
				command = "pyright.organizeimports",
				arguments = { vim.uri_from_bufnr(bufnr) },
			})
		end, {
		desc = "Organize Imports",
		})
		vim.api.nvim_buf_create_user_command(bufnr, "LspPyrightSetPythonPath", set_python_path, {
			desc = "Reconfigure pyright with the provided python path",
			nargs = 1,
			complete = "file",
		})

		M.on_attach(_, bufnr)
	end,
}

M.ts_ls =
{
	init_options = { hostInfo = 'neovim' },
	cmd = { 'typescript-language-server', '--stdio' },
	filetypes = {
		'javascript',
		'javascriptreact',
		'javascript.jsx',
		'typescript',
		'typescriptreact',
		'typescript.tsx',
	},
	root_dir = function(bufnr, on_dir)
		-- The project root is where the LSP can be started from
		-- As stated in the documentation above, this LSP supports monorepos and simple projects.
		-- We select then from the project root, which is identified by the presence of a package
		-- manager lock file.
		local project_root_markers = { 'package-lock.json', 'yarn.lock', 'pnpm-lock.yaml', 'bun.lockb', 'bun.lock' }
		local project_root = vim.fs.root(bufnr, project_root_markers)
		if not project_root then
			on_dir(vim.loop.cwd())
		end

		on_dir(project_root)
	end,
	handlers = {
		-- handle rename request for certain code actions like extracting functions / types
		['_typescript.rename'] = function(_, result, ctx)
			local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
			vim.lsp.util.show_document({
				uri = result.textDocument.uri,
				range = {
					start = result.position,
					['end'] = result.position,
				},
			}, client.offset_encoding)
			vim.lsp.buf.rename()
			return vim.NIL
		end,
	},
	commands = {
		['editor.action.showReferences'] = function(command, ctx)
			local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
			local file_uri, position, references = unpack(command.arguments)

			local quickfix_items = vim.lsp.util.locations_to_items(references, client.offset_encoding)
			vim.fn.setqflist({}, ' ', {
				title = command.title,
				items = quickfix_items,
				context = {
					command = command,
					bufnr = ctx.bufnr,
				},
			})

			vim.lsp.util.show_document({
				uri = file_uri,
				range = {
					start = position,
					['end'] = position,
				},
			}, client.offset_encoding)

			vim.cmd('botright copen')
		end,
	},
	on_attach = function(client, bufnr)
		-- ts_ls provides `source.*` code actions that apply to the whole file. These only appear in
		-- `vim.lsp.buf.code_action()` if specified in `context.only`.
		vim.api.nvim_buf_create_user_command(bufnr, 'LspTypescriptSourceAction', function()
			local source_actions = vim.tbl_filter(function(action)
				return vim.startswith(action, 'source.')
			end, client.server_capabilities.codeActionProvider.codeActionKinds)

			vim.lsp.buf.code_action({
				context = {
					only = source_actions,
				},
			})
		end, {})

		M.on_attach(client, bufnr)
	end,
}

M.jsonls =
{
	cmd = { 'vscode-json-language-server', '--stdio' },
	filetypes = { 'json', 'jsonc' },
	init_options = {
		provideFormatter = true,
	},
	root_markers = { '.git' },
	on_attach = M.on_attach
}

M.html =
{
	cmd = { "vscode-html-language-server", "--stdio" },
	filetypes = { "html", "htmldjango", "templ" },
	root_markers = { "package.json", ".git" },
	settings = {},
	init_options = {
		provideFormatter = true,
		embeddedLanguages = { css = true, javascript = true },
		configurationSection = { "html", "css", "javascript" },
	},

	on_attach = M.on_attach,
}

M.emmet_ls =
{
	cmd = { "emmet-ls", "--stdio" },
	filetypes = {
		"astro",
		"css",
		"eruby",
		"html",
		"htmlangular",
		"htmldjango",
		"javascriptreact",
		"less",
		"pug",
		"sass",
		"scss",
		"svelte",
		"templ",
		"typescriptreact",
		"vue",
	},
	root_markers = { ".git" },

	on_attach = M.on_attach
}

M.cssls =
{
	cmd = { "vscode-css-language-server", "--stdio" },
	filetypes = { "css", "scss", "less" },
	root_markers = { "package.json", ".git" },
	settings = {
		css = {
			validate = true
		},
		less = {
			validate = true
		},
		scss = {
			validate = true
		}
	},

	on_attach = M.on_attach
}

M.gopls =
{
	cmd = { 'gopls' },
	filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
	root_dir = function(bufnr, on_dir)
		local fname = vim.api.nvim_buf_get_name(bufnr)
		get_mod_cache_dir()
		get_std_lib_dir()
		on_dir(get_root_dir(fname))
	end,

	on_attach = M.on_attach
}

return M
