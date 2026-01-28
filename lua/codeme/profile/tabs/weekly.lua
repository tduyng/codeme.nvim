local state = require("codeme.profile.state")
local fmt = require("codeme.profile.formatters")
local ui = require("codeme.ui")
local helpers = require("codeme.profile.helpers")

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
	local globalStats = state.stats
	local lines = {}

	local this_week = globalStats.this_week or {}
	local last_week = globalStats.last_week or {}

	local week_time = this_week.total_time or 0
	local last_week_time = last_week.total_time or 0
	local week_lines = this_week.total_lines or 0

	-- Header
	local t_trend, t_hl = fmt.trend(week_time, last_week_time)

	table.insert(lines, {})
	table.insert(lines, {
		{ "  📅 Weekly Summary  ", "exgreen" },
		{ "⏱️  ", "commentfg" },
		{ fmt.fmt_time(week_time), "exgreen" },
		{ t_trend, t_hl },
		{ "  │  📝 ", "commentfg" },
		{ fmt.fmt_num(week_lines), "exyellow" },
	})
	table.insert(lines, {})

	-- Calculate week boundaries
	local week_monday, week_sunday, today = M.get_week_boundaries()

	local daily_activity = globalStats.daily_activity or {}

	table.insert(lines, { { "  📊 Daily Breakdown (Mon-Sun)", "exgreen" } })
	table.insert(lines, {})

	local day_names = { "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" }
	local tbl = { { "Day", "Date", "Time", "Lines", "Sessions", "Trend" } }

	local max_day_time = 0
	local max_day_data = nil

	for i = 1, 7 do -- 1=Monday, 7=Sunday
		local day_name = day_names[i]
		local expected_date = M.get_weekday_date(i, week_monday)

		local day_stat = daily_activity[expected_date]

		if not day_stat then
			day_stat = { time = 0, lines = 0, files = 0 }
		end

		local session_count = day_stat.session_count or 0
		local time_value = day_stat.time or 0
		local lines_value = day_stat.lines or 0
		local has_activity = time_value > 0 or lines_value > 0 or session_count > 0

		if time_value > max_day_time then
			max_day_time = time_value
			max_day_data = {
				day_name = day_name,
				date = expected_date,
				time = time_value,
				lines = lines_value,
				sessions = session_count,
			}
		end

		local day_label = day_name:sub(1, 3)
		local date_str = tostring(expected_date)
		local date_label = date_str:sub(6, 10) -- MM-DD

		local time_str = has_activity and fmt.fmt_time(time_value) or "-"
		local lines_str = has_activity and fmt.fmt_num(lines_value) or "-"
		local sessions_str = has_activity and tostring(session_count) or "-"
		local trend_str = time_value > 0 and "↗" or "-"

		if expected_date == today then
			day_label = day_label .. " ★"
		end

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

	-- 📌 Week Summary
	table.insert(lines, { { "  📌 Week Summary", "exgreen" } })
	table.insert(lines, {})

	local most_productive_day = globalStats.this_week.most_productive_day or {}

	if most_productive_day.time and most_productive_day.time > 0 then
		table.insert(lines, {
			{ "  • Most Productive: ", "commentfg" },
			{ most_productive_day.weekday or "", "exgreen" },
			{ ", " .. fmt.fmt_date_full(most_productive_day.date or ""), "commentfg" },
			{ string.format(" (%s)", fmt.fmt_time(most_productive_day.time)), "exyellow" },
		})

		-- Session details
		if most_productive_day.session_count and most_productive_day.session_count > 0 then
			table.insert(lines, {
				{ "    ↳ Sessions: ", "commentfg" },
				{ tostring(most_productive_day.session_count), "exgreen" },
				{ string.format(", %s lines", fmt.fmt_num(most_productive_day.lines or 0)), "commentfg" },
			})
		end

		-- Main projects
		if most_productive_day.projects and #most_productive_day.projects > 0 then
			local projects_result = helpers.top_items(most_productive_day.projects, 3)
			table.insert(lines, {
				{ "    ↳ Projects: ", "commentfg" },
				{ projects_result, "exyellow" },
			})
		end

		-- Top languages
		if most_productive_day.languages and #most_productive_day.languages > 0 then
			local languages_result = helpers.top_items(most_productive_day.languages, 5)
			table.insert(lines, {
				{ "    ↳ Languages: ", "commentfg" },
				{ languages_result, "exgreen" },
			})
		end

		table.insert(lines, {})
	elseif max_day_data and max_day_time > 0 then
		table.insert(lines, {
			{ "  • Most Productive: ", "commentfg" },
			{ max_day_data.day_name, "exgreen" },
			{ string.format(" (%s)", fmt.fmt_time(max_day_data.time)), "exyellow" },
		})
		table.insert(lines, {})
	end

	-- Daily Average
	local daily_avg = week_time > 0 and math.floor(week_time / 7) or 0
	table.insert(lines, {
		{ "  • Daily Average: ", "commentfg" },
		{ fmt.fmt_time(daily_avg), "exgreen" },
		{ " (over 7 days)", "commentfg" },
	})

	-- ✅ Coding Days (count days with activity)
	local days_coded = 0
	for date, stat in pairs(daily_activity) do
		if M.is_in_current_week(date, week_monday, week_sunday) and stat.time and stat.time > 0 then
			days_coded = days_coded + 1
		end
	end

	local consistency_pct = math.floor((days_coded / 7) * 100)
	table.insert(lines, {
		{ "  • Coding Days: ", "commentfg" },
		{ string.format("%d/7", days_coded), "exgreen" },
		{ string.format(" (%d%% consistency)", consistency_pct), "commentfg" },
	})

	-- vs Last Week
	if last_week_time > 0 then
		local week_diff = week_time - last_week_time
		local week_trend_str = week_diff > 0 and "↑" or week_diff < 0 and "↓" or "→"
		local week_trend_hl = week_diff > 0 and "exgreen" or week_diff < 0 and "exred" or "commentfg"

		table.insert(lines, {
			{ "  • vs Last Week: ", "commentfg" },
			{ week_trend_str, week_trend_hl },
			{ string.format(" %s", fmt.fmt_time(math.abs(week_diff))), week_trend_hl },
			{
				string.format(" (%s → %s)", fmt.fmt_time(last_week_time), fmt.fmt_time(week_time)),
				"commentfg",
			},
		})
	end

	table.insert(lines, {})

	-- Weekly Pattern
	table.insert(lines, { { "  📈 Weekly Pattern", "exgreen" } })
	table.insert(lines, {})

	-- ✅ Weekday vs Weekend (from daily_activity)
	local weekday_time = 0
	local weekend_time = 0

	for i = 1, 7 do
		local weekday_date = M.get_weekday_date(i, week_monday)
		local day_stat = daily_activity[weekday_date]

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

	-- Most Active Day
	if max_day_data and max_day_time > 0 then
		table.insert(lines, {
			{ "  • Best Day: ", "commentfg" },
			{ max_day_data.day_name, "exgreen" },
			{ string.format(" (%s)", fmt.fmt_time(max_day_data.time)), "exyellow" },
		})
	end

	-- ✅ Productivity Trend (from backend)
	local productivity_trend = globalStats.productivity_trend or ""
	if productivity_trend ~= "" then
		local trend_text
		local trend_color

		if productivity_trend == "increasing" then
			trend_text = "📈 Increasing"
			trend_color = "exgreen"
		elseif productivity_trend == "decreasing" then
			trend_text = "📉 Decreasing"
			trend_color = "exyellow"
		else
			trend_text = "➡️  Stable"
			trend_color = "exblue"
		end

		table.insert(lines, {
			{ "  • Trend: ", "commentfg" },
			{ trend_text, trend_color },
		})
	end

	table.insert(lines, {})

	-- ✅ Heatmap (from backend weekly_heatmap)
	local hm = globalStats.weekly_heatmap
	if hm and #hm > 0 then
		table.insert(lines, { { "  📅 Activity Heatmap", "exgreen" } })
		table.insert(lines, {})
		for _, l in ipairs(ui.heatmap(hm)) do
			table.insert(lines, l)
		end
		table.insert(lines, {})
	end

	return lines
end

return M
