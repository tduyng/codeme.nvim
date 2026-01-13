local M = {}

local state = {
	win = nil,
	buf = nil,
}

function M.show()
	local codeme = require("codeme")

	-- Get all-time stats first
	codeme.get_stats(function(stats)
		-- Then get today-only stats for the Today tab
		codeme.get_stats(function(today_stats)
			-- Merge both into one stats object
			stats.today_stats = today_stats
			require("codeme.profile").open(stats)
		end, true) -- true = today_only
	end, false) -- false = all-time stats
end

function M.toggle()
	-- Check if dashboard is already open
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_win_close(state.win, true)
		state.win = nil
		state.buf = nil
	else
		M.show()
	end
end

return M
