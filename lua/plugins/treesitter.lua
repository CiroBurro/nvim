return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter.config").setup {
      ensure_installed = {
        "c",
        "lua",
        "vim",
        "vimdoc",
        "javascript",
        "html",
        "rust",
        "python",
				"latex",
				"markdown",
				"markdown_inline",
				"yaml",
				"toml",
      },
      sync_install = false,
      highlight = { enable = true },
      indent = { enable = true },
      auto_install = true,
    }
		require'nvim-treesitter'.install {
        "c",
        "lua",
        "vim",
        "vimdoc",
        "javascript",
        "html",
        "rust",
        "python",
				"latex",
				"markdown",
				"markdown_inline",
				"yaml",
				"toml",
		}
  end,
}
