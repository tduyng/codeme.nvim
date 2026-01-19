local M = {}

function M.fmt_time(s)
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

function M.fmt_num(n)
	if not n then
		return "0"
	end
	return tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

function M.progress(pct, w)
	pct = math.max(0, math.min(100, pct or 0))
	local f = math.floor(pct / 100 * w)
	return string.rep("█", f) .. string.rep("░", w - f)
end

function M.trend(cur, prev)
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

function M.get_streak_display(streak)
	if streak == 0 then
		return "─", "commentfg"
	elseif streak < 3 then
		return string.rep("🔥", streak), "exred"
	elseif streak < 7 then
		return string.rep("🔥", 3) .. " +" .. (streak - 3), "exred"
	elseif streak < 30 then
		return "🔥🔥🔥 ⚡ +" .. (streak - 3), "exred"
	elseif streak < 100 then
		return "🔥🔥🔥 ⚡⚡ +" .. (streak - 3), "exred"
	else
		return "🔥🔥🔥 ⚡⚡⚡ +" .. (streak - 3), "exred"
	end
end

function M.fmt_date(timestamp, context)
	if not timestamp then
		return "Unknown"
	end

	local now = os.time()
	local diff = now - timestamp

	-- Context-aware formatting
	if context == "relative" then
		if diff < 60 then
			return "just now"
		elseif diff < 3600 then
			local mins = math.floor(diff / 60)
			return string.format("%d min ago", mins)
		elseif diff < 86400 then
			local hours = math.floor(diff / 3600)
			return string.format("%d hour%s ago", hours, hours > 1 and "s" or "")
		elseif diff < 172800 then -- Less than 2 days
			return "yesterday"
		else
			local days = math.floor(diff / 86400)
			return string.format("%d days ago", days)
		end
	end

	-- Absolute formatting
	if diff < 86400 then
		return "Today " .. os.date("%H:%M", timestamp)
	elseif diff < 604800 then
		return os.date("%a %H:%M", timestamp) -- "Wed 14:30"
	elseif diff < 31536000 then
		return os.date("%b %d", timestamp) -- "Jan 15"
	else
		return os.date("%b %d, %Y", timestamp) -- "Jan 15, 2024"
	end
end

-- Format full date with day name (e.g., "Wednesday, Jan 15")
function M.fmt_date_full(date_str)
	if not date_str then
		return "Unknown"
	end
	local pattern = "(%d+)-(%d+)-(%d+)"
	local year, month, day = date_str:match(pattern)
	if not year then
		return "Unknown"
	end

	local timestamp = os.time({ year = year, month = month, day = day, hour = 12 })
	local today = os.date("%Y-%m-%d")

	if date_str == today then
		return os.date("%A, %b %d", timestamp)
	else
		return os.date("%a, %b %d", timestamp)
	end
end

-- Format date range (e.g., "Jan 13 - Jan 19")
function M.fmt_date_range(start_date, end_date)
	if not start_date or not end_date then
		return "Unknown"
	end

	local pattern = "(%d+)-(%d+)-(%d+)"
	local s_year, s_month, s_day = start_date:match(pattern)
	local e_year, e_month, e_day = end_date:match(pattern)

	if not s_year or not e_year then
		return "Unknown"
	end

	local start_ts = os.time({ year = s_year, month = s_month, day = s_day, hour = 12 })
	local end_ts = os.time({ year = e_year, month = e_month, day = e_day, hour = 12 })

	if s_year == e_year then
		if s_month == e_month then
			return string.format("%s %d-%d", os.date("%b", start_ts), tonumber(s_day), tonumber(e_day))
		else
			return string.format("%s - %s", os.date("%b %d", start_ts), os.date("%b %d", end_ts))
		end
	else
		return string.format("%s - %s", os.date("%b %d, %Y", start_ts), os.date("%b %d, %Y", end_ts))
	end
end

function M.fmt_time_range(start_ts, end_ts)
	if not start_ts or not end_ts then
		return "Unknown"
	end
	local start_time = os.date("%H:%M", start_ts)
	local end_time = os.date("%H:%M", end_ts)
	local duration = end_ts - start_ts
	return string.format("%s - %s (%s)", start_time, end_time, M.fmt_time(duration))
end

function M.fmt_metric_with_trend(current, previous, name)
	local trend_val, trend_hl = M.trend(current, previous)
	local formatted = M.fmt_time(current)

	if trend_val ~= "" then
		return string.format("%s %s", formatted, trend_val), trend_hl
	else
		return formatted, "normal"
	end
end

-- Format percentage with appropriate color
function M.fmt_percentage(value, good_threshold, great_threshold)
	good_threshold = good_threshold or 70
	great_threshold = great_threshold or 85

	local hl = "exred"
	if value >= great_threshold then
		hl = "exgreen"
	elseif value >= good_threshold then
		hl = "exyellow"
	end

	return string.format("%d%%", value), hl
end

-- Format week visual calendar (e.g., "✓✓✓✓✓○○")
function M.fmt_week_calendar(daily_activity, week_start_ts)
	local icons = {}
	for i = 0, 6 do
		local day_ts = week_start_ts + (i * 86400)
		local day_date = os.date("%Y-%m-%d", day_ts)
		local day_stat = daily_activity[day_date]
		local has_activity = day_stat and (day_stat.time or 0) > 0

		if has_activity then
			table.insert(icons, "✓")
		else
			table.insert(icons, "○")
		end
	end
	return table.concat(icons, "")
end

-- Format estimated time (e.g., "6:30 PM")
function M.fmt_estimated_time(timestamp)
	if not timestamp then
		return "Unknown"
	end
	return os.date("%I:%M %p", timestamp):gsub("^0", "")
end

-- Format session count with appropriate icon
function M.fmt_session_count(count)
	if count == 0 then
		return "No sessions", "commentfg"
	elseif count == 1 then
		return "1 session", "normal"
	elseif count >= 5 then
		return string.format("%d sessions 🔥", count), "exgreen"
	else
		return string.format("%d sessions", count), "normal"
	end
end

return M
