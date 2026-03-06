local M = {}

---String width (unicode-aware)
---@param s any
---@return number
M.strwidth = function(s)
	if not s or s == vim.NIL then
		return 0
	end
	return vim.api.nvim_strwidth(tostring(s))
end

---Pad string to width (local fallback for safety)
local function pad(s, w)
	local str = tostring(s or "")
	local current_w = M.strwidth(str)
	local diff = tonumber(w or 0) - current_w
	return str .. (diff > 0 and string.rep(" ", diff) or "")
end

---Truncate with ellipsis (unicode-aware)
function M.truncate(s, w)
	local str = tostring(s or "")
	local target_w = tonumber(w or 0)
	if M.strwidth(str) <= target_w then
		return str
	end

	-- Simple unicode-aware truncation
	local current_w = 0
	local result = ""
	for i = 1, #str do
		local char = str:sub(i, i)
		-- Check if start of UTF-8 character
		local b = string.byte(char)
		if not b then
			break
		end
		if b < 128 or b >= 192 then
			local char_w = M.strwidth(char)
			if current_w + char_w + 1 > target_w then
				break
			end
			current_w = current_w + char_w
		end
		result = result .. char
	end

	return result .. "…"
end

---Build table component
---@param rows table[] Array of rows (first row is header)
---@param width number Max width
---@return table[] Lines with highlight segments
function M.table(rows, width)
	if not rows or #rows == 0 or not rows[1] then
		return {}
	end

	local target_width = tonumber(width) or 80
	local ncols = #rows[1]
	if ncols == 0 then
		return {}
	end

	-- Calculate column widths
	local widths = {}
	for c = 1, ncols do
		widths[c] = 0
		for _, row in ipairs(rows) do
			local cell = tostring(row[c] or "")
			widths[c] = math.max(widths[c], M.strwidth(cell))
		end
	end

	-- Scale if needed
	local total = 4 + ncols * 3
	for c = 1, ncols do
		total = total + widths[c]
	end
	if total > target_width then
		local available = target_width - 4 - ncols * 3
		local scale = available / (total - 4 - ncols * 3)
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
			table.insert(line, { " " .. pad(cell, widths[c]) .. " ", hl })
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
	local p = math.max(0, math.min(100, tonumber(pct) or 0))
	local width = math.max(1, tonumber(w) or 20)
	local filled = math.floor(p / 100 * width)
	return {
		{ string.rep("█", filled), filled_hl or "exgreen" },
		{ string.rep("░", math.max(0, width - filled)), "commentfg" },
	}
end

---Render lines to buffer using extmarks
---@param buf number Buffer handle
---@param lines table[] Lines with highlight segments
---@param ns number Namespace
---@param width number Window width
function M.render(buf, lines, ns, width)
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local target_w = tonumber(width) or 80
	vim.bo[buf].modifiable = true

	-- Clear previous
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	-- Set empty lines
	local empty = {}
	for _ = 1, #lines do
		empty[#empty + 1] = string.rep(" ", target_w)
	end
	vim.api.nvim_buf_set_lines(buf, 0, -1, true, empty)

	-- Render with extmarks
	for i, line in ipairs(lines) do
		if line and #line > 0 then
			vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
				virt_text = line,
				virt_text_pos = "overlay",
			})
		end
	end

	vim.bo[buf].modifiable = false
end

