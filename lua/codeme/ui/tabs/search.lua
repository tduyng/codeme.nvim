local util = require("codeme.util")
local renderer = require("codeme.ui.renderer")
local backend = require("codeme.backend")

local M = {}

-- Tab state (persists while dashboard is open)
local state = {
	date = os.date("%Y-%m-%d"), -- default to today
	data = nil, -- DayStats or nil
	loading = false,
	error = nil,
}

---Fetch day stats from backend
---@param refresh_fn fun() Callback to re-render the dashboard
local function fetch_day(refresh_fn)
	state.loading = true
	state.error = nil
	refresh_fn()

	backend.get_day_stats(state.date, function(data)
		vim.schedule(function()
			state.loading = false
			if not data or (not data.date and not data.total_time) then
				state.error = "Failed to fetch data"
			else
				state.data = data
			end
			refresh_fn()
		end)
	end)
end

---Shift current date by N days
---@param days number Number of days to shift
---@param refresh_fn fun()
local function shift_date(days, refresh_fn)
	local y, m, d = state.date:match("(%d+)-(%d+)-(%d+)")
	if not y then
		state.date = os.date("%Y-%m-%d")
		y, m, d = state.date:match("(%d+)-(%d+)-(%d+)")
	end

	local t = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d) + days, hour = 12 })
	state.date = os.date("%Y-%m-%d", t)
	state.data = nil
	fetch_day(refresh_fn)
end

---Handle keypresses for search tab
---@param key string The key pressed
---@param refresh_fn fun()
function M.on_key(key, refresh_fn)
	if key == "[" then
		shift_date(-1, refresh_fn)
		return true
	elseif key == "]" then
		shift_date(1, refresh_fn)
		return true
	elseif key == "<CR>" or key == "\r" or key == "\n" then
		fetch_day(refresh_fn)
		return true
	elseif key == "/" then
		vim.ui.input({ prompt = "Go to date (YYYY-MM-DD): ", default = state.date }, function(input)
			if input and input:match("^%d%d%d%d%-%d%d%-%d%d$") then
				state.date = input
				state.data = nil
				fetch_day(refresh_fn)
			elseif input then
				vim.notify("CodeMe: Invalid date format. Use YYYY-MM-DD", vim.log.levels.WARN)
			end
		end)
		return true
	end
	return false
end

---Called when tab is entered
---@param refresh_fn fun()
function M.on_enter(refresh_fn)
	if not state.data and not state.loading then
		fetch_day(refresh_fn)
	end
end

function M.render(stats, width, height)
	local lines = {}

	-- Stylized Date Header
	table.insert(lines, {})
	local header_content = {
		{ "  [ ", "commentfg" },
		{ "←", "exyellow" },
		{ " ] ", "commentfg" },
		{ "  " .. os.date("%A, %B %d, %Y", util.parse_iso_date(state.date .. "T12:00:00") or os.time()), "exgreen" },
		{ "  [ ", "commentfg" },
		{ "→", "exyellow" },
		{ " ] ", "commentfg" },
	}
	table.insert(lines, header_content)
	table.insert(lines, { { "    " .. state.date .. "  (Press / to jump, [ ] to navigate)", "commentfg" } })
	table.insert(lines, {})

	if state.loading then
		table.insert(lines, { { "  ⌛ Loading historic data...", "exyellow" } })
		table.insert(lines, {})
		return lines
	end

	if state.error then
		table.insert(lines, { { "  ❌ Error: " .. state.error, "exred" } })
		table.insert(lines, {})
		return lines
	end

	local data = state.data
	if not data or data.is_empty then
		table.insert(lines, { { "  No records found for this date.", "commentfg" } })
		table.insert(lines, {})
		return lines
	end

	-- Summary Card
	local total_time = data.total_time or 0
	local focus_score = data.focus_score or 0

	local summary_lines = {
		{ { "Total Time:  ", "commentfg" }, { util.format_duration(total_time), "exgreen" } },
		{ { "Focus Score: ", "commentfg" }, { focus_score .. "%", focus_score >= 70 and "exgreen" or "exyellow" } },
		{ { "Lines:       ", "commentfg" }, { util.format_number(data.total_lines or 0), "normal" } },
	}
	local summary_card = renderer.card("Daily Overview", summary_lines, 40, "exgreen")

	-- Identity Card
	local identity_lines = {
		{ { "Main Project:  ", "commentfg" }, { data.main_project or "-", "exblue" } },
		{ { "Main Language: ", "commentfg" }, { data.main_language or "-", "excyan" } },
		{ { "Active Hours:  ", "commentfg" }, { (data.start_time or "??") .. " to " .. (data.end_time or "??"), "normal" } },
	}
	local identity_card = renderer.card("Project Identity", identity_lines, 45, "exblue")

	if width >= 100 then
		for _, l in ipairs(renderer.hbox(summary_card, identity_card, 4)) do
			table.insert(lines, l)
		end
	else
		for _, l in ipairs(summary_card) do
			table.insert(lines, l)
		end
		for _, l in ipairs(identity_card) do
			table.insert(lines, l)
		end
	end
	table.insert(lines, {})

	-- Hourly activity
	local hourly = data.hourly_activity or {}
	local has_hourly = false
	for _, v in ipairs(hourly) do
		if v > 0 then
			has_hourly = true
			break
		end
	end

	if has_hourly then
		table.insert(lines, { { "  ⏰ Hourly Distribution", "exgreen" } })
		table.insert(lines, {})
		local hist_line = { { "  ", "normal" } }
		local hist_segs = renderer.histogram(hourly, 0, 1, "exblue")
		for _, s in ipairs(hist_segs) do
			table.insert(hist_line, s)
		end
		table.insert(lines, hist_line)
		table.insert(lines, { { "  00  02  04  06  08  10  12  14  16  18  20  22", "commentfg" } })
		table.insert(lines, {})
	end

	-- Sessions & Files
	local sessions = data.sessions or {}
	if #sessions > 0 then
		table.insert(lines, { { "  ⏰ Session Timeline", "exgreen" } })
		table.insert(lines, {})
		local tbl = { { "Time", "Duration", "Projects" } }
		for _, s in ipairs(sessions) do
			table.insert(tbl, { s.start_time or "??", util.format_duration(s.duration or 0), util.top_items(s.projects or {}, 2) })
		end
		for _, l in ipairs(renderer.table(tbl, width - 10)) do
			table.insert(lines, l)
		end
		table.insert(lines, {})
	end

	-- Top Files
	local files = data.top_files or {}
	if #files > 0 then
		table.insert(lines, { { "  📄 Top Files", "exgreen" } })
		table.insert(lines, {})
		local tblFile = { { "File", "Lang", "Time" } }
		for _, f in ipairs(files) do
			table.insert(tblFile, { f.file, f.language or "-", util.format_duration(f.time) })
		end
		for _, l in ipairs(renderer.table(tblFile, width - 10)) do
			table.insert(lines, l)
		end
		table.insert(lines, {})
	end

	return lines
end

return M
