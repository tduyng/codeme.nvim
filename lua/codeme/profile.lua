local M = {}
local ui = require("codeme.ui")
local api = vim.api

local state = { stats = {}, tab = 1, buf = nil, win = nil, ns = nil, width = 100 }
local TABS = { "☀️ Today", "📅 Weekly", "📊 Overview", "💡 Insights", "💻 Languages", "🔥 Projects" }

--------------------------------------------------------------------------------
-- FORMATTERS
--------------------------------------------------------------------------------

local function fmt_time(s)
	if not s or s == 0 then
		return "0m"
	end
	if s < 60 then
		return s .. "s"
	end
	if s < 3600 then
		return math.floor(s / 60) .. "m"
	end
	local h, m = math.floor(s / 3600), math.floor((s % 3600) / 60)
	return m > 0 and (h .. "h " .. m .. "m") or (h .. "h")
end

local function fmt_num(n)
	if not n then
		return "0"
	end
	return tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function progress(pct, w)
	pct = math.max(0, math.min(100, pct or 0))
	local f = math.floor(pct / 100 * w)
	return string.rep("█", f) .. string.rep("░", w - f)
end

local function trend(cur, prev)
	if not cur or not prev or prev == 0 then
		return "", "commentfg"
	end
	local d = cur - prev
	local p = math.floor(math.abs(d) / prev * 100)
	if d > 0 then
		return " ↑" .. p .. "%", "exgreen"
	end
	if d < 0 then
		return " ↓" .. p .. "%", "exred"
	end
	return " →", "commentfg"
end

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

-- Helper: Calculate hourly time distribution from sessions
local function calculate_hourly_time(sessions)
	local hourly_time = {}
	for i = 0, 23 do
		hourly_time[i] = 0
	end

	if not sessions or #sessions == 0 then
		return hourly_time
	end

	for _, session in ipairs(sessions) do
		local start_str = session.start or ""
		local end_str = session["end"] or ""
		local duration = session.duration or 0

		if duration <= 0 then
			goto continue
		end

		local start_hour = tonumber(start_str:match("T(%d%d):"))
		local end_hour = tonumber(end_str:match("T(%d%d):"))

		if not start_hour or not end_hour then
			goto continue
		end

		-- Same hour
		if start_hour == end_hour then
			hourly_time[start_hour] = hourly_time[start_hour] + duration
		else
			local start_min = tonumber(start_str:match("T%d%d:(%d%d):")) or 0
			local end_min = tonumber(end_str:match("T%d%d:(%d%d):")) or 0

			-- First hour
			local first_hour = (60 - start_min) * 60
			hourly_time[start_hour] = hourly_time[start_hour] + math.min(first_hour, duration)

			local remaining = duration - first_hour
			if remaining > 0 then
				-- Last hour
				local last_hour = end_min * 60
				hourly_time[end_hour] = hourly_time[end_hour] + math.min(last_hour, remaining)

				remaining = remaining - last_hour

				-- Full hours in between
				local h = (start_hour + 1) % 24
				while remaining > 0 and h ~= end_hour do
					local chunk = math.min(3600, remaining)
					hourly_time[h] = hourly_time[h] + chunk
					remaining = remaining - chunk
					h = (h + 1) % 24
				end
			end
		end

		::continue::
	end

	return hourly_time
end

--------------------------------------------------------------------------------
-- TAB BUILDERS (each returns array of lines)
--------------------------------------------------------------------------------

