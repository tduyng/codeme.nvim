local M = {}
local state = require("codeme.profile.state")
local renderer = require("codeme.profile.renderer")
local api = vim.api

function M.open(stats)
	state.set_stats(stats)
	state.tab = 1
	state.width = math.min(130, math.floor(vim.o.columns * 0.9))
	state.ns = api.nvim_create_namespace("codeme")

	-- Calculate height by rendering all tabs once
	local tab_modules = {
		require("codeme.profile.tabs.dashboard"), -- Tab 1: Ultimate overview
		require("codeme.profile.tabs.activity"), -- Tab 2: Today's sessions
		require("codeme.profile.tabs.weekly"), -- Tab 3: Week breakdown
		require("codeme.profile.tabs.insights"), -- Tab 4: Work style analysis
		require("codeme.profile.tabs.work"), -- Tab 5: Projects + Languages
		require("codeme.profile.tabs.records"), -- Tab 6: All-time achievements
	}

	local max_h = 0
	for i = 1, #state.TABS do
		state.tab = i
		local tab_lines = tab_modules[i].render()
		max_h = math.max(max_h, #tab_lines)
	end
	state.tab = 1
	local h = math.min(math.max(max_h + 6, 20), math.floor(vim.o.lines * 0.8))

	-- Create buffer
	state.buf = api.nvim_create_buf(false, true)
	vim.bo[state.buf].buftype = "nofile"
	vim.bo[state.buf].bufhidden = "wipe"

	-- Create window
	state.win = api.nvim_open_win(state.buf, true, {
		relative = "editor",
		width = state.width,
		height = h,
		row = math.floor((vim.o.lines - h) / 2),
		col = math.floor((vim.o.columns - state.width) / 2),
		border = "rounded",
		style = "minimal",
	})

	-- Keymaps
	local o = { buffer = state.buf, silent = true, nowait = true }
	vim.keymap.set("n", "<Tab>", renderer.next_tab, o)
	vim.keymap.set("n", "L", renderer.next_tab, o)
	vim.keymap.set("n", "<S-Tab>", renderer.prev_tab, o)
	vim.keymap.set("n", "H", renderer.prev_tab, o)
	for i = 1, 6 do
		vim.keymap.set("n", tostring(i), function()
			renderer.goto_tab(i)
		end, o)
	end

	local close = function()
		if state.win and api.nvim_win_is_valid(state.win) then
			api.nvim_win_close(state.win, true)
		end
		state.buf, state.win = nil, nil
	end
	vim.keymap.set("n", "q", close, o)
	vim.keymap.set("n", "<Esc>", close, o)

	-- Auto-close when leaving the buffer
	vim.api.nvim_create_autocmd("BufLeave", {
		buffer = state.buf,
		once = true,
		callback = close,
	})

	renderer.render()
end

return M
