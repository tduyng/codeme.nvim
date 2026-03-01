local util = require("codeme.util")
local renderer = require("codeme.ui.renderer")

local M = {}

function M.render(stats, width)
	stats = require("codeme.util").apply_privacy_mask(stats)
	local lines = {}

	-- Helper for safe padding (local to avoid nil field errors)
	local function safe_pad(s, w)
		local str = s or ""
		local current_w = vim.api.nvim_strwidth(str)
		local diff = w - current_w
		return str .. (diff > 0 and string.rep(" ", diff) or "")
	end

	table.insert(lines, {})
	table.insert(lines, { { "  🏆 Hall of Fame", "exgreen" } })
	table.insert(lines, {})

	-- Career Level & Stats
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

	local current_level = nil
	local next_level = nil
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
			{ "RANK: ", "commentfg" },
			{ current_level.icon .. " " .. current_level.name .. " Coder", current_level.color },
		})
	else
		table.insert(badge_lines, { { "RANK: ", "commentfg" }, { "🌱 Beginner", "exblue" } })
	end
	table.insert(badge_lines, { { "TOTAL: ", "commentfg" }, { tostring(total_hours) .. " coding hours", "normal" } })

	if next_level then
		local progress_pct = math.floor((total_hours / next_level.threshold) * 100)
		local bar_segs = renderer.progress(progress_pct, 20, "exyellow")
		local line = { { "NEXT: ", "commentfg" } }
		for _, s in ipairs(bar_segs) do
			table.insert(line, s)
		end
		table.insert(line, { " " .. progress_pct .. "%", "commentfg" })
		table.insert(badge_lines, line)
	end

	local stats_lines = {
		{ { "PERIOD      TIME        LINES", "commentfg" } },
		{
			{ "All Time    ", "commentfg" },
			{ safe_pad(util.format_duration(all_time.total_time or 0), 12), "exgreen" },
			{ util.format_number(all_time.total_lines or 0), "normal" },
		},
		{
			{ "This Month  ", "commentfg" },
			{ safe_pad(util.format_duration((stats.this_month or {}).total_time or 0), 12), "exgreen" },
			{ util.format_number((stats.this_month or {}).total_lines or 0), "normal" },
		},
		{
			{ "Today       ", "commentfg" },
			{ safe_pad(util.format_duration((stats.today or {}).total_time or 0), 12), "exgreen" },
			{ util.format_number((stats.today or {}).total_lines or 0), "normal" },
		},
	}

	local badge_card = renderer.card("Career Badge", badge_lines, 45, "exyellow")
	local stats_card = renderer.card("Summary", stats_lines, 45, "exblue")

	if width >= 100 then
		for _, l in ipairs(renderer.hbox(badge_card, stats_card, 4)) do
			table.insert(lines, l)
		end
	else
		for _, l in ipairs(badge_card) do
			table.insert(lines, l)
		end
		for _, l in ipairs(stats_card) do
			table.insert(lines, l)
		end
	end
	table.insert(lines, {})

	-- Achievements Trophy Cabinet (Grid)
	local achievements = stats.achievements or {}
	if #achievements > 0 then
		table.insert(lines, { { "  🎖️ Trophy Cabinet", "exgreen" } })
		table.insert(lines, {})

		local grid_lines = {}
		local current_grid_line = { { "  ", "normal" } }
		local count_in_row = 0
		local max_per_row = width >= 120 and 10 or 6

		for _, ach in ipairs(achievements) do
			local hl = ach.unlocked and "normal" or "commentfg"
			local icon = ach.unlocked and ach.icon or "🔒"
			table.insert(current_grid_line, { " [" .. icon .. "] ", hl })
			count_in_row = count_in_row + 1
			if count_in_row >= max_per_row then
				table.insert(grid_lines, current_grid_line)
				current_grid_line = { { "  ", "normal" } }
				count_in_row = 0
			end
		end
		if count_in_row > 0 then
			table.insert(grid_lines, current_grid_line)
		end

		for _, l in ipairs(grid_lines) do
			table.insert(lines, l)
		end
		table.insert(lines, {})

		-- Unlocked Achievements Details (Restored)
		local unlocked = {}
		for _, ach in ipairs(achievements) do
			if ach.unlocked then
				table.insert(unlocked, ach)
			end
		end
		if #unlocked > 0 then
			for i = 1, math.min(5, #unlocked) do
				local ach = unlocked[#unlocked - i + 1] -- Show latest 5
				table.insert(lines, {
					{ "  " .. ach.icon .. " ", "normal" },
					{ ach.name, "exgreen" },
					{ " - ", "commentfg" },
					{ ach.description, "commentfg" },
				})
			end
			if #unlocked > 5 then
				table.insert(lines, { { "    ... and " .. (#unlocked - 5) .. " more badges", "commentfg" } })
			end
		end
		table.insert(lines, {})
	end

	-- Records Table
	table.insert(lines, { { "  🏆 Personal Records", "exgreen" } })
	table.insert(lines, {})

	local records = stats.records or {}
	local record_list = {}
	local mpd = records.most_productive_day or {}
	if mpd.time and mpd.time > 0 then
		table.insert(record_list, { "🏆 Best Day", util.format_duration(mpd.time), util.format_date(mpd.date or "") })
	end
	local ls = records.longest_session or {}
	if ls.duration and ls.duration > 0 then
		table.insert(
			record_list,
			{ "⏱️ Longest Session", util.format_duration(ls.duration), util.format_date(ls.date or "") }
		)
	end
	local hdo = records.highest_daily_output or {}
	if hdo.lines and hdo.lines > 0 then
		table.insert(record_list, { "📝 Most Lines", util.format_number(hdo.lines), util.format_date(hdo.date or "") })
	end

	if #record_list > 0 then
		local records_tbl = { { "Category", "Result", "Achieved On" } }
		for _, rec in ipairs(record_list) do
			table.insert(records_tbl, rec)
		end
		for _, l in ipairs(renderer.table(records_tbl, width - 10)) do
			table.insert(lines, l)
		end
		table.insert(lines, {})
	end

	-- Fun Facts (Restored)
	local earliest_start = records.earliest_start or {}
	local latest_end = records.latest_end or {}
	local most_languages_day = records.most_languages_day or {}
	local has_fun_facts = earliest_start.time or latest_end.time or (most_languages_day and most_languages_day.date)

	if has_fun_facts then
		table.insert(lines, { { "  📊 Fun Facts", "exgreen" } })
		table.insert(lines, {})
		if earliest_start.time then
			table.insert(
				lines,
				{
					{ "  🌅 Early Bird: ", "commentfg" },
					{ earliest_start.time, "exgreen" },
					{ " (" .. (earliest_start.date or "") .. ")", "commentfg" },
				}
			)
		end
		if latest_end.time then
			table.insert(
				lines,
				{
					{ "  🌙 Night Owl: ", "commentfg" },
					{ latest_end.time, "exgreen" },
					{ " (" .. (latest_end.date or "") .. ")", "commentfg" },
				}
			)
		end
		if most_languages_day and most_languages_day.date ~= "" then
			local langs_count = util.safe_length(most_languages_day.languages)
			if langs_count > 0 then
				table.insert(
					lines,
					{
						{ "  🌍 Polyglot Day: ", "commentfg" },
						{ langs_count .. " languages", "exgreen" },
						{ " (" .. most_languages_day.date .. ")", "commentfg" },
					}
				)
			end
		end
		table.insert(lines, {})
	end

	-- Challenges (Restored)
	table.insert(lines, { { "  💪 Challenges", "exgreen" } })
	table.insert(lines, {})
	local today_time = (stats.today or {}).total_time or 0
	local streak_info = stats.streak_info or {}
	local challenges = {}

	if mpd.time and today_time > 0 and mpd.time > today_time then
		table.insert(
			challenges,
			{ icon = "🎯", text = util.format_duration(mpd.time - today_time) .. " to beat your best day", hl = "exyellow" }
		)
	end
	if ls.duration then
		table.insert(
			challenges,
			{ icon = "⏰", text = "Can you beat " .. util.format_duration(ls.duration) .. " in one session?", hl = "normal" }
		)
	end
	if #challenges > 0 then
		for _, ch in ipairs(challenges) do
			table.insert(lines, { { "  " .. ch.icon .. "  ", "normal" }, { ch.text, ch.hl } })
		end
	else
		table.insert(lines, { { "  💡 Keep coding to set new records!", "commentfg" } })
	end
	table.insert(lines, {})

	return lines
end

return M
