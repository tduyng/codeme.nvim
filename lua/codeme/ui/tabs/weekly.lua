local domain = require("codeme.domain")
local renderer = require("codeme.ui.renderer")

local M = {}

local function get_week_boundaries()
	local today_time = os.time()
	local today_weekday = tonumber(os.date("%w", today_time))
	if today_weekday == 0 then
		today_weekday = 7
	end

	local days_since_monday = today_weekday - 1
	local monday_time = today_time - (days_since_monday * 86400)
	local sunday_time = monday_time + (6 * 86400)

	return os.date("%Y-%m-%d", monday_time), os.date("%Y-%m-%d", sunday_time), os.date("%Y-%m-%d", today_time)
end

local function get_weekday_date(weekday, monday)
	local monday_time = os.time({
		year = tonumber(monday:sub(1, 4)),
		month = tonumber(monday:sub(6, 7)),
		day = tonumber(monday:sub(9, 10)),
	})
	return os.date("%Y-%m-%d", monday_time + ((weekday - 1) * 86400))
end

local function count_week_coding_days(daily_activity)
	local today = os.date("*t")
	local weekday = today.wday == 1 and 7 or today.wday - 1 -- Convert Sunday=1 to Monday=1 system

	-- Count days coded so far this week
	local days_coded = 0
	for i = 1, weekday do
		-- Calculate date for each day of the week so far
		local days_back = weekday - i
		local check_date = os.time() - (days_back * 24 * 60 * 60)
		local date_str = os.date("%Y-%m-%d", check_date)

		local stat = daily_activity[date_str]
		if stat and stat.time and stat.time > 0 then
			days_coded = days_coded + 1
		end
	end

	return days_coded
end

