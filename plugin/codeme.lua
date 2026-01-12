if vim.g.loaded_codeme then
	return
end
vim.g.loaded_codeme = true

-- Setup with defaults
require("codeme").setup()
