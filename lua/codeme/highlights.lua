local M = {}

-- Helper to extract color from a highlight group
local function get_hl_color(hl_name, attr)
	local hl = vim.api.nvim_get_hl(0, { name = hl_name, link = false })
	if hl and hl[attr] then
		return string.format("#%06x", hl[attr])
	end
	return nil
end

-- Helper to get foreground color with fallbacks
local function get_fg(primary, fallbacks)
	local color = get_hl_color(primary, "fg")
	if color then
		return color
	end

	-- Try fallbacks
	for _, fb in ipairs(fallbacks or {}) do
		color = get_hl_color(fb, "fg")
		if color then
			return color
		end
	end

	-- Ultimate fallback based on background
	return vim.o.background == "dark" and "#ffffff" or "#000000"
end

-- Helper to get background color with fallbacks
local function get_bg(primary, fallbacks)
	local color = get_hl_color(primary, "bg")
	if color then
		return color
	end

	-- Try fallbacks
	for _, fb in ipairs(fallbacks or {}) do
		color = get_hl_color(fb, "bg")
		if color then
			return color
		end
	end

	return "NONE"
end

-- Extract colors from current colorscheme
function M.get_colors()
	-- Try to intelligently extract colors from existing highlight groups
	-- This works with ANY colorscheme (Catppuccin, Gruvbox, Tokyo Night, Nord, etc.)

	return {
		-- Semantic colors from common highlight groups
		green = get_fg("String", { "Function", "Keyword", "Type" }),
		red = get_fg("Error", { "ErrorMsg", "DiagnosticError", "DiffDelete" }),
		yellow = get_fg("Warning", { "WarningMsg", "DiagnosticWarn", "Number" }),
		blue = get_fg("Function", { "Identifier", "Statement", "Type" }),
		cyan = get_fg("Special", { "Constant", "Type", "Identifier" }),
		magenta = get_fg("Keyword", { "Statement", "Constant", "PreProc" }),

		-- UI colors
		comment = get_fg("Comment", { "NonText", "LineNr" }),
		linenr = get_fg("LineNr", { "Comment", "NonText" }),
		normal = get_fg("Normal", {}),

		-- Tab colors
		active_fg = get_fg("TabLineSel", { "Title", "Function", "Identifier" }),
		active_bg = get_bg("TabLineSel", { "Normal" }),
		inactive_fg = get_fg("TabLine", { "Comment", "LineNr" }),
		inactive_bg = get_bg("TabLine", { "Normal" }),

		-- Progress bar colors
		progress_filled = get_fg("Function", { "Identifier", "Type" }),
		progress_empty = get_fg("LineNr", { "Comment", "NonText" }),

		-- Language bar color
		lang_bar = get_fg("String", { "Function", "Type" }),

		-- Footer color
		footer = get_fg("Comment", { "LineNr", "NonText" }),

		-- Activity heatmap (GitHub-style intensity levels)
		-- Use green shades with increasing intensity
		activity_none = get_fg("LineNr", { "Comment" }), -- Very dim
		activity_low = get_fg("Comment", { "LineNr" }), -- Dim
		activity_med = get_fg("String", { "Function" }), -- Medium
		activity_high = get_fg("Function", { "String", "Type" }), -- Bright
	}
end

function M.setup()
	local colors = M.get_colors()

	-- Main semantic highlights
	vim.api.nvim_set_hl(0, "CodeMeGreen", { fg = colors.green, bold = true })
	vim.api.nvim_set_hl(0, "CodeMeRed", { fg = colors.red, bold = true })
	vim.api.nvim_set_hl(0, "CodeMeYellow", { fg = colors.yellow, bold = true })
	vim.api.nvim_set_hl(0, "CodeMeBlue", { fg = colors.blue, bold = true })
	vim.api.nvim_set_hl(0, "CodeMeCyan", { fg = colors.cyan, bold = true })
	vim.api.nvim_set_hl(0, "CodeMeMagenta", { fg = colors.magenta, bold = true })
	vim.api.nvim_set_hl(0, "CodeMeComment", { fg = colors.comment })
	vim.api.nvim_set_hl(0, "CodeMeLineNr", { fg = colors.linenr })

	-- Backwards compatibility aliases (old names)
	vim.api.nvim_set_hl(0, "exgreen", { link = "CodeMeGreen" })
	vim.api.nvim_set_hl(0, "exred", { link = "CodeMeRed" })
	vim.api.nvim_set_hl(0, "exyellow", { link = "CodeMeYellow" })
	vim.api.nvim_set_hl(0, "exblue", { link = "CodeMeBlue" })
	vim.api.nvim_set_hl(0, "excyan", { link = "CodeMeCyan" })
	vim.api.nvim_set_hl(0, "exmagenta", { link = "CodeMeMagenta" })
	vim.api.nvim_set_hl(0, "commentfg", { link = "CodeMeComment" })
	vim.api.nvim_set_hl(0, "linenr", { link = "CodeMeLineNr" })

	-- Tab highlights
	vim.api.nvim_set_hl(0, "CodeMeTabActive", {
		fg = colors.active_fg,
		bg = colors.active_bg,
		bold = true,
	})

	vim.api.nvim_set_hl(0, "CodeMeTabInactive", {
		fg = colors.inactive_fg,
		bg = colors.inactive_bg,
	})

	-- Progress bar highlights
	vim.api.nvim_set_hl(0, "CodeMeProgressFilled", {
		fg = colors.progress_filled,
		bold = true,
	})

	vim.api.nvim_set_hl(0, "CodeMeProgressEmpty", {
		fg = colors.progress_empty,
	})

	-- Language bar highlights
	vim.api.nvim_set_hl(0, "CodeMeLangBar", {
		fg = colors.lang_bar,
		bold = true,
	})

	-- Footer highlights
	vim.api.nvim_set_hl(0, "CodeMeFooter", {
		fg = colors.footer,
		italic = true,
	})

	-- Activity heatmap colors (4 levels)
	vim.api.nvim_set_hl(0, "CodeMeActivityNone", { fg = colors.activity_none })
	vim.api.nvim_set_hl(0, "CodeMeActivityLow", { fg = colors.activity_low })
	vim.api.nvim_set_hl(0, "CodeMeActivityMed", { fg = colors.activity_med })
	vim.api.nvim_set_hl(0, "CodeMeActivityHigh", { fg = colors.activity_high })
end

-- Auto-reload highlights when colorscheme changes
function M.setup_autocmd()
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = vim.api.nvim_create_augroup("CodeMeColors", { clear = true }),
		callback = function()
			-- Small delay to let colorscheme fully load
			vim.defer_fn(function()
				M.setup()
			end, 50)
		end,
	})
end

return M
