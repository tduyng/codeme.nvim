-- ABOUTME: Main dashboard UI for codeme.nvim neovim plugin
-- ABOUTME: Renders tabs with stats, heatmaps, insights, and achievements using volt framework

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

local tab_names = { "☀️ Today", "📅 Weekly", "📊 Overview", "💡 Insights", "💻 Languages", "🔥 Projects" }

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

-- Calculate trend indicator (comparing two values)
local function get_trend(current, previous)
	if not current or not previous or previous == 0 then
		return "", "commentfg"
	end
	local diff = current - previous
	local percent = math.floor((diff / previous) * 100)
	if diff > 0 then
		return string.format(" ↑ %d%%", percent), "exgreen"
	elseif diff < 0 then
		return string.format(" ↓ %d%%", math.abs(percent)), "exred"
	else
		return " →", "commentfg"
	end
end

-- Build flame streak visualization
local function build_streak_flames(streak)
	if streak <= 0 then
		return "No streak", "commentfg"
	end
	local flames = string.rep("🔥", math.min(streak, 7))
	if streak > 7 then
		flames = flames .. " +" .. (streak - 7)
	end
	return flames, "exred"
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

-- Build GitHub-style contribution heatmap grid
local function build_contribution_heatmap(weekly_heatmap, width)
	if not weekly_heatmap or #weekly_heatmap == 0 then
		return { { { "  No activity data available", "commentfg" } } }
	end

	local result = {}
	local level_chars = { "░", "▒", "▓", "█", "█" } -- level 0-4
	local level_colors = { "commentfg", "exblue", "excyan", "exgreen", "exyellow" }

	-- Group by weeks (7 days per row)
	local weeks = {}
	local current_week = {}

	for _, day in ipairs(weekly_heatmap) do
		table.insert(current_week, day)
		if #current_week == 7 then
			table.insert(weeks, current_week)
			current_week = {}
		end
	end
	if #current_week > 0 then
		table.insert(weeks, current_week)
	end

	-- Build header with month labels
	table.insert(result, { { "  Activity (Last 12 Weeks)", "exgreen" } })
	table.insert(result, {})

	-- Day labels
	local day_labels = { "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" }
	local header_line = { { "      ", "commentfg" } }
	for _, label in ipairs(day_labels) do
		table.insert(header_line, { label .. " ", "commentfg" })
	end
	table.insert(result, header_line)

	-- Build each week row
	for week_idx, week in ipairs(weeks) do
		local line = { { string.format("  W%02d ", week_idx), "commentfg" } }
		for _, day in ipairs(week) do
			local char = level_chars[day.level + 1] or "░"
			local color = level_colors[day.level + 1] or "commentfg"
			table.insert(line, { char .. "   ", color })
		end
		table.insert(result, line)
	end

	-- Legend
	table.insert(result, {})
	table.insert(result, {
		{ "  Less ", "commentfg" },
		{ "░ ", "commentfg" },
		{ "▒ ", "exblue" },
		{ "▓ ", "excyan" },
		{ "█ ", "exgreen" },
		{ "█ ", "exyellow" },
		{ "More", "commentfg" },
	})

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

