return {
  "neovim/nvim-lspconfig",
  config = function()
    local capabilities = require("cmp_nvim_lsp").default_capabilities()
		-- Rimuovi la riga deprecata
		-- local lspconfig = require "lspconfig"

		-- Usa vim.lsp.config come funzione, passando il nome del server e la configurazione
		vim.lsp.config("lua_ls", {
		  capabilities = capabilities,
		})
	  vim.lsp.config("clangd", {
		  capabilities = capabilities,
		})
		vim.lsp.config("pylsp", {
			capabilities = capabilities,
		})
	end,
}
