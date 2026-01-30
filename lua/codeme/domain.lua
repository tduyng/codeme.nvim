local M = {}

---Format seconds to human-readable duration
---@param seconds number
---@return string
function M.format_duration(seconds)
	if not seconds or seconds == 0 then
		return "0s"
	end

	if seconds < 60 then
		return string.format("%ds", seconds)
	elseif seconds < 3600 then
		return string.format("%dm", math.floor(seconds / 60))
	else
		local hours = math.floor(seconds / 3600)
		local mins = math.floor((seconds % 3600) / 60)
		if mins > 0 then
			return string.format("%dh %dm", hours, mins)
		end
		return string.format("%dh", hours)
	end
end

---Format number with commas
---@param n number
---@return string
function M.format_number(n)
	if not n then
		return "0"
	end
	local s = tostring(math.floor(n))
	return s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

---Calculate percentage
---@param value number
---@param total number
---@return number
function M.calculate_percentage(value, total)
	if not total or total == 0 then
		return 0
	end
	return math.floor((value / total) * 100)
end

---Get progress bar characters
---@param percentage number 0-100
---@param width number Bar width in characters
---@return string filled, string empty
function M.get_progress_bar(percentage, width)
	percentage = math.max(0, math.min(100, percentage))
	local filled = math.floor(percentage / 100 * width)
	return string.rep("█", filled), string.rep("░", width - filled)
end

---Parse ISO date to timestamp
---@param iso_string string
---@return number|nil
function M.parse_iso_date(iso_string)
	if not iso_string or iso_string == "" then
		return nil
	end
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

---Format date string
---@param date_str string YYYY-MM-DD
---@return string
function M.format_date(date_str)
	if not date_str then
		return "Unknown"
	end
	local year, month, day = date_str:match("(%d+)-(%d+)-(%d+)")
	if not year then
		return "Unknown"
	end

	local timestamp = os.time({ year = year, month = month, day = day, hour = 12 })
	local today = os.date("%Y-%m-%d")

	if date_str == today then
		return os.date("%A, %b %d", timestamp)
	end
	return os.date("%a, %b %d", timestamp)
end

---Calculate streak display
---@param streak_days number
---@return string icon, string color
function M.get_streak_display(streak_days)
	if streak_days == 0 then
		return "─", "commentfg"
	elseif streak_days < 3 then
		return string.rep("🔥", streak_days), "exred"
	elseif streak_days < 7 then
		return "🔥🔥🔥 +" .. (streak_days - 3), "exred"
	elseif streak_days < 30 then
		return "🔥🔥🔥 ⚡ +" .. (streak_days - 3), "exred"
	else
		return "🔥🔥🔥 ⚡⚡ +" .. (streak_days - 3), "exred"
	end
end

---Get trend indicator
---@param current number
---@param previous number
---@return string text, string color
function M.get_trend(current, previous)
	if not current or not previous or previous == 0 then
		return "", "commentfg"
	end

	local diff = current - previous
	local pct = math.floor(math.abs(diff) / previous * 100)

	if diff > 0 then
		return " ↑" .. pct .. "%", "exgreen"
	elseif diff < 0 then
		return " ↓" .. pct .. "%", "exred"
	end
	return " →", "commentfg"
end

---Safe array length (handles vim.NIL)
---@param arr any
---@return number
function M.safe_length(arr)
	if not arr or arr == vim.NIL then
		return 0
	end
	if type(arr) == "table" then
		return #arr
	end
	return 0
end

---Get top N items from list
---@param list table
---@param max number
---@return string
function M.top_items(list, max)
	if not list or #list == 0 then
		return ""
	end

	max = max or #list
	local result = {}

	for i = 1, math.min(max, #list) do
		result[#result + 1] = tostring(list[i])
	end

	if #list > max then
		result[#result + 1] = string.format("+%d more", #list - max)
	end

	return table.concat(result, ", ")
end

function M.sanitize(value)
	-- vim.NIL is the sentinel that vim.json.decode uses for JSON null.
	-- It is neither nil nor false, so `value or {}` does NOT catch it.
	if value == vim.NIL then
		return nil
	end

	if type(value) ~= "table" then
		return value
	end

	local out = {}
	for k, v in pairs(value) do
		local sk = M.sanitize(k)
		local sv = M.sanitize(v)
		if sk ~= nil then
			out[sk] = sv
		end
	end
	return out
end

return M
