return {
	{
		"mason-org/mason.nvim",
		build = ":MasonUpdate",
		config = function()
			require('mason').setup()
		end
	},
	{
    "mason-org/mason-lspconfig.nvim",
    dependencies = {
      "neovim/nvim-lspconfig",
      "mason-org/mason.nvim",
    },
    config = function()
      require("mason-lspconfig").setup({
				ensure_installed = { "lua_ls", "clangd", "ruff", "rust_analyzer", "gopls", "jedi_language_server" },
      	automatic_enable = true,
			})
    end,
  },
}
