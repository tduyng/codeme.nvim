local M = {}

-- Format seconds into human-readable duration
function M.format_duration(seconds)
	if not seconds or seconds == 0 then
		return "0s"
	end

	if seconds < 60 then
		return string.format("%ds", seconds)
	elseif seconds < 3600 then
		local mins = math.floor(seconds / 60)
		return string.format("%dm", mins)
	else
		local hours = math.floor(seconds / 3600)
		local mins = math.floor((seconds % 3600) / 60)
		if mins > 0 then
			return string.format("%dh %dm", hours, mins)
		else
			return string.format("%dh", hours)
		end
	end
end

-- Format large numbers with commas
function M.format_number(n)
	if not n then
		return "0"
	end

	local s = tostring(n)
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return formatted:gsub("^,", "")
end

-- Get date range for a given number of days back
function M.get_date_range(days_back)
	local dates = {}
	local today = os.time()

	for i = days_back - 1, 0, -1 do
		local date = os.date("%Y-%m-%d", today - i * 86400)
		table.insert(dates, date)
	end

	return dates
end

-- Get week range for calendar view
function M.get_week_range(weeks_back)
	local weeks = {}
	local today = os.time()

	for week = weeks_back - 1, 0, -1 do
		local week_dates = {}
		for day = 0, 6 do
			local days_ago = week * 7 + day
			local date = os.date("%Y-%m-%d", today - days_ago * 86400)
			table.insert(week_dates, date)
		end
		table.insert(weeks, week_dates)
	end

	return weeks
end

-- Parse date string to timestamp
function M.parse_date(date_str)
	local year, month, day = date_str:match("(%d+)-(%d+)-(%d+)")
	if year and month and day then
		return os.time({ year = year, month = month, day = day })
	end
	return nil
end

-- Get day of week name
function M.get_day_name(date_str)
	local timestamp = M.parse_date(date_str)
	if timestamp then
		return os.date("%A", timestamp)
	end
	return ""
end

-- Calculate percentage
function M.calculate_percent(value, total)
	if not total or total == 0 then
		return 0
	end
	return math.floor((value / total) * 100)
end

return M
