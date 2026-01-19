local state = require("codeme.profile.state")
local fmt = require("codeme.profile.formatters")
local helpers = require("codeme.profile.helpers")
local ui = require("codeme.ui")

local M = {}

function M.render()
	local s = state.stats
	local lines = {}

	-- Header with daily summary
	local today_date = os.date("%A, %B %d")
	local today_sessions = s.today.sessions or {}
	local total_time = 0
	for _, session in ipairs(today_sessions) do
		total_time = total_time + (session.duration or 0)
	end

	local total_time = 0
	for _, session in ipairs(today_sessions) do
		total_time = total_time + (session.duration or 0)
	end

	table.insert(lines, {})
	table.insert(lines, {
		{ "  ☀️  Today's Activity", "exgreen" },
		{ string.rep(" ", 35), "commentfg" },
		{ fmt.fmt_time(total_time), "exgreen" },
		{ "  •  ", "commentfg" },
		{ today_date, "exyellow" },
	})
	table.insert(lines, {})

	if #today_sessions == 0 then
		table.insert(lines, { { "  No coding sessions yet today", "commentfg" } })
		table.insert(lines, { { "  Start working to track your productivity!", "commentfg" } })
		table.insert(lines, {})
		return lines
	end

	-- 📖 Your Story Today (narrative summary)
	table.insert(lines, { { "  📖 Your Story Today", "exgreen" } })
	table.insert(lines, {})

	local first_session = today_sessions[1]
	local last_session = today_sessions[#today_sessions]
	local start_hour = tonumber(first_session.start:sub(12, 13))
	local end_hour = tonumber(last_session["end"]:sub(12, 13))
	local focus_score = s.focus_score or 0

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

	-- Generate a human story
	local story_parts = {
		{ "  You started coding in the ", "commentfg" },
		{ start_period, "normal" },
		{ " " .. start_icon, "normal" },
	}

	if #today_sessions > 1 then
		table.insert(story_parts, { " and had ", "commentfg" })
		table.insert(story_parts, { tostring(#today_sessions), "exgreen" })
		table.insert(story_parts, { " coding sessions", "commentfg" })
	else
		table.insert(story_parts, { " for one focused session", "commentfg" })
	end

	if start_period ~= end_period then
		table.insert(story_parts, { ", continuing into the ", "commentfg" })
		table.insert(story_parts, { end_period, "normal" })
		table.insert(story_parts, { " " .. end_icon, "normal" })
	end

	table.insert(story_parts, { ".", "commentfg" })

	table.insert(lines, story_parts)
	table.insert(lines, {})

	-- Add focus insight on separate line
	local focus_insight = { { "  ", "commentfg" } }
	if focus_score >= 80 then
		table.insert(focus_insight, { "Deep focus mode! 🎯", "exgreen" })
	elseif focus_score >= 60 then
		table.insert(focus_insight, { "Good concentration.", "exgreen" })
	elseif focus_score >= 40 then
		table.insert(focus_insight, { "Some interruptions.", "exyellow" })
	else
		table.insert(focus_insight, { "Lots of context switching.", "exred" })
	end

	table.insert(lines, focus_insight)
	table.insert(lines, {})

	-- ⏰ Session Timeline (compact with breaks)
	table.insert(lines, { { "  ⏰ Session Timeline", "exgreen" } })
	table.insert(lines, {})

	local longest_duration = 0
	local longest_index = 1
	for i, session in ipairs(today_sessions) do
		local duration = session.duration or 0
		if duration > longest_duration then
			longest_duration = duration
			longest_index = i
		end
	end

	local tbl = { { "Time", "Duration", "Project", "Languages" } }

	for i, session in ipairs(today_sessions) do
		local is_peak = (i == longest_index and #today_sessions > 1)

		-- Get project
		local project = session.project or "General"

		-- Get ALL languages (not just first)
		local langs = ""
		local languages_count = helpers.safe_length(session.languages)
		if session.languages and languages_count > 0 then
			local languages_table = helpers.safe_array_to_table(session.languages)
			langs = helpers.format_list(session.languages)
			if project == "General" and #languages_table > 0 then
				project = languages_table[1]
			end
		end

		-- Format time
		local time_str = session.start:sub(12, 16)
		local duration_str = fmt.fmt_time(session.duration or 0)
		if is_peak then
			duration_str = duration_str .. " ⭐"
		end

		tbl[#tbl + 1] = {
			time_str,
			duration_str,
			project,
			langs ~= "" and langs or "-",
		}

		-- Show breaks between sessions (from original!)
		if i < #today_sessions then
			if session.break_after and session.break_after > 300 then
				local break_icon = session.break_after < 1800 and "☕" or "🍽️"
				tbl[#tbl + 1] = {
					"",
					break_icon .. " " .. fmt.fmt_time(session.break_after),
					"-",
					"",
				}
			end
		end
	end

	for _, l in ipairs(ui.table(tbl, state.width - 8)) do
		table.insert(lines, l)
	end
	table.insert(lines, {})

	-- 📊 Quick Stats
	local avg_time = math.floor(total_time / #today_sessions)

	table.insert(lines, {
		{ "  📊 ", "exgreen" },
		{ fmt.fmt_time(total_time), "exgreen" },
		{ " total  •  ", "commentfg" },
		{ fmt.fmt_time(avg_time), "normal" },
		{ " avg  •  ", "commentfg" },
		{ string.format("Focus %d%%", focus_score), focus_score >= 70 and "exgreen" or "exyellow" },
	})
	table.insert(lines, {})

	-- ⏰ Your Peak Hours
	local hourly_activity = s.hourly_activity or {}
	local total_hourly = 0

	-- Use pairs() like insight.lua does (not indexed 0-23)
	for _, time in pairs(hourly_activity) do
		total_hourly = total_hourly + (time or 0)
	end

	if total_hourly > 0 then
		table.insert(lines, { { "  ⏰ Your Peak Hours", "exgreen" } })
		table.insert(lines, {})

		-- Build hourly map from the data structure
		local hourly_map = {}
		for hour_key, time in pairs(hourly_activity) do
			local hour_num = tonumber(hour_key)
			if hour_num then
				hourly_map[hour_num] = time
			end
		end

		-- 6 blocks (better granularity)
		local blocks = {
			{ label = "Night  00-04", start_h = 0, end_h = 3, icon = "🌙" },
			{ label = "Early  04-08", start_h = 4, end_h = 7, icon = "🌅" },
			{ label = "Morn   08-12", start_h = 8, end_h = 11, icon = "☕" },
			{ label = "Noon   12-16", start_h = 12, end_h = 15, icon = "☀️" },
			{ label = "Eve    16-20", start_h = 16, end_h = 19, icon = "🌆" },
			{ label = "Night  20-24", start_h = 20, end_h = 23, icon = "🌃" },
		}

		local max_pct = 0
		local peak_block = nil

		for _, block in ipairs(blocks) do
			local block_time = 0
			for h = block.start_h, block.end_h do
				block_time = block_time + (hourly_map[h] or 0)
			end

			if block_time > 0 then
				local pct = math.floor((block_time / total_hourly) * 100)
				if pct > max_pct then
					max_pct = pct
					peak_block = block.label
				end

				local bar_hl = pct >= 30 and "exgreen" or pct >= 15 and "exblue" or "commentfg"
				local line = {
					{ "  " .. block.icon .. " ", "normal" },
					{ block.label .. " ", "commentfg" },
				}
				for _, seg in ipairs(ui.progress(pct, 18, bar_hl)) do
					table.insert(line, seg)
				end
				table.insert(line, { string.format(" %d%%", pct), "commentfg" })
				table.insert(lines, line)
			end
		end

		-- Add insight
		if peak_block then
			table.insert(lines, {})
			table.insert(lines, {
				{ "  💡 You're most productive in the ", "commentfg" },
				{ peak_block:sub(8), "exgreen" }, -- Remove icon prefix
			})
		end

		table.insert(lines, {})
	end

	-- 🎯 Productivity Insight (from backend)
	local productivity_trend = s.productivity_trend or ""
	if productivity_trend ~= "" then
		table.insert(lines, { { "  🎯 Trend", "exgreen" } })
		table.insert(lines, {})
		table.insert(lines, {
			{ "  ", "commentfg" },
			{ productivity_trend, "exgreen" },
		})
		table.insert(lines, {})
	end

	return lines
end

return M
