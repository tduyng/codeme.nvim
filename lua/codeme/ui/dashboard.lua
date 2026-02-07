local M = {}

local stats = require("codeme.stats")
local renderer = require("codeme.ui.renderer")
local backend = require("codeme.backend")
local util = require("codeme.util")

-- Tab definitions
local TABS = {
	"📊 Overview",
	"⏰ Activity",
	"📅 Weekly",
	"📁 Work",
	"🏆 Records",
}

-- Tab modules
local tab_modules = {
	require("codeme.ui.tabs.overview"),
	require("codeme.ui.tabs.activity"),
	require("codeme.ui.tabs.weekly"),
	require("codeme.ui.tabs.work"),
	require("codeme.ui.tabs.records"),
}

---Render current tab content
---@param stat_data table
---@return table[] Lines
local function render_tab_content(stat_data)
	local tab = stats.get_active_tab()
	if tab >= 1 and tab <= #tab_modules then
		return tab_modules[tab].render(stat_data)
	end
	return { { { "  Invalid tab", "commentfg" } } }
end

---Render dashboard
---@param stat_data table
local function render_dashboard(stat_data)
	-- Strip every vim.NIL from the backend payload once here.
	stat_data = util.sanitize(stat_data) or {}

	local buf = stats.get_buf()
	local win = stats.get_win()

	if not buf or not win then
		return
	end

	local width = vim.api.nvim_win_get_width(win)
	local ns = vim.api.nvim_create_namespace("codeme_dashboard")

	local lines = {}

	-- Tabs header
	for _, l in ipairs(renderer.tabs(TABS, stats.get_active_tab())) do
		table.insert(lines, l)
	end
	table.insert(lines, {})

	-- Tab content
	for _, l in ipairs(render_tab_content(stat_data)) do
		table.insert(lines, l)
	end

	-- Footer
	table.insert(lines, {})
	table.insert(lines, { { "  <Tab>: Next │ <S-Tab>: Prev │ 1-6: Jump │ q: Close", "commentfg" } })

	renderer.render(buf, lines, ns, width)
end

---Fetch stats and open dashboard
function M.open()
	-- Check cache first
	local cached_stats = stats.get_stats()
	if cached_stats then
		M.show_window(cached_stats)
		return
	end

	-- Fetch from backend
	backend.get_stats(false, function(stat_data)
		stats.set_stats(stat_data)
		M.show_window(stat_data)
	end)
end

---Show dashboard window
---@param stat_data table
function M.show_window(stat_data)
	-- Create buffer
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"

	-- Calculate dimensions
	local width = math.min(130, math.floor(vim.o.columns * 0.9))
	local height = math.min(60, math.floor(vim.o.lines * 0.8))

	-- Create window
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		border = "rounded",
		style = "minimal",
	})

	stats.set_buf(buf)
	stats.set_win(win)

	-- Setup keymaps
	local opts = { buffer = buf, silent = true, nowait = true }

	vim.keymap.set("n", "<Tab>", function()
		M.next_tab()
	end, opts)
	vim.keymap.set("n", "L", function()
		M.next_tab()
	end, opts)
	vim.keymap.set("n", "<S-Tab>", function()
		M.prev_tab()
	end, opts)
	vim.keymap.set("n", "H", function()
		M.prev_tab()
	end, opts)

	for i = 1, 6 do
		vim.keymap.set("n", tostring(i), function()
			M.goto_tab(i)
		end, opts)
	end

	local function close()
		if stats.get_win() then
			vim.api.nvim_win_close(stats.get_win(), true)
		end
		stats.set_win(nil)
		stats.set_buf(nil)
	end

	vim.keymap.set("n", "q", close, opts)
	vim.keymap.set("n", "<Esc>", close, opts)

	vim.api.nvim_create_autocmd("BufLeave", {
		buffer = buf,
		once = true,
		callback = close,
	})

	-- Initial render
	render_dashboard(stat_data)
end

---Next tab
function M.next_tab()
	local current = stats.get_active_tab()
	stats.set_active_tab(current % #TABS + 1)
	local stat_data = stats.get_stats() or {}
	render_dashboard(stat_data)
end

---Previous tab
function M.prev_tab()
	local current = stats.get_active_tab()
	stats.set_active_tab(current == 1 and #TABS or current - 1)
	local stat_data = stats.get_stats() or {}
	render_dashboard(stat_data)
end

---Go to specific tab
---@param n number
function M.goto_tab(n)
	if n >= 1 and n <= #TABS then
		stats.set_active_tab(n)
		local stat_data = stats.get_stats() or {}
		render_dashboard(stat_data)
	end
end

---Toggle dashboard
function M.toggle()
	local win = stats.get_win()
	if win then
		vim.api.nvim_win_close(win, true)
		stats.set_win(nil)
		stats.set_buf(nil)
	else
		M.open()
	end
end

return M
