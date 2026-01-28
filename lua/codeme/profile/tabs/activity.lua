local state = require("codeme.profile.state")
local fmt = require("codeme.profile.formatters")
local helpers = require("codeme.profile.helpers")
local ui = require("codeme.ui")

local M = {}

function M.render()
	local globalStats = state.stats or {}
	local lines = {}

	local today = globalStats.today or {}
	local today_sessions = today.sessions or {}
	local total_time = today.total_time or 0
	local focus_score = today.focus_score or 0

	-- Header
	local today_date = os.date("%A, %B %d")

	table.insert(lines, {})
	table.insert(lines, {
		{ "  ☀️  Today's Activity", "exgreen" },
		{ string.rep(" ", 35), "commentfg" },
		{ fmt.fmt_time(total_time), "exgreen" },
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

	-- 📖 Your Story Today (narrative summary)
	table.insert(lines, { { "  📖 Your Story Today", "exgreen" } })
	table.insert(lines, {})

	-- Safety check: ensure we have sessions before accessing them
	if #today_sessions > 0 then
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
		end
	end

	-- ⏰ Session Timeline
	table.insert(lines, { { "  ⏰ Session Timeline", "exgreen" } })
	table.insert(lines, {})

	if #today_sessions == 0 then
		table.insert(lines, { { "  No sessions recorded yet", "commentfg" } })
		table.insert(lines, {})
		return
	end

	-- Find peak session (longest)
	local peak_index = 1
	for i = 2, #today_sessions do
		if (today_sessions[i].duration or 0) > (today_sessions[peak_index].duration or 0) then
			peak_index = i
		end
	end

	local tbl = {
		{ "Time", "Duration", "Projects", "Languages" },
	}

	for i, session in ipairs(today_sessions) do
		if session.start_time then
			local time_str = session.start_time:sub(12, 16)
			local duration_str = fmt.fmt_time(session.duration or 0)

			if i == peak_index and #today_sessions > 1 then
				duration_str = duration_str .. " ⭐"
			end

			local projects = helpers.top_items(session.projects, 2)
			local languages = helpers.top_items(session.languages, 5)

			tbl[#tbl + 1] = {
				time_str,
				duration_str,
				projects ~= "" and projects or "-",
				languages ~= "" and languages or "-",
			}

			-- Breaks
			if session.break_after and session.break_after > 300 then
				local icon = session.break_after < 1800 and "☕" or "🍽️"
				tbl[#tbl + 1] = {
					"",
					icon .. " " .. fmt.fmt_time(session.break_after),
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

	-- ⏰ Time by Language
	local languages = today.languages
	if #languages > 0 then
		table.insert(lines, { { "  ⏰ Time by Language", "exgreen" } })
		table.insert(lines, {})

		local tblLang = { { "Language", "Time" } }
		for _, lang in ipairs(languages) do
			table.insert(tblLang, {
				lang.name,
				fmt.fmt_time(lang.time),
			})
		end

		for _, l in ipairs(ui.table(tblLang, state.width - 8)) do
			table.insert(lines, l)
		end
		table.insert(lines, {})
	end

	-- 📊 Quick Stats
	table.insert(lines, {
		{ "  📊 ", "exgreen" },
		{ fmt.fmt_time(total_time), "exgreen" },
		{ " total  •  ", "commentfg" },
		{ string.format("Focus %d%%", focus_score), focus_score >= 70 and "exgreen" or "exyellow" },
	})
	table.insert(lines, {})

	-- ⏰ Your Peak Hours
	-- Normalize API data: hour -> duration
	local hourly_activity = {}
	for _, item in ipairs(today.hourly_activity or {}) do
		hourly_activity[item.hour] = item.duration or 0
	end

	-- Total duration
	local total_hourly = 0
	for _, dur in pairs(hourly_activity) do
		total_hourly = total_hourly + dur
	end

	-- Nothing to show
	if total_hourly == 0 then
		return
	end

	table.insert(lines, { { "  ⏰ Your Peak Hours", "exgreen" } })
	table.insert(lines, {})

	local blocks = {
		{ label = "Night  00-04", start_h = 0, end_h = 3, icon = "🌙" },
		{ label = "Early  04-08", start_h = 4, end_h = 7, icon = "🌅" },
		{ label = "Morn   08-12", start_h = 8, end_h = 11, icon = "☕" },
		{ label = "Noon   12-16", start_h = 12, end_h = 15, icon = "☀️" },
		{ label = "Eve    16-20", start_h = 16, end_h = 19, icon = "🌆" },
		{ label = "Night  20-24", start_h = 20, end_h = 23, icon = "🌃" },
	}

	local peak_block, max_pct = nil, 0

	for _, block in ipairs(blocks) do
		local block_time = 0
		for h = block.start_h, block.end_h do
			block_time = block_time + (hourly_activity[h] or 0)
		end

		if block_time > 0 then
			local pct = math.floor((block_time / total_hourly) * 100)

			if pct > max_pct then
				max_pct = pct
				peak_block = block.label
			end

			local hl = pct >= 30 and "exgreen" or pct >= 15 and "exblue" or "commentfg"

			local line = {
				{ "  " .. block.icon .. " ", "normal" },
				{ block.label .. " ", "commentfg" },
			}

			for _, seg in ipairs(ui.progress(pct, 18, hl)) do
				line[#line + 1] = seg
			end

			line[#line + 1] = { string.format(" %d%%", pct), "commentfg" }

			table.insert(lines, line)
		end
	end

	if peak_block then
		table.insert(lines, {})
		table.insert(lines, {
			{ "  💡 You're most productive in the ", "commentfg" },
			{ peak_block:sub(8), "exgreen" },
		})
	end

	table.insert(lines, {})

	-- 🎯 Productivity Trend
	local productivity_trend = globalStats.day_over_day and globalStats.day_over_day.trend or ""
	if productivity_trend ~= "" then
		local trend_text
		if productivity_trend == "increasing" then
			trend_text = "📈 Productivity Increasing"
		elseif productivity_trend == "decreasing" then
			trend_text = "📉 Slowing Down"
		else
			trend_text = "➡️  Stable Pace"
		end

		table.insert(lines, { { "  🎯 Trend", "exgreen" } })
		table.insert(lines, {})
		table.insert(lines, {
			{ "  ", "commentfg" },
			{ trend_text, "exgreen" },
		})
		table.insert(lines, {})
	end

	return lines
end

return M
