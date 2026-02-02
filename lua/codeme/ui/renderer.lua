local M = {}

---String width (unicode-aware)
---@param s string
---@return number
M.strwidth = vim.api.nvim_strwidth

---Pad string to width
---@param s string
---@param w number
---@return string
function M.pad(s, w)
	local diff = w - M.strwidth(s or "")
	return (s or "") .. (diff > 0 and string.rep(" ", diff) or "")
end

---Truncate with ellipsis
---@param s string
---@param w number
---@return string
function M.truncate(s, w)
	if M.strwidth(s or "") <= w then
		return s or ""
	end
	return string.sub(s, 1, w - 1) .. "…"
end

---Build table component
---@param rows table[] Array of rows (first row is header)
---@param width number Max width
---@return table[] Lines with highlight segments
function M.table(rows, width)
	if not rows or #rows == 0 or not rows[1] then
		return {}
	end

	local ncols = #rows[1]
	if ncols == 0 then
		return {}
	end

	-- Calculate column widths
	local widths = {}
	for c = 1, ncols do
		widths[c] = 0
		for _, row in ipairs(rows) do
			local cell = row[c] or ""
			widths[c] = math.max(widths[c], M.strwidth(tostring(cell)))
		end
	end

	-- Scale if needed
	local total = 4 + ncols * 3
	for c = 1, ncols do
		total = total + widths[c]
	end
	if total > width then
		local scale = (width - 4 - ncols * 3) / (total - 4 - ncols * 3)
		for c = 1, ncols do
			widths[c] = math.max(3, math.floor(widths[c] * scale))
		end
	end

	-- Build borders
	local function border(l, m, r)
		local parts = {}
		for c = 1, ncols do
			parts[c] = string.rep("─", widths[c] + 2)
		end
		return { { "  " .. l .. table.concat(parts, m) .. r, "commentfg" } }
	end

	-- Build output
	local out = { border("┌", "┬", "┐") }

	for i, row in ipairs(rows) do
		local line = { { "  │", "commentfg" } }
		for c = 1, ncols do
			local cell = M.truncate(tostring(row[c] or ""), widths[c])
			local hl = i == 1 and "exgreen" or "normal"
			table.insert(line, { " " .. M.pad(cell, widths[c]) .. " ", hl })
			table.insert(line, { "│", "commentfg" })
		end
		table.insert(out, line)
		if i == 1 then
			table.insert(out, border("├", "┼", "┤"))
		end
	end

	table.insert(out, border("└", "┴", "┘"))
	return out
end

---Build tabs header
---@param names string[] Tab names
---@param active number Active tab index
---@return table[] Lines
function M.tabs(names, active)
	local line = { { "  ", "normal" } }
	for i, name in ipairs(names) do
		local hl = i == active and "exgreen" or "commentfg"
		local prefix = i == active and "▸ " or "  "
		table.insert(line, { prefix .. name, hl })
		if i < #names then
			table.insert(line, { "  │  ", "commentfg" })
		end
	end
	return { line }
end

---Build progress bar
---@param pct number 0-100
---@param w number Width in characters
---@param filled_hl string Highlight for filled portion
---@return table[] Segments
function M.progress(pct, w, filled_hl)
	pct = math.max(0, math.min(100, pct or 0))
	local filled = math.floor(pct / 100 * w)
	return {
		{ string.rep("█", filled), filled_hl or "exgreen" },
		{ string.rep("░", w - filled), "commentfg" },
	}
end

---Render lines to buffer using extmarks
---@param buf number Buffer handle
---@param lines table[] Lines with highlight segments
---@param ns number Namespace
---@param width number Window width
function M.render(buf, lines, ns, width)
	vim.bo[buf].modifiable = true

	-- Clear previous
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	-- Set empty lines
	local empty = {}
	for _ = 1, #lines do
		empty[#empty + 1] = string.rep(" ", width)
	end
	vim.api.nvim_buf_set_lines(buf, 0, -1, true, empty)

	-- Render with extmarks
	for i, line in ipairs(lines) do
		vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
			virt_text = line,
			virt_text_pos = "overlay",
		})
	end

	vim.bo[buf].modifiable = false
end

