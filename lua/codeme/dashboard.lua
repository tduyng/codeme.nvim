local M = {}

local state = {
	win = nil,
	buf = nil,
}

function M.show()
	local codeme = require("codeme")

	-- Get stats from server
	codeme.get_stats(function(stats)
		require("codeme.profile").open(stats)
	end)
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
