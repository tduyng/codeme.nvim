local state = require("codeme.profile.state")
local fmt = require("codeme.profile.formatters")
local ui = require("codeme.ui")

local M = {}

function M.render()
	local globalStats = state.stats or {}
	local lines = {}

	table.insert(lines, {})
	table.insert(lines, { { "  💼 Work Portfolio", "exgreen" } })
	table.insert(lines, {})

	-- PROJECTS
	table.insert(lines, { { "  🔥 Active Projects", "exgreen" } })
	table.insert(lines, {})

	local projects_data = globalStats.all_time and globalStats.all_time.projects or {}
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
				growth = project.growth or "",
				last_active = project.last_active,
			})
		end

		table.sort(items, function(a, b)
			return a.time > b.time
		end)

		-- Projects table (top 10)
		local tbl = { { "Project", "Time", "Lines", "Language", "Trend" } }

		for i = 1, math.min(10, #items) do
			local it = items[i]
			tbl[#tbl + 1] = {
				it.name,
				fmt.fmt_time(it.time),
				fmt.fmt_num(it.lines),
				it.main_lang ~= "" and it.main_lang or "Mixed",
				it.growth ~= "" and it.growth or "-",
			}
		end

		for _, l in ipairs(ui.table(tbl, state.width - 8)) do
			table.insert(lines, l)
		end
		table.insert(lines, {})

		-- Quick stats
		if #items > 0 then
			local main_proj = items[1]
			local main_pct = total_time > 0 and math.floor(main_proj.time / total_time * 100) or 0

			-- Count active projects (last 7 days)
			local active_count = 0
			for _, proj in ipairs(items) do
				if proj.last_active and proj.last_active ~= "" then
					local y, m, d = proj.last_active:match("(%d%d%d%d)-(%d%d)-(%d%d)")
					if y and m and d then
						local t = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d) })
						if t then
							local days_ago = math.floor((os.time() - t) / 86400)
							if days_ago <= 7 then
								active_count = active_count + 1
							end
						end
					end
				end
			end

			table.insert(lines, {
				{ "  Main: ", "commentfg" },
				{ main_proj.name, "exgreen" },
				{ string.format(" (%d%%)", main_pct), "commentfg" },
				{ "  •  Active (last 7 days): ", "commentfg" },
				{ tostring(active_count) .. "/" .. tostring(#items), "exyellow" },
			})
			table.insert(lines, {})
		end
	end

	-- LANGUAGES
	table.insert(lines, { { "  💻 Language Mastery", "exgreen" } })
	table.insert(lines, {})

	local langs = globalStats.all_time and globalStats.all_time.languages or {}
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
				trending = lang.trending or false,
			})
		end

		table.sort(lang_items, function(a, b)
			return a.time > b.time
		end)

		-- Languages table (top 10)
		local tbl = { { "Language", "Time", "Proficiency", "Status" } }

		for i = 1, math.min(10, #lang_items) do
			local it = lang_items[i]

			local status = "-"
			if it.trending then
				status = "↗"
			elseif it.proficiency == "Master" or it.proficiency == "Expert" then
				status = "🏆 Expert"
			elseif it.proficiency == "Advanced" then
				status = "⭐ Advanced"
			end

			tbl[#tbl + 1] = {
				it.name,
				fmt.fmt_time(it.time),
				it.proficiency,
				status,
			}
		end

		for _, l in ipairs(ui.table(tbl, state.width - 8)) do
			table.insert(lines, l)
		end
		table.insert(lines, {})

		-- OVERVIEW
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

					-- Icon column (2-space indent + icon)
					table.insert(bar_line, { "  " .. prof.icon .. " ", prof.color })

					-- Name column (manually padded)
					table.insert(bar_line, {
						string.format("%-" .. NAME_COL_WIDTH .. "s", prof.name),
						prof.color,
					})

					-- Space before bar
					table.insert(bar_line, { " ", "normal" })

					-- Progress bar
					for _, seg in ipairs(ui.progress(pct, BAR_WIDTH, prof.color)) do
						table.insert(bar_line, seg)
					end

					-- Count column
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
