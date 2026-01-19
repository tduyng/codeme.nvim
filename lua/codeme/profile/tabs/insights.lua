local state = require("codeme.profile.state")
local fmt = require("codeme.profile.formatters")
local ui = require("codeme.ui")

local M = {}

function M.render()
	local s = state.stats
	local lines = {}

	table.insert(lines, {})
	table.insert(lines, { { "  💡 Insights - Your Coding DNA", "exgreen" } })
	table.insert(lines, {})

	-- ============================================================
	-- 💼 WORK STYLE PROFILE (Visual Card)
	-- ============================================================
	local hourly_activity = s.hourly_activity or {}
	local total_time = 0
	for _, time in pairs(hourly_activity) do
		total_time = total_time + time
	end

	if total_time > 0 then
		table.insert(lines, { { "  💼 Work Style Profile", "exgreen" } })
		table.insert(lines, {})

		local most_active_hour = s.most_active_hour or 14
		local style, icon, period

		if most_active_hour >= 6 and most_active_hour < 12 then
			style, icon, period = "Early Bird", "🌅", "mornings"
		elseif most_active_hour >= 12 and most_active_hour < 18 then
			style, icon, period = "Day Coder", "☀️", "afternoons"
		elseif most_active_hour >= 18 and most_active_hour < 24 then
			style, icon, period = "Night Owl", "🦉", "evenings"
		else
			style, icon, period = "Midnight Hacker", "🌙", "late nights"
		end

		local peak_hours = s.peak_hours or { most_active_hour }
		local peak_time = #peak_hours > 0 and string.format("%02d:00-%02d:00", peak_hours[1], peak_hours[1] + 1) or "-"

		-- Use ui.table for clean layout
		local tbl = {
			{ "Type", "Peak Hours" },
			{ icon .. " " .. style, peak_time .. " (" .. period .. ")" },
		}

		for _, l in ipairs(ui.table(tbl, state.width - 8)) do
			table.insert(lines, l)
		end
		table.insert(lines, {})
	end

	-- ============================================================
	-- 📊 TIME DISTRIBUTION (Using ui.table for clean layout)
	-- ============================================================
	table.insert(lines, { { "  📊 Time Distribution", "exgreen" } })
	table.insert(lines, {})

	local weekday_pattern = s.weekday_pattern or {}
	if #weekday_pattern >= 7 then
		local weekday_time = 0
		local weekend_time = 0

		for i = 1, 5 do
			weekday_time = weekday_time + (weekday_pattern[i] or 0)
		end
		for i = 6, 7 do
			weekend_time = weekend_time + (weekday_pattern[i] or 0)
		end

		local total_week = weekday_time + weekend_time

		if total_week > 0 then
			local weekday_pct = math.floor((weekday_time / total_week) * 100)
			local weekend_pct = math.floor((weekend_time / total_week) * 100)

			-- Summary bar
			local weekday_line = { { "  🏢  Weekday  ", "commentfg" } }
			for _, seg in ipairs(ui.progress(weekday_pct, 20, "exgreen")) do
				table.insert(weekday_line, seg)
			end
			table.insert(weekday_line, { string.format(" %d%%", weekday_pct), "exgreen" })
			table.insert(lines, weekday_line)

			local weekend_line = { { "  🏖️  Weekend  ", "commentfg" } }
			local weekend_hl = weekend_pct >= 20 and "exyellow" or "exblue"
			for _, seg in ipairs(ui.progress(weekend_pct, 20, weekend_hl)) do
				table.insert(weekend_line, seg)
			end
			table.insert(weekend_line, { string.format(" %d%%", weekend_pct), weekend_hl })
			table.insert(lines, weekend_line)

			table.insert(lines, {})

			-- Daily breakdown using ui.table
			local day_names = { "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" }
			local tbl = { { "Day", "Time", "%" } }

			for i = 1, 7 do
				local day_time = weekday_pattern[i] or 0
				local pct = total_week > 0 and math.floor((day_time / total_week) * 100) or 0

				if pct > 0 then
					local day_icon = i <= 5 and "▪" or "▫"
					tbl[#tbl + 1] = {
						day_icon .. " " .. day_names[i],
						fmt.fmt_time(day_time),
						string.format("%d%%", pct),
					}
				end
			end

			-- Only show table if we have data
			if #tbl > 1 then
				for _, l in ipairs(ui.table(tbl, state.width - 8)) do
					table.insert(lines, l)
				end
			end
		end

		table.insert(lines, {})
	end

	-- ============================================================
	-- 🎯 SESSION QUALITY (Visual metrics card)
	-- ============================================================
	local avg_session_length = s.avg_session_length or 0
	local focus_score = s.focus_score or 0

	if avg_session_length > 0 or focus_score > 0 then
		table.insert(lines, { { "  🎯 Session Quality", "exgreen" } })
		table.insert(lines, {})

		-- Session style badge
		local focus_level, focus_icon
		if avg_session_length > 7200 then
			focus_level, focus_icon = "Deep Focus", "🎯"
		elseif avg_session_length > 3600 then
			focus_level, focus_icon = "Good Focus", "⭐"
		else
			focus_level, focus_icon = "Sprint Style", "🏃"
		end

		table.insert(lines, {
			{ "  " .. focus_icon .. " ", "normal" },
			{ focus_level, avg_session_length > 3600 and "exgreen" or "exyellow" },
			{ "  •  Avg: ", "commentfg" },
			{ fmt.fmt_time(avg_session_length), "normal" },
		})

		-- Focus score with visual bar
		if focus_score > 0 then
			local focus_hl = focus_score >= 70 and "exgreen" or focus_score >= 50 and "exyellow" or "exred"
			local focus_line = { { "  Focus:  ", "commentfg" } }
			for _, seg in ipairs(ui.progress(focus_score, 20, focus_hl)) do
				table.insert(focus_line, seg)
			end
			table.insert(focus_line, { string.format(" %d/100", focus_score), focus_hl })
			table.insert(lines, focus_line)
		end

		-- Longest session (compact)
		local records = s.records or {}
		local longest_session = records.longest_session or {}
		if longest_session.duration and longest_session.duration > 0 then
			table.insert(lines, {
				{ "  Record: ", "commentfg" },
				{ fmt.fmt_time(longest_session.duration), "exgreen" },
				{ " ⭐", "normal" },
			})
		end

		table.insert(lines, {})
	end

	-- ============================================================
	-- 🔥 STREAK & CONSISTENCY (Visual emphasis)
	-- ============================================================
	local streak_info = s.streak_info or {}
	local current_streak = streak_info.current or s.streak or 0
	local longest_streak = streak_info.longest or s.longest_streak or 0

	table.insert(lines, { { "  🔥 Streak & Consistency", "exgreen" } })
	table.insert(lines, {})

	-- Current streak (big visual emphasis)
	local streak_icon = current_streak >= 14 and "🔥🔥🔥"
		or current_streak >= 7 and "🔥🔥"
		or current_streak > 0 and "🔥"
		or "💤"
	local streak_hl = current_streak >= 7 and "exgreen" or current_streak > 0 and "exyellow" or "commentfg"

	table.insert(lines, {
		{ "  " .. streak_icon .. "  ", "normal" },
		{ string.format("%d days", current_streak), streak_hl },
		{ " current", "commentfg" },
		{ longest_streak > current_streak and string.format("  •  Best: %d days", longest_streak) or "", "commentfg" },
	})

	-- Weekly consistency bar
	local weekly_pattern = streak_info.weekly_pattern or {}
	if #weekly_pattern >= 7 then
		local days_coded = 0
		for i = 1, 7 do
			if weekly_pattern[i] then
				days_coded = days_coded + 1
			end
		end

		local consistency_pct = math.floor((days_coded / 7) * 100)
		local consistency_hl = consistency_pct >= 70 and "exgreen" or "exyellow"

		local consistency_line = { { "  This week: ", "commentfg" } }
		for _, seg in ipairs(ui.progress(consistency_pct, 15, consistency_hl)) do
			table.insert(consistency_line, seg)
		end
		table.insert(consistency_line, { string.format(" %d/7 days", days_coded), consistency_hl })
		table.insert(lines, consistency_line)
	end

	table.insert(lines, {})

	-- ============================================================
	-- 💪 YOUR STRENGTHS (Badge collection)
	-- ============================================================
	table.insert(lines, { { "  💪 Your Strengths", "exgreen" } })
	table.insert(lines, {})

	local strengths = {}

	-- Build strengths list
	if current_streak >= 14 then
		table.insert(strengths, { icon = "🔥", text = current_streak .. "-day streak", color = "exgreen" })
	elseif current_streak >= 7 then
		table.insert(strengths, { icon = "📅", text = "Week+ consistency", color = "exgreen" })
	end

	if focus_score >= 80 then
		table.insert(strengths, { icon = "🎯", text = "Laser focus (" .. focus_score .. "/100)", color = "exgreen" })
	elseif avg_session_length >= 3600 then
		table.insert(strengths, { icon = "⏰", text = "Deep work sessions", color = "exgreen" })
	end

	local total_time_stat = s.total_time or 0
	if total_time_stat > 360000 then
		local hours = math.floor(total_time_stat / 3600)
		table.insert(strengths, { icon = "🏆", text = hours .. "+ hours experience", color = "exgreen" })
	elseif total_time_stat > 72000 then
		table.insert(strengths, { icon = "⭐", text = "20+ hours logged", color = "exyellow" })
	end

	-- Language expertise
	local programming_languages = s.programming_languages or {}
	local expert_langs = {}
	for lang, stat in pairs(programming_languages) do
		if stat.proficiency == "Master" or stat.proficiency == "Expert" then
			table.insert(expert_langs, lang)
		end
	end

	if #expert_langs > 0 then
		table.insert(strengths, {
			icon = "🎓",
			text = table.concat(expert_langs, ", ") .. " expert",
			color = "exgreen",
		})
	end

	-- Display as compact badges
	if #strengths > 0 then
		for _, strength in ipairs(strengths) do
			table.insert(lines, {
				{ "  " .. strength.icon .. " ", "normal" },
				{ strength.text, strength.color },
			})
		end
	else
		table.insert(lines, { { "  Keep coding to unlock strengths! 💪", "commentfg" } })
	end

	table.insert(lines, {})

	-- ============================================================
	-- 💡 SMART RECOMMENDATIONS (Actionable insights)
	-- ============================================================
	table.insert(lines, { { "  💡 Smart Recommendations", "exgreen" } })
	table.insert(lines, {})

	local recommendations = {}

	-- Peak timing
	local peak_hours = s.peak_hours or {}
	if #peak_hours > 0 then
		local peak_hour = peak_hours[1]
		table.insert(recommendations, {
			icon = "⏰",
			text = string.format("Schedule deep work at %02d:00", peak_hour),
			color = "exyellow",
		})
	end

	-- Focus improvement
	if focus_score > 0 and focus_score < 70 then
		table.insert(recommendations, {
			icon = "🎯",
			text = "Try longer sessions to boost focus",
			color = "exyellow",
		})
	end

	-- Streak motivation
	if current_streak > 0 and current_streak < 7 then
		table.insert(recommendations, {
			icon = "🔥",
			text = string.format("%d more days to reach week streak", 7 - current_streak),
			color = "exyellow",
		})
	elseif current_streak == 0 then
		table.insert(recommendations, {
			icon = "🚀",
			text = "Start a streak today - even 15 min counts",
			color = "exyellow",
		})
	end

	-- Trending languages
	local trending_langs = {}
	for lang, stat in pairs(programming_languages) do
		if stat.trending then
			table.insert(trending_langs, lang)
		end
	end

	if #trending_langs > 0 then
		table.insert(recommendations, {
			icon = "📈",
			text = "Growing fast: " .. table.concat(trending_langs, ", "),
			color = "exgreen",
		})
	end

	-- Display recommendations
	if #recommendations > 0 then
		for _, rec in ipairs(recommendations) do
			table.insert(lines, {
				{ "  " .. rec.icon .. "  ", "normal" },
				{ rec.text, rec.color },
			})
		end
	else
		table.insert(lines, { { "  Keep coding for personalized insights! 💡", "commentfg" } })
	end

	table.insert(lines, {})

	return lines
end

return M