function M.heatmap(days)
	if not days or #days == 0 then
		return { { { "  No activity data", "commentfg" } } }
	end

	local chars = { "░", "▒", "▓", "█", "█" }
	local colors = { "commentfg", "exblue", "excyan", "exgreen", "exyellow" }

	-- Helper: Parse date string "2026-01-15" into components
	local function parse_date(date_str)
		local year, month, day = date_str:match("(%d+)-(%d+)-(%d+)")
		return {
			year = tonumber(year),
			month = tonumber(month),
			day = tonumber(day),
		}
	end

	-- Helper: Get month name from date
	local function get_month_name(date_str)
		local parsed = parse_date(date_str)
		local timestamp = os.time({ year = parsed.year, month = parsed.month, day = 1 })
		return os.date("%B", timestamp), os.date("%b", timestamp) -- Full & short
	end

	-- Helper: Format date as "02/12" or "02/12'25" label with optional year (dd/mm format)
	local function format_week_label(date_str, show_year)
		local parsed = parse_date(date_str)
		local year_suffix = show_year and string.format("'%02d", parsed.year % 100) or "   "
		return string.format("%02d/%02d%s", parsed.day, parsed.month, year_suffix)
	end

	-- Helper: Calculate date range for a week (numeric format: "02-08" or "30-05")
	local function get_week_range(week)
		local first_day = week[1].date
		local last_day = week[#week].date -- Last day of week (may be incomplete)

		local f_parsed = parse_date(first_day)
		local l_parsed = parse_date(last_day)

		-- Just show day numbers: "02-08" or "30-05" (for cross-month)
		return string.format("%02d-%02d", f_parsed.day, l_parsed.day)
	end

	-- Group into weeks
	local weeks = {}
	for i = 1, #days, 7 do
		local week = {}
		for j = i, math.min(i + 6, #days) do
			week[#week + 1] = days[j]
		end
		-- Accept incomplete weeks (for smart date ranges)
		if #week > 0 then
			weeks[#weeks + 1] = week
		end
	end

	-- Calculate statistics for summary
	local max_time = 0
	local active_days = 0
	local total_non_future_days = 0
	for _, day in ipairs(days) do
		-- Only count non-future days
		if day.level ~= -1 then
			total_non_future_days = total_non_future_days + 1
			if day.time and day.time > 0 then
				active_days = active_days + 1
				max_time = math.max(max_time, day.time)
			end
		end
	end

	local consistency = total_non_future_days > 0 and math.floor((active_days / total_non_future_days) * 100) or 0

	-- Format max time as "4h 10m"
	local function format_time(seconds)
		local hours = math.floor(seconds / 3600)
		local minutes = math.floor((seconds % 3600) / 60)
		if hours > 0 then
			return string.format("%dh %dm", hours, minutes)
		else
			return string.format("%dm", minutes)
		end
	end

	-- Group weeks by month (we'll use this to determine when to show year)
	local weeks_by_month = {}
	local month_order = {} -- Preserve order
	local prev_year = nil

	for wi, week in ipairs(weeks) do
		local first_day = week[1] -- Monday of this week
		local month_name, month_abbr = get_month_name(first_day.date)
		local parsed = parse_date(first_day.date)
		local month_key = string.format("%d-%02d", parsed.year, parsed.month)

		-- Determine if we should show year (first week of new year or first week overall)
		local show_year = (prev_year ~= parsed.year)
		prev_year = parsed.year

		if not weeks_by_month[month_key] then
			weeks_by_month[month_key] = {
				month_name = month_name,
				month_abbr = month_abbr,
				year = parsed.year,
				weeks = {},
				order = #month_order + 1,
			}
			table.insert(month_order, month_key)
		end

		table.insert(weeks_by_month[month_key].weeks, {
			index = wi,
			week = week,
			label = format_week_label(first_day.date, show_year),
			range = get_week_range(week),
			show_year = show_year,
		})
	end

	-- Find current week (contains today)
	local today = os.date("%Y-%m-%d")
	local current_week_index = nil

	for wi, week in ipairs(weeks) do
		for _, day in ipairs(week) do
			if day.date == today then
				current_week_index = wi
				break
			end
		end
		if current_week_index then
			break
		end
	end

	-- Build output
	local out = {
		{ { "  🗓️  Activity Heatmap (Last " .. #weeks .. " Weeks)", "exgreen" } },
		{
			{ "  📊 ", "exyellow" },
			{ string.format("%d/%d days active", active_days, total_non_future_days), "normal" },
			{ string.format(" (%d%% consistency)", consistency), "commentfg" },
			{ " • Peak: ", "commentfg" },
			{ format_time(max_time), "exgreen" },
		},
		{},
	}

	-- Day labels header (show once at the top) - use day abbreviations
	local header = { { "          ", "normal" } }
	for _, d in ipairs({ "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" }) do
		table.insert(header, { d .. " ", "commentfg" })
	end
	table.insert(out, header)

	-- Render all weeks continuously (no blank lines between months)
	for _, month_key in ipairs(month_order) do
		local month_data = weeks_by_month[month_key]

		-- Render weeks in this month continuously
		for _, week_info in ipairs(month_data.weeks) do
			local is_current = (week_info.index == current_week_index)

			-- Week label with fixed width for perfect alignment (e.g., "12/02'25" or "01/06   ")
			local line = { { "  " .. week_info.label .. " ", week_info.show_year and "exgreen" or "commentfg" } }

			-- Day cells
			for i = 1, 7 do
				local day = week_info.week[i]
				if day then
					local lvl = math.max(0, math.min(4, day.level or 0))

					-- Mark current week's today with *
					local is_today = (day.date == today)
					local cell = chars[lvl + 1]

					if day.level == -1 then
						-- Future day
						table.insert(line, { "·   ", "commentfg" })
					else
						if is_today and is_current then
							table.insert(line, { cell .. "*  ", colors[lvl + 1] })
						else
							table.insert(line, { cell .. "   ", colors[lvl + 1] })
						end
					end
				else
					-- Pad incomplete weeks with empty cells
					table.insert(line, { "    ", "normal" })
				end
			end

			-- Date range on right
			table.insert(line, { "  " .. week_info.range, "commentfg" })

			-- THIS WEEK indicator
			if is_current then
				table.insert(line, { " ⭐", "exyellow" })
			end

			table.insert(out, line)
		end
	end

	-- Legend (compact)
	table.insert(out, {})
	local legend = { { "  ", "commentfg" } }
	table.insert(legend, { "░", "commentfg" })
	table.insert(legend, { " None  ", "commentfg" })
	table.insert(legend, { "▒", "exblue" })
	table.insert(legend, { " Low  ", "commentfg" })
	table.insert(legend, { "▓", "excyan" })
	table.insert(legend, { " Medium  ", "commentfg" })
	table.insert(legend, { "█", "exgreen" })
	table.insert(legend, { " High  ", "commentfg" })
	table.insert(legend, { "█", "exyellow" })
	table.insert(legend, { " Peak  ", "commentfg" })
	table.insert(legend, { "·", "commentfg" })
	table.insert(legend, { " Future", "commentfg" })
	table.insert(out, legend)

	return out
end

return M
