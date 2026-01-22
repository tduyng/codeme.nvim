local M = {}

-- Parse ISO timestamp to Lua time
function M.parse_timestamp(iso_string)
	if not iso_string or iso_string == "" then
		return nil
	end
	-- Basic ISO parsing - backend now provides formatted timestamps
	local pattern = "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)"
	local year, month, day, hour, min, sec = iso_string:match(pattern)
	if year then
		return os.time({
			year = tonumber(year),
			month = tonumber(month),
			day = tonumber(day),
			hour = tonumber(hour),
			min = tonumber(min),
			sec = tonumber(sec),
		})
	end
	return nil
end

-- Get short day name (Mon, Tue, etc.)
function M.get_day_name_short(date_str)
	local days = { "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" }
	local t =
		os.time({ year = date_str:match("(%d+)"), month = date_str:match("-(%d+)-"), day = date_str:match("-(%d+)$") })
	return days[os.date("*t", t).wday]
end

-- Get full day name
function M.get_day_name(date_str)
	local days = { "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" }
	local t =
		os.time({ year = date_str:match("(%d+)"), month = date_str:match("-(%d+)-"), day = date_str:match("-(%d+)$") })
	return days[os.date("*t", t).wday]
end

-- Calculate week start (Monday) for given timestamp
function M.get_week_start(timestamp)
	local t = os.date("*t", timestamp)
	local days_since_monday = (t.wday - 2) % 7
	return timestamp - (days_since_monday * 86400)
end

-- Categorize hour into time of day
function M.get_time_of_day(hour)
	if hour >= 5 and hour < 12 then
		return "Morning"
	elseif hour >= 12 and hour < 17 then
		return "Afternoon"
	elseif hour >= 17 and hour < 22 then
		return "Evening"
	else
		return "Night"
	end
end

-- Find peak hour from backend data (backend now calculates this)
function M.find_peak_hour(stats)
	return stats.most_active_hour or 14
end

-- Session analysis simplified - backend now provides rich session data
function M.calculate_session_breakdown(stats)
	local sessions = stats.sessions or {}
	local total_sessions = #sessions

	if total_sessions == 0 then
		return {
			total_sessions = 0,
			total_time = 0,
			avg_length = 0,
			longest_session = 0,
		}
	end

	-- Backend already calculates these, just extract them
	local total_time = stats.today_time or 0
	local avg_length = stats.avg_session_length or 0
	local longest_session = 0

	-- Find longest session from today's sessions
	for _, session in ipairs(sessions) do
		if session.duration > longest_session then
			longest_session = session.duration
		end
	end

	return {
		total_sessions = total_sessions,
		total_time = total_time,
		avg_length = avg_length,
		longest_session = longest_session,
	}
end

-- Group sessions by time of day (simplified - backend provides session times)
function M.group_sessions_by_time_of_day(stats)
	local sessions = stats.sessions or {}
	local groups = {
		morning = { sessions = {}, total_time = 0 },
		afternoon = { sessions = {}, total_time = 0 },
		evening = { sessions = {}, total_time = 0 },
		night = { sessions = {}, total_time = 0 },
	}

	for _, session in ipairs(sessions) do
		local start_time = M.parse_timestamp(session.start)
		if start_time then
			local hour = tonumber(os.date("%H", start_time))
			local time_period = string.lower(M.get_time_of_day(hour))

			if groups[time_period] then
				table.insert(groups[time_period].sessions, session)
				groups[time_period].total_time = groups[time_period].total_time + session.duration
			end
		end
	end

	return groups
end

-- Calculate focus score (backend now provides this)
function M.calculate_focus_score(sessions)
	-- Backend calculates focus_score, just return it with a label
	local score = vim.g.codeme_stats and vim.g.codeme_stats.focus_score or 0

	local label
	if score >= 85 then
		label = "Deep Focus 🎯"
	elseif score >= 70 then
		label = "Good Focus ⭐"
	elseif score >= 50 then
		label = "Moderate Focus 💼"
	else
		label = "Sprint Style 🏃"
	end

	return score, label
end

-- Estimate goal completion time (backend provides goals and current progress)
function M.estimate_goal_completion(current_time, goal_time)
	if goal_time <= 0 or current_time >= goal_time then
		return nil -- Already reached or invalid goal
	end

	local remaining = goal_time - current_time
	local now = os.time()

	-- Simple estimation: if it's before 6 PM, assume work continues until 10 PM
	local current_hour = tonumber(os.date("%H", now))
	if current_hour >= 22 then
		return nil -- Too late to estimate
	end

	-- local remaining_work_hours = math.max(1, 22 - current_hour)
	local estimated_completion = now + remaining

	return estimated_completion
end

-- Safe array operations for userdata compatibility
function M.safe_length(arr)
	if not arr then
		return 0
	end

	-- Check for vim.NIL (null from JSON)
	if arr == vim.NIL then
		return 0
	end

	-- If it's a regular Lua table, use #
	if type(arr) == "table" then
		return #arr
	end

	-- Handle userdata that represents null/empty arrays
	if type(arr) == "userdata" then
		-- Convert userdata to string to check if it represents null
		local str_rep = tostring(arr)
		if str_rep == "null" or str_rep == "vim.NIL" then
			return 0
		end
	end

	return 0
end

-- Convert userdata array to Lua table safely
function M.safe_array_to_table(arr)
	if not arr then
		return {}
	end

	-- Check for vim.NIL (null from JSON)
	if arr == vim.NIL then
		return {}
	end

	-- Already a table
	if type(arr) == "table" then
		return arr
	end

	-- Handle userdata that represents null
	if type(arr) == "userdata" then
		local str_rep = tostring(arr)
		if str_rep == "null" or str_rep == "vim.NIL" then
			return {}
		end
	end

	return {}
end

function M.format_list(data, max_items)
	max_items = max_items or 5

	-- Handle empty or invalid data
	local count = M.safe_length(data)
	if not data or count == 0 then
		return ""
	end

	-- Convert to table if needed
	local items_table = M.safe_array_to_table(data)

	-- Truncate to max_items
	local display = {}
	for i = 1, math.min(max_items, #items_table) do
		table.insert(display, items_table[i])
	end

	local result = table.concat(display, ", ")
	if count > max_items then
		result = result .. " ..."
	end

	return result
end

function M.get_relative_path(file_path, project_root)
	if not file_path or file_path == "" then
		return ""
	end
	project_root = project_root or vim.fn.getcwd()
	if file_path:sub(1, #project_root) == project_root then
		return file_path:sub(#project_root + 2) -- +2 to skip separator
	end
	return file_path
end

function M.format_items_list(items, key, max_items)
	max_items = max_items or 5

	if not items or #items == 0 then
		return ""
	end

	-- Extract the key from each item
	local extracted = {}
	for _, item in ipairs(items) do
		if item[key] then
			table.insert(extracted, tostring(item[key]))
		end
	end

	-- Use format_list to display with truncation
	return M.format_list(extracted, max_items)
end

function M.get_top_from_session_list(list, max)
	if not list or #list == 0 then
		return ""
	end

	max = max or #list
	local result = {}

	for i = 1, math.min(max, #list) do
		result[#result + 1] = list[i]
	end

	if #list > max then
		result[#result + 1] = "..."
	end

	return table.concat(result, ", ")
end

function M.get_top_projects(session, max)
	return M.get_top_from_session_list(session.projects, max or 3)
end

function M.get_top_languages(session, max)
	return M.get_top_from_session_list(session.languages, max or 5)
end

return M
