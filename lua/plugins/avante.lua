return {
	"yetone/avante.nvim",
	config = function()
		require("avante").setup {
			provider = "mistral",
			vendors = {
				mistral = {
					__inherited_from = "openai",
					api_key_name = "MISTRAL_API_KEY",
					endpoint = "https://api.mistral.ai/v1/",
					model = "codestral-mamba-latest",
				},
				github = {
					__inherited_from = "openai",
					api_key_name = "GITHUB_API_KEY",
					endpoint = "https://models.inference.ai.azure.com",
					model = "gpt-4o-mini",
				},
			},
		}
	end,
	event = "VeryLazy",
	lazy = false,
	version = false,
	opts = {},

	build = "make",

	dependencies = {
		"stevearc/dressing.nvim",
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
		"hrsh7th/nvim-cmp",
		"nvim-tree/nvim-web-devicons",
		{
			-- support for image pasting
			"HakonHarnes/img-clip.nvim",
			event = "VeryLazy",
			opts = {
				-- recommended settings
				default = {
					embed_image_as_base64 = false,
					prompt_for_file_name = false,
					drag_and_drop = {
						insert_mode = true,
					},
				},
			},
		},
		{
			-- Make sure to set this up properly if you have lazy=true
			"MeanderingProgrammer/render-markdown.nvim",
			opts = {
				file_types = { "markdown", "Avante" },
			},
			ft = { "markdown", "Avante" },
		},
	},
}
