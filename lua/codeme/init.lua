local M = {}

-- File state cache for tracking line changes
local file_state = {}

local config = {
	codeme_bin = "codeme", -- Binary name in PATH
	auto_track = true, -- Auto track on file save and open
	track_on_idle = false, -- Track on cursor idle (not implemented yet)
	verbose = false, -- Show tracking notifications
	auto_install = true, -- Auto-install binary if not found
	-- Goals configuration
	goals = {
		daily_hours = 5, -- Daily goal in hours (set to 0 to disable)
		daily_lines = 1000, -- Daily goal in lines (set to 0 to disable)
	},
}

-- Expose config for other modules
function M.get_config()
	return config
end

function M.setup(opts)
	config = vim.tbl_deep_extend("force", config, opts or {})

	-- Setup highlights
	local highlights = require("codeme.highlights")
	highlights.setup()
	highlights.setup_autocmd() -- Auto-reload on colorscheme change

	-- Check if binary is installed
	local installer = require("codeme.installer")
	if config.auto_install and not installer.is_installed() then
		installer.ensure_installed(function(success)
			if success then
				local bin = installer.get_binary()
				if bin then
					config.codeme_bin = bin
				end
				M.setup_tracking()
			end
		end)
	else
		-- Update config with actual binary path
		local bin = installer.get_binary()
		if bin then
			config.codeme_bin = bin
		end
		M.setup_tracking()
	end

	M.setup_commands()
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
		M.track_current_file()
		if config.verbose then
			vim.notify("CodeMe: Tracked current file", vim.log.levels.INFO)
		end
	end, { desc = "Manually track current file" })

	vim.api.nvim_create_user_command("CodeMeInstall", function()
		local installer = require("codeme.installer")
		installer.install_latest(function(success, err)
			if success then
				vim.notify("✓ codeme installed successfully", vim.log.levels.INFO)
				-- Update binary path
				config.codeme_bin = installer.get_binary() or "codeme"
				M.setup_tracking()
			else
				vim.notify("Failed to install codeme: " .. (err or "unknown error"), vim.log.levels.ERROR)
			end
		end)
	end, { desc = "Install/update codeme binary" })

	vim.api.nvim_create_user_command("CodeMeVersion", function()
		local installer = require("codeme.installer")
		installer.get_version(function(version)
			if version then
				vim.notify("codeme " .. version, vim.log.levels.INFO)
			else
				vim.notify("codeme not installed", vim.log.levels.WARN)
			end
		end)
	end, { desc = "Show codeme version" })
end

function M.setup_tracking()
	if not config.auto_track then
		return
	end

	local augroup = vim.api.nvim_create_augroup("CodeMeTrack", { clear = true })

	-- Track on file save
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = augroup,
		callback = function()
			M.track_current_file()
		end,
	})

	-- Track when opening a file (but throttle to avoid spam)
	vim.api.nvim_create_autocmd("BufReadPost", {
		group = augroup,
		callback = function()
			-- Delay to let buffer fully load
			vim.defer_fn(function()
				M.track_current_file()
			end, 100)
		end,
	})

	-- Track on focus gained (when switching back to Neovim)
	vim.api.nvim_create_autocmd("FocusGained", {
		group = augroup,
		callback = function()
			M.track_current_file()
		end,
	})
end

-- Helper: Get git diff stats for a file
local function get_git_diff(filepath)
	-- Check if we're in a git repo
	if vim.v.shell_error ~= 0 then
		return nil -- Not a git repo
	end

	-- Get git diff stats (staged + unstaged changes)
	local cmd = string.format("git diff HEAD --numstat -- %s 2>/dev/null", vim.fn.shellescape(filepath))
	local output = vim.fn.system(cmd)
	if vim.v.shell_error ~= 0 or output == "" then
		return nil
	end

	-- Parse: "5	2	file.lua" = 5 added, 2 deleted = 7 total changes
	local added, deleted = output:match("^(%d+)%s+(%d+)")
	if added and deleted then
		return tonumber(added) + tonumber(deleted)
	end
	return nil
end

