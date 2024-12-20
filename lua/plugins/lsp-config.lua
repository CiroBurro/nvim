return {
  "neovim/nvim-lspconfig",
  config = function()
    local capabilities = require("cmp_nvim_lsp").default_capabilities()
    local lspconfig = require "lspconfig"
    lspconfig.lua_ls.setup {
      capabilities = capabilities,
    }
    --lspconfig.rust_analyzer.setup {
      --capabilities = capabilities,
    --}
    lspconfig.ast_grep.setup {
      capabilities = capabilities,
    }
    lspconfig.clangd.setup {
      capabilities = capabilities,
    }
    lspconfig.cssls.setup {
      capabilities = capabilities,
    }
    lspconfig.html.setup {
      capabilities = capabilities,
    }
    lspconfig.pylsp.setup {
      capabilities = capabilities,
    }
  end,
}