---Build a card (bordered box)
---@param title string
---@param lines table[] Lines inside the card
---@param width number Total width
---@param color string? Border highlight group
---@return table[]
function M.card(title, lines, width, color)
	local hl = color or "commentfg"
	local target_w = math.max(10, tonumber(width) or 40)
	local out = {}

	-- Top border
	local title_str = tostring(title or "")
	local title_len = M.strwidth(title_str)
	local top
	if title_str ~= "" then
		local left_line = string.rep("─", 2)
		local available = target_w - 4 - 2 - 1 - title_len - 1
		local right_line = string.rep("─", math.max(0, available))
		top = { { "  ╭" .. left_line .. " " .. title_str .. " " .. right_line .. "╮", hl } }
	else
		top = { { "  ╭" .. string.rep("─", math.max(0, target_w - 4)) .. "╮", hl } }
	end
	table.insert(out, top)

	-- Content
	for _, line in ipairs(lines) do
		local content_width = 0
		for _, seg in ipairs(line) do
			content_width = content_width + M.strwidth(tostring(seg[1] or ""))
		end

		local l = { { "  │ ", hl } }
		for _, seg in ipairs(line) do
			table.insert(l, seg)
		end
		local p = math.max(0, target_w - 6 - content_width)
		table.insert(l, { string.rep(" ", p), "normal" })
		table.insert(l, { " │", hl })
		table.insert(out, l)
	end

	-- Bottom border
	table.insert(out, { { "  ╰" .. string.rep("─", math.max(0, target_w - 4)) .. "╯", hl } })

	return out
end

