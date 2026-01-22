local state = require("codeme.profile.state")
local fmt = require("codeme.profile.formatters")
local ui = require("codeme.ui")

local M = {}

function M.render()
	local globalStats = state.stats or {}
	local lines = {}

	table.insert(lines, {})
	table.insert(lines, { { "  💡 Insights - Your Coding DNA", "exgreen" } })
	table.insert(lines, {})

	-- WORK STYLE PROFILE
	local hourly_activity = globalStats.all_time.hourly_activity or {}
	local total_time = 0

	-- Sum durations safely
	for _, entry in ipairs(hourly_activity) do
		local duration = tonumber(entry.duration) or 0
		total_time = total_time + duration
	end

	if total_time > 0 then
		table.insert(lines, { { "  💼 Work Style Profile", "exgreen" } })
		table.insert(lines, {})

		-- Derive most active hour from hourly_activity (new backend way)
		local most_active_hour = nil
		local max_time = 0

		for _, entry in ipairs(hourly_activity) do
			local hour = tonumber(entry.hour)
			local duration = tonumber(entry.duration) or 0

			if hour ~= nil and duration > max_time then
				max_time = duration
				most_active_hour = hour
			end
		end

		local style, icon, period
		local hour = most_active_hour or 12

		if hour >= 6 and hour < 12 then
			style, icon, period = "Early Bird", "🌅", "mornings"
		elseif hour >= 12 and hour < 18 then
			style, icon, period = "Day Coder", "☀️", "afternoons"
		elseif hour >= 18 and hour < 24 then
			style, icon, period = "Night Owl", "🦉", "evenings"
		else
			style, icon, period = "Midnight Hacker", "🌙", "late nights"
		end

		local peak_time = most_active_hour and string.format("%02d:00-%02d:00", hour, (hour + 1) % 24) or "-"

		local tbl = {
			{ "Type", "Peak Hours" },
			{ icon .. " " .. style, peak_time .. " (" .. period .. ")" },
		}

		for _, l in ipairs(ui.table(tbl, state.width - 8)) do
			table.insert(lines, l)
		end
		table.insert(lines, {})
	end

	-- TIME DISTRIBUTION (weekday vs weekend)
	table.insert(lines, { { "  📊 Time Distribution", "exgreen" } })
	table.insert(lines, {})

	local daily_activity = globalStats.daily_activity or {}
	local weekday_time, weekend_time = 0, 0

	for date, stat in pairs(daily_activity) do
		if stat and stat.time then
			local wday = tonumber(os.date(
				"%w",
				os.time({
					year = tonumber(date:sub(1, 4)),
					month = tonumber(date:sub(6, 7)),
					day = tonumber(date:sub(9, 10)),
				})
			))
			if wday == 0 or wday == 6 then
				weekend_time = weekend_time + stat.time
			else
				weekday_time = weekday_time + stat.time
			end
		end
	end

	local total_week = weekday_time + weekend_time
	if total_week > 0 then
		local weekday_pct = math.floor((weekday_time / total_week) * 100)
		local weekend_pct = 100 - weekday_pct

		local weekday_line = { { "  🏢  Weekday  ", "commentfg" } }
		for _, seg in ipairs(ui.progress(weekday_pct, 20, "exgreen")) do
			table.insert(weekday_line, seg)
		end
		table.insert(weekday_line, { string.format(" %d%%", weekday_pct), "exgreen" })
		table.insert(lines, weekday_line)

		local weekend_hl = weekend_pct >= 20 and "exyellow" or "exblue"
		local weekend_line = { { "  🏖️  Weekend  ", "commentfg" } }
		for _, seg in ipairs(ui.progress(weekend_pct, 20, weekend_hl)) do
			table.insert(weekend_line, seg)
		end
		table.insert(weekend_line, { string.format(" %d%%", weekend_pct), weekend_hl })
		table.insert(lines, weekend_line)

		table.insert(lines, {})
	end

	-- SESSION QUALITY
	local focus_score = globalStats.all_time.focus_score or 0
	local avg_session_length = globalStats.all_time.avg_session_length or 0

	if focus_score > 0 or avg_session_length > 0 then
		table.insert(lines, { { "  🎯 Session Quality", "exgreen" } })
		table.insert(lines, {})

		local focus_level, focus_icon
		if avg_session_length >= 7200 then
			focus_level, focus_icon = "Deep Focus", "🎯"
		elseif avg_session_length >= 3600 then
			focus_level, focus_icon = "Good Focus", "⭐"
		else
			focus_level, focus_icon = "Sprint Style", "🏃"
		end

		table.insert(lines, {
			{ "  " .. focus_icon .. " ", "normal" },
			{ focus_level, avg_session_length >= 3600 and "exgreen" or "exyellow" },
			avg_session_length > 0 and { "  •  Avg: ", "commentfg" } or nil,
			avg_session_length > 0 and { fmt.fmt_time(avg_session_length), "normal" } or nil,
		})

		if focus_score > 0 then
			local hl = focus_score >= 70 and "exgreen" or focus_score >= 50 and "exyellow" or "exred"
			local line = { { "  Focus:  ", "commentfg" } }
			for _, seg in ipairs(ui.progress(focus_score, 20, hl)) do
				table.insert(line, seg)
			end
			table.insert(line, { string.format(" %d/100", focus_score), hl })
			table.insert(lines, line)
		end

		table.insert(lines, {})
	end

	-- STREAK & CONSISTENCY
	local current_streak = globalStats.streak or 0
	local longest_streak = globalStats.longest_streak or 0

	table.insert(lines, { { "  🔥 Streak & Consistency", "exgreen" } })
	table.insert(lines, {})

	local streak_icon = current_streak >= 14 and "🔥🔥🔥"
		or current_streak >= 7 and "🔥🔥"
		or current_streak > 0 and "🔥"
		or "💤"

	local streak_hl = current_streak >= 7 and "exgreen" or current_streak > 0 and "exyellow" or "commentfg"

	table.insert(lines, {
		{ "  " .. streak_icon .. "  ", "normal" },
		{ string.format("%d days", current_streak), streak_hl },
		{ " current", "commentfg" },
		{
			longest_streak > current_streak and string.format("  •  Best: %d days", longest_streak) or "",
			"commentfg",
		},
	})

	table.insert(lines, {})

	-- YOUR STRENGTHS
	table.insert(lines, { { "  💪 Your Strengths", "exgreen" } })
	table.insert(lines, {})

	local strengths = {}

	if current_streak >= 14 then
		table.insert(strengths, { icon = "🔥", text = current_streak .. "-day streak", color = "exgreen" })
	elseif current_streak >= 7 then
		table.insert(strengths, { icon = "📅", text = "Consistent week coder", color = "exgreen" })
	end

	if focus_score >= 80 then
		table.insert(strengths, { icon = "🎯", text = "Laser focus", color = "exgreen" })
	end

	local total_time_stat = globalStats.total_time or 0
	if total_time_stat >= 72000 then
		table.insert(strengths, {
			icon = "⏰",
			text = math.floor(total_time_stat / 3600) .. "+ hours logged",
			color = "exyellow",
		})
	end

	if #strengths > 0 then
		for _, st in ipairs(strengths) do
			table.insert(lines, {
				{ "  " .. st.icon .. " ", "normal" },
				{ st.text, st.color },
			})
		end
	else
		table.insert(lines, { { "  Keep coding to unlock strengths! 💪", "commentfg" } })
	end

	table.insert(lines, {})

	-- SMART RECOMMENDATIONS
	table.insert(lines, { { "  💡 Smart Recommendations", "exgreen" } })
	table.insert(lines, {})

	local recommendations = {}

	if focus_score > 0 and focus_score < 70 then
		table.insert(recommendations, {
			icon = "🎯",
			text = "Try longer uninterrupted sessions",
			color = "exyellow",
		})
	end

	if current_streak > 0 and current_streak < 7 then
		table.insert(recommendations, {
			icon = "🔥",
			text = string.format("%d more days to hit a week streak", 7 - current_streak),
			color = "exyellow",
		})
	elseif current_streak == 0 then
		table.insert(recommendations, {
			icon = "🚀",
			text = "Start a streak today — even 15 min counts",
			color = "exyellow",
		})
	end

	if #recommendations > 0 then
		for _, rec in ipairs(recommendations) do
			table.insert(lines, {
				{ "  " .. rec.icon .. "  ", "normal" },
				{ rec.text, rec.color },
			})
		end
	else
		table.insert(lines, { { "  Keep coding for deeper insights! 💡", "commentfg" } })
	end

	table.insert(lines, {})

	return lines
end

return M
