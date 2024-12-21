return {
  "VonHeikemen/fine-cmdline.nvim",
  dependencies = { "MunifTanjim/nui.nvim" },
  config = function()
    require("fine-cmdline").setup {
      cmdline = {
        enable_keybindings = true,
        smart_history = true,
        prompt = "cmd ❯ ",
      },
      popup = {
        position = "50%",
        border = {
          style = "rounded",
          text = { top = " Inserisci comando", top_align = "center" },
        },
        win_options = {
          winblend = 10,
          winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
        },
      },
    }
  end,
} 