local function tab_today()
	local ts = state.stats.today_stats or {}
	local s = state.stats
	local lines = {}

	-- Header
	local t_trend, t_hl = trend(ts.total_time or 0, s.yesterday_time or 0)
	table.insert(lines, {})
	table.insert(lines, { { "  ☀️ Today's Coding", "exgreen" } })
	table.insert(lines, {})
	table.insert(lines, {
		{ "  ⏱️ ", "commentfg" },
		{ fmt_time(ts.total_time or 0), "exgreen" },
		{ t_trend, t_hl },
		{ "  │  📝 ", "commentfg" },
		{ fmt_num(ts.total_lines or 0), "exyellow" },
		{ "  │  📂 ", "commentfg" },
		{ tostring(ts.total_files or 0), "exred" },
	})
	table.insert(lines, {})

	-- Goals
	local cfg = require("codeme").get_config().goals or {}
	if (cfg.daily_hours or 0) > 0 then
		local pct = math.min(100, math.floor((ts.total_time or 0) / (cfg.daily_hours * 3600) * 100))
		local hl = pct >= 100 and "exgreen" or pct >= 50 and "exyellow" or "exred"
		table.insert(
			lines,
			{ { "  🎯 Time : ", "commentfg" }, { progress(pct, 25), hl }, { " " .. pct .. "%", "commentfg" } }
		)
	end
	if (cfg.daily_lines or 0) > 0 then
		local pct = math.min(100, math.floor((ts.total_lines or 0) / cfg.daily_lines * 100))
		local hl = pct >= 100 and "exgreen" or pct >= 50 and "exyellow" or "exred"
		table.insert(
			lines,
			{ { "  🎯 Lines: ", "commentfg" }, { progress(pct, 25), hl }, { " " .. pct .. "%", "commentfg" } }
		)
	end
	if #lines > 5 then
		table.insert(lines, {})
	end

	-- Hourly activity (TIME-based, not events) - MOVED UP
	local today_sessions = s.sessions or {}
	if #today_sessions > 0 then
		table.insert(lines, {})
		table.insert(lines, { { "  📊 Activity Distribution", "exgreen" } })

		-- Calculate hourly time distribution
		local hourly_time = calculate_hourly_time(today_sessions)

		local total_time = 0
		for i = 0, 23 do
			total_time = total_time + (hourly_time[i] or 0)
		end

		if total_time > 0 then
			local blocks = {
				{ "00–04", 0, 3 },
				{ "04–08", 4, 7 },
				{ "08–12", 8, 11 },
				{ "12–16", 12, 15 },
				{ "16–20", 16, 19 },
				{ "20–24", 20, 23 },
			}
			for _, b in ipairs(blocks) do
				local sum = 0
				for h = b[2], b[3] do
					sum = sum + (hourly_time[h] or 0)
				end
				local pct = math.floor(sum / total_time * 100)
				local hl
				if pct >= 35 then
					hl = "exgreen"
				elseif pct >= 20 then
					hl = "exyellow"
				else
					hl = "commentfg"
				end
				table.insert(lines, {
					{ "  " .. b[1] .. " ", "commentfg" },
					{ progress(pct, 25), hl },
					{ string.format(" %3d%%  %s", pct, fmt_time(sum)), "commentfg" },
				})
			end
		end
		table.insert(lines, {})
	end

	-- Languages table
	if ts.languages and next(ts.languages) then
		local items, total = {}, 0
		for name, stat in pairs(ts.languages) do
			total = total + (stat.time or 0)
			items[#items + 1] = { name = name, time = stat.time or 0, lines = stat.lines or 0 }
		end
		table.sort(items, function(a, b)
			return a.time > b.time
		end)

		local tbl = { { "Language", "Time", "Lines", "%" } }
		for i = 1, math.min(5, #items) do
			local it = items[i]
			local pct = total > 0 and math.floor(it.time / total * 100) or 0
			tbl[#tbl + 1] = { it.name, fmt_time(it.time), fmt_num(it.lines), progress(pct, 15) .. " " .. pct .. "%" }
		end
		table.insert(lines, { { "  💻 Languages", "exgreen" } })
		table.insert(lines, {})
		for _, l in ipairs(ui.table(tbl, state.width - 8)) do
			table.insert(lines, l)
		end
	else
		table.insert(lines, { { "  💻 No activity yet. Start coding!", "commentfg" } })
	end

	-- Projects (today)
	if ts.projects and next(ts.projects) then
		local items = {}
		for name, stat in pairs(ts.projects) do
			items[#items + 1] = { name = name, time = stat.time or 0, lines = stat.lines or 0 }
		end
		table.sort(items, function(a, b)
			return a.time > b.time
		end)

		table.insert(lines, {})
		table.insert(lines, { { "  🔥 Top 10 Projects", "exgreen" } })
		table.insert(lines, {})

		-- Build table rows
		local tbl = { { "Project", "Time", "Lines" } }
		for i = 1, math.min(10, #items) do
			local it = items[i]
			tbl[#tbl + 1] = { it.name, fmt_time(it.time), fmt_num(it.lines) }
		end

		-- Render table
		for _, l in ipairs(ui.table(tbl, state.width)) do
			table.insert(lines, l)
		end
	end

	return lines
end

local function tab_weekly()
	local s = state.stats
	local lines = {}
	local t_trend, t_hl = trend(s.week_time or 0, s.last_week_time or 0)

	-- Calculate this week's date range (Monday to Sunday)
	local now = os.time()
	local weekday = tonumber(os.date("%w", now)) -- 0=Sunday, 1=Monday, ...
	if weekday == 0 then
		weekday = 7
	end -- Sunday = 7
	local week_start = now - ((weekday - 1) * 86400)
	local week_end = week_start + (6 * 86400)
	local week_start_str = os.date("%b %d", week_start)
	local week_end_str = os.date("%b %d", week_end)
	local today_date = os.date("%Y-%m-%d", now)

	table.insert(lines, {})
	table.insert(lines, {
		{ "  📅 Weekly Summary  ", "exgreen" },
		{ "🗓️  ", "commentfg" },
		{ week_start_str .. " - " .. week_end_str, "exyellow" },
		{ "  │  ⏱️ ", "commentfg" },
		{ fmt_time(s.week_time or 0), "exgreen" },
		{ t_trend, t_hl },
		{ "  │  📝 ", "commentfg" },
		{ fmt_num(s.week_lines or 0), "exyellow" },
	})
	table.insert(lines, {})

	-- Daily Breakdown Table (This Week)
	local daily_activity = s.daily_activity or {}

	table.insert(lines, { { "  📊 Daily Breakdown (Mon-Sun)", "exgreen" } })
	table.insert(lines, {})

	-- Build daily table
	local day_names = { "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" }
	local tbl = { { "Day", "Time", "Lines", "Files", "Trend" } }

	local max_day_time = 0
	local max_day_name = ""

	for i = 0, 6 do
		local day_timestamp = week_start + (i * 86400)
		local day_date = os.date("%Y-%m-%d", day_timestamp)
		local last_week_date = os.date("%Y-%m-%d", day_timestamp - (7 * 86400))

		local day_stat = daily_activity[day_date] or { time = 0, lines = 0, files = 0 }
		local last_week_stat = daily_activity[last_week_date] or { time = 0, lines = 0, files = 0 }

		-- Track max for "Most Productive Day"
		if day_stat.time > max_day_time then
			max_day_time = day_stat.time
			max_day_name = day_names[i + 1]
		end

		-- Calculate trend vs same day last week
		local day_trend, _ = trend(day_stat.time, last_week_stat.time)
		local trend_str = "-"
		if day_trend ~= "" then
			trend_str = day_trend
		elseif last_week_stat.time == 0 and day_stat.time > 0 then
			trend_str = "🆕" -- New activity (no data last week)
		elseif day_stat.time == 0 and last_week_stat.time == 0 then
			trend_str = "-" -- No activity both weeks
		end

		-- Mark today
		local day_label = day_names[i + 1]
		if day_date == today_date then
			day_label = day_label .. " ★"
		end

		tbl[#tbl + 1] = {
			day_label,
			fmt_time(day_stat.time),
			fmt_num(day_stat.lines),
			tostring(day_stat.files),
			trend_str,
		}
	end

	for _, l in ipairs(ui.table(tbl, state.width - 8)) do
		table.insert(lines, l)
	end

	-- Week Insights (compact single line)
	local daily_avg = s.week_time and math.floor((s.week_time or 0) / 7) or 0
	if max_day_time > 0 then
		table.insert(lines, {})
		table.insert(lines, {
			{ "  📌 Most Productive: ", "commentfg" },
			{ max_day_name, "exgreen" },
			{ string.format(" (%s)", fmt_time(max_day_time)), "commentfg" },
			{ "  │  Daily Avg: ", "commentfg" },
			{ fmt_time(daily_avg), "exgreen" },
		})
	else
		table.insert(lines, {})
		table.insert(lines, {
			{ "  📌 Daily Average: ", "commentfg" },
			{ fmt_time(daily_avg), "exgreen" },
		})
	end
	table.insert(lines, {})

	-- Heatmap
	local hm = s.weekly_heatmap
	if hm and #hm > 0 then
		for _, l in ipairs(ui.heatmap(hm)) do
			table.insert(lines, l)
		end
	end

	return lines
end

local function tab_overview()
	local s = state.stats
	local lines = {}

	table.insert(lines, {})
	table.insert(lines, { { "  📊 Overview", "exgreen" } })
	table.insert(lines, {})

	-- Summary table (cross-period comparison)
	local tbl = {
		{ "Period", "Time", "Lines", "Files" },
		{ "Today", fmt_time(s.today_time or 0), fmt_num(s.today_lines or 0), tostring(s.today_files or 0) },
		{ "Week", fmt_time(s.week_time or 0), fmt_num(s.week_lines or 0), tostring(s.week_files or 0) },
		{ "Month", fmt_time(s.month_time or 0), fmt_num(s.month_lines or 0), tostring(s.month_files or 0) },
		{ "Total", fmt_time(s.total_time or 0), fmt_num(s.total_lines or 0), tostring(s.total_files or 0) },
	}
	for _, l in ipairs(ui.table(tbl, state.width - 8)) do
		table.insert(lines, l)
	end
	table.insert(lines, {})

	-- Top Achievements (show unlocked ones)
	local achs = s.achievements or {}
	local unlocked = {}
	for _, a in ipairs(achs) do
		if a.unlocked then
			table.insert(unlocked, a)
		end
	end

	if #unlocked > 0 then
		table.insert(lines, { { "  🏆 Top Achievements", "exgreen" } })
		table.insert(lines, {})

		for i = 1, math.min(5, #unlocked) do
			local a = unlocked[i]
			table.insert(lines, {
				{ "  " .. (a.icon or "🏆") .. " ", "normal" },
				{ a.name, "exgreen" },
				{ " - " .. a.description, "commentfg" },
			})
		end
		table.insert(lines, {})
	end

	-- Milestones (based on total time)
	local total_hours = math.floor((s.total_time or 0) / 3600)
	local milestones = {
		{ threshold = 50000, name = "Legendary Coder", icon = "👑" },
		{ threshold = 25000, name = "Master Coder", icon = "🏅" },
		{ threshold = 10000, name = "Elite Engineer", icon = "🎖️" },
		{ threshold = 7500, name = "Expert Programmer", icon = "🏆" },
		{ threshold = 5000, name = "Senior Developer", icon = "💎" },
		{ threshold = 3000, name = "Seasoned Developer", icon = "🔥" },
		{ threshold = 1500, name = "Advanced Coder", icon = "🚀" },
		{ threshold = 1000, name = "Century Coder", icon = "💯" },
		{ threshold = 750, name = "Committed Developer", icon = "⭐" },
		{ threshold = 500, name = "Dedicated Developer", icon = "⏰" },
		{ threshold = 250, name = "Rising Developer", icon = "🌱" },
		{ threshold = 100, name = "New Contributor", icon = "🐣" },
	}

	-- Find next milestone
	local next_milestone = nil
	for _, m in ipairs(milestones) do
		if total_hours < m.threshold then
			next_milestone = m
		end
	end

	if next_milestone then
		table.insert(lines, { { "  🎯 Next Milestone", "exgreen" } })
		table.insert(lines, {})

		local _ = math.floor((total_hours / next_milestone.threshold) * 100)
		local bar_len = math.floor((total_hours / next_milestone.threshold) * 25)
		local bar = string.rep("▓", bar_len) .. string.rep("░", 25 - bar_len)

		table.insert(lines, {
			{ "  " .. next_milestone.icon .. " ", "normal" },
			{ next_milestone.name, "exgreen" },
		})
		table.insert(lines, {
			{ "  ", "commentfg" },
			{ bar, "exyellow" },
			{ string.format("  %dh / %dh", total_hours, next_milestone.threshold), "commentfg" },
		})
	end

	return lines
end

local function tab_insights()
	local s = state.stats
	local lines = {}

	table.insert(lines, {})
	table.insert(lines, { { "  💡 Insights & Productivity Analysis", "exgreen" } })
	table.insert(lines, {})

	-- Calculate time-based hourly distribution from today's sessions
	local today_sessions = s.sessions or {}
	local hourly_time = calculate_hourly_time(today_sessions)

	-- Find peak hour based on TIME
	local peak_hour = 0
	local peak_hour_val = 0
	for hour, time in pairs(hourly_time) do
		if time > peak_hour_val then
			peak_hour_val = time
			peak_hour = hour
		end
	end

	-- Calculate longest session
	local longest_session = 0
	for _, session in ipairs(today_sessions) do
		if (session.duration or 0) > longest_session then
			longest_session = session.duration
		end
	end

	-- Calculate average session length
	local avg_session = 0
	if #today_sessions > 0 then
		local total = 0
		for _, session in ipairs(today_sessions) do
			total = total + (session.duration or 0)
		end
		avg_session = math.floor(total / #today_sessions)
	end

	-- Calculate consistency (days coded this week)
	local days_coded = 0
	local days_in_week = 7
	for _, hm in ipairs(s.weekly_heatmap or {}) do
		if hm.time and hm.time > 0 then
			days_coded = days_coded + 1
		end
	end
	local consistency = days_coded > 0 and math.floor(days_coded / days_in_week * 100) or 0

	-- Section: Coding Patterns
	table.insert(lines, { { "  ⏰ Coding Patterns", "exgreen" } })
	table.insert(lines, {})

	-- Aligned columns without table borders
	local col1_width = 20 -- Label width
	local function pad_right(str, width)
		return str .. string.rep(" ", width - #str)
	end

	if peak_hour_val > 0 then
		table.insert(lines, {
			{ "  " .. pad_right("Peak Hour:", col1_width), "commentfg" },
			{ string.format("%02d:00-%02d:00", peak_hour, peak_hour + 1), "exgreen" },
			{ string.format("  (%s)", fmt_time(peak_hour_val)), "commentfg" },
		})
	end

	local day_time = s.most_active_day_time or 0
	if day_time > 0 then
		table.insert(lines, {
			{ "  " .. pad_right("Most Active Day:", col1_width), "commentfg" },
			{ s.most_active_day or "N/A", "exgreen" },
			{ string.format("  (%s avg)", fmt_time(day_time)), "commentfg" },
		})
	end

	if longest_session > 0 then
		table.insert(lines, {
			{ "  " .. pad_right("Longest Session:", col1_width), "commentfg" },
			{ fmt_time(longest_session), "exgreen" },
		})
	end

	if #today_sessions > 0 then
		table.insert(lines, {
			{ "  " .. pad_right("Average Session:", col1_width), "commentfg" },
			{ fmt_time(avg_session), "exgreen" },
		})
	end

	local today_time = s.today_time or 0
	if today_time > 0 then
		local daily_avg = s.week_time and math.floor((s.week_time or 0) / 7) or today_time
		table.insert(lines, {
			{ "  " .. pad_right("Daily Average:", col1_width), "commentfg" },
			{ fmt_time(daily_avg), "exgreen" },
		})
	end

	table.insert(lines, {})

	-- Section: Time Distribution (4 blocks: Morning/Afternoon/Evening/Night)
	table.insert(lines, { { "  📊 Time Distribution", "exgreen" } })
	table.insert(lines, {})

	local time_blocks = {
		{ label = "Morning   (06-12)", start = 6, end_h = 11 },
		{ label = "Afternoon (12-18)", start = 12, end_h = 17 },
		{ label = "Evening   (18-24)", start = 18, end_h = 23 },
		{ label = "Night     (00-06)", start = 0, end_h = 5 },
	}

	-- Calculate total time and max for each block
	local total_time = 0
	for i = 0, 23 do
		total_time = total_time + (hourly_time[i] or 0)
	end

	local max_block_time = 0
	for _, block in ipairs(time_blocks) do
		local block_time = 0
		for h = block.start, block.end_h do
			block_time = block_time + (hourly_time[h] or 0)
		end
		if block_time > max_block_time then
			max_block_time = block_time
		end
	end

	-- Render time blocks with aligned columns
	local bar_width = 25
	for _, block in ipairs(time_blocks) do
		local block_time = 0
		for h = block.start, block.end_h do
			block_time = block_time + (hourly_time[h] or 0)
		end

		local pct = total_time > 0 and math.floor(block_time / total_time * 100) or 0
		local bar_pct = max_block_time > 0 and (block_time / max_block_time) or 0
		local bar_len = math.floor(bar_pct * bar_width)
		local bar = string.rep("█", bar_len) .. string.rep("░", bar_width - bar_len)

		-- Color based on percentage
		local bar_hl = "commentfg"
		if block_time > 0 then
			bar_hl = bar_pct > 0.7 and "exgreen" or bar_pct > 0.4 and "exyellow" or "exblue"
		end

		table.insert(lines, {
			{ "  " .. block.label .. " ", "commentfg" },
			{ bar, bar_hl },
			{ string.format(" %3d%%  ", pct), "commentfg" },
			{ fmt_time(block_time), "normal" },
		})
	end

	table.insert(lines, {})

	-- Section: Productivity Trends
	table.insert(lines, { { "  📈 Productivity Trends", "exgreen" } })
	table.insert(lines, {})

	table.insert(lines, {
		{ "  " .. pad_right("Consistency:", col1_width), "commentfg" },
		{
			string.format("%d%%", consistency),
			consistency >= 70 and "exgreen" or consistency >= 40 and "exyellow" or "exred",
		},
		{ string.format("  (coded %d/%d days this week)", days_coded, days_in_week), "commentfg" },
	})

	local streak = s.streak or 0
	local streak_text = streak > 0 and string.rep("🔥", math.min(streak, 7)) or "No streak"
	if streak > 7 then
		streak_text = streak_text .. " +" .. (streak - 7)
	end
	table.insert(lines, {
		{ "  " .. pad_right("Current Streak:", col1_width), "commentfg" },
		{ streak_text, streak > 0 and "exred" or "commentfg" },
		{ string.format("  (%d days)", streak), "commentfg" },
	})

	local best_streak = s.longest_streak or 0
	table.insert(lines, {
		{ "  " .. pad_right("Best Streak:", col1_width), "commentfg" },
		{ tostring(best_streak) .. " days", "exgreen" },
	})

	table.insert(lines, {})

	-- Section: Work Style Analysis
	if total_time > 0 then
		table.insert(lines, { { "  💼 Work Style Analysis", "exgreen" } })
		table.insert(lines, {})

		-- Determine work style based on time distribution
		local morning_time = 0
		local afternoon_time = 0
		local evening_time = 0
		for h = 6, 11 do
			morning_time = morning_time + (hourly_time[h] or 0)
		end
		for h = 12, 17 do
			afternoon_time = afternoon_time + (hourly_time[h] or 0)
		end
		for h = 18, 23 do
			evening_time = evening_time + (hourly_time[h] or 0)
		end

		local style = "Balanced"
		local peak_period = "throughout the day"
		local max_period = math.max(morning_time, afternoon_time, evening_time)

		if max_period == morning_time and morning_time > total_time * 0.5 then
			style = "Early Bird"
			peak_period = "mornings"
		elseif max_period == afternoon_time and afternoon_time > total_time * 0.5 then
			style = "Afternoon Coder"
			peak_period = "afternoons"
		elseif max_period == evening_time and evening_time > total_time * 0.5 then
			style = "Night Owl"
			peak_period = "evenings"
		end

		table.insert(lines, {
			{ "  📌 You're ", "commentfg" },
			{ "a " .. style, "exgreen" },
			{ " - peak productivity in " .. peak_period, "commentfg" },
		})

		if avg_session > 0 then
			local focus_level = avg_session > 7200 and "Deep Focus" or avg_session > 3600 and "Good Focus" or "Sprint Style"
			table.insert(lines, {
				{ "  📌 " .. focus_level .. " sessions", "commentfg" },
				{ string.format(" (avg %s)", fmt_time(avg_session)), "commentfg" },
			})
		end

		if #today_sessions > 0 then
			table.insert(lines, {
				{ string.format("  📌 Average %.1f sessions per day", #today_sessions), "commentfg" },
			})
		end
	end

	return lines
end

local function tab_languages()
	local s = state.stats
	local lines = {}
	table.insert(lines, {})
	table.insert(lines, { { "  💻 Languages", "exgreen" } })
	table.insert(lines, {})

	local data = s.languages
	if not data or not next(data) then
		table.insert(lines, { { "  No data yet", "commentfg" } })
		return lines
	end

	local items, total = {}, 0
	for name, stat in pairs(data) do
		total = total + (stat.time or 0)
		items[#items + 1] = { name = name, time = stat.time or 0, lines = stat.lines or 0, files = stat.files or 0 }
	end
	table.sort(items, function(a, b)
		return a.time > b.time
	end)

	-- Language table
	local tbl = { { "Language", "Time", "Lines", "Files", "%" } }
	for i = 1, math.min(30, #items) do
		local it = items[i]
		local pct = total > 0 and math.floor(it.time / total * 100) or 0
		tbl[#tbl + 1] =
			{ it.name, fmt_time(it.time), fmt_num(it.lines), tostring(it.files), progress(pct, 12) .. " " .. pct .. "%" }
	end
	for _, l in ipairs(ui.table(tbl, state.width - 8)) do
		table.insert(lines, l)
	end
	table.insert(lines, {})
	-- Language insights
	table.insert(lines, { { "  📊 Language Insights", "exgreen" } })
	table.insert(lines, {})

	local favorite = items[1]

	table.insert(lines, {
		{ "  ⭐ Favorite: ", "commentfg" },
		{ favorite.name, "exgreen" },
		{
			string.format(" (%s, %d%%)", fmt_time(favorite.time), math.floor(favorite.time / total * 100)),
			"commentfg",
		},
	})

	return lines
end

local function tab_projects()
	local s = state.stats
	local lines = {}
	table.insert(lines, {})
	table.insert(lines, { { "  🔥 Projects", "exgreen" } })
	table.insert(lines, {})

	local data = s.projects
	if not data or not next(data) then
		table.insert(lines, { { "  No data yet", "commentfg" } })
		return lines
	end

	local items, total = {}, 0
	for name, stat in pairs(data) do
		total = total + (stat.time or 0)
		items[#items + 1] = { name = name, time = stat.time or 0, lines = stat.lines or 0, files = stat.files or 0 }
	end
	table.sort(items, function(a, b)
		return a.time > b.time
	end)

	-- Projects table
	local tbl = { { "Project", "Time", "Lines", "Files", "%" } }
	for i = 1, math.min(30, #items) do
		local it = items[i]
		local pct = total > 0 and math.floor(it.time / total * 100) or 0
		tbl[#tbl + 1] =
			{ it.name, fmt_time(it.time), fmt_num(it.lines), tostring(it.files), progress(pct, 12) .. " " .. pct .. "%" }
	end
	for _, l in ipairs(ui.table(tbl, state.width - 8)) do
		table.insert(lines, l)
	end
	table.insert(lines, {})

	-- Project insights
	if #items > 0 then
		table.insert(lines, { { "  📊 Project Insights", "exgreen" } })
		table.insert(lines, {})

		-- Main project (most time)
		table.insert(lines, {
			{ "  🎯 Main Project: ", "commentfg" },
			{ items[1].name, "exgreen" },
			{ string.format(" (%s, %d%%)", fmt_time(items[1].time), math.floor(items[1].time / total * 100)), "commentfg" },
		})

		-- Project count
		table.insert(lines, {
			{ "  📁 Total Projects: ", "commentfg" },
			{ tostring(#items), "exgreen" },
		})

		-- Today's active project (if available)
		local today_stats = s.today_stats or {}
		local today_projects = today_stats.projects or {}
		if next(today_projects) then
			local today_items = {}
			for name, stat in pairs(today_projects) do
				table.insert(today_items, { name = name, time = stat.time or 0 })
			end
			table.sort(today_items, function(a, b)
				return a.time > b.time
			end)
			if #today_items > 0 then
				table.insert(lines, {
					{ "  ⚡ Active Today: ", "commentfg" },
					{ today_items[1].name, "exyellow" },
					{ string.format(" (%s)", fmt_time(today_items[1].time)), "commentfg" },
				})
			end
		end
	end

	return lines
end

local TAB_FNS = { tab_today, tab_weekly, tab_overview, tab_insights, tab_languages, tab_projects }

--------------------------------------------------------------------------------
-- RENDERING
--------------------------------------------------------------------------------

local function render()
	if not state.buf or not api.nvim_buf_is_valid(state.buf) then
		return
	end

	-- Build all lines
	local lines = {}

	-- Tabs header
	for _, l in ipairs(ui.tabs(TABS, state.tab)) do
		table.insert(lines, l)
	end
	table.insert(lines, {})

	-- Tab content
	for _, l in ipairs(TAB_FNS[state.tab]()) do
		table.insert(lines, l)
	end

	-- Footer
	table.insert(lines, {})
	table.insert(lines, { { "  <Tab>: Next │ <S-Tab>: Prev │ 1-6: Jump │ q: Close", "commentfg" } })

	-- Render
	ui.render(state.buf, lines, state.ns, state.width)
end

local function next_tab()
	state.tab = state.tab % #TABS + 1
	render()
end
local function prev_tab()
	state.tab = state.tab == 1 and #TABS or state.tab - 1
	render()
end
local function goto_tab(n)
	if n >= 1 and n <= #TABS then
		state.tab = n
		render()
	end
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

function M.open(stats)
	state.stats = stats or {}
	state.tab = 1
	state.width = math.min(110, math.floor(vim.o.columns * 0.85))
	state.ns = api.nvim_create_namespace("codeme")

	-- Calculate height
	local max_h = 0
	for i = 1, #TABS do
		state.tab = i
		max_h = math.max(max_h, #TAB_FNS[i]())
	end
	state.tab = 1
	local h = math.min(math.max(max_h + 6, 20), math.floor(vim.o.lines * 0.8))

	-- Create buffer
	state.buf = api.nvim_create_buf(false, true)
	vim.bo[state.buf].buftype = "nofile"
	vim.bo[state.buf].bufhidden = "wipe"

	-- Create window
	state.win = api.nvim_open_win(state.buf, true, {
		relative = "editor",
		width = state.width,
		height = h,
		row = math.floor((vim.o.lines - h) / 2),
		col = math.floor((vim.o.columns - state.width) / 2),
		border = "rounded",
		style = "minimal",
	})

	-- Keymaps
	local o = { buffer = state.buf, silent = true, nowait = true }
	vim.keymap.set("n", "<Tab>", next_tab, o)
	vim.keymap.set("n", "L", next_tab, o)
	vim.keymap.set("n", "<S-Tab>", prev_tab, o)
	vim.keymap.set("n", "H", prev_tab, o)
	for i = 1, 6 do
		vim.keymap.set("n", tostring(i), function()
			goto_tab(i)
		end, o)
	end

	local close = function()
		if state.win and api.nvim_win_is_valid(state.win) then
			api.nvim_win_close(state.win, true)
		end
		state.buf, state.win = nil, nil
	end
	vim.keymap.set("n", "q", close, o)
	vim.keymap.set("n", "<Esc>", close, o)

	-- Auto-close when leaving the buffer
	vim.api.nvim_create_autocmd("BufLeave", {
		buffer = state.buf,
		once = true,
		callback = close,
	})

	render()
end

return M