-- Track current file
function M.track_current_file()
	local file = vim.fn.expand("%:p")
	local lang = vim.bo.filetype
	local bufnr = vim.api.nvim_get_current_buf()
	local current_lines = vim.api.nvim_buf_line_count(bufnr)

	-- Skip if no file or empty buffer
	if file == "" or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	-- Skip certain filetypes
	local skip_fts = { "", "NvimTree", "neo-tree", "dashboard", "alpha", "help", "qf", "fugitive", "TelescopePrompt" }
	if vim.tbl_contains(skip_fts, lang) then
		return
	end

	-- Skip non-file buffers
	if vim.bo.buftype ~= "" then
		return
	end

	-- Try git diff first (more accurate for git repos)
	local lines_changed = get_git_diff(file)

	-- Fallback to delta calculation if not in git or no changes detected
	if not lines_changed or lines_changed == 0 then
		local previous_lines = file_state[file] or current_lines
		lines_changed = math.abs(current_lines - previous_lines)
	end

	-- Update cache
	file_state[file] = current_lines

	-- Call codeme binary to track (with both changed and total)
	local cmd = string.format(
		"%s track --file %s --lang %s --lines %d --total %d",
		config.codeme_bin,
		vim.fn.shellescape(file),
		lang ~= "" and lang or "unknown",
		lines_changed, -- Changed lines
		current_lines -- Total lines for reference
	)

	vim.fn.jobstart(cmd, {
		detach = true,
		on_exit = function(_, code)
			if code ~= 0 then
				if config.verbose then
					vim.notify("CodeMe: Failed to track file", vim.log.levels.WARN)
				end
			elseif config.verbose then
				vim.notify(
					string.format("CodeMe: Tracked %s (+%d lines)", vim.fn.fnamemodify(file, ":t"), lines_changed),
					vim.log.levels.INFO
				)
			end
		end,
	})
end

-- Get stats from codeme binary
-- @param callback function to call with stats
-- @param today_only boolean if true, only get today's stats
function M.get_stats(callback, today_only)
	local cmd = config.codeme_bin .. " stats --json"
	if today_only then
		cmd = cmd .. " --today"
	end

	-- DEBUG: Log the command being executed
	if config.verbose then
		vim.notify("CodeMe: Running command: " .. cmd, vim.log.levels.DEBUG)
	end

	vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		on_stdout = function(_, data)
			-- DEBUG: Log raw data received
			if config.verbose then
				vim.notify(string.format("CodeMe: Received %d data items", #data), vim.log.levels.DEBUG)
			end

			if data and #data > 0 then
				-- Filter out empty strings AND lines that don't look like JSON
				-- (to handle shell initialization output like "Using Node v22.11.0")
				local filtered = vim.tbl_filter(function(line)
					if line == "" then
						return false
					end
					-- Only accept lines that start with { or are part of JSON
					-- First real line should start with {
					return line:match("^%s*{") or line:match("[,}%]]%s*$")
				end, data)

				-- DEBUG: Log filtered count
				if config.verbose then
					vim.notify(string.format("CodeMe: After filtering: %d items", #filtered), vim.log.levels.DEBUG)
				end

				if #filtered > 0 then
					local json_str = table.concat(filtered, "")

					-- DEBUG: Log JSON string info
					if config.verbose then
						vim.notify(string.format("CodeMe: JSON string length: %d", #json_str), vim.log.levels.DEBUG)
					end

					local ok, stats = pcall(vim.json.decode, json_str)
					if ok and stats then
						callback(stats)
					else
						-- Enhanced error message with details
						vim.notify(
							string.format(
								"CodeMe: Failed to parse stats - invalid JSON\nError: %s\nFirst 200 chars: %s",
								tostring(stats),
								json_str:sub(1, 200)
							),
							vim.log.levels.ERROR
						)
					end
				else
					vim.notify("CodeMe: No data after filtering empty lines", vim.log.levels.WARN)
				end
			else
				vim.notify("CodeMe: No data received from stdout", vim.log.levels.WARN)
			end
		end,
		on_stderr = function(_, data)
			if data and #data > 0 then
				local errors = table.concat(data, "\n")
				if errors ~= "" then
					vim.notify("CodeMe error: " .. errors, vim.log.levels.ERROR)
				end
			end
		end,
		on_exit = function(_, code)
			if code ~= 0 then
				vim.notify(string.format("CodeMe: Command exited with code %d", code), vim.log.levels.ERROR)
			end
		end,
	})
end

return M
