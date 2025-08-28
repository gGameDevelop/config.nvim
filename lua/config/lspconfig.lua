local servers = {"lua_ls", "clangd", "glsl_analyzer", "pyright", "ts_ls", "jsonls", "html", "emmet_ls", "cssls", "gopls"}

vim.lsp.config("lua_ls", require("lsp.init").lua_ls)
vim.lsp.config("clangd", require("lsp.init").clangd)
vim.lsp.config("glsl_analyzer", require("lsp.init").glsl_analyzer)
vim.lsp.config("pyright", require("lsp.init").pyright)
vim.lsp.config("ts_ls", require("lsp.init").ts_ls)
vim.lsp.config('jsonls', require("lsp.init").jsonls)
vim.lsp.config("html", require("lsp.init").html)
vim.lsp.config("emmet_ls", require("lsp.init").emmet_ls)
vim.lsp.config("cssls", require("lsp.init").cssls)
vim.lsp.config("gopls", require("lsp.init").gopls)

vim.lsp.enable(servers)

local x = vim.diagnostic.severity

vim.diagnostic.config {
	virtual_text = { prefix = "" },
	signs = { text = { [x.ERROR] = "󰅙", [x.WARN] = "", [x.INFO] = "󰋼", [x.HINT] = "󰌵" } },
	underline = true,
	float = { border = "single" },
}
