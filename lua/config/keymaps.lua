-- KEYMAPS GENERALI
vim.g.mapleader = " "
vim.keymap.set({ "n", "v" }, "<Leader>y", '"+y', { noremap = true, silent = true })
vim.keymap.set('n', '<leader>q', ':q<CR>', {})
vim.keymap.set('n', '<leader>w', ':w<CR>', {})
vim.keymap.set('n', '<leader>wq', ':wq<CR>', {})
vim.keymap.set('n', ';', ':', { desc = 'CMD enter command mode'})

-- KEYMAPS PER I PLUGIN
vim.keymap.set('n', '<leader>ff', ':Telescope find_files<CR>', {}) -- telescope cerca file
vim.keymap.set('n', '<leader>fg', ':Telescope live_grep<CR>', {}) -- telescope cerca contenuto
vim.keymap.set('n', '<leader>fb', ':Telescope buffers<CR>', {}) -- telescope cerca contenuto

vim.keymap.set('n', '<C-n>', ':Neotree toggle<CR>', {}) -- apri neotree

vim.keymap.set('n', '<leader>gf', vim.lsp.buf.format, {}) -- formatta il testo

vim.keymap.set('n', '<leader>gp', ':Gitsigns preview_hunk_inline<CR>', {}) -- gitsigns preview dei cambiamenti

vim.keymap.set('n', '<leader>ct', ':Codeium Chat<CR>', {}) -- codeium apre la chat

vim.keymap.set('n', ':', '<cmd>FineCmdline<CR>', {noremap = true}) -- cmdline inserisci comando
