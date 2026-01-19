local state = require("codeme.profile.state")
local fmt = require("codeme.profile.formatters")
local helpers = require("codeme.profile.helpers")
local ui = require("codeme.ui")

local M = {}

function M.get_week_boundaries()
	local today_time = os.time()
	local today_weekday = tonumber(os.date("%w", today_time))

	-- Convert Sunday (0) to 7 for ISO 8601
	if today_weekday == 0 then
		today_weekday = 7
	end

	-- Calculate Monday (start of week)
	local days_since_monday = today_weekday - 1
	local monday_time = today_time - (days_since_monday * 86400)
	local monday_date = os.date("%Y-%m-%d", monday_time)

	-- Calculate Sunday (end of week)
	local days_until_sunday = 7 - days_since_monday
	local sunday_time = today_time + (days_until_sunday * 86400)
	local sunday_date = os.date("%Y-%m-%d", sunday_time)

	return monday_date, sunday_date, os.date("%Y-%m-%d", today_time)
end

-- Check if a date is within the current week
function M.is_in_current_week(date_str, monday, sunday)
	return date_str >= monday and date_str <= sunday
end

-- Get date for a specific weekday in current week (1=Monday, 7=Sunday)
function M.get_weekday_date(weekday, monday)
	local monday_time = os.time({
		year = tonumber(monday:sub(1, 4)),
		month = tonumber(monday:sub(6, 7)),
		day = tonumber(monday:sub(9, 10)),
	})

	local days_offset = weekday - 1
	local target_time = monday_time + (days_offset * 86400)
	return os.date("%Y-%m-%d", target_time)
end

