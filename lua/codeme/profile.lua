local M = {}
local ui = require("codeme.ui")
local api = vim.api

local state = { stats = {}, tab = 1, buf = nil, win = nil, ns = nil, width = 100 }
local TABS = { "☀️ Today", "📅 Weekly", "📊 Overview", "💡 Insights", "💻 Languages", "🔥 Projects" }

--------------------------------------------------------------------------------
-- FORMATTERS
--------------------------------------------------------------------------------

local function fmt_time(s)
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

local function fmt_num(n)
	if not n then
		return "0"
	end
	return tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function progress(pct, w)
	pct = math.max(0, math.min(100, pct or 0))
	local f = math.floor(pct / 100 * w)
	return string.rep("█", f) .. string.rep("░", w - f)
end

local function trend(cur, prev)
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

--------------------------------------------------------------------------------
-- TAB BUILDERS (each returns array of lines)
--------------------------------------------------------------------------------

local function tab_today()
	local ts = state.stats.today_stats or {}
	local s = state.stats
	local lines = {}

	-- Header
	local t_trend, t_hl = trend(ts.total_time or 0, s.yesterday_time or 0)
	table.insert(lines, {})
	table.insert(lines, { { "  ☀️ Today's Coding", "exgreen" } })
	table.insert(lines, {})
	table.insert(lines, {
		{ "  ⏱️ ", "commentfg" },
		{ fmt_time(ts.total_time or 0), "exgreen" },
		{ t_trend, t_hl },
		{ "  │  📝 ", "commentfg" },
		{ fmt_num(ts.total_lines or 0), "exyellow" },
		{ "  │  📂 ", "commentfg" },
		{ tostring(ts.total_files or 0), "exred" },
	})
	table.insert(lines, {})

	-- Goals
	local cfg = require("codeme").get_config().goals or {}
	if (cfg.daily_hours or 0) > 0 then
		local pct = math.min(100, math.floor((ts.total_time or 0) / (cfg.daily_hours * 3600) * 100))
		local hl = pct >= 100 and "exgreen" or pct >= 50 and "exyellow" or "exred"
		table.insert(
			lines,
			{ { "  🎯 Time : ", "commentfg" }, { progress(pct, 25), hl }, { " " .. pct .. "%", "commentfg" } }
		)
	end
	if (cfg.daily_lines or 0) > 0 then
		local pct = math.min(100, math.floor((ts.total_lines or 0) / cfg.daily_lines * 100))
		local hl = pct >= 100 and "exgreen" or pct >= 50 and "exyellow" or "exred"
		table.insert(
			lines,
			{ { "  🎯 Lines: ", "commentfg" }, { progress(pct, 25), hl }, { " " .. pct .. "%", "commentfg" } }
		)
	end
	if #lines > 5 then
		table.insert(lines, {})
	end

	-- Languages table
	if ts.languages and next(ts.languages) then
		local items, total = {}, 0
		for name, stat in pairs(ts.languages) do
			total = total + (stat.time or 0)
			items[#items + 1] = { name = name, time = stat.time or 0, lines = stat.lines or 0 }
		end
		table.sort(items, function(a, b)
			return a.time > b.time
		end)

		local tbl = { { "Language", "Time", "Lines", "%" } }
		for i = 1, math.min(5, #items) do
			local it = items[i]
			local pct = total > 0 and math.floor(it.time / total * 100) or 0
			tbl[#tbl + 1] = { it.name, fmt_time(it.time), fmt_num(it.lines), progress(pct, 15) .. " " .. pct .. "%" }
		end
		table.insert(lines, { { "  💻 Languages", "exgreen" } })
		table.insert(lines, {})
		for _, l in ipairs(ui.table(tbl, state.width - 8)) do
			table.insert(lines, l)
		end
	else
		table.insert(lines, { { "  💻 No activity yet. Start coding!", "commentfg" } })
	end

	-- Hourly activity
	local ha = ts.hourly_activity
	if ha and next(ha) then
		table.insert(lines, {})
		table.insert(lines, { { "  📊 Activity", "exgreen" } })
		local max = 0
		for _, c in pairs(ha) do
			max = math.max(max, c)
		end
		if max > 0 then
			for _, b in ipairs({ { "00-06", 0, 5 }, { "06-12", 6, 11 }, { "12-18", 12, 17 }, { "18-24", 18, 23 } }) do
				local sum = 0
				for h = b[2], b[3] do
					sum = sum + (ha[tostring(h)] or ha[h] or 0)
				end
				local pct = math.floor(sum / max * 100)
				local hl = pct > 60 and "exgreen" or pct > 30 and "exyellow" or "commentfg"
				table.insert(lines, { { "  " .. b[1] .. " ", "commentfg" }, { progress(pct, 25), hl } })
			end
		end
	end

	return lines
end

local function tab_weekly()
	local s = state.stats
	local lines = {}
	local t_trend, t_hl = trend(s.week_time or 0, s.last_week_time or 0)

	table.insert(lines, {})
	table.insert(lines, { { "  📅 Weekly Summary", "exgreen" } })
	table.insert(lines, {})
	table.insert(lines, {
		{ "  ⏱️ ", "commentfg" },
		{ fmt_time(s.week_time or 0), "exgreen" },
		{ t_trend, t_hl },
		{ "  │  📝 ", "commentfg" },
		{ fmt_num(s.week_lines or 0), "exyellow" },
	})
	table.insert(lines, {})

	-- Comparison table
	local tbl = {
		{ "Period", "Time", "Lines", "Files" },
		{ "This Week", fmt_time(s.week_time or 0), fmt_num(s.week_lines or 0), tostring(s.week_files or 0) },
		{ "Last Week", fmt_time(s.last_week_time or 0), fmt_num(s.last_week_lines or 0), tostring(s.last_week_files or 0) },
	}
	for _, l in ipairs(ui.table(tbl, state.width - 8)) do
		table.insert(lines, l)
	end
	table.insert(lines, {})

	-- Heatmap
	local hm = s.weekly_heatmap
	if hm and #hm > 0 then
		for _, l in ipairs(ui.heatmap(hm)) do
			table.insert(lines, l)
		end
	end

	return lines
end

local function tab_overview()
	local s = state.stats
	local lines = {}
	local streak = s.streak or 0
	local flames = streak > 0 and string.rep("🔥", math.min(streak, 7)) .. (streak > 7 and " +" .. (streak - 7) or "")
		or "No streak"

	table.insert(lines, {})
	table.insert(lines, { { "  📊 Overview", "exgreen" } })
	table.insert(lines, {})
	table.insert(lines, {
		{ "  🔥 Streak: ", "commentfg" },
		{ flames, streak > 0 and "exred" or "commentfg" },
		{ "  (Best: " .. (s.longest_streak or 0) .. ")", "commentfg" },
	})
	table.insert(lines, {})

	local tbl = {
		{ "Period", "Time", "Lines", "Files" },
		{ "Today", fmt_time(s.today_time or 0), fmt_num(s.today_lines or 0), tostring(s.today_files or 0) },
		{ "Week", fmt_time(s.week_time or 0), fmt_num(s.week_lines or 0), tostring(s.week_files or 0) },
		{ "Month", fmt_time(s.month_time or 0), fmt_num(s.month_lines or 0), tostring(s.month_files or 0) },
		{ "Total", fmt_time(s.total_time or 0), fmt_num(s.total_lines or 0), tostring(s.total_files or 0) },
	}
	for _, l in ipairs(ui.table(tbl, state.width - 8)) do
		table.insert(lines, l)
	end

	return lines
end

local function tab_insights()
	local s = state.stats
	local lines = {}

	table.insert(lines, {})
	table.insert(lines, { { "  💡 Insights", "exgreen" } })
	table.insert(lines, {})

	-- Peak times
	local hour = s.most_active_hour or 0
	table.insert(
		lines,
		{ { "  ⏰ Peak Hour: ", "commentfg" }, { string.format("%02d:00-%02d:00", hour, hour + 1), "exgreen" } }
	)
	table.insert(lines, { { "  📅 Peak Day: ", "commentfg" }, { s.most_active_day or "N/A", "exgreen" } })
	table.insert(lines, {})

	-- Comparisons
	local t1, h1 = trend(s.today_time or 0, s.yesterday_time or 0)
	local t2, h2 = trend(s.week_time or 0, s.last_week_time or 0)
	table.insert(lines, {
		{ "  Today vs Yesterday: ", "commentfg" },
		{ fmt_time(s.today_time or 0), "exgreen" },
		{ " vs ", "commentfg" },
		{ fmt_time(s.yesterday_time or 0), "exyellow" },
		{ t1, h1 },
	})
	table.insert(lines, {
		{ "  Week vs Last: ", "commentfg" },
		{ fmt_time(s.week_time or 0), "exgreen" },
		{ " vs ", "commentfg" },
		{ fmt_time(s.last_week_time or 0), "exyellow" },
		{ t2, h2 },
	})
	table.insert(lines, {})

	-- Achievements
	local achs = s.achievements or {}
	if #achs > 0 then
		table.insert(lines, { { "  🏆 Achievements", "exgreen" } })
		table.insert(lines, {})
		for _, a in ipairs(achs) do
			if a.unlocked then
				table.insert(lines, {
					{ "  " .. (a.icon or "🏆") .. " ", "normal" },
					{ a.name, "exgreen" },
					{ " - " .. a.description, "commentfg" },
				})
			end
		end
		local shown = 0
		for _, a in ipairs(achs) do
			if not a.unlocked and shown < 3 then
				table.insert(
					lines,
					{ { "  🔒 ", "commentfg" }, { a.name, "commentfg" }, { " - " .. a.description, "commentfg" } }
				)
				shown = shown + 1
			end
		end
	end

	return lines
end

local function build_stat_table(title, data)
	local lines = {}
	table.insert(lines, {})
	table.insert(lines, { { "  " .. title, "exgreen" } })
	table.insert(lines, {})

	if not data or not next(data) then
		table.insert(lines, { { "  No data yet", "commentfg" } })
		return lines
	end

	local items, total = {}, 0
	for name, stat in pairs(data) do
		total = total + (stat.time or 0)
		items[#items + 1] = { name = name, time = stat.time or 0, lines = stat.lines or 0 }
	end
	table.sort(items, function(a, b)
		return a.time > b.time
	end)

	local tbl = { { "Name", "Time", "Lines", "%" } }
	for i = 1, math.min(10, #items) do
		local it = items[i]
		local pct = total > 0 and math.floor(it.time / total * 100) or 0
		tbl[#tbl + 1] = { it.name, fmt_time(it.time), fmt_num(it.lines), progress(pct, 15) .. " " .. pct .. "%" }
	end
	for _, l in ipairs(ui.table(tbl, state.width - 8)) do
		table.insert(lines, l)
	end

	return lines
end

local function tab_languages()
	return build_stat_table("💻 Languages", state.stats.languages)
end
local function tab_projects()
	return build_stat_table("🔥 Projects", state.stats.projects)
end

local TAB_FNS = { tab_today, tab_weekly, tab_overview, tab_insights, tab_languages, tab_projects }

--------------------------------------------------------------------------------
-- RENDERING
--------------------------------------------------------------------------------

local function render()
	if not state.buf or not api.nvim_buf_is_valid(state.buf) then
		return
	end

	-- Build all lines
	local lines = {}

	-- Tabs header
	for _, l in ipairs(ui.tabs(TABS, state.tab)) do
		table.insert(lines, l)
	end
	table.insert(lines, {})

	-- Tab content
	for _, l in ipairs(TAB_FNS[state.tab]()) do
		table.insert(lines, l)
	end

	-- Footer
	table.insert(lines, {})
	table.insert(lines, { { "  <Tab>: Next │ <S-Tab>: Prev │ 1-6: Jump │ q: Close", "commentfg" } })

	-- Render
	ui.render(state.buf, lines, state.ns, state.width)
end

local function next_tab()
	state.tab = state.tab % #TABS + 1
	render()
end
local function prev_tab()
	state.tab = state.tab == 1 and #TABS or state.tab - 1
	render()
end
local function goto_tab(n)
	if n >= 1 and n <= #TABS then
		state.tab = n
		render()
	end
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

function M.open(stats)
	state.stats = stats or {}
	state.tab = 1
	state.width = math.min(110, math.floor(vim.o.columns * 0.85))
	state.ns = api.nvim_create_namespace("codeme")

	-- Calculate height
	local max_h = 0
	for i = 1, #TABS do
		state.tab = i
		max_h = math.max(max_h, #TAB_FNS[i]())
	end
	state.tab = 1
	local h = math.min(math.max(max_h + 6, 20), math.floor(vim.o.lines * 0.8))

	-- Create buffer
	state.buf = api.nvim_create_buf(false, true)
	vim.bo[state.buf].buftype = "nofile"
	vim.bo[state.buf].bufhidden = "wipe"

	-- Create window
	state.win = api.nvim_open_win(state.buf, true, {
		relative = "editor",
		width = state.width,
		height = h,
		row = math.floor((vim.o.lines - h) / 2),
		col = math.floor((vim.o.columns - state.width) / 2),
		border = "rounded",
		style = "minimal",
	})

	-- Keymaps
	local o = { buffer = state.buf, silent = true, nowait = true }
	vim.keymap.set("n", "<Tab>", next_tab, o)
	vim.keymap.set("n", "L", next_tab, o)
	vim.keymap.set("n", "<S-Tab>", prev_tab, o)
	vim.keymap.set("n", "H", prev_tab, o)
	for i = 1, 6 do
		vim.keymap.set("n", tostring(i), function()
			goto_tab(i)
		end, o)
	end

	local close = function()
		if state.win and api.nvim_win_is_valid(state.win) then
			api.nvim_win_close(state.win, true)
		end
		state.buf, state.win = nil, nil
	end
	vim.keymap.set("n", "q", close, o)
	vim.keymap.set("n", "<Esc>", close, o)

	render()
end

return M