-- Build top files section
local function build_top_files(top_files, width, limit)
	local result = {}
	limit = limit or 5

	if not top_files or #top_files == 0 then
		return result
	end

	table.insert(result, { { "  📄 Top Files", "exgreen" } })
	table.insert(result, {})

	local tbl = { { "File", "Time", "Lines" } }
	for i = 1, math.min(limit, #top_files) do
		local file = top_files[i]
		-- Get just the filename
		local filename = file.path:match("([^/]+)$") or file.path
		-- Truncate if too long
		if #filename > 30 then
			filename = "..." .. filename:sub(-27)
		end
		table.insert(tbl, {
			filename,
			format_time(file.time or 0),
			format_number(file.lines or 0),
		})
	end

	local table_lines = voltui.table(tbl, width)
	vim.list_extend(result, table_lines)
	return result
end

-- Build sessions list
local function build_sessions(sessions)
	local result = {}

	if not sessions or #sessions == 0 then
		return result
	end

	table.insert(result, { { "  ⏰ Today's Sessions", "exgreen" } })
	table.insert(result, {})

	for i, session in ipairs(sessions) do
		if i > 5 then
			break
		end
		-- Parse start time to get just the time portion
		local start_time = session.start:match("T(%d+:%d+)") or session.start
		local end_time = session["end"]:match("T(%d+:%d+)") or session["end"]
		local duration = format_time(session.duration or 0)
		local project = session.project or "unknown"

		table.insert(result, {
			{ "  " .. start_time .. " - " .. end_time, "commentfg" },
			{ " (" .. duration .. ")", "exyellow" },
			{ " - " .. project, "exgreen" },
		})
	end

	return result
end

-- Build daily goals progress section
local function build_goals_progress(today_time, today_lines)
	local result = {}
	local codeme = require("codeme")
	local config = codeme.get_config()
	local goals = config.goals or {}

	local goal_hours = goals.daily_hours or 0
	local goal_lines = goals.daily_lines or 0

	-- Skip if both goals are disabled
	if goal_hours <= 0 and goal_lines <= 0 then
		return result
	end

	table.insert(result, { { "  🎯 Daily Goals", "exgreen" } })
	table.insert(result, {})

	-- Time goal
	if goal_hours > 0 then
		local goal_seconds = goal_hours * 3600
		local time_percent = math.min(100, math.floor((today_time / goal_seconds) * 100))
		local time_bar = build_progress_bar(time_percent, 30)
		local time_color = time_percent >= 100 and "exgreen" or (time_percent >= 50 and "exyellow" or "exred")
		local check = time_percent >= 100 and " ✓" or ""

		table.insert(result, {
			{ "  ⏱️  Time: ", "commentfg" },
			{ time_bar, time_color },
			{ string.format(" %d%% (%s / %dh)%s", time_percent, format_time(today_time), goal_hours, check), "commentfg" },
		})
	end

	-- Lines goal
	if goal_lines > 0 then
		local lines_percent = math.min(100, math.floor((today_lines / goal_lines) * 100))
		local lines_bar = build_progress_bar(lines_percent, 30)
		local lines_color = lines_percent >= 100 and "exgreen" or (lines_percent >= 50 and "exyellow" or "exred")
		local check = lines_percent >= 100 and " ✓" or ""

		table.insert(result, {
			{ "  📝 Lines: ", "commentfg" },
			{ lines_bar, lines_color },
			{
				string.format(" %d%% (%s / %s)%s", lines_percent, format_number(today_lines), format_number(goal_lines), check),
				"commentfg",
			},
		})
	end

	table.insert(result, {})
	return result
end

-- Build achievements section
local function build_achievements(achievements)
	local result = {}

	if not achievements or #achievements == 0 then
		return result
	end

	table.insert(result, { { "  🏆 Achievements", "exgreen" } })
	table.insert(result, {})

	local unlocked = {}
	local locked = {}

	for _, ach in ipairs(achievements) do
		if ach.unlocked then
			table.insert(unlocked, ach)
		else
			table.insert(locked, ach)
		end
	end

	-- Show unlocked first
	for _, ach in ipairs(unlocked) do
		table.insert(result, {
			{ "  " .. (ach.icon or "🏆") .. " ", "normal" },
			{ ach.name, "exgreen" },
			{ " - " .. ach.description, "commentfg" },
		})
	end

	-- Show a few locked ones
	for i, ach in ipairs(locked) do
		if i > 3 then
			break
		end
		table.insert(result, {
			{ "  🔒 ", "commentfg" },
			{ ach.name, "commentfg" },
			{ " - " .. ach.description, "commentfg" },
		})
	end

	return result
end

-- Tab content builders
local function today_tab()
	local today_stats = state.stats.today_stats or {}
	local all_stats = state.stats
	local result = {}

	-- Header
	local today_time = format_time(today_stats.total_time or 0)
	local today_lines = today_stats.total_lines or 0
	local today_files = today_stats.total_files or 0

	-- Comparison with yesterday
	local yesterday_time = all_stats.yesterday_time or 0
	local trend_text, trend_color = get_trend(today_stats.total_time or 0, yesterday_time)

	table.insert(result, {})
	table.insert(result, { { "  ☀️ Today's Coding Session", "exgreen" } })
	table.insert(result, {})
	table.insert(result, {
		{ "  ⏱️  Active Time: ", "commentfg" },
		{ today_time, "exgreen" },
		{ trend_text, trend_color },
		{ "  |  📝 Lines: ", "commentfg" },
		{ format_number(today_lines), "exyellow" },
		{ "  |  📂 Files: ", "commentfg" },
		{ tostring(today_files), "exred" },
	})
	table.insert(result, {})

	-- Daily goals progress
	local goals_section = build_goals_progress(today_stats.total_time or 0, today_lines)
	vim.list_extend(result, goals_section)

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

	-- Today's Top Files
	if today_stats.top_files and #today_stats.top_files > 0 then
		local files_section = build_top_files(today_stats.top_files, state.win_width - 8, 3)
		vim.list_extend(result, files_section)
		table.insert(result, {})
	end

	-- Today's Sessions
	if today_stats.sessions and #today_stats.sessions > 0 then
		local sessions_section = build_sessions(today_stats.sessions)
		vim.list_extend(result, sessions_section)
		table.insert(result, {})
	end

	-- Hourly Activity
	if today_stats.hourly_activity and vim.tbl_count(today_stats.hourly_activity) > 0 then
		table.insert(result, { { "  📊 Hourly Activity", "exgreen" } })
		table.insert(result, {})

		local heatmap = build_hourly_heatmap(today_stats.hourly_activity, state.win_width)
		vim.list_extend(result, heatmap)
		table.insert(result, {})
	end

	return result
end

local function weekly_tab()
	local stats = state.stats
	local result = {}

	table.insert(result, {})
	table.insert(result, { { "  📅 Weekly Summary", "exgreen" } })
	table.insert(result, {})

	-- This week stats with comparison
	local week_time = format_time(stats.week_time or 0)
	local week_lines = format_number(stats.week_lines or 0)
	local week_files = stats.week_files or 0

	local trend_text, trend_color = get_trend(stats.week_time or 0, stats.last_week_time or 0)

	table.insert(result, {
		{ "  ⏱️  This Week: ", "commentfg" },
		{ week_time, "exgreen" },
		{ trend_text, trend_color },
		{ "  |  📝 Lines: ", "commentfg" },
		{ week_lines, "exyellow" },
		{ "  |  📂 Files: ", "commentfg" },
		{ tostring(week_files), "exred" },
	})
	table.insert(result, {})

	-- Comparison table
	table.insert(result, { { "  📊 Week Comparison", "exgreen" } })
	table.insert(result, {})

	local comparison_table = {
		{ "Period", "Time", "Lines", "Files" },
		{
			"This Week",
			format_time(stats.week_time or 0),
			format_number(stats.week_lines or 0),
			tostring(stats.week_files or 0),
		},
		{
			"Last Week",
			format_time(stats.last_week_time or 0),
			format_number(stats.last_week_lines or 0),
			tostring(stats.last_week_files or 0),
		},
	}

	local table_lines = voltui.table(comparison_table, state.win_width - 8)
	vim.list_extend(result, table_lines)
	table.insert(result, {})

	-- Contribution heatmap
	local heatmap = build_contribution_heatmap(stats.weekly_heatmap, state.win_width)
	vim.list_extend(result, heatmap)
	table.insert(result, {})

	return result
end

local function overview_tab()
	local stats = state.stats
	local result = {}

	-- Header with streak
	local streak = stats.streak or 0
	local longest_streak = stats.longest_streak or 0
	local total_time = format_time(stats.total_time or 0)
	local today_time = format_time((stats.today and stats.today.time) or stats.today_time or 0)

	table.insert(result, {})
	table.insert(result, { { "  📊 CodeMe Dashboard", "exgreen" } })
	table.insert(result, {})

	-- Streak with flames
	local streak_text, streak_color = build_streak_flames(streak)
	table.insert(result, {
		{ "  🔥 Streak: ", "commentfg" },
		{ streak_text, streak_color },
		{ "  (Best: " .. longest_streak .. " days)", "commentfg" },
	})
	table.insert(result, {})

	-- Stats overview
	table.insert(result, {
		{ "  📈 Total: ", "commentfg" },
		{ total_time, "exgreen" },
		{ "  |  ⏱️  Today: ", "commentfg" },
		{ today_time, "exyellow" },
		{ "  |  📅 This Week: ", "commentfg" },
		{ format_time(stats.week_time or 0), "exblue" },
	})
	table.insert(result, {})

	-- Trends table
	table.insert(result, { { "  📈 Coding Trends", "exgreen" } })
	table.insert(result, {})

	local today_lines = (stats.today and stats.today.lines) or stats.today_lines or 0
	local trends_table = {
		{ "Period", "Duration", "Lines", "Files" },
		{ "Today", format_time(stats.today_time or 0), format_number(today_lines), tostring(stats.today_files or 0) },
		{
			"This Week",
			format_time(stats.week_time or 0),
			format_number(stats.week_lines or 0),
			tostring(stats.week_files or 0),
		},
		{
			"This Month",
			format_time(stats.month_time or 0),
			format_number(stats.month_lines or 0),
			tostring(stats.month_files or 0),
		},
		{
			"All Time",
			format_time(stats.total_time or 0),
			format_number(stats.total_lines or 0),
			tostring(stats.total_files or 0),
		},
	}

	local table_lines = voltui.table(trends_table, state.win_width - 8)
	vim.list_extend(result, table_lines)
	table.insert(result, {})

	-- Quick stats
	local projects_count = stats.projects and vim.tbl_count(stats.projects) or 0
	local langs_count = stats.languages and vim.tbl_count(stats.languages) or 0

	table.insert(result, {
		{ "  📂 Projects: ", "commentfg" },
		{ tostring(projects_count), "exgreen" },
		{ "  |  💻 Languages: ", "commentfg" },
		{ tostring(langs_count), "exgreen" },
	})

	return result
end

local function insights_tab()
	local stats = state.stats
	local result = {}

	table.insert(result, {})
	table.insert(result, { { "  💡 Coding Insights", "exgreen" } })
	table.insert(result, {})

	-- Peak productivity
	table.insert(result, { { "  ⏰ Peak Productivity", "exgreen" } })
	table.insert(result, {})

	local most_active_hour = stats.most_active_hour or 0
	local hour_str = string.format("%02d:00 - %02d:00", most_active_hour, most_active_hour + 1)
	local most_active_day = stats.most_active_day or "N/A"

	table.insert(result, {
		{ "  Most Active Hour: ", "commentfg" },
		{ hour_str, "exgreen" },
	})
	table.insert(result, {
		{ "  Most Active Day: ", "commentfg" },
		{ most_active_day, "exgreen" },
		{ " (" .. format_time(stats.most_active_day_time or 0) .. ")", "commentfg" },
	})
	table.insert(result, {})

	-- Comparisons
	table.insert(result, { { "  📈 Comparisons", "exgreen" } })
	table.insert(result, {})

	-- Today vs Yesterday
	local today_time = stats.today_time or 0
	local yesterday_time = stats.yesterday_time or 0
	local today_trend, today_trend_color = get_trend(today_time, yesterday_time)

	table.insert(result, {
		{ "  Today vs Yesterday: ", "commentfg" },
		{ format_time(today_time), "exgreen" },
		{ " vs ", "commentfg" },
		{ format_time(yesterday_time), "exyellow" },
		{ today_trend, today_trend_color },
	})

	-- This week vs Last week
	local week_time = stats.week_time or 0
	local last_week_time = stats.last_week_time or 0
	local week_trend, week_trend_color = get_trend(week_time, last_week_time)

	table.insert(result, {
		{ "  This Week vs Last: ", "commentfg" },
		{ format_time(week_time), "exgreen" },
		{ " vs ", "commentfg" },
		{ format_time(last_week_time), "exyellow" },
		{ week_trend, week_trend_color },
	})
	table.insert(result, {})

	-- Achievements
	if stats.achievements and #stats.achievements > 0 then
		local achievements_section = build_achievements(stats.achievements)
		vim.list_extend(result, achievements_section)
		table.insert(result, {})
	end

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
			lines = function()
				return voltui.tabs(tab_names, state.win_width, { active = tab_names[state.current_tab] })
			end,
		},
		{
			name = "empty",
			lines = function()
				return { {} }
			end,
		},
		{
			name = "content",
			lines = function()
				if state.current_tab == 1 then
					return today_tab()
				elseif state.current_tab == 2 then
					return weekly_tab()
				elseif state.current_tab == 3 then
					return overview_tab()
				elseif state.current_tab == 4 then
					return insights_tab()
				elseif state.current_tab == 5 then
					return languages_tab()
				else
					return projects_tab()
				end
			end,
		},
		{
			name = "footer",
			lines = function()
				return {
					{ { "  <Tab>: Next | <S-Tab>: Prev | 1-6: Jump | q: Close", "commentfg" } },
				}
			end,
		},
	}
end

-- Helper to safely refresh the dashboard
local function refresh_layout()
	if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
		return
	end

	local ns = vim.api.nvim_create_namespace("codeme")

	-- Make buffer modifiable for clearing
	vim.bo[state.buf].modifiable = true

	-- Clear ALL existing extmarks to prevent ghost content from previous tabs
	vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)

	-- Calculate actual content height for current layout
	local layout = get_layout()
	local total_lines = 0
	for _, section in ipairs(layout) do
		local lines = section.lines()
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

	-- First calculate content height
	local content_height = 0
	for tab = 1, #tab_names do
		state.current_tab = tab
		local tab_content
		if tab == 1 then
			tab_content = today_tab()
		elseif tab == 2 then
			tab_content = weekly_tab()
		elseif tab == 3 then
			tab_content = overview_tab()
		elseif tab == 4 then
			tab_content = insights_tab()
		elseif tab == 5 then
			tab_content = languages_tab()
		else
			tab_content = projects_tab()
		end
		content_height = math.max(content_height, #tab_content)
	end
	state.current_tab = 1

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

	-- Number keys for all 6 tabs
	for i = 1, 6 do
		vim.keymap.set("n", tostring(i), function()
			goto_tab(i)
		end, opts)
	end

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
