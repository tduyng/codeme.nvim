local M = {}

---Get highlight attribute safely
---@param name string
---@param attr string
---@return string|nil
local function get_hl(name, attr)
	local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
	if ok and hl[attr] then
		return string.format("#%06x", hl[attr])
	end
end

---Get first valid color from list
---@param ... string
---@return string
local function first_valid(...)
	for _, val in ipairs({ ... }) do
		if val then
			return val
		end
	end
	return "#ffffff" -- fallback
end

---Setup highlight groups
function M.setup()
	local is_dark = vim.o.background == "dark"

	local colors = {
		green = first_valid(get_hl("@string", "fg"), get_hl("String", "fg"), is_dark and "#a6e3a1" or "#40a02b"),
		red = first_valid(get_hl("Error", "fg"), get_hl("ErrorMsg", "fg"), is_dark and "#f38ba8" or "#d20f39"),
		yellow = first_valid(get_hl("@number", "fg"), get_hl("Number", "fg"), is_dark and "#f9e2af" or "#df8e1d"),
		blue = first_valid(get_hl("@function", "fg"), get_hl("Function", "fg"), is_dark and "#89b4fa" or "#1e66f5"),
		cyan = first_valid(get_hl("@property", "fg"), get_hl("Special", "fg"), is_dark and "#94e2d5" or "#179299"),
		magenta = first_valid(get_hl("@keyword", "fg"), get_hl("Keyword", "fg"), is_dark and "#cba6f7" or "#8839ef"),
		comment = first_valid(get_hl("Comment", "fg"), is_dark and "#6c7086" or "#9ca0b0"),
		linenr = first_valid(get_hl("LineNr", "fg"), is_dark and "#585b70" or "#acb0be"),
	}

	-- Set highlight groups
	vim.api.nvim_set_hl(0, "CodeMeGreen", { fg = colors.green, bold = true })
	vim.api.nvim_set_hl(0, "CodeMeRed", { fg = colors.red, bold = true })
	vim.api.nvim_set_hl(0, "CodeMeYellow", { fg = colors.yellow, bold = true })
	vim.api.nvim_set_hl(0, "CodeMeBlue", { fg = colors.blue, bold = true })
	vim.api.nvim_set_hl(0, "CodeMeCyan", { fg = colors.cyan, bold = true })
	vim.api.nvim_set_hl(0, "CodeMeMagenta", { fg = colors.magenta, bold = true })
	vim.api.nvim_set_hl(0, "CodeMeComment", { fg = colors.comment })
	vim.api.nvim_set_hl(0, "CodeMeLineNr", { fg = colors.linenr })

	-- Legacy aliases
	vim.api.nvim_set_hl(0, "exgreen", { link = "CodeMeGreen" })
	vim.api.nvim_set_hl(0, "exred", { link = "CodeMeRed" })
	vim.api.nvim_set_hl(0, "exyellow", { link = "CodeMeYellow" })
	vim.api.nvim_set_hl(0, "exblue", { link = "CodeMeBlue" })
	vim.api.nvim_set_hl(0, "excyan", { link = "CodeMeCyan" })
	vim.api.nvim_set_hl(0, "exmagenta", { link = "CodeMeMagenta" })
	vim.api.nvim_set_hl(0, "commentfg", { link = "CodeMeComment" })
	vim.api.nvim_set_hl(0, "linenr", { link = "CodeMeLineNr" })
end

---Setup autocmd for colorscheme changes
function M.setup_autocmd()
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = vim.api.nvim_create_augroup("CodeMeColors", { clear = true }),
		callback = function()
			vim.schedule(function()
				M.setup()
			end)
		end,
	})
end

return M
