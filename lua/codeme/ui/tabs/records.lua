local util = require("codeme.util")
local renderer = require("codeme.ui.renderer")

local M = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Hover state (module-level, persists across re-renders while dashboard is open)
-- ─────────────────────────────────────────────────────────────────────────────
local _hs = {
	augroup = nil, -- augroup id for CursorMoved
	-- Maps absolute buffer line number (1-based) → { ach, ach, ... } (one grid row)
	line_to_row = {},
	anchor_line = nil, -- absolute buffer line of the hover-detail anchor
	last_key = nil, -- dedup: last rendered ach name or "__clear__"
	ns = nil, -- dedicated namespace so clear_namespace won't kill it
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Teardown – called by dashboard.lua close()
-- ─────────────────────────────────────────────────────────────────────────────
function M.teardown_hover()
	if _hs.augroup then
		pcall(vim.api.nvim_del_augroup_by_id, _hs.augroup)
		_hs.augroup = nil
	end
	_hs.line_to_row = {}
	_hs.anchor_line = nil
	_hs.last_key = nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Internal: render (or clear) the detail bar at the anchor line.
-- Uses a *separate* namespace ("codeme_ach_hover") so the main dashboard
-- clear_namespace call (which targets "codeme_dashboard") never wipes it.
-- ─────────────────────────────────────────────────────────────────────────────
local function show_detail(buf, ach)
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	if not _hs.anchor_line then
		return
	end

	-- Dedup: skip if same achievement (or both nil) as last render
	local key = ach and (ach.name or "?") or "__clear__"
	if key == _hs.last_key then
		return
	end
	_hs.last_key = key

	-- Lazily create our own namespace once
	if not _hs.ns then
		_hs.ns = vim.api.nvim_create_namespace("codeme_ach_hover")
	end

	-- Clear previous hover virt_line
	vim.api.nvim_buf_clear_namespace(buf, _hs.ns, 0, -1)

	if not ach then
		return
	end

	local unlocked = ach.unlocked
	local hl = unlocked and "exgreen" or "commentfg"
	local icon = unlocked and (ach.icon or "?") or "🔒"
	local badge = unlocked and "✔ UNLOCKED" or "✘ LOCKED"
	local name = ach.name or "Unknown"
	local desc = ach.description or "No description"
	local hint = (not unlocked and ach.hint) and ach.hint or nil

	local vline = {
		{ "  ", "normal" },
		{ icon .. "  ", hl },
		{ name, hl },
		{ "   │   ", "commentfg" },
		{ desc, "normal" },
	}
	if hint then
		table.insert(vline, { "   💡 " .. hint, "exyellow" })
	end
	table.insert(vline, { "   [" .. badge .. "]", hl })

	-- virt_lines_above = false → detail appears BELOW the anchor line
	vim.api.nvim_buf_set_extmark(buf, _hs.ns, _hs.anchor_line - 1, 0, {
		virt_lines = { vline },
		virt_lines_above = false,
	})
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Internal: attach CursorMoved autocmd.
-- Called once per render. Re-renders just update _hs tables; the autocmd
-- callback always reads the latest _hs state, so re-attaching is safe.
-- ─────────────────────────────────────────────────────────────────────────────
local function attach_hover_autocmd(buf)
	if _hs.augroup then
		pcall(vim.api.nvim_del_augroup_by_id, _hs.augroup)
	end
	_hs.augroup = vim.api.nvim_create_augroup("CodeMeAchHover", { clear = true })

	vim.api.nvim_create_autocmd("CursorMoved", {
		group = _hs.augroup,
		buffer = buf,
		callback = function()
			-- Only active on the records tab (index 5 in the dashboard TABS list)
			local active_tab = require("codeme.stats").get_active_tab()
			if active_tab ~= 5 then
				show_detail(buf, nil)
				return
			end

			local pos = vim.api.nvim_win_get_cursor(0)
			local abs_row = pos[1] -- 1-based buffer line
			local col = pos[2] -- 0-based byte column
			local row_achs = _hs.line_to_row[abs_row]

			if not row_achs then
				show_detail(buf, nil)
				return
			end

			-- Layout of each grid cell: " [<emoji>] "
			--   " "   = 1 byte
			--   "["   = 1 byte
			--   emoji = 4 bytes (standard Unicode emoji, UTF-8 encoded)
			--   "]"   = 1 byte
			--   " "   = 1 byte
			--   total = 8 bytes per cell
			-- Leading prefix on the grid line: "  " = 2 bytes
			local CELL_BYTES = 8
			local PREFIX = 2
			local idx = math.floor(math.max(0, col - PREFIX) / CELL_BYTES) + 1
			idx = math.max(1, math.min(idx, #row_achs))

			show_detail(buf, row_achs[idx])
		end,
	})
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Main render
-- ─────────────────────────────────────────────────────────────────────────────
function M.render(stats, width, height)
	local lines = {}

	-- Reset per-render state
	_hs.line_to_row = {}
	_hs.anchor_line = nil
	_hs.last_key = nil -- force re-draw of detail after any re-render

	local stats_mod = require("codeme.stats")
	local buf = stats_mod.get_buf()

	-- dashboard.lua's render_dashboard() inserts these lines BEFORE tab content:
	--   [1]  renderer.tabs(...)  → exactly 1 rendered line
	--   [2]  {}                  → blank line
	-- Therefore the first line we push here lands on buffer line 3 (1-based).
	-- HEADER_LINES must stay in sync with dashboard.lua → render_dashboard().
	local HEADER_LINES = 2

	-- Returns the absolute buffer line number the *next* table.insert will occupy.
	local function next_abs()
		return HEADER_LINES + #lines + 1
	end

	-- ── Section: header ─────────────────────────────────────────────────
	table.insert(lines, {})
	table.insert(lines, { { "  🏆 Hall of Fame", "exgreen" } })
	table.insert(lines, {})

	-- ── Section: career badge + summary ─────────────────────────────────
	local all_time = stats.all_time or {}
	local total_hours = math.floor((all_time.total_time or 0) / 3600)

	local milestones = {
		{ threshold = 100000, name = "Legendary", icon = "👑", color = "exgreen" },
		{ threshold = 50000, name = "Master", icon = "🏅", color = "exgreen" },
		{ threshold = 25000, name = "Expert", icon = "🎖️", color = "exgreen" },
		{ threshold = 10000, name = "Senior", icon = "💎", color = "exyellow" },
		{ threshold = 5000, name = "Professional", icon = "🔥", color = "exyellow" },
		{ threshold = 2500, name = "Committed", icon = "⭐", color = "exyellow" },
		{ threshold = 1000, name = "Century", icon = "💯", color = "exblue" },
		{ threshold = 100, name = "Rising", icon = "🌱", color = "exblue" },
	}

	local current_level, next_level
	for _, m in ipairs(milestones) do
		if total_hours >= m.threshold then
			current_level = m
			break
		else
			next_level = m
		end
	end

	local badge_lines = {}
	if current_level then
		table.insert(badge_lines, {
			{ "RANK:  ", "commentfg" },
			{ current_level.icon .. " " .. current_level.name .. " Coder", current_level.color },
		})
	else
		table.insert(badge_lines, {
			{ "RANK:  ", "commentfg" },
			{ "🌱 Beginner", "exblue" },
		})
	end
	table.insert(badge_lines, {
		{ "TOTAL: ", "commentfg" },
		{ tostring(total_hours) .. " hours coded", "normal" },
	})
	if next_level then
		local pct = math.min(99, math.floor((total_hours / next_level.threshold) * 100))
		local segs = renderer.progress(pct, 20, "exyellow")
		local bar = { { "NEXT:  ", "commentfg" } }
		for _, s in ipairs(segs) do
			table.insert(bar, s)
		end
		table.insert(bar, { "  " .. pct .. "% → " .. next_level.name, "commentfg" })
		table.insert(badge_lines, bar)
	end

	local summary_lines = {
		{ { "           TIME          LINES", "commentfg" } },
		{
			{ "All time   ", "commentfg" },
			{ string.format("%-14s", util.format_duration(all_time.total_time or 0)), "exgreen" },
			{ util.format_number(all_time.total_lines or 0), "normal" },
		},
		{
			{ "This month ", "commentfg" },
			{ string.format("%-14s", util.format_duration((stats.this_month or {}).total_time or 0)), "exgreen" },
			{ util.format_number((stats.this_month or {}).total_lines or 0), "normal" },
		},
		{
			{ "Today      ", "commentfg" },
			{ string.format("%-14s", util.format_duration((stats.today or {}).total_time or 0)), "exgreen" },
			{ util.format_number((stats.today or {}).total_lines or 0), "normal" },
		},
	}

	local badge_card = renderer.card("Career Badge", badge_lines, 50, "exyellow")
	local summary_card = renderer.card("Summary", summary_lines, 50, "exblue")

	if width >= 100 then
		for _, l in ipairs(renderer.hbox(badge_card, summary_card, 4)) do
			table.insert(lines, l)
		end
	else
		for _, l in ipairs(badge_card) do
			table.insert(lines, l)
		end
		for _, l in ipairs(summary_card) do
			table.insert(lines, l)
		end
	end
	table.insert(lines, {})

	-- ── Section: trophy cabinet ──────────────────────────────────────────
	local achievements = stats.achievements or {}

	if #achievements > 0 then
		table.insert(lines, { { "  🎖️  Trophy Cabinet", "exgreen" } })
		table.insert(lines, {
			{ "  ", "normal" },
			{ "Navigate over any icon to preview it below", "commentfg" },
			{ "   🔒 = locked", "commentfg" },
		})
		table.insert(lines, {})

		-- Split achievements into grid rows of max_per_row each
		local max_per_row = width >= 120 and 10 or 6
		local rows = {}
		do
			local cur = {}
			for i, ach in ipairs(achievements) do
				table.insert(cur, ach)
				if #cur >= max_per_row or i == #achievements then
					table.insert(rows, cur)
					cur = {}
				end
			end
		end

		-- Render grid and register line→row mapping
		for _, row_achs in ipairs(rows) do
			local this_abs = next_abs() -- absolute buffer line this row will be on

			local grid_line = { { "  ", "normal" } }
			for _, ach in ipairs(row_achs) do
				local hl = ach.unlocked and "exyellow" or "commentfg"
				local icon = ach.unlocked and (ach.icon or "?") or "🔒"
				-- Cell layout: " [<emoji>] " = 8 bytes (see CELL_BYTES in autocmd above)
				table.insert(grid_line, { " [" .. icon .. "] ", hl })
			end

			table.insert(lines, grid_line)
			_hs.line_to_row[this_abs] = row_achs -- register AFTER insert so next_abs() was correct
		end

		-- Blank anchor line: the hover virt_line appears BELOW this
		table.insert(lines, {})
		_hs.anchor_line = next_abs() - 1 -- the blank we just inserted

		-- Extra blank for visual breathing room below the detail bar
		table.insert(lines, {})

		-- Attach CursorMoved (safe to re-attach on every re-render)
		if buf then
			attach_hover_autocmd(buf)
		end

		-- Recent unlocks list below the grid
		local unlocked = {}
		for _, ach in ipairs(achievements) do
			if ach.unlocked then
				table.insert(unlocked, ach)
			end
		end

		if #unlocked > 0 then
			table.insert(lines, { { "  ✨ Recent Unlocks", "exgreen" } })
			table.insert(lines, {})
			for i = 1, math.min(5, #unlocked) do
				local ach = unlocked[#unlocked - i + 1] -- most recent first
				table.insert(lines, {
					{ "  " .. (ach.icon or "?") .. "  ", "exyellow" },
					{ string.format("%-22s", ach.name or ""), "exgreen" },
					{ " — ", "commentfg" },
					{ ach.description or "", "normal" },
				})
			end
			if #unlocked > 5 then
				table.insert(lines, {
					{ "  … and " .. (#unlocked - 5) .. " more unlocked", "commentfg" },
				})
			end
			table.insert(lines, {})
		end
	end

	-- ── Section: personal records ────────────────────────────────────────
	table.insert(lines, { { "  🏆 Personal Records", "exgreen" } })
	table.insert(lines, {})

	local records = stats.records or {}
	local record_list = {}
	local mpd = records.most_productive_day or {}
	if mpd.time and mpd.time > 0 then
		table.insert(record_list, {
			"🏆 Best Day",
			util.format_duration(mpd.time),
			util.format_date(mpd.date or ""),
		})
	end
	local ls = records.longest_session or {}
	if ls.duration and ls.duration > 0 then
		table.insert(record_list, {
			"⏱️  Longest Session",
			util.format_duration(ls.duration),
			util.format_date(ls.date or ""),
		})
	end
	local hdo = records.highest_daily_output or {}
	if hdo.lines and hdo.lines > 0 then
		table.insert(record_list, {
			"📝 Most Lines",
			util.format_number(hdo.lines),
			util.format_date(hdo.date or ""),
		})
	end

	if #record_list > 0 then
		local tbl = { { "Category", "Result", "Achieved On" } }
		for _, rec in ipairs(record_list) do
			table.insert(tbl, rec)
		end
		for _, l in ipairs(renderer.table(tbl, width - 10)) do
			table.insert(lines, l)
		end
		table.insert(lines, {})
	end

	-- ── Section: fun facts ───────────────────────────────────────────────
	local earliest_start = records.earliest_start or {}
	local latest_end = records.latest_end or {}
	local most_languages_day = records.most_languages_day or {}
	local has_fun = earliest_start.time or latest_end.time or (most_languages_day.date and most_languages_day.date ~= "")

	if has_fun then
		table.insert(lines, { { "  📊 Fun Facts", "exgreen" } })
		table.insert(lines, {})
		if earliest_start.time then
			table.insert(lines, {
				{ "  🌅 Early Bird:   ", "commentfg" },
				{ earliest_start.time, "exgreen" },
				{ "   (" .. (earliest_start.date or "") .. ")", "commentfg" },
			})
		end
		if latest_end.time then
			table.insert(lines, {
				{ "  🌙 Night Owl:    ", "commentfg" },
				{ latest_end.time, "exgreen" },
				{ "   (" .. (latest_end.date or "") .. ")", "commentfg" },
			})
		end
		local langs_count = util.safe_length(most_languages_day.languages)
		if langs_count > 0 then
			table.insert(lines, {
				{ "  🌍 Polyglot Day: ", "commentfg" },
				{ langs_count .. " languages", "exgreen" },
				{ "   (" .. (most_languages_day.date or "") .. ")", "commentfg" },
			})
		end
		table.insert(lines, {})
	end

	-- ── Section: challenges ──────────────────────────────────────────────
	table.insert(lines, { { "  💪 Challenges", "exgreen" } })
	table.insert(lines, {})

	local today_time = (stats.today or {}).total_time or 0
	local challenges = {}

	if mpd.time and today_time > 0 and mpd.time > today_time then
		table.insert(challenges, {
			icon = "🎯",
			text = util.format_duration(mpd.time - today_time) .. " more to beat your best day",
			hl = "exyellow",
		})
	end
	if ls.duration and ls.duration > 0 then
		table.insert(challenges, {
			icon = "⏰",
			text = "Can you beat " .. util.format_duration(ls.duration) .. " in one session?",
			hl = "normal",
		})
	end

	if #challenges > 0 then
		for _, ch in ipairs(challenges) do
			table.insert(lines, {
				{ "  " .. ch.icon .. "  ", "normal" },
				{ ch.text, ch.hl },
			})
		end
	else
		table.insert(lines, { { "  💡 Keep coding to set new records!", "commentfg" } })
	end
	table.insert(lines, {})

	return lines
end

return M
