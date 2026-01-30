local domain = require("codeme.domain")
local renderer = require("codeme.ui.renderer")

local M = {}

function M.render(stats)
	local lines = {}

	table.insert(lines, {})
	table.insert(lines, { { "  💼 Work Portfolio", "exgreen" } })
	table.insert(lines, {})

	-- Projects
	table.insert(lines, { { "  🔥 Active Projects", "exgreen" } })
	table.insert(lines, {})

	local projects_data = stats.all_time and stats.all_time.projects or {}
	if not next(projects_data) then
		table.insert(lines, { { "  No projects tracked yet", "commentfg" } })
		table.insert(lines, {})
	else
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

		local tbl = { { "Project", "Time", "Lines", "Language" } }

		for i = 1, math.min(10, #items) do
			local it = items[i]
			tbl[#tbl + 1] = {
				it.name,
				domain.format_duration(it.time),
				domain.format_number(it.lines),
				it.main_lang ~= "" and it.main_lang or "Mixed",
			}
		end

		for _, l in ipairs(renderer.table(tbl, 120)) do
			table.insert(lines, l)
		end
		table.insert(lines, {})

		if #items > 0 then
			local main_proj = items[1]
			local main_pct = total_time > 0 and math.floor(main_proj.time / total_time * 100) or 0

			table.insert(lines, {
				{ "  Main: ", "commentfg" },
				{ main_proj.name, "exgreen" },
				{ string.format(" (%d%%)", main_pct), "commentfg" },
			})
			table.insert(lines, {})
		end
	end

	-- Languages
	table.insert(lines, { { "  💻 Language Mastery", "exgreen" } })
	table.insert(lines, {})

	local langs = stats.all_time and stats.all_time.languages or {}
	if not next(langs) then
		table.insert(lines, { { "  No languages tracked yet", "commentfg" } })
		table.insert(lines, {})
	else
		local lang_items = {}
		local total_lang_time = 0

		for _, lang in pairs(langs) do
			total_lang_time = total_lang_time + (lang.time or 0)
			table.insert(lang_items, {
				name = lang.name,
				time = lang.time or 0,
				lines = lang.lines or 0,
				proficiency = lang.proficiency or "Beginner",
				hours_total = lang.hours_total or 0,
			})
		end

		table.sort(lang_items, function(a, b)
			return a.time > b.time
		end)

		local tbl = { { "Language", "Time", "Lines", "Proficiency" } }

		for i = 1, math.min(10, #lang_items) do
			local it = lang_items[i]

			tbl[#tbl + 1] = {
				it.name,
				domain.format_duration(it.time),
				it.lines,
				it.proficiency,
			}
		end

		for _, l in ipairs(renderer.table(tbl, 120)) do
			table.insert(lines, l)
		end
		table.insert(lines, {})

		-- Overview
		table.insert(lines, { { "  📊 Overview", "exgreen" } })
		table.insert(lines, {})

		local total_languages = #lang_items

		if #lang_items > 0 then
			local favorite = lang_items[1]
			local fav_pct = total_lang_time > 0 and math.floor(favorite.time / total_lang_time * 100) or 0

			table.insert(lines, {
				{ "  ⭐ Main: ", "commentfg" },
				{ favorite.name, "exgreen" },
				{ string.format(" • %dh • %d%%", favorite.hours_total, fav_pct), "commentfg" },
			})
		end

		-- Proficiency distribution
		local proficiency_counts = {}
		for _, lang in ipairs(lang_items) do
			proficiency_counts[lang.proficiency] = (proficiency_counts[lang.proficiency] or 0) + 1
		end

		if next(proficiency_counts) then
			table.insert(lines, {})
			table.insert(lines, { { "  Skills", "commentfg" } })

			local prof_order = {
				{ name = "Master", icon = "👑", color = "exgreen" },
				{ name = "Expert", icon = "🏆", color = "exgreen" },
				{ name = "Advanced", icon = "⭐", color = "exyellow" },
				{ name = "Intermediate", icon = "📚", color = "exblue" },
				{ name = "Beginner+", icon = "🌱", color = "commentfg" },
				{ name = "Beginner", icon = "🔰", color = "commentfg" },
			}

			local NAME_COL_WIDTH = 14
			local BAR_WIDTH = 15

			for _, prof in ipairs(prof_order) do
				local count = proficiency_counts[prof.name] or 0
				if count > 0 then
					local pct = math.floor((count / total_languages) * 100)

					local bar_line = {}
					table.insert(bar_line, { "  " .. prof.icon .. " ", prof.color })
					table.insert(bar_line, {
						string.format("%-" .. NAME_COL_WIDTH .. "s", prof.name),
						prof.color,
					})
					table.insert(bar_line, { " ", "normal" })

					for _, seg in ipairs(renderer.progress(pct, BAR_WIDTH, prof.color)) do
						table.insert(bar_line, seg)
					end

					table.insert(bar_line, {
						string.format(" %d", count),
						"commentfg",
					})

					table.insert(lines, bar_line)
				end
			end
		end
	end

	return lines
end

return M
