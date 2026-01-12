local M = {}

function M.show_today()
	local codeme = require("codeme")
	local util = require("codeme.util")

	codeme.get_stats(function(stats)
		if not stats or not stats.today then
			vim.notify("No activity recorded for today", vim.log.levels.INFO, { title = "CodeMe Today" })
			return
		end

		local today = stats.today
		local time = util.format_duration(today.time or 0)
		local lines = util.format_number(today.lines or 0)
		local files = today.files or 0

		local msg = string.format("⏱️  Time: %s\n📝 Lines: %s\n📄 Files: %d", time, lines, files)

		vim.notify(msg, vim.log.levels.INFO, { title = "CodeMe Today" })
	end)
end

function M.show_projects()
	local codeme = require("codeme")
	local util = require("codeme.util")

	codeme.get_stats(function(stats)
		if not stats or not stats.projects or vim.tbl_count(stats.projects) == 0 then
			vim.notify("No projects recorded yet", vim.log.levels.INFO, { title = "CodeMe Projects" })
			return
		end

		-- Sort projects by time
		local projects = {}
		for name, data in pairs(stats.projects) do
			table.insert(projects, {
				name = name,
				time = data.time or 0,
				lines = data.lines or 0,
				files = data.files or 0,
			})
		end

		table.sort(projects, function(a, b)
			return a.time > b.time
		end)

		-- Build message
		local lines = {}
		for i = 1, math.min(5, #projects) do
			local proj = projects[i]
			local time = util.format_duration(proj.time)
			local line_count = util.format_number(proj.lines)
			table.insert(lines, string.format("%s: %s, %s lines", proj.name, time, line_count))
		end

		local msg = table.concat(lines, "\n")
		vim.notify(msg, vim.log.levels.INFO, { title = "Top Projects" })
	end)
end

return M