function M.render()
	local s = state.stats
	local lines = {}

	-- Header (using backend data)
	local t_trend, t_hl = fmt.trend(s.week_time or 0, s.last_week_time or 0)

	table.insert(lines, {})
	table.insert(lines, {
		{ "  📅 Weekly Summary  ", "exgreen" },
		{ "⏱️  ", "commentfg" },
		{ fmt.fmt_time(s.week_time or 0), "exgreen" },
		{ t_trend, t_hl },
		{ "  │  📝 ", "commentfg" },
		{ fmt.fmt_num(s.week_lines or 0), "exyellow" },
	})
	table.insert(lines, {})

	-- Calculate week boundaries
	local week_monday, week_sunday, today = M.get_week_boundaries()

	-- Daily Breakdown Table (using backend daily_activity)
	local daily_activity = s.daily_activity or {}

	table.insert(lines, { { "  📊 Daily Breakdown (Mon-Sun)", "exgreen" } })
	table.insert(lines, {})

	local day_names = { "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" }
	local tbl = { { "Day", "Date", "Time", "Lines", "Session count", "Trend" } }

	local max_day_time = 0
	local max_day_data = nil

	for i = 1, 7 do -- 1=Monday, 7=Sunday
		local day_name = day_names[i]

		-- Calculate the actual date for this weekday in current week
		local expected_date = M.get_weekday_date(i, week_monday)

		-- Find daily stat for this date
		local day_stat = daily_activity[expected_date]

		if not day_stat then
			day_stat = { time = 0, lines = 0, sessions = 0, session_count = 0 }
		end

		if day_stat.time > max_day_time then
			max_day_time = day_stat.time
			max_day_data = {
				day_name = day_name,
				date = expected_date,
				time = day_stat.time,
				lines = day_stat.lines or 0,
				sessions = day_stat.sessions or day_stat.session_count or 0,
			}
		end

		local day_label = day_name:sub(1, 3)
		local date_label = expected_date:sub(6, 10) -- MM-DD format
		local time_str = fmt.fmt_time(day_stat.time)
		local lines_str = fmt.fmt_num(day_stat.lines or 0)
		local sessions_str = tostring(day_stat.session_count or day_stat.sessions or 0)
		local trend_str = day_stat.time > 0 and "↗" or "-"

		-- Mark today with a star
		if expected_date == today then
			day_label = day_label .. " ★"
		end

		-- Show "-" for future dates (after today)
		if expected_date > today then
			time_str = "-"
			lines_str = "-"
			sessions_str = "-"
			trend_str = "-"
		end

		tbl[#tbl + 1] = {
			day_label,
			date_label,
			time_str,
			lines_str,
			sessions_str,
			trend_str,
		}
	end

	for _, l in ipairs(ui.table(tbl, state.width - 8)) do
		table.insert(lines, l)
	end

	table.insert(lines, {})

	-- 📌 Week Summary (using backend records data)
	table.insert(lines, { { "  📌 Week Summary", "exgreen" } })
	table.insert(lines, {})

	-- Most Productive Day (from backend records)
	local records = s.records or {}
	local most_productive_day = records.most_productive_day or {}

	if most_productive_day.time and most_productive_day.time > 0 then
		table.insert(lines, {
			{ "  • Most Productive: ", "commentfg" },
			{ most_productive_day.weekday or "Unknown", "exgreen" },
			{ ", " .. fmt.fmt_date_full(most_productive_day.date or ""), "commentfg" },
			{ string.format(" (%s)", fmt.fmt_time(most_productive_day.time)), "exyellow" },
		})

		-- Session details for best day
		if most_productive_day.sessions and most_productive_day.sessions > 0 then
			table.insert(lines, {
				{ "    ↳ Sessions: ", "commentfg" },
				{ tostring(most_productive_day.sessions), "exgreen" },
				{ string.format(", %s lines", fmt.fmt_num(most_productive_day.lines or 0)), "commentfg" },
			})
		end

		-- Top languages for best day (from backend)
		local languages_count = helpers.safe_length(most_productive_day.languages)
		if most_productive_day.languages and languages_count > 0 then
			local languages_result = helpers.format_list(most_productive_day.languages)
			table.insert(lines, {
				{ "    ↳ Languages: ", "commentfg" },
				{ languages_result, "exgreen" },
			})
		end

		-- Main projects for best day (from backend)
		local projects_count = helpers.safe_length(most_productive_day.projects)
		if most_productive_day.projects and projects_count > 0 then
			local projects_result = helpers.format_list(most_productive_day.projects)
			table.insert(lines, {
				{ "    ↳ Projects: ", "commentfg" },
				{ projects_result, "exyellow" },
			})
		end

		table.insert(lines, {})
	elseif max_day_data and max_day_time > 0 then
		-- Fallback to calculated data if backend records not available
		table.insert(lines, {
			{ "  • Most Productive: ", "commentfg" },
			{ max_day_data.day_name, "exgreen" },
			{ string.format(" (%s)", fmt.fmt_time(max_day_data.time)), "exyellow" },
		})
		table.insert(lines, {})
	end

	-- Daily Average (calculated from backend data)
	local daily_avg = s.week_time and math.floor((s.week_time or 0) / 7) or 0
	table.insert(lines, {
		{ "  • Daily Average: ", "commentfg" },
		{ fmt.fmt_time(daily_avg), "exgreen" },
		{ " (over 7 days)", "commentfg" },
	})

	-- Coding Days (from backend streak info)
	local streak_info = s.streak_info or {}
	local weekly_pattern = streak_info.weekly_pattern or {}
	local days_coded = 0

	for i = 1, 7 do
		if weekly_pattern[i] then
			days_coded = days_coded + 1
		end
	end

	if days_coded == 0 then
		for date, stat in pairs(daily_activity) do
			if M.is_in_current_week(date, week_monday, week_sunday) and stat.time and stat.time > 0 then
				days_coded = days_coded + 1
			end
		end
		days_coded = math.min(days_coded, 7) -- Cap at 7 for this week
	end

	local consistency_pct = math.floor((days_coded / 7) * 100)
	table.insert(lines, {
		{ "  • Coding Days: ", "commentfg" },
		{ string.format("%d/7", days_coded), "exgreen" },
		{ string.format(" (%d%% consistency)", consistency_pct), "commentfg" },
	})

	-- vs Last Week (using backend data)
	if s.last_week_time and s.last_week_time > 0 then
		local week_diff = (s.week_time or 0) - s.last_week_time
		local week_trend_str = week_diff > 0 and "↑" or week_diff < 0 and "↓" or "→"
		local week_trend_hl = week_diff > 0 and "exgreen" or week_diff < 0 and "exred" or "commentfg"

		table.insert(lines, {
			{ "  • vs Last Week: ", "commentfg" },
			{ week_trend_str, week_trend_hl },
			{ string.format(" %s", fmt.fmt_time(math.abs(week_diff))), week_trend_hl },
			{
				string.format(" (%s → %s)", fmt.fmt_time(s.last_week_time), fmt.fmt_time(s.week_time or 0)),
				"commentfg",
			},
		})
	end

	table.insert(lines, {})

	-- Weekly Pattern
	table.insert(lines, { { "  📈 Weekly Pattern", "exgreen" } })
	table.insert(lines, {})

	-- Weekday vs Weekend (from backend weekday_pattern)
	local weekday_time = 0
	local weekend_time = 0
	for i = 1, 7 do
		local weekday_date = M.get_weekday_date(i, week_monday) -- Get exact date this week
		local day_stat = daily_activity[weekday_date] -- Get data for that specific date

		if day_stat and day_stat.time then
			if i <= 5 then -- Mon-Fri
				weekday_time = weekday_time + day_stat.time
			else -- Sat-Sun
				weekend_time = weekend_time + day_stat.time
			end
		end
	end

	local total_week_time = weekday_time + weekend_time
	if total_week_time > 0 then
		local weekday_pct = math.floor((weekday_time / total_week_time) * 100)
		local weekend_pct = math.floor((weekend_time / total_week_time) * 100)

		table.insert(lines, {
			{ "  • Weekday Coder: ", "commentfg" },
			{ string.format("%d%%", weekday_pct), "exgreen" },
			{ string.format(" of time Mon-Fri (%s)", fmt.fmt_time(weekday_time)), "commentfg" },
		})

		table.insert(lines, {
			{ "  • Weekend Coder: ", "commentfg" },
			{ string.format("%d%%", weekend_pct), weekend_pct >= 20 and "exgreen" or "exyellow" },
			{ string.format(" of time Sat-Sun (%s)", fmt.fmt_time(weekend_time)), "commentfg" },
		})
	end

	-- Most Active Day (from backend)
	if max_day_data and max_day_time > 0 then
		table.insert(lines, {
			{ "  • Best Day: ", "commentfg" },
			{ max_day_data.day_name, "exgreen" },
			{ string.format(" (%s)", fmt.fmt_time(max_day_data.time)), "exyellow" },
		})
	end

	-- Productivity Trend (from backend)
	local productivity_trend = s.productivity_trend or ""
	if productivity_trend ~= "" then
		table.insert(lines, {
			{ "  • Trend: ", "commentfg" },
			{ productivity_trend, "exgreen" },
		})
	end

	table.insert(lines, {})

	-- Heatmap (using backend weekly_heatmap)
	local hm = s.weekly_heatmap
	if hm and #hm > 0 then
		for _, l in ipairs(ui.heatmap(hm)) do
			table.insert(lines, l)
		end
	end

	return lines
end

return M
