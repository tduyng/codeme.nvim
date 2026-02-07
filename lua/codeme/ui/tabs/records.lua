local util = require("codeme.util")
local renderer = require("codeme.ui.renderer")

local M = {}

function M.render(stats)
	local lines = {}

	table.insert(lines, {})
	table.insert(lines, { { "  🏆 Hall of Fame", "exgreen" } })
	table.insert(lines, {})

	-- Career Stats
	table.insert(lines, { { "  📊 Career Stats", "exgreen" } })
	table.insert(lines, {})

	local today = stats.today or {}
	local this_week = stats.this_week or {}
	local this_month = stats.this_month or {}
	local all_time = stats.all_time or {}

	local stats_tbl = {
		{ "Period", "Time", "Lines", "Files" },
		{
			"Today",
			util.format_duration(today.total_time or 0),
			util.format_number(today.total_lines or 0),
			tostring(today.total_files or 0),
		},
		{
			"This Week",
			util.format_duration(this_week.total_time or 0),
			util.format_number(this_week.total_lines or 0),
			tostring(this_week.total_files or 0),
		},
		{
			"This Month",
			util.format_duration(this_month.total_time or 0),
			util.format_number(this_month.total_lines or 0),
			tostring(this_month.total_files or 0),
		},
		{
			"All Time",
			util.format_duration(all_time.total_time or 0),
			util.format_number(all_time.total_lines or 0),
			tostring(all_time.total_files or 0),
		},
	}

	for _, l in ipairs(renderer.table(stats_tbl, 120)) do
		table.insert(lines, l)
	end
	table.insert(lines, {})

	-- Career Level
	table.insert(lines, { { "  🎯 Career Level", "exgreen" } })
	table.insert(lines, {})

	local total_hours = math.floor((all_time.total_time or 0) / 3600)
	local milestones = {
		{ threshold = 100000, name = "Legendary", icon = "👑", color = "exgreen" },
		{ threshold = 50000, name = "Master", icon = "🏅", color = "exgreen" },
		{ threshold = 25000, name = "Expert", icon = "🎖️", color = "exgreen" },
		{ threshold = 10000, name = "Senior", icon = "💎", color = "exyellow" },
		{ threshold = 5000, name = "Professional", icon = "🔥", color = "exyellow" },
		{ threshold = 2500, name = "Committed", icon = "⭐", color = "exyellow" },
		{ threshold = 1000, name = "Century", icon = "💯", color = "exblue" },
		{ threshold = 100, name = "Rising", icon = "🌱", color = "exblue" },
	}

	local current_level = nil
	local next_level = nil

	for _, m in ipairs(milestones) do
		if total_hours >= m.threshold then
			current_level = m
			break
		else
			next_level = m
		end
	end

	if current_level then
		table.insert(lines, {
			{ "  " .. current_level.icon .. "  ", "normal" },
			{ current_level.name .. " Coder", current_level.color },
			{ string.format("  •  %d hours", total_hours), "commentfg" },
		})
	else
		table.insert(lines, {
			{ "  🌱  ", "normal" },
			{ "Beginner", "exblue" },
			{ string.format("  •  %d hours", total_hours), "commentfg" },
		})
	end

	if next_level then
		local hours_needed = next_level.threshold - total_hours
		local progress_pct = math.floor((total_hours / next_level.threshold) * 100)

		table.insert(lines, {})
		local progress_line = { { "  Next: " .. next_level.icon .. " " .. next_level.name .. "  ", "commentfg" } }
		for _, seg in ipairs(renderer.progress(progress_pct, 20, "exyellow")) do
			table.insert(progress_line, seg)
		end
		table.insert(progress_line, { string.format(" %d%%", progress_pct), "exyellow" })
		table.insert(lines, progress_line)

		table.insert(lines, {
			{ "  ", "commentfg" },
			{ string.format("%d hours to go!", hours_needed), "commentfg" },
		})
	else
		table.insert(lines, {})
		table.insert(lines, {
			{ "  👑 ", "exgreen" },
			{ "LEGENDARY STATUS ACHIEVED!", "exgreen" },
		})
	end

	table.insert(lines, {})

	-- Records
	table.insert(lines, { { "  🏆 Your Records", "exgreen" } })
	table.insert(lines, {})

	local records = stats.records or {}
	local record_list = {}

	local most_productive_day = records.most_productive_day or {}
	if most_productive_day.time and most_productive_day.time > 0 then
		table.insert(record_list, {
			icon = "🏆",
			title = "Best Day",
			value = util.format_duration(most_productive_day.time),
			detail = most_productive_day.date and util.format_date(most_productive_day.date) or "",
			extra = most_productive_day.lines and util.format_number(most_productive_day.lines) .. " lines" or "",
		})
	end

	local longest_session = records.longest_session or {}
	if longest_session.duration and longest_session.duration > 0 then
		local time_range = ""
		if longest_session.start and longest_session["end"] then
			time_range = longest_session.start:sub(12, 16) .. "-" .. longest_session["end"]:sub(12, 16)
		end

		table.insert(record_list, {
			icon = "⏱️",
			title = "Longest Session",
			value = util.format_duration(longest_session.duration),
			detail = longest_session.date and util.format_date(longest_session.date) or "",
			extra = time_range,
		})
	end

	local highest_daily_output = records.highest_daily_output or {}
	if highest_daily_output.lines and highest_daily_output.lines > 0 then
		table.insert(record_list, {
			icon = "📝",
			title = "Most Lines",
			value = util.format_number(highest_daily_output.lines) .. " lines",
			detail = highest_daily_output.date and util.format_date(highest_daily_output.date) or "",
			extra = highest_daily_output.session_count and highest_daily_output.session_count .. " sessions" or "",
		})
	end

	local best_streak = records.best_streak or {}
	if best_streak.day_count and best_streak.day_count > 0 then
		local streak_icon, _ = util.get_streak_display(best_streak.day_count)
		local date_range = ""
		if best_streak.start_date and best_streak.end_date then
			date_range = best_streak.start_date:sub(6, 10) .. " - " .. best_streak.end_date:sub(6, 10)
		end

		table.insert(record_list, {
			icon = "🔥",
			title = "Best Streak",
			value = best_streak.day_count .. " days " .. streak_icon,
			detail = date_range,
			extra = best_streak.total_time and util.format_duration(best_streak.total_time) .. " total" or "",
		})
	end

	if #record_list > 0 then
		local records_tbl = { { "Trophy", "Record", "Date", "Details" } }

		for _, rec in ipairs(record_list) do
			table.insert(records_tbl, {
				rec.icon .. " " .. rec.title,
				rec.value,
				rec.detail,
				rec.extra,
			})
		end

		for _, l in ipairs(renderer.table(records_tbl, 120)) do
			table.insert(lines, l)
		end
		table.insert(lines, {})
	end

	-- Fun Facts
	local earliest_start = records.earliest_start or {}
	local latest_end = records.latest_end or {}
	local most_languages_day = records.most_languages_day or {}

	local has_fun_facts = earliest_start.time or latest_end.time or (most_languages_day and most_languages_day.date)

	if has_fun_facts then
		table.insert(lines, { { "  📊 Fun Facts", "exgreen" } })
		table.insert(lines, {})

		if earliest_start.time then
			table.insert(lines, {
				{ "  🌅 ", "normal" },
				{ "Early Bird: ", "commentfg" },
				{ earliest_start.time, "exgreen" },
				{ " (" .. (earliest_start.date or "") .. ")", "commentfg" },
			})
		end

		if latest_end.time then
			table.insert(lines, {
				{ "  🌙 ", "normal" },
				{ "Night Owl: ", "commentfg" },
				{ latest_end.time, "exgreen" },
				{ " (" .. (latest_end.date or "") .. ")", "commentfg" },
			})
		end

		if most_languages_day and most_languages_day.date and most_languages_day.date ~= "" then
			local languages_count = util.safe_length(most_languages_day.languages)
			if languages_count > 0 then
				table.insert(lines, {
					{ "  🌍 ", "normal" },
					{ "Polyglot Day: ", "commentfg" },
					{ languages_count .. " languages", "exgreen" },
					{ " (" .. most_languages_day.date .. ")", "commentfg" },
				})
			end
		end

		table.insert(lines, {})
	end

	-- Achievements
	local achievements = stats.achievements or {}
	if #achievements > 0 then
		table.insert(lines, { { "  🎖️ Achievements", "exgreen" } })
		table.insert(lines, {})

		local unlocked = {}
		local locked = {}

		for _, achievement in ipairs(achievements) do
			if achievement.unlocked then
				table.insert(unlocked, achievement)
			else
				table.insert(locked, achievement)
			end
		end

		if #unlocked > 0 then
			for _, ach in ipairs(unlocked) do
				table.insert(lines, {
					{ "  " .. ach.icon .. " ", "normal" },
					{ ach.name, "exgreen" },
					{ " - ", "commentfg" },
					{ ach.description, "commentfg" },
				})
			end
		end

		if #locked > 0 then
			table.insert(lines, {})
			table.insert(lines, {
				{ "  🔒 ", "commentfg" },
				{ #locked .. " more to unlock", "commentfg" },
			})
		end

		table.insert(lines, {})
		local ach_pct = math.floor((#unlocked / #achievements) * 100)
		local ach_line = { { "  Progress: ", "commentfg" } }
		for _, seg in ipairs(renderer.progress(ach_pct, 20, "exgreen")) do
			table.insert(ach_line, seg)
		end
		table.insert(ach_line, { string.format(" %d%%", ach_pct), "exgreen" })
		table.insert(ach_line, { string.format(" (%d/%d)", #unlocked, #achievements), "commentfg" })
		table.insert(lines, ach_line)

		table.insert(lines, {})
	end

	-- Challenges
	table.insert(lines, { { "  💪 Can You Beat These?", "exgreen" } })
	table.insert(lines, {})

	local streak_info = stats.streak_info or {}
	local current_streak = (streak_info.current or 0) + 1
	local challenges = {}

	if most_productive_day.time then
		local today_time = today.total_time or 0
		local gap = most_productive_day.time - today_time
		if gap > 0 and today_time > 0 then
			table.insert(challenges, {
				icon = "🎯",
				text = util.format_duration(gap) .. " more to beat your best day",
				color = gap < 3600 and "exgreen" or "exyellow",
			})
		end
	end

	if best_streak.day_count and current_streak > 0 then
		local streak_gap = best_streak.day_count - current_streak
		if streak_gap > 0 then
			table.insert(challenges, {
				icon = "🔥",
				text = streak_gap .. " more days to beat your streak record",
				color = "exyellow",
			})
		elseif streak_gap == 0 then
			table.insert(challenges, {
				icon = "🔥",
				text = "One more day for a NEW RECORD!",
				color = "exgreen",
			})
		end
	end

	if longest_session.duration then
		table.insert(challenges, {
			icon = "⏰",
			text = "Can you beat " .. util.format_duration(longest_session.duration) .. " in one session?",
			color = "exyellow",
		})
	end

	if #challenges > 0 then
		for _, ch in ipairs(challenges) do
			table.insert(lines, {
				{ "  " .. ch.icon .. "  ", "normal" },
				{ ch.text, ch.color },
			})
		end
	else
		table.insert(lines, {
			{ "  💡 Keep coding to set new records!", "commentfg" },
		})
	end

	table.insert(lines, {})

	return lines
end

return M
