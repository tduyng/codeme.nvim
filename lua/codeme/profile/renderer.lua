local state = require("codeme.profile.state")
local ui = require("codeme.ui")
local api = vim.api

local M = {}

-- Lazy load tab modules (6 tabs in optimized order)
local function get_tab_modules()
	return {
		require("codeme.profile.tabs.dashboard"), -- Tab 1: Ultimate overview
		require("codeme.profile.tabs.activity"), -- Tab 2: Today's sessions
		require("codeme.profile.tabs.weekly"), -- Tab 3: Week breakdown
		require("codeme.profile.tabs.insights"), -- Tab 4: Work style analysis
		require("codeme.profile.tabs.work"), -- Tab 5: Projects + Languages
		require("codeme.profile.tabs.records"), -- Tab 6: All-time achievements
	}
end

function M.render()
	if not state.buf or not api.nvim_buf_is_valid(state.buf) then
		return
	end

	local lines = {}

	-- Tabs header
	for _, l in ipairs(ui.tabs(state.TABS, state.tab)) do
		table.insert(lines, l)
	end
	table.insert(lines, {})

	-- Tab content
	local tab_modules = get_tab_modules()
	for _, l in ipairs(tab_modules[state.tab].render()) do
		table.insert(lines, l)
	end

	-- Footer
	table.insert(lines, {})
	table.insert(lines, { { "  <Tab>: Next │ <S-Tab>: Prev │ 1-6: Jump │ q: Close", "commentfg" } })

	-- Render
	ui.render(state.buf, lines, state.ns, state.width)
end

function M.next_tab()
	state.tab = state.tab % #state.TABS + 1
	M.render()
end

function M.prev_tab()
	state.tab = state.tab == 1 and #state.TABS or state.tab - 1
	M.render()
end

function M.goto_tab(n)
	if n >= 1 and n <= #state.TABS then
		state.tab = n
		M.render()
	end
end

return M
