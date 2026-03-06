local util = require("codeme.util")
local renderer = require("codeme.ui.renderer")

local M = {}

function M.render(stats, width, height)
	local lines = {}
	local today = stats.today or {}
	local today_sessions = today.sessions or {}
	local total_time = today.total_time or 0
	local focus_score = today.focus_score or 0

	-- ── Header ─────────────────────────────────────────────────────────
	table.insert(lines, {})
	table.insert(lines, {
		{ "  ☀️  Today's Activity", "exgreen" },
		{ "   —   ", "commentfg" },
		{ os.date("%A, %B %d"), "exyellow" },
		{ "   —   ", "commentfg" },
		{ "Total: ", "commentfg" },
		{ util.format_duration(total_time), "exgreen" },
	})
	table.insert(lines, {})

	if total_time == 0 then
		table.insert(
			lines,
			{ { "  No coding activity yet today. Start working to track your productivity!", "commentfg" } }
		)
		table.insert(lines, {})
		return lines
	end

	-- ── Hourly sparkline ───────────────────────────────────────────────
	local hourly_raw = {}
	for i = 1, 24 do
		hourly_raw[i] = 0
	end
	for _, item in ipairs(today.hourly_activity or {}) do
		if item.hour and item.hour >= 0 and item.hour < 24 then
			hourly_raw[item.hour + 1] = item.duration or 0
		end
	end

	local hist_line = { { "  ", "commentfg" } }
	for _, s in ipairs(renderer.histogram(hourly_raw, 0, 1, "exblue", 2)) do
		table.insert(hist_line, s)
	end
	table.insert(lines, hist_line)

	local label_line = { { "  ", "commentfg" } }
	for h = 0, 23 do
		local display_h = h % 24
		table.insert(label_line, { string.format("%02d ", display_h), "commentfg" })
	end
	table.insert(lines, label_line)

	-- Focus score inline
	if focus_score > 0 then
		local focus_hl = focus_score >= 70 and "exgreen" or focus_score >= 40 and "exyellow" or "exred"
		table.insert(lines, {
			{ "  Focus score: ", "commentfg" },
			{ tostring(focus_score) .. "%", focus_hl },
			{ "   Peak block: ", "commentfg" },
		})
		-- find peak 4-hour block
		local block_labels = {
			{ label = "early morning", start_h = 4, end_h = 7 },
			{ label = "morning", start_h = 8, end_h = 11 },
			{ label = "afternoon", start_h = 12, end_h = 15 },
			{ label = "evening", start_h = 16, end_h = 19 },
			{ label = "night", start_h = 20, end_h = 23 },
			{ label = "late night", start_h = 0, end_h = 3 },
		}
		local total_hourly = 0
		for _, v in ipairs(hourly_raw) do
			total_hourly = total_hourly + v
		end
		if total_hourly > 0 then
			local peak_block, max_pct = "—", 0
			for _, b in ipairs(block_labels) do
				local bt = 0
				for h = b.start_h, b.end_h do
					bt = bt + (hourly_raw[h + 1] or 0)
				end
				local pct = math.floor((bt / total_hourly) * 100)
				if pct > max_pct then
					max_pct = pct
					peak_block = b.label
				end
			end
			-- patch the last inserted line to complete it
			local last = lines[#lines]
			table.insert(last, { peak_block, "normal" })
		end
	end
	table.insert(lines, {})

	-- ── Sessions ───────────────────────────────────────────────────────
	if #today_sessions == 0 then
		table.insert(lines, { { "  No sessions recorded yet.", "commentfg" } })
		table.insert(lines, {})
		return lines
	end

	-- Compute per-session duration defensively.
	-- Backend may send duration directly (seconds) OR start+end timestamps.
	-- We never accumulate across sessions — each session is independent.
	local function session_duration(s)
		-- Prefer explicit duration field if it looks sane (< 24h = 86400s)
		if s.duration and s.duration > 0 and s.duration < 86400 then
			return s.duration
		end
		-- Fall back: parse ISO start/end strings
		if s.start_time and s.end_time then
			local function parse_t(iso)
				local h, m, sec = iso:match("T?(%d%d):(%d%d):(%d%d)")
				if h then
					return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(sec)
				end
				-- short "HH:MM" form
				h, m = iso:match("(%d%d):(%d%d)$")
				if h then
					return tonumber(h) * 3600 + tonumber(m) * 60
				end
				return nil
			end
			local st = parse_t(s.start_time)
			local et = parse_t(s.end_time)
			if st and et then
				local diff = et - st
				-- Handle midnight crossover
				if diff < 0 then
					diff = diff + 86400
				end
				if diff > 0 and diff < 86400 then
					return diff
				end
			end
		end
		return 0
	end

	-- Clamp sum: sessions should never exceed total_time reported by backend.
	-- If they do, it means durations overlap or are cumulative — we scale them.
	local raw_sum = 0
	local durations = {}
	for i, s in ipairs(today_sessions) do
		durations[i] = session_duration(s)
		raw_sum = raw_sum + durations[i]
	end
	local scale = (raw_sum > 0 and raw_sum > total_time * 1.05) and (total_time / raw_sum) or 1.0

	-- Find longest session index for star marker
	local max_dur, max_idx = 0, 1
	for i, d in ipairs(durations) do
		local scaled = math.floor(d * scale)
		if scaled > max_dur then
			max_dur = scaled
			max_idx = i
		end
	end

	-- Section header
	table.insert(lines, {
		{ "  ⏰ Sessions", "exgreen" },
		{ "  (" .. #today_sessions .. " total)", "commentfg" },
	})
	table.insert(lines, {})

	-- Bar width for mini per-session bar (adapts to window)
	local bar_w = math.max(8, math.min(20, math.floor((width - 60) / 2)))

	for i, session in ipairs(today_sessions) do
		local dur = math.floor(durations[i] * scale)
		local is_last = (i == #today_sessions)
		local is_peak = (i == max_idx) and (#today_sessions > 1)

		-- Time range string
		local t_start = ""
		local t_end = ""
		if session.start_time then
			t_start = session.start_time:match("T?(%d%d:%d%d)") or session.start_time:sub(1, 5)
		end
		if session.end_time then
			t_end = session.end_time:match("T?(%d%d:%d%d)") or session.end_time:sub(1, 5)
		end
		local time_range = (t_start ~= "" and t_end ~= "") and (t_start .. "→" .. t_end)
			or (t_start ~= "" and t_start or "??:??")

		-- Mini progress bar proportional to total_time
		local pct = total_time > 0 and math.floor((dur / total_time) * 100) or 0
		local bar_hl = is_peak and "exyellow" or "exblue"

		-- Tree connector
		local connector = is_last and "╰─" or "├─"

		-- Projects / languages (compact)
		local proj_str = util.top_items(session.projects or {}, 2)
		local lang_str = util.top_items(session.languages or {}, 2)
		local meta = ""
		if proj_str ~= "" and lang_str ~= "" then
			meta = proj_str .. "  [" .. lang_str .. "]"
		elseif proj_str ~= "" then
			meta = proj_str
		elseif lang_str ~= "" then
			meta = "[" .. lang_str .. "]"
		end

		local time_col = time_range .. string.rep(" ", math.max(0, 11 - #time_range))
		local dur_str = util.format_duration(dur)
		local dur_col = dur_str .. string.rep(" ", math.max(0, 6 - #dur_str))
		local star_col = is_peak and "⭐" or "  "

		local sess_line = {
			{ "  " .. connector .. " ", "commentfg" },
			{ time_col, "commentfg" },
			{ "  ", "normal" },
			{ dur_col, is_peak and "exyellow" or "normal" },
			{ " " .. star_col .. " ", "exyellow" },
		}

		-- Mini bar
		local filled = math.floor(pct / 100 * bar_w)
		table.insert(sess_line, { string.rep("▪", filled), bar_hl })
		table.insert(sess_line, { string.rep("·", bar_w - filled), "commentfg" })
		table.insert(sess_line, { string.format(" %3d%%  ", pct), "commentfg" })
		if meta ~= "" then
			table.insert(sess_line, { meta, "exgreen" })
		end
		table.insert(lines, sess_line)

		-- Break gap
		if not is_last then
			local break_sec = session.break_after or 0
			if break_sec >= 300 then
				local break_icon = break_sec >= 3600 and "🍽️ " or "☕ "
				table.insert(lines, {
					{ "  │   ", "commentfg" },
					{ break_icon, "normal" },
					{ util.format_duration(break_sec) .. " break", "commentfg" },
				})
			else
				table.insert(lines, { { "  │", "commentfg" } })
			end
		end
	end

	-- ── Summary bar (total confirmed) ─────────────────────────────────
	table.insert(lines, {
		{ "  Total coded today: ", "commentfg" },
		{ util.format_duration(total_time), "exgreen" },
		{ "  across ", "commentfg" },
		{ tostring(#today_sessions), "normal" },
		{ " session" .. (#today_sessions == 1 and "" or "s"), "commentfg" },
	})
	table.insert(lines, {})

	-- ── Language breakdown table ───────────────────────────────────────
	local languages = today.languages or {}
	if #languages > 0 then
		table.insert(lines, { { "  📝 FileType Breakdown", "exgreen" } })
		table.insert(lines, {})
		local tbl = { { "FileType", "Time", "Lines", "Share" } }
		for _, lang in ipairs(languages) do
			table.insert(tbl, {
				lang.name,
				util.format_duration(lang.time),
				util.format_number(lang.lines),
				string.format("%.1f%%", lang.percent_total or 0),
			})
		end
		for _, l in ipairs(renderer.table(tbl, width - 10)) do
			table.insert(lines, l)
		end
		table.insert(lines, {})
	end

	return lines
end

return M
