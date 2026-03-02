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
	"🔍 Search",
}

-- Tab modules
local tab_modules = {
	require("codeme.ui.tabs.overview"),
	require("codeme.ui.tabs.activity"),
	require("codeme.ui.tabs.weekly"),
	require("codeme.ui.tabs.work"),
	require("codeme.ui.tabs.records"),
	require("codeme.ui.tabs.search"),
}

---Render current tab content
---@param stat_data table
---@param width number
---@param height number
---@return table[] Lines
local function render_tab_content(stat_data, width, height)
	local tab = stats.get_active_tab()
	if tab >= 1 and tab <= #tab_modules then
		-- Pass dimensions to tabs for adaptive rendering
		return tab_modules[tab].render(stat_data, width, height)
	end
	return { { { "  Invalid tab", "commentfg" } } }
end

---Render dashboard
---@param stat_data table
local function render_dashboard(stat_data)
	-- Strip every vim.NIL from the backend payload once here.
	stat_data = util.sanitize(stat_data) or {}
	stat_data = util.apply_privacy_mask(stat_data)

	local buf = stats.get_buf()
	local win = stats.get_win()

	if not buf or not win or not vim.api.nvim_win_is_valid(win) then
		return
	end

	local width = vim.api.nvim_win_get_width(win)
	local height = vim.api.nvim_win_get_height(win)
	local current_tab = stats.get_active_tab()

	local ns = vim.api.nvim_create_namespace("codeme_dashboard")
	local lines = {}

	-- Tabs header
	for _, l in ipairs(renderer.tabs(TABS, current_tab)) do
		table.insert(lines, l)
	end
	table.insert(lines, {})

	-- Tab content (now adaptive)
	for _, l in ipairs(render_tab_content(stat_data, width, height)) do
		table.insert(lines, l)
	end

	-- Footer
	table.insert(lines, {})
	table.insert(lines, { { "  <Tab>: Next │ <S-Tab>: Prev │ 1-6: Jump │ r: Refresh │ q: Close", "commentfg" } })
	if current_tab == 6 then
		table.insert(lines, { { "  [ / ]: Navigate Day │ /: Type Date │ Enter: Update Results", "exyellow" } })
	end

	renderer.render(buf, lines, ns, width)
end

---Trigger tab enter logic
local function trigger_on_enter()
	local current_tab = stats.get_active_tab()
	if tab_modules[current_tab] and tab_modules[current_tab].on_enter then
		tab_modules[current_tab].on_enter(function()
			local current_win = stats.get_win()
			if current_win and vim.api.nvim_win_is_valid(current_win) then
				render_dashboard(stats.get_stats_persistent() or {})
			end
		end)
	end
end

---Fetch stats and open dashboard
function M.open()
	-- Check cache first (persistent)
	local cached_stats = stats.get_stats_persistent()
	if cached_stats then
		M.show_window(cached_stats)
		trigger_on_enter()
		return
	end

	-- Fetch from backend
	backend.get_stats(false, function(stat_data)
		stats.set_stats(stat_data)
		M.show_window(stat_data)
		trigger_on_enter()
	end)
end

---Show dashboard window
---@param stat_data table
function M.show_window(stat_data)
	-- ... (rest of the function stays same until keymaps)

	-- Create buffer
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"

	-- Calculate dimensions (Increased for modern high-density layout)
	local width = math.min(160, math.floor(vim.o.columns * 0.95))
	local height = math.min(60, math.floor(vim.o.lines * 0.85))

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

	-- Global refresh keymap
	local function force_refresh()
		backend.get_stats(false, function(new_stat_data)
			stats.set_stats(new_stat_data)
			render_dashboard(new_stat_data)
			trigger_on_enter()
		end)
	end

	vim.keymap.set("n", "r", force_refresh, opts)

	-- Search tab specific keymaps
	local function refresh()
		local data = stats.get_stats_persistent() or {}
		render_dashboard(data)
	end

	vim.keymap.set("n", "[", function()
		if stats.get_active_tab() == 6 then
			tab_modules[6].on_key("[", refresh)
		end
	end, opts)
	vim.keymap.set("n", "]", function()
		if stats.get_active_tab() == 6 then
			tab_modules[6].on_key("]", refresh)
		end
	end, opts)
	vim.keymap.set("n", "<CR>", function()
		if stats.get_active_tab() == 6 then
			tab_modules[6].on_key("<CR>", refresh)
		end
	end, opts)
	vim.keymap.set("n", "/", function()
		if stats.get_active_tab() == 6 then
			tab_modules[6].on_key("/", refresh)
		end
	end, opts)

	for i = 1, 6 do
		vim.keymap.set("n", tostring(i), function()
			M.goto_tab(i)
		end, opts)
	end

	local function close()
		local ok, records_tab = pcall(require, "codeme.ui.tabs.records")
		if ok and records_tab.teardown_hover then
			records_tab.teardown_hover()
		end

		local win_handle = stats.get_win()
		if win_handle and vim.api.nvim_win_is_valid(win_handle) then
			vim.api.nvim_win_close(win_handle, true)
		end
		stats.set_win(nil)
		stats.set_buf(nil)
	end

	vim.keymap.set("n", "q", close, opts)
	vim.keymap.set("n", "<Esc>", close, opts)

	-- Auto-resize logic
	local group = vim.api.nvim_create_augroup("CodeMeResize", { clear = true })
	vim.api.nvim_create_autocmd("VimResized", {
		group = group,
		buffer = buf,
		callback = function()
			local current_win = stats.get_win()
			if current_win and vim.api.nvim_win_is_valid(current_win) then
				local new_width = math.min(160, math.floor(vim.o.columns * 0.95))
				local new_height = math.min(60, math.floor(vim.o.lines * 0.85))

				-- Ensure minimum size to prevent crash
				new_width = math.max(40, new_width)
				new_height = math.max(10, new_height)

				pcall(vim.api.nvim_win_set_config, current_win, {
					relative = "editor",
					width = new_width,
					height = new_height,
					row = math.max(0, math.floor((vim.o.lines - new_height) / 2)),
					col = math.max(0, math.floor((vim.o.columns - new_width) / 2)),
					anchor = "NW",
					focusable = true,
					zindex = 50,
				})
				render_dashboard(stats.get_stats_persistent() or {})
			end
		end,
	})

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
	local stat_data = stats.get_stats_persistent() or {}
	render_dashboard(stat_data)
	trigger_on_enter()
end

---Previous tab
function M.prev_tab()
	local current = stats.get_active_tab()
	stats.set_active_tab(current == 1 and #TABS or current - 1)
	local stat_data = stats.get_stats_persistent() or {}
	render_dashboard(stat_data)
	trigger_on_enter()
end

---Go to specific tab
---@param n number
function M.goto_tab(n)
	if n >= 1 and n <= #TABS then
		stats.set_active_tab(n)
		local stat_data = stats.get_stats_persistent() or {}
		render_dashboard(stat_data)
		trigger_on_enter()
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
