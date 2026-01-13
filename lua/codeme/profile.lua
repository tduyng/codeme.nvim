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

local tab_names = { "☀️ Today", "📊 Overview", "💻 Languages", "🔥 Projects" }

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

-- Build hourly activity heatmap
local function build_hourly_heatmap(hourly_activity, width)
	if not hourly_activity or vim.tbl_count(hourly_activity) == 0 then
		return {}
	end

	-- Find max activity for scaling
	local max_activity = 0
	for _, count in pairs(hourly_activity) do
		if count > max_activity then
			max_activity = count
		end
	end

	if max_activity == 0 then
		return {}
	end

	local result = {}

	-- Group hours into 4 blocks (6 hours each)
	local blocks = {
		{ name = "00-06", start_h = 0, end_h = 5 },
		{ name = "06-12", start_h = 6, end_h = 11 },
		{ name = "12-18", start_h = 12, end_h = 17 },
		{ name = "18-24", start_h = 18, end_h = 23 },
	}

	for _, block in ipairs(blocks) do
		local block_activity = 0
		for hour = block.start_h, block.end_h do
			-- JSON converts numeric keys to strings, so we need to check both
			block_activity = block_activity + (hourly_activity[tostring(hour)] or hourly_activity[hour] or 0)
		end

		local percentage = math.floor((block_activity / max_activity) * 100)
		local bar_width = math.min(30, math.floor(width * 0.4))
		local bar = build_progress_bar(percentage, bar_width)

		local color = "commentfg"
		if percentage > 60 then
			color = "exgreen"
		elseif percentage > 30 then
			color = "exyellow"
		end

		table.insert(result, {
			{ "  " .. block.name .. ": ", "commentfg" },
			{ bar, color },
			{ string.format("  %d heartbeats", block_activity), "commentfg" },
		})
	end

	return result
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
local function today_tab()
	local today_stats = state.stats.today_stats or {}
	local result = {}

	-- Header
	local today_time = format_time(today_stats.total_time or 0)
	local today_lines = today_stats.total_lines or 0
	local today_files = today_stats.total_files or 0

	table.insert(result, {})
	table.insert(result, { { "  ☀️ Today's Coding Session", "exgreen" } })
	table.insert(result, {})
	table.insert(result, {
		{ "  ⏱️  Active Time: ", "commentfg" },
		{ today_time, "exgreen" },
		{ "  |  📝 Lines: ", "commentfg" },
		{ format_number(today_lines), "exyellow" },
		{ "  |  📂 Files: ", "commentfg" },
		{ tostring(today_files), "exred" },
	})
	table.insert(result, {})

	-- Today's Languages
	if today_stats.languages and vim.tbl_count(today_stats.languages) > 0 then
		table.insert(result, { { "  💻 Languages (Today)", "exgreen" } })
		table.insert(result, {})

		-- Build table
		local items = {}
		local total_time = 0
		for name, stat in pairs(today_stats.languages) do
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

		local tbl = { { "Name", "Time", "Lines", "Percentage" } }
		for i = 1, math.min(5, #items) do
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

		local table_lines = voltui.table(tbl, state.win_width - 8)
		vim.list_extend(result, table_lines)
		table.insert(result, {})
	else
		table.insert(result, { { "  💻 Languages (Today)", "exgreen" } })
		table.insert(result, {})
		table.insert(result, { { "  No activity yet today. Start coding!", "commentfg" } })
		table.insert(result, {})
	end

	-- Today's Projects
	if today_stats.projects and vim.tbl_count(today_stats.projects) > 0 then
		table.insert(result, { { "  🔥 Projects (Today)", "exgreen" } })
		table.insert(result, {})

		-- Build table
		local items = {}
		local total_time = 0
		for name, stat in pairs(today_stats.projects) do
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

		local tbl = { { "Name", "Time", "Lines", "Percentage" } }
		for i = 1, math.min(5, #items) do
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

		local table_lines = voltui.table(tbl, state.win_width - 8)
		vim.list_extend(result, table_lines)
		table.insert(result, {})
	end

	-- Hourly Activity
	if today_stats.hourly_activity and vim.tbl_count(today_stats.hourly_activity) > 0 then
		table.insert(result, { { "  📊 Hourly Activity", "exgreen" } })
		table.insert(result, {})

		local heatmap = build_hourly_heatmap(today_stats.hourly_activity, state.win_width)
		vim.list_extend(result, heatmap)
		table.insert(result, {}) -- Add trailing empty line
	end

	return result
end

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
					return today_tab()
				elseif state.current_tab == 2 then
					return overview_tab()
				elseif state.current_tab == 3 then
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
					{ { "  <Tab>: Next | <S-Tab>: Prev | 1-4: Jump | q: Close", "commentfg" } },
				}
			end,
		},
	}
end

-- Helper to safely refresh the dashboard
-- volt caches section.row values during gen_data(), so we need to regenerate
-- layout data when content changes (tab switches) to recalculate row offsets
local function refresh_layout()
	if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
		return
	end

	local ns = vim.api.nvim_create_namespace("codeme")

	-- Make buffer modifiable for clearing
	vim.bo[state.buf].modifiable = true

	-- Clear ALL existing extmarks to prevent ghost content from previous tabs
	-- This is critical because volt uses extmarks for all visual content
	vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)

	-- Calculate actual content height for current layout
	local layout = get_layout()
	local total_lines = 0
	for _, section in ipairs(layout) do
		local lines = section.lines(state.buf)
		total_lines = total_lines + #lines
	end

	-- Always reset buffer to exact size needed (clear old content)
	local empty_lines = {}
	for _ = 1, total_lines do
		table.insert(empty_lines, string.rep(" ", state.win_width))
	end
	vim.api.nvim_buf_set_lines(state.buf, 0, -1, true, empty_lines)

	-- Regenerate layout data with new row calculations
	volt.gen_data({
		{ buf = state.buf, layout = get_layout(), xpad = 4, ns = ns },
	})

	-- Redraw all sections
	volt.redraw(state.buf, "all")

	-- Make buffer read-only again
	vim.bo[state.buf].modifiable = false
end

-- Tab navigation
local function next_tab()
	state.current_tab = state.current_tab % #tab_names + 1
	refresh_layout()
end

local function prev_tab()
	state.current_tab = state.current_tab - 1
	if state.current_tab < 1 then
		state.current_tab = #tab_names
	end
	refresh_layout()
end

local function goto_tab(n)
	if n >= 1 and n <= #tab_names then
		state.current_tab = n
		refresh_layout()
	end
end

-- Open dashboard
function M.open(stats)
	state.stats = stats or {}
	state.current_tab = 1

	-- Calculate window size
	state.win_width = math.min(120, math.floor(vim.o.columns * 0.9))

	-- First calculate content height, then determine window size
	-- We need a temporary calculation to know the content height
	local content_height = 0
	for tab = 1, #tab_names do
		state.current_tab = tab
		-- Estimate content height for each tab
		local tab_content
		if tab == 1 then
			tab_content = today_tab()
		elseif tab == 2 then
			tab_content = overview_tab()
		elseif tab == 3 then
			tab_content = languages_tab()
		else
			tab_content = projects_tab()
		end
		content_height = math.max(content_height, #tab_content)
	end
	state.current_tab = 1 -- Reset to first tab

	-- Add space for tabs (2 lines), empty line (1), and footer (1) = 4 extra lines
	local required_height = content_height + 4
	local max_height = math.floor(vim.o.lines * 0.85)
	local win_height = math.max(math.min(required_height, max_height), 20)

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
	vim.keymap.set("n", "4", function()
		goto_tab(4)
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
