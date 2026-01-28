local M = {}

local function get_hl(name, attr)
	local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
	if ok and hl[attr] then
		return string.format("#%06x", hl[attr])
	end
end

local function first_valid(...)
	for _, val in ipairs({ ... }) do
		if val then
			return val
		end
	end
end

function M.get_colors()
	local is_dark = vim.o.background == "dark"

	return {
		green = first_valid(
			get_hl("@string", "fg"),
			get_hl("String", "fg"),
			get_hl("@function", "fg"),
			get_hl("Function", "fg"),
			is_dark and "#a6e3a1" or "#40a02b"
		),

		red = first_valid(
			get_hl("Error", "fg"),
			get_hl("ErrorMsg", "fg"),
			get_hl("@keyword", "fg"),
			get_hl("DiagnosticError", "fg"),
			is_dark and "#f38ba8" or "#d20f39"
		),

		yellow = first_valid(
			get_hl("@number", "fg"),
			get_hl("Number", "fg"),
			get_hl("WarningMsg", "fg"),
			get_hl("@constant", "fg"),
			is_dark and "#f9e2af" or "#df8e1d"
		),

		blue = first_valid(
			get_hl("@function", "fg"),
			get_hl("Function", "fg"),
			get_hl("Identifier", "fg"),
			get_hl("@type", "fg"),
			is_dark and "#89b4fa" or "#1e66f5"
		),

		cyan = first_valid(
			get_hl("@property", "fg"),
			get_hl("Special", "fg"),
			get_hl("@constant", "fg"),
			get_hl("Constant", "fg"),
			is_dark and "#94e2d5" or "#179299"
		),

		magenta = first_valid(
			get_hl("@keyword", "fg"),
			get_hl("Keyword", "fg"),
			get_hl("Statement", "fg"),
			get_hl("@variable", "fg"),
			is_dark and "#cba6f7" or "#8839ef"
		),

		comment = first_valid(
			get_hl("@comment", "fg"),
			get_hl("Comment", "fg"),
			get_hl("NonText", "fg"),
			is_dark and "#6c7086" or "#9ca0b0"
		),

		linenr = first_valid(
			get_hl("LineNr", "fg"),
			get_hl("@comment", "fg"),
			get_hl("Comment", "fg"),
			is_dark and "#585b70" or "#acb0be"
		),

		normal = first_valid(get_hl("Normal", "fg"), is_dark and "#cdd6f4" or "#4c4f69"),

		active_fg = first_valid(
			get_hl("TabLineSel", "fg"),
			get_hl("@function", "fg"),
			get_hl("Function", "fg"),
			get_hl("Title", "fg"),
			is_dark and "#89b4fa" or "#1e66f5"
		),

		active_bg = first_valid(get_hl("TabLineSel", "bg"), get_hl("CursorLine", "bg"), get_hl("Visual", "bg")),

		inactive_fg = first_valid(
			get_hl("TabLine", "fg"),
			get_hl("@comment", "fg"),
			get_hl("Comment", "fg"),
			is_dark and "#6c7086" or "#9ca0b0"
		),

		inactive_bg = first_valid(get_hl("TabLine", "bg"), get_hl("Normal", "bg")),

		progress_filled = first_valid(
			get_hl("@function", "fg"),
			get_hl("Function", "fg"),
			get_hl("Identifier", "fg"),
			is_dark and "#89b4fa" or "#1e66f5"
		),

		progress_empty = first_valid(
			get_hl("LineNr", "fg"),
			get_hl("@comment", "fg"),
			get_hl("Comment", "fg"),
			is_dark and "#585b70" or "#acb0be"
		),

		lang_bar = first_valid(
			get_hl("@string", "fg"),
			get_hl("String", "fg"),
			get_hl("Function", "fg"),
			is_dark and "#a6e3a1" or "#40a02b"
		),

		footer = first_valid(
			get_hl("@comment", "fg"),
			get_hl("Comment", "fg"),
			get_hl("LineNr", "fg"),
			is_dark and "#6c7086" or "#9ca0b0"
		),

		activity_none = first_valid(get_hl("LineNr", "fg"), is_dark and "#45475a" or "#ccd0da"),

		activity_low = first_valid(get_hl("@comment", "fg"), get_hl("Comment", "fg"), is_dark and "#6c7086" or "#9ca0b0"),

		activity_med = first_valid(get_hl("@string", "fg"), get_hl("String", "fg"), is_dark and "#a6e3a1" or "#40a02b"),

		activity_high = first_valid(
			get_hl("@function", "fg"),
			get_hl("Function", "fg"),
			is_dark and "#89b4fa" or "#1e66f5"
		),
	}
end

function M.setup()
	local c = M.get_colors()

	vim.api.nvim_set_hl(0, "CodeMeGreen", { fg = c.green, bold = true })
	vim.api.nvim_set_hl(0, "CodeMeRed", { fg = c.red, bold = true })
	vim.api.nvim_set_hl(0, "CodeMeYellow", { fg = c.yellow, bold = true })
	vim.api.nvim_set_hl(0, "CodeMeBlue", { fg = c.blue, bold = true })
	vim.api.nvim_set_hl(0, "CodeMeCyan", { fg = c.cyan, bold = true })
	vim.api.nvim_set_hl(0, "CodeMeMagenta", { fg = c.magenta, bold = true })
	vim.api.nvim_set_hl(0, "CodeMeComment", { fg = c.comment })
	vim.api.nvim_set_hl(0, "CodeMeLineNr", { fg = c.linenr })
	vim.api.nvim_set_hl(0, "CodeMeTabActive", { fg = c.active_fg, bg = c.active_bg, bold = true })
	vim.api.nvim_set_hl(0, "CodeMeTabInactive", { fg = c.inactive_fg, bg = c.inactive_bg })
	vim.api.nvim_set_hl(0, "CodeMeProgressFilled", { fg = c.progress_filled, bold = true })
	vim.api.nvim_set_hl(0, "CodeMeProgressEmpty", { fg = c.progress_empty })
	vim.api.nvim_set_hl(0, "CodeMeLangBar", { fg = c.lang_bar, bold = true })
	vim.api.nvim_set_hl(0, "CodeMeFooter", { fg = c.footer, italic = true })
	vim.api.nvim_set_hl(0, "CodeMeActivityNone", { fg = c.activity_none })
	vim.api.nvim_set_hl(0, "CodeMeActivityLow", { fg = c.activity_low })
	vim.api.nvim_set_hl(0, "CodeMeActivityMed", { fg = c.activity_med })
	vim.api.nvim_set_hl(0, "CodeMeActivityHigh", { fg = c.activity_high })

	-- Backwards compatibility
	vim.api.nvim_set_hl(0, "exgreen", { link = "CodeMeGreen" })
	vim.api.nvim_set_hl(0, "exred", { link = "CodeMeRed" })
	vim.api.nvim_set_hl(0, "exyellow", { link = "CodeMeYellow" })
	vim.api.nvim_set_hl(0, "exblue", { link = "CodeMeBlue" })
	vim.api.nvim_set_hl(0, "excyan", { link = "CodeMeCyan" })
	vim.api.nvim_set_hl(0, "exmagenta", { link = "CodeMeMagenta" })
	vim.api.nvim_set_hl(0, "commentfg", { link = "CodeMeComment" })
	vim.api.nvim_set_hl(0, "linenr", { link = "CodeMeLineNr" })
end

function M.setup_autocmd()
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = vim.api.nvim_create_augroup("CodeMeColors", { clear = true }),
		callback = function()
			vim.defer_fn(M.setup, 50)
		end,
	})
end

return M