function M.render(stats)
	local lines = {}

	local this_week = stats.this_week or {}
	local last_week = stats.last_week or {}
	local daily_activity = stats.daily_activity or {}

	local week_time = this_week.total_time or 0
	local last_week_time = last_week.total_time or 0
	local week_lines = this_week.total_lines or 0

	local t_trend, t_hl = domain.get_trend(week_time, last_week_time)

	-- Header
	table.insert(lines, {})
	table.insert(lines, {
		{ "  📅 Weekly Summary  ", "exgreen" },
		{ "⏱️  ", "commentfg" },
		{ domain.format_duration(week_time), "exgreen" },
		{ t_trend, t_hl },
		{ "  │  📝 ", "commentfg" },
		{ domain.format_number(week_lines), "exyellow" },
	})
	table.insert(lines, {})

	-- Daily Breakdown
	local week_monday, _, today = get_week_boundaries()

	table.insert(lines, { { "  📊 Daily Breakdown (Mon-Sun)", "exgreen" } })
	table.insert(lines, {})

	local day_names = { "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" }
	local tbl = { { "Day", "Date", "Time", "Lines", "Sessions", "Trend" } }

	local mpd = this_week.most_productive_day or {}
	local hdo = this_week.highest_daily_output or {}
	local mpd_date = mpd.date
	local hdo_date = hdo.date

	for i = 1, 7 do
		local date = get_weekday_date(i, week_monday)
		local stat = daily_activity[date] or {}

		local t = stat.time or 0
		local l = stat.lines or 0
		local s = stat.session_count or 0

		local label = day_names[i]:sub(1, 3)
		if (mpd_date and date == mpd_date) or (hdo_date and date == hdo_date) then
			label = label .. " 🔥"
		end
		if date == today then
			label = label .. " ★"
		end

		if date > today then
			tbl[#tbl + 1] = { label, date:sub(6, 10), "-", "-", "-", "-" }
		else
			tbl[#tbl + 1] = {
				label,
				date:sub(6, 10),
				t > 0 and domain.format_duration(t) or "-",
				l > 0 and domain.format_number(l) or "-",
				s > 0 and tostring(s) or "-",
				t > 0 and "↗" or "-",
			}
		end
	end

	for _, l in ipairs(renderer.table(tbl, 120)) do
		table.insert(lines, l)
	end
	table.insert(lines, {})

	-- 12 weeks activity heatmap
	local hm = stats.weekly_heatmap
	if hm and #hm > 0 then
		table.insert(lines, { { "  📅 Activity Heatmap", "exgreen" } })
		table.insert(lines, {})
		for _, l in ipairs(renderer.heatmap(hm)) do
			table.insert(lines, l)
		end
		table.insert(lines, {})
	end

	-- Week Summary
	table.insert(lines, { { "  📌 Week Summary", "exgreen" } })
	table.insert(lines, {})

	local daily_avg = week_time > 0 and math.floor(week_time / 7) or 0
	table.insert(lines, {
		{ "     Daily Average: ", "commentfg" },
		{ domain.format_duration(daily_avg), "exgreen" },
	})

	local days_coded = count_week_coding_days(daily_activity)
	table.insert(lines, {
		{ "     Coding Days: ", "commentfg" },
		{ string.format("%d/7", days_coded), "exgreen" },
	})

	if last_week_time > 0 then
		local diff = week_time - last_week_time
		local arrow = diff > 0 and "↑" or diff < 0 and "↓" or "→"
		local hl = diff > 0 and "exgreen" or diff < 0 and "exred" or "commentfg"
		table.insert(lines, {
			{ "     Vs Last Week: ", "commentfg" },
			{ arrow, hl },
			{ " " .. domain.format_duration(math.abs(diff)), hl },
		})
	end
	local weekday_time, weekend_time = 0, 0
	for i = 1, 7 do
		local d = daily_activity[get_weekday_date(i, week_monday)]
		if d and d.time then
			if i <= 5 then
				weekday_time = weekday_time + d.time
			else
				weekend_time = weekend_time + d.time
			end
		end
	end

	local total = weekday_time + weekend_time
	if total > 0 then
		local weekday_pct = math.floor((weekday_time / total) * 100)
		local weekend_pct = 100 - weekday_pct

		local wd_line = { { "  🏢 Weekday  ", "commentfg" } }
		for _, seg in ipairs(renderer.progress(weekday_pct, 20, "exgreen")) do
			table.insert(wd_line, seg)
		end
		table.insert(wd_line, { " " .. weekday_pct .. "%", "exgreen" })
		table.insert(lines, wd_line)

		local we_hl = weekend_pct >= 20 and "exgreen" or "exyellow"
		local we_line = { { "  🏖️ Weekend  ", "commentfg" } }
		for _, seg in ipairs(renderer.progress(weekend_pct, 20, we_hl)) do
			table.insert(we_line, seg)
		end
		table.insert(we_line, { " " .. weekend_pct .. "%", we_hl })
		table.insert(lines, we_line)
	end

	-- Work Style (shared with Insights)
	local hourly = stats.all_time and stats.all_time.hourly_activity or {}
	if hourly and #hourly > 0 then
		local max_time, best_hour = 0, nil
		for _, e in ipairs(hourly) do
			local d = tonumber(e.duration) or 0
			local h = tonumber(e.hour)
			if h and d > max_time then
				max_time = d
				best_hour = h
			end
		end

		if best_hour then
			local style, icon, period
			if best_hour >= 6 and best_hour < 12 then
				style, icon, period = "Early Bird", "🌅", "mornings"
			elseif best_hour >= 12 and best_hour < 18 then
				style, icon, period = "Day Coder", "☀️", "afternoons"
			elseif best_hour >= 18 then
				style, icon, period = "Night Owl", "🦉", "evenings"
			else
				style, icon, period = "Midnight Hacker", "🌙", "late nights"
			end
			local peak = string.format("%02d:00-%02d:00", best_hour, (best_hour + 1) % 24)
			table.insert(lines, { { "  " .. icon .. " " .. style .. " " .. peak .. " (" .. period .. ")", "exgreen" } })
		end
	end

	return lines
end

return M
