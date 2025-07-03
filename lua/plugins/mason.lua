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
				ensure_installed = { "lua_ls", "rust_analyzer", "clangd", "html", "ast_grep", "pylsp" },
      	automatic_enable = true,
			})
    end,
  },
}