---Place multiple blocks side-by-side
---@param arg1 any Array of blocks OR first block
---@param arg2 any Second block OR spacing gap
---@param arg3 any Spacing gap (if using old signature)
---@return table[]
function M.hbox(arg1, arg2, arg3)
	local blocks, gap
	-- Robust signature detection
	if type(arg2) == "table" then
		-- Old: hbox(left, right, gap)
		blocks = { arg1, arg2 }
		gap = tonumber(arg3) or 4
	elseif
		type(arg1) == "table"
		and arg1[1]
		and type(arg1[1]) == "table"
		and arg1[1][1]
		and type(arg1[1][1]) == "table"
	then
		-- New: hbox({b1, b2, ...}, gap)
		blocks = arg1
		gap = tonumber(arg2) or 4
	else
		-- Fallback
		blocks = type(arg1) == "table" and arg1 or { arg1 }
		gap = tonumber(arg2) or 4
	end

	local out = {}
	local max_lines = 0
	for _, block in ipairs(blocks) do
		if type(block) == "table" then
			max_lines = math.max(max_lines, #block)
		end
	end

	local gap_val = math.max(0, tonumber(gap) or 4)
	local gap_str = string.rep(" ", gap_val)

	-- Calculate widths for each block
	local widths = {}
	for b_idx, block in ipairs(blocks) do
		local w = 0
		if type(block) == "table" then
			for _, line in ipairs(block) do
				local line_w = 0
				if type(line) == "table" then
					for _, seg in ipairs(line) do
						line_w = line_w + M.strwidth(tostring(seg[1] or ""))
					end
				end
				w = math.max(w, line_w)
			end
		end
		widths[b_idx] = w
	end

	for i = 1, max_lines do
		local final_line = {}
		for b_idx, block in ipairs(blocks) do
			local line = (type(block) == "table" and block[i]) or {}
			local cur_w = 0
			if type(line) == "table" then
				for _, seg in ipairs(line) do
					table.insert(final_line, seg)
					cur_w = cur_w + M.strwidth(tostring(seg[1] or ""))
				end
			end

			-- Add padding to align next block
			if b_idx < #blocks then
				local pad_val = math.max(0, (widths[b_idx] or 0) - cur_w)
				table.insert(final_line, { string.rep(" ", pad_val) .. gap_str, "normal" })
			end
		end
		table.insert(out, final_line)
	end

	return out
end

---Vertical histogram using Unicode block elements
---@param data number[] Values
---@param max_val number?
---@param height number? Max 1 currently supported for sparklines
---@param hl_group string?
---@param spacing number? Number of spaces after each bar (default 1)
---@return table[] Segments
function M.histogram(data, max_val, height, hl_group, spacing)
	local blocks = { " ", " ", "▂", "▃", "▄", "▅", "▆", "▇", "█" }
	local max = tonumber(max_val) or 0
	local data_list = type(data) == "table" and data or {}
	local bar_spacing = math.max(0, tonumber(spacing) or 1)

	if max == 0 then
		for _, v in ipairs(data_list) do
			local num = tonumber(v) or 0
			if num > max then
				max = num
			end
		end
	end

	local segs = {}
	for _, v in ipairs(data_list) do
		local num = tonumber(v) or 0
		local level = 1
		if max > 0 and num > 0 then
			level = math.floor((num / max) * 7) + 2
		elseif num > 0 then
			level = 2
		end
		level = math.min(9, math.max(1, level))
		table.insert(segs, { blocks[level] .. string.rep(" ", bar_spacing), hl_group or "exgreen" })
	end
	return segs
end

---Render prominent metric pills
---@param metrics table[] {icon, label, value, color}
---@return table[] Lines
function M.metric_pills(metrics)
	local line = { { "  ", "normal" } }
	local m_list = type(metrics) == "table" and metrics or {}
	for i, m in ipairs(m_list) do
		table.insert(line, { " " .. tostring(m.icon or "") .. " " .. tostring(m.label or "") .. ": ", "commentfg" })
		table.insert(line, { " " .. tostring(m.value or "") .. " ", m.color or "exgreen" })
		if i < #m_list then
			table.insert(line, { "    ", "normal" })
		end
	end
	return { line }
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

	-- Helper: Calculate date range for a week
	local function get_week_range(week)
		local first_day = week[1].date
		local last_day = week[#week].date
		local f_parsed = parse_date(first_day)
		local l_parsed = parse_date(last_day)
		return string.format("%02d-%02d", f_parsed.day, l_parsed.day)
	end

	-- Group into weeks
	local weeks = {}
	for i = 1, #days, 7 do
		local week = {}
		for j = i, math.min(i + 6, #days) do
			week[#week + 1] = days[j]
		end
		if #week > 0 then
			weeks[#weeks + 1] = week
		end
	end

	-- Calculate statistics
	local max_time = 0
	local active_days = 0
	local total_non_future_days = 0
	for _, day in ipairs(days) do
		if day.level ~= -1 then
			total_non_future_days = total_non_future_days + 1
			if day.time and day.time > 0 then
				active_days = active_days + 1
				max_time = math.max(max_time, day.time)
			end
		end
	end

	local consistency = total_non_future_days > 0 and math.floor((active_days / total_non_future_days) * 100) or 0

	local function format_time(seconds)
		local hours = math.floor(seconds / 3600)
		local minutes = math.floor((seconds % 3600) / 60)
		if hours > 0 then
			return string.format("%dh %dm", hours, minutes)
		else
			return string.format("%dm", minutes)
		end
	end

	-- Group weeks by month
	local weeks_by_month = {}
	local month_order = {}
	local prev_year = nil

	for wi, week in ipairs(weeks) do
		local first_day = week[1]
		local month_name, month_abbr = get_month_name(first_day.date)
		local parsed = parse_date(first_day.date)
		local month_key = string.format("%d-%02d", parsed.year, parsed.month)

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

	local header = { { "          ", "normal" } }
	for _, d in ipairs({ "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" }) do
		table.insert(header, { d .. " ", "commentfg" })
	end
	table.insert(out, header)

	for _, month_key in ipairs(month_order) do
		local month_data = weeks_by_month[month_key]

		for _, week_info in ipairs(month_data.weeks) do
			local is_current = (week_info.index == current_week_index)
			local line = { { "  " .. week_info.label .. " ", week_info.show_year and "exgreen" or "commentfg" } }

			for i = 1, 7 do
				local day = week_info.week[i]
				if day then
					local lvl = math.max(0, math.min(4, day.level or 0))
					local is_today = (day.date == today)
					local cell = chars[lvl + 1]

					if day.level == -1 then
						table.insert(line, { "·   ", "commentfg" })
					else
						if is_today and is_current then
							table.insert(line, { cell .. "*  ", colors[lvl + 1] })
						else
							table.insert(line, { cell .. "   ", colors[lvl + 1] })
						end
					end
				else
					table.insert(line, { "    ", "normal" })
				end
			end

			table.insert(line, { "  " .. week_info.range, "commentfg" })
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
