local util = require("codeme.util")
local renderer = require("codeme.ui.renderer")

local M = {}

function M.render(stats, width)
	stats = require("codeme.util").apply_privacy_mask(stats)
	local lines = {}

	table.insert(lines, {})
	table.insert(lines, { { "  💼 Work Portfolio", "exgreen" } })
	table.insert(lines, {})

	-- Build Project Table
	local proj_lines = {}
	table.insert(proj_lines, { { "🔥 Active Projects", "exgreen" } })
	table.insert(proj_lines, {})

	local projects_data = stats.all_time and stats.all_time.projects or {}
	local items = {}
	local total_time = 0

	for _, project in pairs(projects_data) do
		total_time = total_time + (project.time or 0)
		table.insert(items, {
			name = project.name,
			time = project.time or 0,
			lines = project.lines or 0,
			main_lang = project.main_lang or "",
		})
	end

	table.sort(items, function(a, b)
		return a.time > b.time
	end)

	local proj_table_data = { { "Project", "Time", "Lines", "Language" } }
	for i = 1, math.min(10, #items) do
		local it = items[i]
		table.insert(proj_table_data, {
			it.name,
			util.format_duration(it.time),
			util.format_number(it.lines),
			it.main_lang ~= "" and it.main_lang or "Mixed",
		})
	end

	-- Remove Language column if too narrow
	if width < 140 then
		for _, row in ipairs(proj_table_data) do
			table.remove(row, 4)
		end
	end

	local table_w = math.floor(width / 2) - 6
	if width < 120 then
		table_w = width - 10
	end

	for _, l in ipairs(renderer.table(proj_table_data, table_w)) do
		table.insert(proj_lines, l)
	end

	-- Build Language Table
	local lang_lines = {}
	table.insert(lang_lines, { { "💻 Language Mastery", "exgreen" } })
	table.insert(lang_lines, {})

	local langs = stats.all_time and stats.all_time.languages or {}
	local lang_items = {}
	local total_lang_time = 0

	for _, lang in pairs(langs) do
		if lang.is_code then
			total_lang_time = total_lang_time + (lang.time or 0)
			table.insert(lang_items, {
				name = lang.name,
				time = lang.time or 0,
				lines = lang.lines or 0,
				proficiency = lang.proficiency or "Beginner",
				hours_total = lang.hours_total or 0,
			})
		end
	end

	table.sort(lang_items, function(a, b)
		return a.time > b.time
	end)

	local lang_table_data = { { "Language", "Time", "Lines", "Rank" } }
	for i = 1, math.min(10, #lang_items) do
		local it = lang_items[i]
		table.insert(lang_table_data, {
			"● " .. it.name, -- Dot prefix
			util.format_duration(it.time),
			util.format_number(it.lines),
			it.proficiency,
		})
	end

	-- Remove Lines column if too narrow
	if width < 140 then
		for _, row in ipairs(lang_table_data) do
			table.remove(row, 3)
		end
	end

	for _, l in ipairs(renderer.table(lang_table_data, table_w)) do
		table.insert(lang_lines, l)
	end

	-- Layout decision based on width
	if width >= 120 then
		-- Side by side
		local combined = renderer.hbox(proj_lines, lang_lines, 4)
		for _, l in ipairs(combined) do
			table.insert(lines, l)
		end
	else
		-- Vertical stack
		for _, l in ipairs(proj_lines) do
			table.insert(lines, l)
		end
		table.insert(lines, {})
		for _, l in ipairs(lang_lines) do
			table.insert(lines, l)
		end
	end

	table.insert(lines, {})

	-- Overview & Skills
	if #lang_items > 0 then
		table.insert(lines, { { "  📊 Career Overview", "exgreen" } })
		table.insert(lines, {})

		if #items > 0 then
			local main_proj = items[1]
			local main_pct = total_time > 0 and math.floor(main_proj.time / total_time * 100) or 0
			table.insert(lines, {
				{ "  📁 Main Project:  ", "commentfg" },
				{ main_proj.name, "exgreen" },
				{ string.format(" (%d%% share)", main_pct), "commentfg" },
			})
		end

		local favorite = lang_items[1]
		local fav_pct = total_lang_time > 0 and math.floor(favorite.time / total_lang_time * 100) or 0

		table.insert(lines, {
			{ "  ⭐ Main Language: ", "commentfg" },
			{ favorite.name, "excyan" },
			{ string.format(" • %dh • %d%%", favorite.hours_total, fav_pct), "commentfg" },
		})

		-- Proficiency distribution
		local proficiency_counts = {}
		for _, lang in ipairs(lang_items) do
			proficiency_counts[lang.proficiency] = (proficiency_counts[lang.proficiency] or 0) + 1
		end

		if next(proficiency_counts) then
			table.insert(lines, {})
			local prof_order = {
				{ name = "Master", icon = "👑", color = "exgreen" },
				{ name = "Expert", icon = "🏆", color = "exgreen" },
				{ name = "Advanced", icon = "⭐", color = "exyellow" },
				{ name = "Intermediate", icon = "📚", color = "exblue" },
				{ name = "Beginner+", icon = "🌱", color = "commentfg" },
				{ name = "Beginner", icon = "🔰", color = "commentfg" },
			}

			local total_languages = #lang_items
			local NAME_COL_WIDTH = 14
			local BAR_WIDTH = 25

			for _, prof in ipairs(prof_order) do
				local count = proficiency_counts[prof.name] or 0
				if count > 0 then
					local pct = math.floor((count / total_languages) * 100)
					local bar_line = {}
					table.insert(bar_line, { "  " .. prof.icon .. " ", prof.color })
					table.insert(bar_line, { string.format("%-" .. NAME_COL_WIDTH .. "s", prof.name), prof.color })
					for _, seg in ipairs(renderer.progress(pct, BAR_WIDTH, prof.color)) do
						table.insert(bar_line, seg)
					end
					table.insert(bar_line, { string.format(" %d", count), "commentfg" })
					table.insert(lines, bar_line)
				end
			end
		end
	end

	return lines
end

return M
