local M = {}

-- Module state
M.stats = {}
M.tab = 1
M.buf = nil
M.win = nil
M.ns = nil
M.width = 100

-- Tab definitions (6 tabs - optimized structure)
M.TABS = { "📊 Dashboard", "⏰ Activity", "📅 Weekly", "💡 Insights", "📁 Work", "🏆 Records" }

function M.reset()
	M.stats = {}
	M.tab = 1
	M.buf = nil
	M.win = nil
	M.ns = nil
	M.width = 100
end

function M.get_stats()
	return M.stats
end

function M.set_stats(stats)
	M.stats = stats or {}
end

return M
