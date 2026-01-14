local M = {}
local api = vim.api

-- Core: String width (handles unicode)
M.strwidth = api.nvim_strwidth

-- Core: Pad string to width
function M.pad(s, w)
	local diff = w - M.strwidth(s or "")
	return (s or "") .. (diff > 0 and string.rep(" ", diff) or "")
end

-- Core: Truncate with ellipsis
function M.truncate(s, w)
	if M.strwidth(s or "") <= w then
		return s or ""
	end
	return string.sub(s, 1, w - 1) .. "…"
end

--------------------------------------------------------------------------------
-- COMPONENTS
--------------------------------------------------------------------------------

-- Simple table renderer
-- @param rows: array of arrays (first = header)
-- @param width: max width
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

	-- Scale if too wide
	local total = 4 + ncols * 3 -- borders + padding
	for c = 1, ncols do
		total = total + widths[c]
	end
	if total > width then
		local scale = (width - 4 - ncols * 3) / (total - 4 - ncols * 3)
		for c = 1, ncols do
			widths[c] = math.max(3, math.floor(widths[c] * scale))
		end
	end

	-- Border builder
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

-- Tabs header (inline style)
function M.tabs(names, active)
	if type(active) == "string" then
		for i, n in ipairs(names) do
			if n == active then
				active = i
				break
			end
		end
	end

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

-- Progress bar (returns segments for inline use)
function M.progress(pct, w, filled_hl)
	pct = math.max(0, math.min(100, pct or 0))
	local filled = math.floor(pct / 100 * w)
	return {
		{ string.rep("█", filled), filled_hl or "exgreen" },
		{ string.rep("░", w - filled), "commentfg" },
	}
end

-- GitHub-style heatmap
function M.heatmap(days)
	if not days or #days == 0 then
		return { { { "  No activity data", "commentfg" } } }
	end

	local chars = { "░", "▒", "▓", "█", "█" }
	local colors = { "commentfg", "exblue", "excyan", "exgreen", "exyellow" }

	-- Group into weeks
	local weeks = {}
	for i = 1, #days, 7 do
		local week = {}
		for j = i, math.min(i + 6, #days) do
			week[#week + 1] = days[j]
		end
		weeks[#weeks + 1] = week
	end

	local out = {
		{ { "  Activity (Last " .. #weeks .. " Weeks)", "exgreen" } },
		{},
	}

	-- Day labels
	local header = { { "      ", "normal" } }
	for _, d in ipairs({ "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" }) do
		table.insert(header, { d .. " ", "commentfg" })
	end
	table.insert(out, header)

	-- Weeks
	for wi, week in ipairs(weeks) do
		local line = { { string.format("  W%02d ", wi), "commentfg" } }
		for _, day in ipairs(week) do
			local lvl = math.max(0, math.min(4, day.level or 0))
			table.insert(line, { chars[lvl + 1] .. "   ", colors[lvl + 1] })
		end
		table.insert(out, line)
	end

	-- Legend
	table.insert(out, {})
	local legend = { { "  Less ", "commentfg" } }
	for i = 1, 5 do
		table.insert(legend, { chars[i] .. " ", colors[i] })
	end
	table.insert(legend, { "More", "commentfg" })
	table.insert(out, legend)

	return out
end

--------------------------------------------------------------------------------
-- RENDERING (minimal extmark-based renderer)
--------------------------------------------------------------------------------

-- Render all lines to buffer
function M.render(buf, lines, ns, width)
	vim.bo[buf].modifiable = true

	-- Clear previous
	api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	-- Set empty lines as base
	local empty = {}
	for _ = 1, #lines do
		empty[#empty + 1] = string.rep(" ", width)
	end
	api.nvim_buf_set_lines(buf, 0, -1, true, empty)

	-- Render extmarks
	for i, line in ipairs(lines) do
		api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
			virt_text = line,
			virt_text_pos = "overlay",
		})
	end

	vim.bo[buf].modifiable = false
end

return M
