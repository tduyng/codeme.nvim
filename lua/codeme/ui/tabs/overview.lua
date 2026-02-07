local util = require("codeme.util")
local renderer = require("codeme.ui.renderer")

local M = {}

function M.render(stats)
	local lines = {}
	local today = stats.today or {}
	local today_time = today.total_time or 0
	local today_lines = today.total_lines or 0
	local focus_score = today.focus_score or 0

	-- Hero section
	local hour = tonumber(os.date("%H"))
	local daily_goals = stats.daily_goals or {}
	local daily_goal_time = daily_goals.time_goal or 14400
	local daily_goal_lines = daily_goals.lines_goal or 500

	local progress_pct = 0
	if daily_goal_time > 0 and today_time > 0 then
		progress_pct = math.floor((today_time / daily_goal_time) * 100)
	end

	local hero_msg, hero_icon, hero_color
	if progress_pct >= 100 then
		hero_msg, hero_icon, hero_color = "GOAL CRUSHED! 🎉", "🏆", "exgreen"
	elseif progress_pct >= 75 then
		hero_msg, hero_icon, hero_color = "On Fire Today!", "🔥", "exgreen"
	elseif progress_pct >= 50 then
		hero_msg, hero_icon, hero_color = "Great Progress!", "⭐", "exyellow"
	elseif today_time > 0 then
		hero_msg, hero_icon, hero_color = "Keep Going!", "💪", "exgreen"
	else
		local greeting = hour < 12 and "Rise & Code" or hour < 18 and "Code Time" or "Night Session"
		hero_msg, hero_icon, hero_color = greeting, "🌟", "commentfg"
	end

	table.insert(lines, {})
	table.insert(lines, {
		{ "  ", "commentfg" },
		{ hero_icon .. "  " .. hero_msg, hero_color },
		{ string.rep(" ", 45 - #hero_msg), "commentfg" },
		{ os.date("%a, %b %d"), "exyellow" },
	})
	table.insert(lines, {})

	-- Quick metrics table
	local focus_str = focus_score > 0 and tostring(focus_score) .. "/100" or "─"
	local metrics_tbl = {
		{ "⏰ Time", "📝 Lines", "🎯 Focus" },
		{ util.format_duration(today_time), util.format_number(today_lines), focus_str },
	}

	for _, l in ipairs(renderer.table(metrics_tbl, 120)) do
		table.insert(lines, l)
	end
	table.insert(lines, {})

	-- Goal progress
	if daily_goal_time > 0 or daily_goal_lines > 0 then
		table.insert(lines, { { "  🎯 Today's Goals", "exgreen" } })
		table.insert(lines, {})

		if daily_goal_time > 0 then
			local time_pct = today_time > 0 and math.floor((today_time / daily_goal_time) * 100) or 0
			local display_pct = math.min(100, time_pct)
			local goal_hl = time_pct >= 100 and "exgreen" or time_pct >= 75 and "exyellow" or "exblue"

			local time_goal_line = { { "  ⏰ ", "commentfg" } }
			for _, seg in ipairs(renderer.progress(display_pct, 25, goal_hl)) do
				table.insert(time_goal_line, seg)
			end
			table.insert(time_goal_line, { string.format(" %d%%", time_pct), goal_hl })
			table.insert(time_goal_line, {
				string.format("  %s / %s", util.format_duration(today_time), util.format_duration(daily_goal_time)),
				"commentfg",
			})
			table.insert(lines, time_goal_line)
		end

		if daily_goal_lines > 0 then
			local lines_pct = today_lines > 0 and math.floor((today_lines / daily_goal_lines) * 100) or 0
			local display_pct = math.min(100, lines_pct)
			local lines_hl = lines_pct >= 100 and "exgreen" or lines_pct >= 75 and "exyellow" or "exblue"

			local lines_goal_line = { { "  📝 ", "commentfg" } }
			for _, seg in ipairs(renderer.progress(display_pct, 25, lines_hl)) do
				table.insert(lines_goal_line, seg)
			end
			table.insert(lines_goal_line, { string.format(" %d%%", lines_pct), lines_hl })
			table.insert(lines_goal_line, {
				string.format("  %s / %s", util.format_number(today_lines), util.format_number(daily_goal_lines)),
				"commentfg",
			})
			table.insert(lines, lines_goal_line)
		end

		local time_pct = today_time > 0 and math.floor((today_time / daily_goal_time) * 100) or 0
		local goal_pct = math.min(100, time_pct)
		local goal_hl = goal_pct >= 100 and "exgreen" or goal_pct >= 75 and "exyellow" or "exblue"
		local status_msg
		if goal_pct >= 100 then
			status_msg = "🏆 Goal achieved! You're a productivity beast!"
		elseif goal_pct >= 75 then
			status_msg = "🔥 Almost there! Push to 100%"
		elseif goal_pct >= 50 then
			status_msg = "💪 Halfway there - keep the momentum"
		elseif goal_pct > 0 then
			local remaining = daily_goal_time - today_time
			status_msg = "🚀 Great start - " .. util.format_duration(remaining) .. " to go"
		else
			status_msg = "💡 Goal: " .. util.format_duration(daily_goal_time) .. " - Let's begin!"
		end

		table.insert(lines, {})
		table.insert(lines, { { "  ", "commentfg" }, { status_msg, goal_hl } })
		table.insert(lines, {})
	end

	-- Streak visualization
	table.insert(lines, { { "  🔥 Streak Power", "exgreen" } })
	table.insert(lines, {})

	local streak_info = stats.streak_info or {}
	local current_streak = streak_info.current or 0
	local longest_streak = streak_info.longest or 0
	local flame_display, streak_hl

	if current_streak >= 30 then
		flame_display, streak_hl = "🔥🔥🔥🔥🔥", "exgreen"
	elseif current_streak >= 21 then
		flame_display, streak_hl = "🔥🔥🔥🔥", "exgreen"
	elseif current_streak >= 14 then
		flame_display, streak_hl = "🔥🔥🔥", "exgreen"
	elseif current_streak >= 7 then
		flame_display, streak_hl = "🔥🔥", "exyellow"
	elseif current_streak > 0 then
		flame_display, streak_hl = "🔥", "exyellow"
	else
		flame_display, streak_hl = "💤", "commentfg"
	end

	table.insert(lines, {
		{ "  " .. flame_display .. "  ", "normal" },
		{ string.format("%d DAY%s", current_streak, current_streak == 1 and "" or "S"), streak_hl },
		{
			longest_streak > current_streak and string.format("  •  Record: %d days", longest_streak)
				or (current_streak > 0 and "  •  NEW RECORD!" or ""),
			"commentfg",
		},
	})
	table.insert(lines, {})

	-- Week pattern
	local daily_activity = stats.daily_activity or {}
	local days_with_activity = {}
	local now = os.date("*t")
	local iso_wday = now.wday == 1 and 7 or now.wday - 1
	local monday_time = os.time({
		year = now.year,
		month = now.month,
		day = now.day - (iso_wday - 1),
		hour = 0,
		min = 0,
		sec = 0,
	})

	for i = 0, 6 do
		local day_time = monday_time + i * 86400
		local day_date = os.date("%Y-%m-%d", day_time)
		local entry = daily_activity[day_date]
		local has_activity = entry ~= nil and entry.time and entry.time > 0
		if day_time > os.time() then
			has_activity = false
		end
		days_with_activity[#days_with_activity + 1] = has_activity
	end

	local pattern_line = { { "  This week:  ", "commentfg" } }
	for i = 1, 7 do
		local char = days_with_activity[i] and "●" or "○"
		local hl = days_with_activity[i] and "exgreen" or "commentfg"
		table.insert(pattern_line, { char .. " ", hl })
	end
	table.insert(lines, pattern_line)

	local label_line = { { "              ", "commentfg" } }
	for _, label in ipairs({ "M", "T", "W", "T", "F", "S", "S" }) do
		table.insert(label_line, { label .. " ", "commentfg" })
	end
	table.insert(lines, label_line)
	table.insert(lines, {})

	-- Performance comparison
	table.insert(lines, { { "  📊 Performance", "exgreen" } })
	table.insert(lines, {})

	local yesterday = stats.yesterday or {}
	local this_week = stats.this_week or {}
	local last_week = stats.last_week or {}
	local yesterday_time = yesterday.total_time or 0
	local week_time = this_week.total_time or 0
	local last_week_time = last_week.total_time or 0

	local comparison_data = {}
	if today_time > 0 or yesterday_time > 0 then
		if yesterday_time == 0 then
			table.insert(comparison_data, {
				"vs Yesterday",
				util.format_duration(today_time),
				util.format_duration(0),
				"↑ New",
			})
		else
			local diff = today_time - yesterday_time
			local diff_pct = math.floor((math.abs(diff) / yesterday_time) * 100)
			local status = diff >= 0 and "↑" or "↓"
			table.insert(comparison_data, {
				"vs Yesterday",
				util.format_duration(today_time),
				util.format_duration(yesterday_time),
				string.format("%s %d%%", status, diff_pct),
			})
		end
	end

	if week_time > 0 or last_week_time > 0 then
		if last_week_time == 0 then
			table.insert(comparison_data, {
				"vs Last Week",
				util.format_duration(week_time),
				util.format_duration(0),
				"↑ New",
			})
		else
			local diff = week_time - last_week_time
			local diff_pct = math.floor((math.abs(diff) / last_week_time) * 100)
			local status = diff >= 0 and "↑" or "↓"
			table.insert(comparison_data, {
				"vs Last Week",
				util.format_duration(week_time),
				util.format_duration(last_week_time),
				string.format("%s %d%%", status, diff_pct),
			})
		end
	end

	if #comparison_data > 0 then
		local comp_tbl = { { "Period", "Now", "Before", "Change" } }
		for _, comp in ipairs(comparison_data) do
			table.insert(comp_tbl, comp)
		end
		for _, l in ipairs(renderer.table(comp_tbl, 120)) do
			table.insert(lines, l)
		end
		table.insert(lines, {})
	end

	return lines
end

return M
