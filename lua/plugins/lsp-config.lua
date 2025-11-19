return {
  "neovim/nvim-lspconfig",
  config = function()
    local capabilities = require("cmp_nvim_lsp").default_capabilities()
		vim.lsp.config("lua_ls", {
		  capabilities = capabilities,
		})
	  vim.lsp.config("clangd", {
		  capabilities = capabilities,
		})
		vim.lsp.config("ruff", {
			capabilities = capabilities,
		})
		vim.lsp.config("jedi-language-server", {
			capabilities = capabilities,
		})
		vim.lsp.config("marksman", {
		  capabilities = capabilities,
		})
		vim.lsp.config("gopls", {
			capabilities = capabilities,
		})
	end,
}
