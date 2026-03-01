local util = require("codeme.util")
local renderer = require("codeme.ui.renderer")

local M = {}

function M.render(stats, width)
	stats = require("codeme.util").apply_privacy_mask(stats)
	local lines = {}
	local today = stats.today or {}
	local today_sessions = today.sessions or {}
	local total_time = today.total_time or 0
	local focus_score = today.focus_score or 0

	-- Header
	local today_date = os.date("%A, %B %d")

	table.insert(lines, {})
	table.insert(lines, {
		{ "  ☀️  Activity Timeline", "exgreen" },
		{ string.rep(" ", 30), "commentfg" },
		{ util.format_duration(total_time), "exgreen" },
		{ "  •  ", "commentfg" },
		{ today_date, "exyellow" },
	})
	table.insert(lines, {})

	if total_time == 0 then
		table.insert(lines, { { "  No coding activity yet today", "commentfg" } })
		table.insert(lines, { { "  Start working to track your productivity!", "commentfg" } })
		table.insert(lines, {})
		return lines
	end

	-- Hourly Activity Sparkline (Condensed)
	local hourly_raw = {}
	for i = 1, 24 do
		hourly_raw[i] = 0
	end
	for _, item in ipairs(today.hourly_activity or {}) do
		if item.hour and item.hour >= 0 and item.hour < 24 then
			hourly_raw[item.hour + 1] = item.duration or 0
		end
	end
	if #today_sessions > 0 then
		local hist_line = { { "  Activity Map: ", "commentfg" } }
		local hist_segs = renderer.histogram(hourly_raw, 0, 1, "exblue")
		for _, s in ipairs(hist_segs) do
			table.insert(hist_line, s)
		end
		table.insert(hist_line, { "  Focus: " .. focus_score .. "%", focus_score >= 70 and "exgreen" or "exyellow" })
		table.insert(lines, hist_line)
		table.insert(lines, { { "                 00  04  08  12  16  20  23", "commentfg" } })

		-- Peak Block Insight (Restored)
		local total_hourly = 0
		for _, dur in pairs(hourly_raw) do
			total_hourly = total_hourly + dur
		end
		if total_hourly > 0 then
			local blocks = {
				{ label = "early morning 🌅", start_h = 4, end_h = 7 },
				{ label = "morning ☕", start_h = 8, end_h = 11 },
				{ label = "afternoon ☀️", start_h = 12, end_h = 15 },
				{ label = "evening 🌆", start_h = 16, end_h = 19 },
				{ label = "night 🌃", start_h = 20, end_h = 23 },
				{ label = "late night 🌙", start_h = 0, end_h = 3 },
			}
			local peak_block, max_pct = nil, 0
			for _, block in ipairs(blocks) do
				local block_time = 0
				for h = block.start_h, block.end_h do
					block_time = block_time + (hourly_raw[h + 1] or 0)
				end
				local pct = math.floor((block_time / total_hourly) * 100)
				if pct > max_pct then
					max_pct = pct
					peak_block = block.label
				end
			end
			if peak_block then
				table.insert(lines, {
					{ "  💡 You're most productive in the ", "commentfg" },
					{ peak_block, "exgreen" },
					{ " today.", "commentfg" },
				})
			end
		end
		table.insert(lines, {})

		-- Narrative Story (Restored)
		local first_session = today_sessions[1]
		local last_session = today_sessions[#today_sessions]
		if first_session.start_time and last_session.end_time then
			local start_hour = tonumber(first_session.start_time:sub(12, 13))
			local end_hour = tonumber(last_session.end_time:sub(12, 13))
			local function get_period(hour)
				if hour >= 5 and hour < 12 then
					return "morning", "🌅"
				elseif hour >= 12 and hour < 17 then
					return "afternoon", "☀️"
				elseif hour >= 17 and hour < 21 then
					return "evening", "🌆"
				else
					return "late night", "🦉"
				end
			end
			local start_period, start_icon = get_period(start_hour)
			local end_period, end_icon = get_period(end_hour)
			local story = {
				{ "  📖 ", "exgreen" },
				{ "You started in the ", "commentfg" },
				{ start_period .. " " .. start_icon, "normal" },
			}
			if start_period ~= end_period then
				table.insert(story, { " and continued into the ", "commentfg" })
				table.insert(story, { end_period .. " " .. end_icon, "normal" })
			end
			table.insert(story, { ".", "commentfg" })
			table.insert(lines, story)
			table.insert(lines, {})
		end
	end

	-- Visual Timeline
	table.insert(lines, { { "  ⏰ Sessions", "exgreen" } })
	table.insert(lines, {})

	if #today_sessions == 0 then
		table.insert(lines, { { "  No sessions recorded yet", "commentfg" } })
		table.insert(lines, {})
	else
		local max_dur = 0
		for _, s in ipairs(today_sessions) do
			if (s.duration or 0) > max_dur then
				max_dur = s.duration
			end
		end

		for i, session in ipairs(today_sessions) do
			local time_str = session.start_time and session.start_time:sub(12, 16) or "??:??"
			local dur_str = util.format_duration(session.duration or 0)
			local is_peak = (session.duration or 0) == max_dur and #today_sessions > 1

			-- Session entry
			local line = {
				{ "  " .. time_str .. " ", "commentfg" },
				{ i == #today_sessions and "╰─ " or "├─ ", "exblue" },
				{ dur_str, is_peak and "exyellow" or "normal" },
				{ is_peak and " ⭐ " or "    ", "exyellow" },
				{ util.top_items(session.projects or {}, 2), "exgreen" },
				{ " (", "commentfg" },
				{ util.top_items(session.languages or {}, 3), "excyan" },
				{ ")", "commentfg" },
			}
			table.insert(lines, line)

			-- Break indicator
			if session.break_after and session.break_after > 300 then
				local icon = session.break_after < 1800 and "☕" or "🍽️"
				table.insert(lines, {
					{ "        ", "commentfg" },
					{ "│  ", "exblue" },
					{ icon .. " " .. util.format_duration(session.break_after) .. " break", "commentfg" },
				})
			elseif i < #today_sessions then
				table.insert(lines, { { "        ", "commentfg" }, { "│", "exblue" } })
			end
		end
		table.insert(lines, {})
	end

	-- FileType Activity Table (Adaptive)
	local languages = today.languages or {}
	if #languages > 0 then
		table.insert(lines, { { "  FileType breakdown", "exgreen" } })
		table.insert(lines, {})

		local tblLang = { { "FileType", "Time", "Lines", "Share" } }
		for _, lang in ipairs(languages) do
			table.insert(tblLang, {
				lang.name,
				util.format_duration(lang.time),
				util.format_number(lang.lines),
				string.format("%.1f%%", lang.percent_total or 0),
			})
		end

		for _, l in ipairs(renderer.table(tblLang, width - 10)) do
			table.insert(lines, l)
		end
		table.insert(lines, {})
	end

	return lines
end

return M
