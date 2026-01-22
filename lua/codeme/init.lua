-- CodeMe
-- - Plugin tracks file activity
-- - Git diff calculated on save
-- - Backend stores and aggregates data

local M = {}

M.config = {
	codeme_bin = os.getenv("CODEME_BIN") or "codeme",
	verbose = false,
	auto_track = true,
	goals = {
		daily_hours = 4, -- Daily goal in hours
		daily_lines = 500, -- Daily goal in lines
	},
}

function M.setup(opts)
	opts = opts or {}
	M.config = vim.tbl_deep_extend("force", M.config, opts)

	-- Setup highlights (must be before commands/tracking)
	local highlights = require("codeme.highlights")
	highlights.setup()
	highlights.setup_autocmd() -- Auto-reload on colorscheme change

	M.setup_commands()

	if M.config.auto_track then
		M.setup_tracking()
	end
end

function M.setup_commands()
	vim.api.nvim_create_user_command("CodeMe", function()
		require("codeme.dashboard").show()
	end, { desc = "Open CodeMe dashboard" })

	vim.api.nvim_create_user_command("CodeMeToggle", function()
		require("codeme.dashboard").toggle()
	end, { desc = "Toggle CodeMe dashboard" })

	vim.api.nvim_create_user_command("CodeMeToday", function()
		require("codeme.stats").show_today()
	end, { desc = "Show today's stats" })

	vim.api.nvim_create_user_command("CodeMeProjects", function()
		require("codeme.stats").show_projects()
	end, { desc = "Show project breakdown" })

	vim.api.nvim_create_user_command("CodeMeTrack", function()
		M.track(true)
		if M.config.verbose then
			vim.notify("CodeMe: Heartbeat sent", vim.log.levels.INFO)
		end
	end, { desc = "Manually send heartbeat" })
end

function M.setup_tracking()
	local augroup = vim.api.nvim_create_augroup("CodeMeTrack", { clear = true })

	-- Track on save - this is where we calculate git diff
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = augroup,
		callback = function()
			M.track(true)
		end,
		desc = "CodeMe: Track on save",
	})

	-- Track on open - just a heartbeat, no line counting
	vim.api.nvim_create_autocmd("BufReadPost", {
		group = augroup,
		callback = function()
			vim.defer_fn(function()
				M.track(false)
			end, 100)
		end,
		desc = "CodeMe: Track on open",
	})
end

--- Send tracking heartbeat
--- @param is_save boolean true if this is a save event
function M.track(is_save)
	local tracker = require("codeme.tracker")
	tracker.send_heartbeat({
		is_save = is_save,
		codeme_bin = M.config.codeme_bin,
		verbose = M.config.verbose,
	})
end

function M.get_stats(callback)
	local cmd = M.config.codeme_bin .. " api --compact"
	local output = {}

	vim.fn.jobstart(cmd, {
		stdout_buffered = true, -- still fine
		on_stdout = function(_, data)
			if data then
				vim.list_extend(output, data)
			end
		end,
		on_stderr = function(_, data)
			if data and #data > 0 then
				local msg = table.concat(data, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
				if msg ~= "" then
					vim.notify("CodeMe API error: " .. msg, vim.log.levels.WARN)
				end
			end
		end,
		on_exit = function(_, exit_code)
			if exit_code ~= 0 then
				vim.notify(string.format("CodeMe API exited with code %d", exit_code), vim.log.levels.ERROR)
				return
			end

			local json_str = table.concat(output, "\n")
			-- Strip anything before first `{`
			json_str = json_str:match("({.*})")
			if not json_str then
				vim.notify("CodeMe: No JSON found in output", vim.log.levels.ERROR)
				return
			end

			local ok, stats = pcall(vim.json.decode, json_str)
			if ok then
				callback(stats)
			else
				vim.notify(
					string.format("CodeMe: Failed to parse stats JSON\nFirst 200 chars: %s", json_str:sub(1, 200)),
					vim.log.levels.ERROR
				)
			end
		end,
	})
end

function M.get_config()
	return M.config
end

return M
