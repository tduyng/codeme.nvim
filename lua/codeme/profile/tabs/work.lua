local state = require("codeme.profile.state")
local fmt = require("codeme.profile.formatters")
local ui = require("codeme.ui")

local M = {}

function M.render()
	local s = state.stats
	local lines = {}

	table.insert(lines, {})
	table.insert(lines, { { "  💼 Work Portfolio", "exgreen" } })
	table.insert(lines, {})

	-- PROJECTS
	table.insert(lines, { { "  🔥 Active Projects", "exgreen" } })
	table.insert(lines, {})

	local projects_data = s.projects or {}
	if not next(projects_data) then
		table.insert(lines, { { "  No projects tracked yet", "commentfg" } })
		table.insert(lines, {})
	else
		local items = {}
		local total_time = 0

		for name, stat in pairs(projects_data) do
			total_time = total_time + (stat.time or 0)
			table.insert(items, {
				name = name,
				time = stat.time or 0,
				lines = stat.lines or 0,
				main_lang = stat.main_lang or "",
				growth = stat.growth or "",
				last_active = stat.last_active,
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
					local year, month, day = proj.last_active:match("(%d%d%d%d)-(%d%d)-(%d%d)")
					if year and month and day then
						local proj_time = os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(day) })
						local days_ago = math.floor((os.time() - proj_time) / 86400)
						if days_ago <= 7 then
							active_count = active_count + 1
						end
					end
				end
			end

			table.insert(lines, {
				{ "  Main: ", "commentfg" },
				{ main_proj.name, "exgreen" },
				{ string.format(" (%d%%)", main_pct), "commentfg" },
				{ "  •  Active: ", "commentfg" },
				{ tostring(active_count) .. "/" .. tostring(#items), "exyellow" },
			})
			table.insert(lines, {})
		end
	end

	-- LANGUAGES
	table.insert(lines, { { "  💻 Language Mastery", "exgreen" } })
	table.insert(lines, {})

	local programming_languages = s.programming_languages or {}
	if not next(programming_languages) then
		table.insert(lines, { { "  No languages tracked yet", "commentfg" } })
		table.insert(lines, {})
	else
		local lang_items = {}
		local total_lang_time = 0

		for name, stat in pairs(programming_languages) do
			total_lang_time = total_lang_time + (stat.time or 0)
			table.insert(lang_items, {
				name = name,
				time = stat.time or 0,
				lines = stat.lines or 0,
				proficiency = stat.proficiency or "Beginner",
				hours_total = stat.hours_total or 0,
				trending = stat.trending or false,
			})
		end

		-- Sort by total time (global)
		table.sort(lang_items, function(a, b)
			return a.time > b.time
		end)

		-- Languages table (top 10)
		local tbl = { { "Language", "Time", "Proficiency", "Status" } }

		for i = 1, math.min(10, #lang_items) do
			local it = lang_items[i]

			local status = ""
			if it.trending then
				status = "🔥 Hot"
			elseif it.proficiency == "Master" or it.proficiency == "Expert" then
				status = "🏆 Expert"
			elseif it.proficiency == "Advanced" then
				status = "⭐ Advanced"
			else
				status = "-"
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

		-- LANGUAGE STATS
		table.insert(lines, { { "  📊 Overview", "exgreen" } })
		table.insert(lines, {})

		local total_languages = #lang_items

		-- Top language stats
		if #lang_items > 0 then
			local favorite = lang_items[1]
			local fav_pct = total_lang_time > 0 and math.floor(favorite.time / total_lang_time * 100) or 0

			table.insert(lines, {
				{ "  ⭐ Main: ", "commentfg" },
				{ favorite.name, "exgreen" },
				{ string.format(" • %dh • %d%%", favorite.hours_total, fav_pct), "commentfg" },
			})
		end

		-- Proficiency distribution (visual bars)
		local proficiency_counts = {}
		for _, lang in ipairs(lang_items) do
			local prof = lang.proficiency
			proficiency_counts[prof] = (proficiency_counts[prof] or 0) + 1
		end

		local has_proficiency = false
		for _, count in pairs(proficiency_counts) do
			if count > 0 then
				has_proficiency = true
				break
			end
		end

		if has_proficiency then
			table.insert(lines, {})
			table.insert(lines, { { "  Skill Levels:", "commentfg" } })

			local prof_order = {
				{ name = "Master", icon = "👑", color = "exgreen" },
				{ name = "Expert", icon = "🏆", color = "exgreen" },
				{ name = "Advanced", icon = "⭐", color = "exyellow" },
				{ name = "Intermediate", icon = "📚", color = "exblue" },
				{ name = "Beginner+", icon = "🌱", color = "commentfg" },
				{ name = "Beginner", icon = "🔰", color = "commentfg" },
			}

			for _, prof in ipairs(prof_order) do
				local count = proficiency_counts[prof.name] or 0
				if count > 0 then
					local pct = math.floor((count / total_languages) * 100)
					local bar_line = { { "  " .. prof.icon .. " ", "normal" } }
					for _, seg in ipairs(ui.progress(pct, 15, prof.color)) do
						table.insert(bar_line, seg)
					end
					table.insert(bar_line, { string.format(" %d", count), prof.color })
					table.insert(lines, bar_line)
				end
			end
		end

		table.insert(lines, {})

		-- POLYGLOT PROGRESS
		table.insert(lines, { { "  🌍 Polyglot Journey", "exgreen" } })
		table.insert(lines, {})

		local milestones = {
			{ threshold = 20, name = "Code Polymath", icon = "🎓" },
			{ threshold = 15, name = "Polyglot Master", icon = "🧠" },
			{ threshold = 10, name = "Multi-Linguist", icon = "🌍" },
			{ threshold = 5, name = "Polyglot", icon = "🚀" },
			{ threshold = 2, name = "Bilingual", icon = "💬" },
		}

		local current_level = nil
		local next_level = nil

		for _, m in ipairs(milestones) do
			if total_languages >= m.threshold then
				current_level = m
				break
			else
				next_level = m
			end
		end

		-- Current level
		if current_level then
			table.insert(lines, {
				{ "  " .. current_level.icon .. "  ", "normal" },
				{ current_level.name, "exgreen" },
				{ string.format("  •  %d language%s", total_languages, total_languages > 1 and "s" or ""), "commentfg" },
			})
		else
			table.insert(lines, {
				{ "  🔰  ", "normal" },
				{ "Beginner", "commentfg" },
				{ string.format("  •  %d language%s", total_languages, total_languages > 1 and "s" or ""), "commentfg" },
			})
		end

		-- Next level progress
		if next_level then
			local needed = next_level.threshold - total_languages
			local progress_pct = math.floor((total_languages / next_level.threshold) * 100)

			table.insert(lines, {})
			local progress_line = { { "  Next: " .. next_level.icon .. " " .. next_level.name .. "  ", "commentfg" } }
			for _, seg in ipairs(ui.progress(progress_pct, 15, "exyellow")) do
				table.insert(progress_line, seg)
			end
			table.insert(progress_line, { string.format(" %d%%", progress_pct), "exyellow" })
			table.insert(lines, progress_line)

			table.insert(lines, {
				{ "  ", "commentfg" },
				{ string.format("%d more language%s to go!", needed, needed > 1 and "s" or ""), "commentfg" },
			})
		else
			table.insert(lines, {})
			table.insert(lines, {
				{ "  👑 ", "exgreen" },
				{ "MAXIMUM LEVEL ACHIEVED!", "exgreen" },
			})
		end

		table.insert(lines, {})

		-- HIGHLIGHTS
		table.insert(lines, { { "  🔥 Highlights", "exgreen" } })
		table.insert(lines, {})

		-- Top 5 languages (FIXED: Global top 5)
		if #lang_items > 0 then
			local top_langs = {}
			for i = 1, math.min(5, #lang_items) do
				table.insert(top_langs, lang_items[i].name)
			end
			table.insert(lines, {
				{ "  💎 Top 5: ", "commentfg" },
				{ table.concat(top_langs, ", "), "exgreen" },
			})
		end

		-- Trending languages
		local trending_langs = {}
		for _, lang in ipairs(lang_items) do
			if lang.trending then
				table.insert(trending_langs, lang.name)
			end
		end

		if #trending_langs > 0 then
			table.insert(lines, {
				{ "  📈 Trending: ", "commentfg" },
				{ table.concat(trending_langs, ", "), "exyellow" },
				{ " 🔥", "normal" },
			})
		end

		-- Expert languages
		local expert_langs = {}
		for _, lang in ipairs(lang_items) do
			if lang.proficiency == "Expert" or lang.proficiency == "Master" then
				table.insert(expert_langs, lang.name)
			end
		end

		if #expert_langs > 0 then
			table.insert(lines, {
				{ "  🏆 Mastered: ", "commentfg" },
				{ table.concat(expert_langs, ", "), "exgreen" },
			})
		end

		table.insert(lines, {})
	end

	return lines
end

return M
