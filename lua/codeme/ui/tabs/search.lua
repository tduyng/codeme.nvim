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

function M.render(stats)
	local lines = {}

	-- Header / Search Control
	table.insert(lines, {})
	table.insert(lines, {
		{ "  🔍 Search Day:  ", "exgreen" },
		{ " [ ", "commentfg" },
		{ "←", "exyellow" },
		{ " ] ", "commentfg" },
		{ "  " .. state.date .. "  ", "normal" },
		{ " [ ", "commentfg" },
		{ "→", "exyellow" },
		{ " ] ", "commentfg" },
		{ "    ( [ ] to navigate, / to type, Enter to refresh )", "commentfg" },
	})
	table.insert(lines, {})

	if state.loading then
		table.insert(lines, { { "  Loading stats for " .. state.date .. "...", "exyellow" } })
		table.insert(lines, {})
		return lines
	end

	if state.error then
		table.insert(lines, { { "  Error: " .. state.error, "exred" } })
		table.insert(lines, {})
		return lines
	end

	local data = state.data
	if not data or data.is_empty then
		table.insert(lines, { { "  No activity recorded on " .. state.date, "commentfg" } })
		table.insert(lines, {})
		return lines
	end

	-- Day Summary
	local total_time = data.total_time or 0
	local focus_score = data.focus_score or 0

	table.insert(lines, {
		{ "  📊 Summary", "exgreen" },
		{ string.rep(" ", 38), "normal" },
		{ util.format_duration(total_time), "exgreen" },
		{ " total  •  ", "commentfg" },
		{ string.format("Focus %d%%", focus_score), focus_score >= 70 and "exgreen" or "exyellow" },
	})

	local summary_parts = {
		{ "  Main: ", "commentfg" },
		{ data.main_project or "-", "exblue" },
		{ " (", "commentfg" },
		{ data.main_language or "-", "excyan" },
		{ ")", "commentfg" },
	}
	if data.start_time then
		table.insert(summary_parts, { "  •  Time: ", "commentfg" })
		table.insert(summary_parts, { data.start_time .. " → " .. (data.end_time or "??:??"), "normal" })
	end
	table.insert(lines, summary_parts)
	table.insert(lines, {})

	-- Session Timeline
	local sessions = data.sessions or {}
	if #sessions > 0 then
		table.insert(lines, { { "  ⏰ Session Timeline", "exgreen" } })
		table.insert(lines, {})

		local tbl = { { "Time", "Duration", "Projects", "Languages" } }
		local max_duration = 0
		for _, s in ipairs(sessions) do
			max_duration = math.max(max_duration, s.duration or 0)
		end

		for _, s in ipairs(sessions) do
			local time_str = s.start_time or "??:??"
			local dur_str = util.format_duration(s.duration or 0)
			local projs = util.top_items(s.projects or {}, 2)
			local langs = util.top_items(s.languages or {}, 3)

			table.insert(tbl, {
				time_str,
				dur_str,
				projs ~= "" and projs or "-",
				langs ~= "" and langs or "-",
			})
		end

		for _, l in ipairs(renderer.table(tbl, 120)) do
			table.insert(lines, l)
		end
		table.insert(lines, {})
	end

	-- Languages & Projects
	local langs = data.languages or {}
	if #langs > 0 then
		table.insert(lines, { { "  🔤 Languages", "exgreen" } })
		table.insert(lines, {})
		local tblLang = { { "Language", "Time", "Lines", "Pct" } }
		for _, l in ipairs(langs) do
			table.insert(tblLang, {
				l.name,
				util.format_duration(l.time),
				util.format_number(l.lines),
				string.format("%.1f%%", l.percent_total or 0),
			})
		end
		for _, l in ipairs(renderer.table(tblLang, 120)) do
			table.insert(lines, l)
		end
		table.insert(lines, {})
	end

	local projs = data.projects or {}
	if #projs > 0 then
		table.insert(lines, { { "  📁 Projects", "exgreen" } })
		table.insert(lines, {})
		local tblProj = { { "Project", "Time", "Lines", "Main Language" } }
		for _, p in ipairs(projs) do
			table.insert(tblProj, {
				p.name,
				util.format_duration(p.time),
				util.format_number(p.lines),
				p.main_lang or "-",
			})
		end
		for _, l in ipairs(renderer.table(tblProj, 120)) do
			table.insert(lines, l)
		end
		table.insert(lines, {})
	end

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
		table.insert(lines, { { "  ⏰ Hourly Activity", "exgreen" } })
		table.insert(lines, {})

		local max_h = 0
		for _, v in ipairs(hourly) do
			max_h = math.max(max_h, v)
		end

		local line_h = { { "  ", "normal" } }
		for i = 0, 23 do
			local val = hourly[i + 1] or 0
			local pct = max_h > 0 and (val / max_h * 100) or 0
			local char = "░"
			local hl = "commentfg"
			if pct > 75 then
				char = "█"
				hl = "exyellow"
			elseif pct > 50 then
				char = "█"
				hl = "exgreen"
			elseif pct > 25 then
				char = "▓"
				hl = "excyan"
			elseif pct > 0 then
				char = "▒"
				hl = "exblue"
			end
			table.insert(line_h, { char .. " ", hl })
		end
		table.insert(lines, line_h)

		local labels = { { "  ", "normal" } }
		for i = 0, 23, 4 do
			table.insert(labels, { string.format("%02d  ", i), "commentfg" })
			if i < 20 then
				table.insert(labels, { string.rep(" ", 6), "normal" })
			end
		end
		table.insert(lines, labels)
		table.insert(lines, {})
	end

	-- Top Files
	local files = data.top_files or {}
	if #files > 0 then
		table.insert(lines, { { "  📄 Top Files", "exgreen" } })
		table.insert(lines, {})
		local tblFile = { { "File", "Language", "Time", "Lines" } }
		for _, f in ipairs(files) do
			table.insert(tblFile, {
				f.file,
				f.language or "-",
				util.format_duration(f.time),
				util.format_number(f.lines),
			})
		end
		for _, l in ipairs(renderer.table(tblFile, 120)) do
			table.insert(lines, l)
		end
		table.insert(lines, {})
	end

	-- Notice for old dates
	if #sessions == 0 and total_time > 0 then
		table.insert(lines, { { "  ℹ️  Session details unavailable for dates older than 365 days.", "exyellow" } })
		table.insert(lines, {})
	end

	return lines
end

return M
