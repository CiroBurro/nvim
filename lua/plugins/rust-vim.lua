return {
  "rust-lang/rust.vim",
  ft = "rust",
  config = function()
    vim.g.rustfmt_autosave = 1

    -- Funzione per chiudere il codice marcato come inattivo da rust-analyzer
    local function fold_inactive_cfg()
      local diagnostics = vim.diagnostic.get(0, { severity = { min = vim.diagnostic.severity.HINT } })
      local folded_count = 0
      local fold_ranges = {}

      for _, diag in ipairs(diagnostics) do
        if diag.source == "rust-analyzer" and diag.code == "inactive-code" then
          table.insert(fold_ranges, { diag.lnum + 1, diag.end_lnum + 1 })
        end
      end

      if #fold_ranges > 0 then
        local view = vim.fn.winsaveview()
        vim.cmd("setlocal foldmethod=manual")
        vim.cmd("normal! zE")

        for i = #fold_ranges, 1, -1 do
          local r = fold_ranges[i]
          vim.cmd(r[1] .. "," .. r[2] .. "fold")
          folded_count = folded_count + 1
        end

        vim.fn.winrestview(view)
        print(string.format("%d region(i) di codice inattivo sono state chiuse.", folded_count))
      else
        print("Nessuna regione di codice inattivo trovata.")
      end
    end

    -- Funzione per mostrare la documentazione (hover)
    local function show_documentation_hover()
      vim.lsp.buf.hover()
    end

    -- Mappature dei tasti
    vim.keymap.set("n", "<leader>fc", fold_inactive_cfg, { noremap = true, silent = true, buffer = true, desc = "Fold Inactive Rust Code" })
    vim.keymap.set("n", "K", show_documentation_hover, { noremap = true, silent = true, buffer = true, desc = "Show Documentation (Hover)" })

  end,
}
