local M = {}
local volt = require("volt")
local voltui = require("volt.ui")

local state = {
	stats = {},
	current_tab = 1,
	win_width = 0,
	buf = nil,
	win = nil,
}

local tab_names = { "󰃰 Overview", "💻 Languages", "🔥 Projects" }

-- Utility functions
local function format_time(seconds)
	if not seconds or seconds == 0 then
		return "0m"
	end

	if seconds < 60 then
		return string.format("%ds", seconds)
	elseif seconds < 3600 then
		local mins = math.floor(seconds / 60)
		return string.format("%dm", mins)
	else
		local hours = math.floor(seconds / 3600)
		local mins = math.floor((seconds % 3600) / 60)
		return mins > 0 and string.format("%dh %dm", hours, mins) or string.format("%dh", hours)
	end
end

local function format_number(n)
	if not n then
		return "0"
	end
	local s = tostring(n)
	s = s:reverse():gsub("(%d%d%d)", "%1,")
	s = s:reverse()
	return s:gsub("^,", "")
end

local function build_progress_bar(percentage, width)
	local filled = math.floor(percentage / 100 * width)
	return string.rep("█", filled) .. string.rep("░", width - filled)
end

-- Build stat table (reusable for languages and projects)
local function build_stat_table(title, data, width)
	local result = {}
	table.insert(result, {})
	table.insert(result, { { "  " .. title, "exgreen" } })
	table.insert(result, {})

	if not data or vim.tbl_count(data) == 0 then
		table.insert(result, { { "  No data yet. Start coding!" } })
		return result
	end

	-- Convert to array and sort by time
	local items = {}
	local total_time = 0
	for name, stat in pairs(data) do
		total_time = total_time + (stat.time or 0)
		table.insert(items, {
			name = name,
			time = stat.time or 0,
			lines = stat.lines or 0,
		})
	end
	table.sort(items, function(a, b)
		return a.time > b.time
	end)

	-- Build table
	local tbl = { { "Name", "Time", "Lines", "Percentage" } }
	for i = 1, math.min(8, #items) do
		local item = items[i]
		local percent = total_time > 0 and math.floor((item.time / total_time) * 100) or 0
		local bar = build_progress_bar(percent, 20)

		table.insert(tbl, {
			item.name,
			format_time(item.time),
			format_number(item.lines),
			bar .. " " .. percent .. "%",
		})
	end

	local table_lines = voltui.table(tbl, width)
	vim.list_extend(result, table_lines)
	return result
end

-- Tab content builders
local function overview_tab()
	local stats = state.stats
	local result = {}

	-- Header
	local streak = stats.streak or 0
	local total_time = format_time(stats.total_time or 0)
	local today_time = format_time((stats.today and stats.today.time) or stats.today_time or 0)
	local today_lines = (stats.today and stats.today.lines) or stats.today_lines or 0
	local total_lines = format_number(stats.total_lines or 0)

	table.insert(result, {})
	table.insert(result, { { "  📊 CodeMe Dashboard", "exgreen" } })
	table.insert(result, {})
	table.insert(result, {
		{ "  🔥 Streak: ", "commentfg" },
		{ tostring(streak) .. " days", "exred" },
		{ "  |  📈 Total: ", "commentfg" },
		{ total_time, "exgreen" },
		{ "  |  ⏱️  Today: ", "commentfg" },
		{ today_time, "exyellow" },
	})
	table.insert(result, {})

	-- Stats table
	table.insert(result, { { "  📈 Coding Trends", "exgreen" } })
	table.insert(result, {})

	local trends_table = {
		{ "Period", "Duration", "Lines" },
		{ "Today", today_time, tostring(today_lines) },
		{ "Total", total_time, total_lines },
	}

	local table_lines = voltui.table(trends_table, state.win_width - 8)
	vim.list_extend(result, table_lines)
	table.insert(result, {})

	-- Quick stats
	local projects_count = stats.projects and vim.tbl_count(stats.projects) or 0
	local langs_count = stats.languages and vim.tbl_count(stats.languages) or 0
	local files_count = stats.total_files or 0

	table.insert(result, {
		{ "  📂 Projects: ", "commentfg" },
		{ tostring(projects_count), "exgreen" },
		{ "  |  💻 Languages: ", "commentfg" },
		{ tostring(langs_count), "exgreen" },
		{ "  |  📝 Files: ", "commentfg" },
		{ tostring(files_count), "exgreen" },
	})

	return result
end

local function languages_tab()
	return build_stat_table("💻 Top Languages", state.stats.languages, state.win_width - 8)
end

local function projects_tab()
	return build_stat_table("🔥 Active Projects", state.stats.projects, state.win_width - 8)
end

-- Layout
local function get_layout()
	return {
		{
			name = "tabs",
			lines = function(buf)
				return voltui.tabs(tab_names, state.win_width, { active = tab_names[state.current_tab] })
			end,
		},
		{
			name = "empty",
			lines = function(buf)
				return { {} }
			end,
		},
		{
			name = "content",
			lines = function(buf)
				if state.current_tab == 1 then
					return overview_tab()
				elseif state.current_tab == 2 then
					return languages_tab()
				else
					return projects_tab()
				end
			end,
		},
		{
			name = "footer",
			lines = function(buf)
				return {
					{ { "  <Tab>: Next | <S-Tab>: Prev | 1-3: Jump | q: Close", "commentfg" } },
				}
			end,
		},
	}
end

-- Tab navigation
local function next_tab()
	state.current_tab = state.current_tab % #tab_names + 1
	volt.redraw(state.buf, "all")
end

local function prev_tab()
	state.current_tab = state.current_tab - 1
	if state.current_tab < 1 then
		state.current_tab = #tab_names
	end
	volt.redraw(state.buf, "all")
end

local function goto_tab(n)
	if n >= 1 and n <= #tab_names then
		state.current_tab = n
		volt.redraw(state.buf, "all")
	end
end

-- Open dashboard
function M.open(stats)
	state.stats = stats or {}
	state.current_tab = 1

	-- Calculate window size
	state.win_width = math.min(120, math.floor(vim.o.columns * 0.9))
	local win_height = math.min(35, math.floor(vim.o.lines * 0.85))

	-- Create buffer
	state.buf = vim.api.nvim_create_buf(false, true)
	vim.bo[state.buf].buftype = "nofile"
	vim.bo[state.buf].bufhidden = "wipe"
	vim.bo[state.buf].filetype = "codeme"

	-- Create window
	state.win = vim.api.nvim_open_win(state.buf, true, {
		relative = "editor",
		width = state.win_width,
		height = win_height,
		row = math.floor((vim.o.lines - win_height) / 2),
		col = math.floor((vim.o.columns - state.win_width) / 2),
		border = "rounded",
		style = "minimal",
	})

	-- Setup keymaps
	local opts = { buffer = state.buf, silent = true, nowait = true }

	vim.keymap.set("n", "<Tab>", next_tab, opts)
	vim.keymap.set("n", "L", next_tab, opts)
	vim.keymap.set("n", "<S-Tab>", prev_tab, opts)
	vim.keymap.set("n", "H", prev_tab, opts)

	vim.keymap.set("n", "1", function()
		goto_tab(1)
	end, opts)
	vim.keymap.set("n", "2", function()
		goto_tab(2)
	end, opts)
	vim.keymap.set("n", "3", function()
		goto_tab(3)
	end, opts)

	local close_fn = function()
		if state.win and vim.api.nvim_win_is_valid(state.win) then
			vim.api.nvim_win_close(state.win, true)
		end
		state.buf = nil
		state.win = nil
	end

	vim.keymap.set("n", "q", close_fn, opts)
	vim.keymap.set("n", "<Esc>", close_fn, opts)

	-- Create namespace
	local ns = vim.api.nvim_create_namespace("codeme")

	-- Initialize volt
	volt.gen_data({
		{ buf = state.buf, layout = get_layout(), xpad = 4, ns = ns },
	})

	-- Run volt
	volt.run(state.buf, { h = win_height, w = state.win_width })
end

return M
