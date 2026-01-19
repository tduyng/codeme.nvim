local state = require("codeme.profile.state")
local fmt = require("codeme.profile.formatters")
local ui = require("codeme.ui")

local M = {}

function M.render()
	local s = state.stats
	local lines = {}

	-- DYNAMIC HERO SECTION
	local hour = tonumber(os.date("%H"))
	local today_time = s.today_time or 0
	local current_streak = s.streak_info and s.streak_info.current or s.streak or 0

	-- Get daily goals
	local daily_goals = s.daily_goals or {}
	local daily_goal_time = daily_goals.time_goal or 14400
	local daily_goal_lines = daily_goals.lines_goal or 500

	-- Calculate progress percentage correctly
	local progress_pct = 0
	if daily_goal_time > 0 and today_time > 0 then
		progress_pct = math.floor((today_time / daily_goal_time) * 100)
	end

	-- Dynamic status based on today's progress
	local hero_msg, hero_icon, hero_color

	if progress_pct >= 100 then
		hero_msg, hero_icon, hero_color = "GOAL CRUSHED! 🎉", "🏆", "exgreen"
	elseif progress_pct >= 75 then
		hero_msg, hero_icon, hero_color = "On Fire Today!", "🔥", "exgreen"
	elseif progress_pct >= 50 then
		hero_msg, hero_icon, hero_color = "Great Progress!", "⭐", "exyellow"
	elseif today_time > 0 then
		hero_msg, hero_icon, hero_color = "Keep Going!", "💪", "exblue"
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

	-- TODAY AT A GLANCE
	local today_lines = s.today_lines or 0
	-- local today_files = s.today_files or 0
	local focus_score = s.focus_score or 0

	local focus_str = focus_score > 0 and tostring(focus_score) .. "/100" or "N/A"

	-- Create metrics table
	local metrics_tbl = {
		{ "⏰ Time", "📝 Lines", "🎯 Focus" },
		{ fmt.fmt_time(today_time), fmt.fmt_num(today_lines), focus_str },
	}

	for _, l in ipairs(ui.table(metrics_tbl, state.width - 8)) do
		table.insert(lines, l)
	end
	table.insert(lines, {})

	-- GOAL PROGRESS
	local today_lines = s.today_lines or 0

	if daily_goal_time > 0 or daily_goal_lines > 0 then
		table.insert(lines, { { "  🎯 Today's Goals", "exgreen" } })
		table.insert(lines, {})

		if daily_goal_time > 0 then
			local time_pct = 0
			if today_time > 0 then
				time_pct = math.floor((today_time / daily_goal_time) * 100)
			end

			local display_pct = math.min(100, time_pct)
			local goal_hl = time_pct >= 100 and "exgreen" or time_pct >= 75 and "exyellow" or "exblue"

			local time_goal_line = { { "  ⏰ ", "commentfg" } }
			for _, seg in ipairs(ui.progress(display_pct, 25, goal_hl)) do
				table.insert(time_goal_line, seg)
			end
			table.insert(time_goal_line, { string.format(" %d%%", time_pct), goal_hl })
			table.insert(time_goal_line, {
				string.format("  %s / %s", fmt.fmt_time(today_time), fmt.fmt_time(daily_goal_time)),
				"commentfg",
			})
			table.insert(lines, time_goal_line)
		end

		-- LINES GOAL
		if daily_goal_lines > 0 then
			local lines_pct = 0
			if today_lines > 0 then
				lines_pct = math.floor((today_lines / daily_goal_lines) * 100)
			end
			local display_pct = math.min(100, lines_pct)
			local lines_hl = lines_pct >= 100 and "exgreen" or lines_pct >= 75 and "exyellow" or "exblue"

			local lines_goal_line = { { "  📝 ", "commentfg" } }
			for _, seg in ipairs(ui.progress(display_pct, 25, lines_hl)) do
				table.insert(lines_goal_line, seg)
			end
			table.insert(lines_goal_line, { string.format(" %d%%", lines_pct), lines_hl })
			table.insert(lines_goal_line, {
				string.format("  %s / %s", fmt.fmt_num(today_lines), fmt.fmt_num(daily_goal_lines)),
				"commentfg",
			})
			table.insert(lines, lines_goal_line)
		end

		-- Goal status message (based on time goal)
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
			status_msg = "🚀 Great start - " .. fmt.fmt_time(remaining) .. " to go"
		else
			status_msg = "💡 Goal: " .. fmt.fmt_time(daily_goal_time) .. " - Let's begin!"
		end

		table.insert(lines, {})
		table.insert(lines, {
			{ "  ", "commentfg" },
			{ status_msg, goal_hl },
		})
		table.insert(lines, {})
	end

	-- STREAK VISUALIZATION
	table.insert(lines, { { "  🔥 Streak Power", "exgreen" } })
	table.insert(lines, {})

	local longest_streak = s.streak_info and s.streak_info.longest or s.longest_streak or 0

	-- Visual flame meter based on streak
	local flame_display = ""
	local streak_hl = "commentfg"

	if current_streak >= 30 then
		flame_display = "🔥🔥🔥🔥🔥"
		streak_hl = "exgreen"
	elseif current_streak >= 21 then
		flame_display = "🔥🔥🔥🔥"
		streak_hl = "exgreen"
	elseif current_streak >= 14 then
		flame_display = "🔥🔥🔥"
		streak_hl = "exgreen"
	elseif current_streak >= 7 then
		flame_display = "🔥🔥"
		streak_hl = "exyellow"
	elseif current_streak > 0 then
		flame_display = "🔥"
		streak_hl = "exyellow"
	else
		flame_display = "💤"
		streak_hl = "commentfg"
	end

	table.insert(lines, {
		{ "  " .. flame_display .. "  ", "normal" },
		{ string.format("%d DAY%s", current_streak, current_streak == 1 and "" or "S"), streak_hl },
		{
			longest_streak > current_streak and string.format("  •  Record: %d days", longest_streak)
				or "  •  NEW RECORD!",
			"commentfg",
		},
	})

	-- Weekly pattern with visual dots
	local weekly_pattern = s.streak_info and s.streak_info.weekly_pattern or {}
	if #weekly_pattern >= 7 then
		table.insert(lines, {})

		local pattern_line = { { "  This week:  ", "commentfg" } }
		for i = 1, 7 do
			local day_char = weekly_pattern[i] and "●" or "○"
			local day_hl = weekly_pattern[i] and "exgreen" or "commentfg"
			table.insert(pattern_line, { day_char .. " ", day_hl })
		end
		table.insert(lines, pattern_line)

		local label_line = { { "              ", "commentfg" } }
		for _, label in ipairs({ "M", "T", "W", "T", "F", "S", "S" }) do
			table.insert(label_line, { label .. " ", "commentfg" })
		end
		table.insert(lines, label_line)
	end

	table.insert(lines, {})

	-- PERFORMANCE COMPARISON (Visual vs yesterday/week)
	table.insert(lines, { { "  📊 Performance", "exgreen" } })
	table.insert(lines, {})

	local yesterday_time = s.yesterday_time or 0
	local week_time = s.week_time or 0
	local last_week_time = s.last_week_time or 0

	local comparison_data = {}

	-- Today vs Yesterday
	if yesterday_time > 0 then
		local diff = today_time - yesterday_time
		local diff_pct = math.floor((diff / yesterday_time) * 100)
		local status = diff >= 0 and "↑" or "↓"
		local status_hl = diff >= 0 and "exgreen" or "exred"

		table.insert(comparison_data, {
			label = "vs Yesterday",
			current = fmt.fmt_time(today_time),
			previous = fmt.fmt_time(yesterday_time),
			trend = string.format("%s %d%%", status, math.abs(diff_pct)),
			trend_hl = status_hl,
		})
	end

	-- This Week vs Last Week
	if last_week_time > 0 then
		local week_diff = week_time - last_week_time
		local week_diff_pct = math.floor((week_diff / last_week_time) * 100)
		local week_status = week_diff >= 0 and "↑" or "↓"
		local week_status_hl = week_diff >= 0 and "exgreen" or "exred"

		table.insert(comparison_data, {
			label = "vs Last Week",
			current = fmt.fmt_time(week_time),
			previous = fmt.fmt_time(last_week_time),
			trend = string.format("%s %d%%", week_status, math.abs(week_diff_pct)),
			trend_hl = week_status_hl,
		})
	end

	-- Display comparisons
	if #comparison_data > 0 then
		local comp_tbl = { { "Period", "Now", "Before", "Change" } }
		for _, comp in ipairs(comparison_data) do
			table.insert(comp_tbl, {
				comp.label,
				comp.current,
				comp.previous,
				comp.trend,
			})
		end

		for _, l in ipairs(ui.table(comp_tbl, state.width - 8)) do
			table.insert(lines, l)
		end
		table.insert(lines, {})
	end

	-- LIVE HIGHLIGHTS
	table.insert(lines, { { "  🌟 Live Highlights", "exgreen" } })
	table.insert(lines, {})

	local programming_languages = s.programming_languages or {}
	local top_lang = nil
	local top_lang_time = 0

	for lang, stat in pairs(programming_languages) do
		local lang_time = stat.time or 0
		if lang_time > top_lang_time then
			top_lang = lang
			top_lang_time = lang_time
		end
	end

	-- Top language with badge
	if top_lang then
		local lang_stat = programming_languages[top_lang]
		local badge = ""
		if lang_stat.trending then
			badge = " 🔥 TRENDING"
		elseif lang_stat.proficiency == "Expert" or lang_stat.proficiency == "Master" then
			badge = " 🏆 EXPERT"
		end

		table.insert(lines, {
			{ "  💎 ", "normal" },
			{ top_lang, "exgreen" },
			{ badge, "exyellow" },
		})
	end

	-- Peak productivity time
	local peak_hours = s.peak_hours or {}
	if #peak_hours > 0 then
		local peak_time = string.format("%02d:00-%02d:00", peak_hours[1], peak_hours[1] + 1)
		local is_peak_now = hour >= peak_hours[1] and hour < peak_hours[1] + 1

		table.insert(lines, {
			{ "  ⚡ Peak: ", "commentfg" },
			{ peak_time, "exyellow" },
			{ is_peak_now and "  ← NOW!" or "", "exgreen" },
		})
	end

	-- Productivity status
	local productivity_trend = s.productivity_trend or ""
	if productivity_trend ~= "" then
		table.insert(lines, {
			{ "  📈 ", "normal" },
			{ productivity_trend, "exgreen" },
		})
	end

	table.insert(lines, {})

	-- MOTIVATION ZONE
	table.insert(lines, { { "  💪 Motivation", "exgreen" } })
	table.insert(lines, {})

	local motivations = {}

	-- Goal-based motivation
	if progress_pct >= 100 then
		table.insert(motivations, { icon = "🎉", text = "You've crushed today's goal - LEGEND!", color = "exgreen" })
	elseif progress_pct >= 50 then
		local remaining = daily_goal_time - today_time
		table.insert(motivations, {
			icon = "🎯",
			text = "Just " .. fmt.fmt_time(remaining) .. " more to hit your goal!",
			color = "exyellow",
		})
	end

	-- Streak motivation
	if current_streak > 0 and current_streak < 7 then
		table.insert(motivations, {
			icon = "🔥",
			text = string.format(
				"%d more day%s to your first week!",
				7 - current_streak,
				7 - current_streak == 1 and "" or "s"
			),
			color = "exyellow",
		})
	elseif current_streak >= 7 and current_streak < 30 then
		table.insert(motivations, {
			icon = "🚀",
			text = "You're on fire! Don't break the chain!",
			color = "exgreen",
		})
	elseif current_streak >= 30 then
		table.insert(motivations, {
			icon = "👑",
			text = "LEGENDARY STREAK! You're unstoppable!",
			color = "exgreen",
		})
	end

	-- Record chasing
	local records = s.records or {}
	local most_productive_day = records.most_productive_day or {}
	if most_productive_day.time and most_productive_day.time > today_time and today_time > 0 then
		local gap = most_productive_day.time - today_time
		if gap < 3600 then -- Within 1 hour of record
			table.insert(motivations, {
				icon = "🏆",
				text = fmt.fmt_time(gap) .. " from your record - GO FOR IT!",
				color = "exyellow",
			})
		end
	end

	-- Display motivations
	if #motivations > 0 then
		for _, m in ipairs(motivations) do
			table.insert(lines, {
				{ "  " .. m.icon .. "  ", "normal" },
				{ m.text, m.color },
			})
		end
	else
		local default_motivations = {
			"Every line of code is progress! 💻",
			"Small steps lead to big achievements! 🌟",
			"Your future self will thank you! 🙏",
			"Consistency beats intensity! 📈",
		}
		local random_msg = default_motivations[math.random(#default_motivations)]
		table.insert(lines, {
			{ "  💡  ", "normal" },
			{ random_msg, "exyellow" },
		})
	end

	table.insert(lines, {})

	return lines
end

return M
