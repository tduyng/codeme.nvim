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

---Pad string to width (unicode-aware)
---@param s string
---@param w number
---@return string
function M.pad(s, w)
	local str = tostring(s or "")
	local current_w = vim.api.nvim_strwidth(str)
	local diff = tonumber(w or 0) - current_w
	return str .. (diff > 0 and string.rep(" ", diff) or "")
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
		return "_"
	end
	local year, month, day = date_str:match("(%d+)-(%d+)-(%d+)")
	if not year then
		return "_"
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

---Check if a string matches any pattern in a list (Expert Glob Engine)
---@param str string
---@param patterns string[]
---@param anchored boolean? If true, matches entire string. If false, matches substring.
---@return boolean
function M.matches_any(str, patterns, anchored)
	local lower_str = str:lower()
	for _, p in ipairs(patterns) do
		local lower_p = p:lower()
		local lua_pattern
		if p:match("[%^%$%%]") then
			lua_pattern = lower_p
		else
			lua_pattern = lower_p:gsub("([%(%)%.%+%-%?%[%]])", "%%%1")
			lua_pattern = lua_pattern:gsub("%*", ".*")
			if anchored then
				lua_pattern = "^" .. lua_pattern .. "$"
			end
		end
		if lower_str:match(lua_pattern) then
			return true
		end
	end
	return false
end

---Apply privacy masking to stats data (Recursive & Aggressive)
---@param data table The statistics payload
---@return table Masked data
function M.apply_privacy_mask(data)
	if type(data) ~= "table" then
		return data
	end

	local ok, codeme = pcall(require, "codeme")
	if not ok then
		return data
	end

	local config = codeme.get_config()
	local ignores = config.ignores or {}
	local dashboard_filters = ignores.dashboard or {}

	local ignore_projects = dashboard_filters.projects or {}
	local ignore_langs = dashboard_filters.languages or {}
	local ignore_files = dashboard_filters.files or {}

	-- Deep recursive traverser with context awareness
	local function traverse(obj, key)
		if type(obj) ~= "table" then
			if type(obj) == "string" then
				-- Check for project masking
				-- We match strings in fields named 'name', 'project', 'main_project', OR inside lists (numeric keys)
				local is_project_ctx = (
					key == "name"
					or key == "project"
					or key == "main_project"
					or key == "main_lang"
					or type(key) == "number"
				)
				if is_project_ctx and M.matches_any(obj, ignore_projects, true) then
					return "[private]"
				end

				-- Check for language filtering
				if
					(key == "language" or key == "main_language" or key == "main_lang") and M.matches_any(obj, ignore_langs, true)
				then
					return "[hidden]"
				end

				-- Check for file masking
				if key == "file" and M.matches_any(obj, ignore_files, false) then
					return "[private]"
				end
			end
			return obj
		end

		-- Detect if this is a sequential array
		local is_array = true
		local max_idx = 0
		for k, _ in pairs(obj) do
			if type(k) ~= "number" then
				is_array = false
				break
			end
			max_idx = math.max(max_idx, k)
		end

		local new_obj = {}
		for k, v in pairs(obj) do
			if not (type(k) == "string" and M.matches_any(k, ignore_projects, true)) then
				local val
				-- Filter out ignored languages from arrays (e.g. stats.languages)
				if k == "languages" and type(v) == "table" then
					local filtered = {}
					for _, item in ipairs(v) do
						local name = type(item) == "table" and item.name or item
						if not (type(name) == "string" and M.matches_any(name, ignore_langs, true)) then
							table.insert(filtered, traverse(item, k))
						end
					end
					val = filtered
				else
					-- Standard Recursion
					val = traverse(v, k)
				end

				new_obj[k] = val
			end
		end

		-- Rebuild array to ensure sequential indices
		if is_array and max_idx > 0 then
			local arr = {}
			local i = 1
			for idx = 1, max_idx do
				if new_obj[idx] ~= nil then
					arr[i] = new_obj[idx]
					i = i + 1
				end
			end
			return arr
		end

		return new_obj
	end

	return traverse(data, nil)
end

---Sanitize data (handles vim.NIL)
---@param value any
---@return any
function M.sanitize(value)
	if value == vim.NIL then
		return nil
	end

	if type(value) ~= "table" then
		return value
	end

	-- Check if this is an array or a dictionary
	local is_array = true
	local count = 0
	for k, _ in pairs(value) do
		count = count + 1
		if type(k) ~= "number" then
			is_array = false
			break
		end
	end

	if is_array and count > 0 then
		local out = {}
		for i = 1, count do
			out[i] = M.sanitize(value[i])
		end
		return out
	end

	-- It's a dictionary
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
