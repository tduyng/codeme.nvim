local M = {}

function M.setup()
	local colors = M.get_colors()

	-- Highlight groups
	vim.api.nvim_set_hl(0, "exgreen", { fg = colors.green, bold = true })
	vim.api.nvim_set_hl(0, "exred", { fg = colors.red, bold = true })
	vim.api.nvim_set_hl(0, "exyellow", { fg = colors.yellow, bold = true })
	vim.api.nvim_set_hl(0, "exblue", { fg = colors.blue, bold = true })
	vim.api.nvim_set_hl(0, "commentfg", { fg = colors.comment })
	vim.api.nvim_set_hl(0, "linenr", { fg = colors.linenr })

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

	-- Activity heatmap colors
	vim.api.nvim_set_hl(0, "CodeMeActivityNone", { fg = colors.activity_none })
	vim.api.nvim_set_hl(0, "CodeMeActivityLow", { fg = colors.activity_low })
	vim.api.nvim_set_hl(0, "CodeMeActivityMed", { fg = colors.activity_med })
	vim.api.nvim_set_hl(0, "CodeMeActivityHigh", { fg = colors.activity_high })
end

function M.get_colors()
	-- Try to detect colorscheme and adapt
	local bg = vim.o.background

	if bg == "dark" then
		return {
			green = "#9ece6a",
			red = "#f7768e",
			yellow = "#e0af68",
			blue = "#7aa2f7",
			comment = "#565f89",
			linenr = "#3b4261",

			-- Tabs
			active_fg = "#7dcfff",
			active_bg = "NONE",
			inactive_fg = "#565f89",
			inactive_bg = "NONE",

			-- Progress
			progress_filled = "#7aa2f7",
			progress_empty = "#3b4261",

			-- Language bars
			lang_bar = "#9ece6a",

			-- Footer
			footer = "#565f89",

			-- Activity heatmap (GitHub-style greens)
			activity_none = "#161b22",
			activity_low = "#0e4429",
			activity_med = "#006d32",
			activity_high = "#26a641",
		}
	else
		return {
			green = "#22863a",
			red = "#d73a49",
			yellow = "#e36209",
			blue = "#0366d6",
			comment = "#6a737d",
			linenr = "#d1d5da",

			-- Tabs
			active_fg = "#0066cc",
			active_bg = "NONE",
			inactive_fg = "#999999",
			inactive_bg = "NONE",

			-- Progress
			progress_filled = "#0066cc",
			progress_empty = "#cccccc",

			-- Language bars
			lang_bar = "#22863a",

			-- Footer
			footer = "#999999",

			-- Activity heatmap
			activity_none = "#ebedf0",
			activity_low = "#9be9a8",
			activity_med = "#40c463",
			activity_high = "#30a14e",
		}
	end
end

return M
