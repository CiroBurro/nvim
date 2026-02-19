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
				"go",
				"java"
      },
      sync_install = false,
      highlight = { enable = true },
      indent = { enable = true },
      auto_install = true,
    }

    vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('TreesitterMarkdownHighlighter', {}),
        pattern = 'markdown',
        callback = function(args)
            vim.treesitter.start(args.buf)
        end,
    })
  end,
}
