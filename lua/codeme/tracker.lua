-- CodeMe Tracker

local M = {}

-- Create augroup once (clear existing autocmds from previous loads)
local augroup = vim.api.nvim_create_augroup("CodeMeTracker", { clear = true })

local last_heartbeat_time = {}
local last_git_diff_lines = {}
local last_non_git_save_time = {}
local active_file = nil
local presence_timer = nil
local PRESENCE_INTERVAL = 120
local COOLDOWN_SAME_FILE = 60
local NON_GIT_COOLDOWN = 60

local function should_track(bufnr, filepath)
	if filepath == "" or not vim.api.nvim_buf_is_valid(bufnr) then
		return false
	end

	if vim.bo[bufnr].buftype ~= "" then
		return false
	end

	local filetype = vim.bo[bufnr].filetype
	local skip_fts = { "NvimTree", "neo-tree", "dashboard", "help", "qf", "TelescopePrompt", "oil", "noice", "notify" }

	if vim.tbl_contains(skip_fts, filetype) then
		return false
	end

	return true
end

local function get_git_lines_changed(filepath)
	local dir = vim.fn.fnamemodify(filepath, ":h")
	local filename = vim.fn.fnamemodify(filepath, ":t")

	-- Try git diff
	local cmd = string.format(
		"cd %s && git diff --numstat HEAD -- %s 2>/dev/null",
		vim.fn.shellescape(dir),
		vim.fn.shellescape(filename)
	)
	local output = vim.fn.system(cmd)

	-- Not in git or no changes
	if vim.v.shell_error ~= 0 or output == "" then
		return nil
	end

	-- Parse: "5	2	file.lua" -> 5 added, 2 deleted = 7 total
	local added, deleted = output:match("^(%d+)%s+(%d+)")
	if added and deleted then
		return tonumber(added) + tonumber(deleted)
	end

	return nil
end

local function send_to_backend(filepath, lines_changed, opts)
	opts = opts or {}

	local bufnr = vim.fn.bufnr(filepath)
	if bufnr == -1 or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local line_count = vim.api.nvim_buf_line_count(bufnr)
	local language = vim.bo[bufnr].filetype ~= "" and vim.bo[bufnr].filetype or "unknown"

	local cmd = {
		opts.codeme_bin or "codeme",
		"track",
		"--file",
		filepath,
		"--lang",
		language,
		"--lines",
		tostring(lines_changed),
		"--total",
		tostring(line_count),
	}

	vim.fn.jobstart(cmd, {
		detach = true,
		on_exit = function(_, code)
			if opts.verbose then
				local heartbeat_type = opts.heartbeat_type or "unknown"
				if code == 0 then
					vim.notify(
						string.format(
							"codeme: ✓ %s (%d lines) [%s]",
							vim.fn.fnamemodify(filepath, ":t"),
							lines_changed,
							heartbeat_type
						),
						vim.log.levels.INFO
					)
				else
					vim.notify(
						string.format("codeme: ✗ failed to track %s", vim.fn.fnamemodify(filepath, ":t")),
						vim.log.levels.WARN
					)
				end
			end
		end,
	})
end

local function calculate_lines_changed(filepath)
	local current_diff = get_git_lines_changed(filepath)

	if current_diff ~= nil then
		-- GIT-TRACKED FILE
		local last_diff = last_git_diff_lines[filepath] or 0
		local delta = current_diff - last_diff

		-- Update baseline
		last_git_diff_lines[filepath] = current_diff

		if delta > 0 then
			return delta, "save" -- productivity signal
		end

		-- File was reset (commit, checkout, stash, etc.)
		-- Still send heartbeat with 0 lines to preserve time tracking
		if current_diff == 0 and last_diff > 0 then
			return 0, "save_reset" -- still counts as time spent
		end

		-- No new changes since last save (delta <= 0)
		-- Don't send redundant heartbeat
		return nil, nil
	else
		-- NON-GIT-TRACKED FILE (with NON_GIT_COOLDOWN throttling)
		local now = os.time()
		local last_save = last_non_git_save_time[filepath]

		if not last_save then
			-- First save of this non-git file
			last_non_git_save_time[filepath] = now
			return 0, "save_new" -- new file, track time only
		elseif (now - last_save) < NON_GIT_COOLDOWN then
			-- Too soon since last save, skip to prevent spam
			-- This implements the NON_GIT_COOLDOWN throttling
			return nil, nil
		else
			-- Enough time passed, send heartbeat and reset timer
			last_non_git_save_time[filepath] = now
			return 0, "save_untracked" -- untracked file, time only
		end
	end
end

function M.send_heartbeat(opts)
	opts = opts or {}
	local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
	local filepath = opts.filepath or vim.fn.expand("%:p")

	if not should_track(bufnr, filepath) then
		return
	end

	local now = os.time()
	local is_save = opts.is_save or false

	if not is_save and not opts.is_periodic then
		local last_time = last_heartbeat_time[filepath]
		if last_time and (now - last_time) < COOLDOWN_SAME_FILE then
			return
		end
	end

	local lines_changed
	local heartbeat_type

	if is_save then
		local delta, hb_type = calculate_lines_changed(filepath)
		if delta == nil then
			return
		end
		lines_changed = delta
		heartbeat_type = hb_type or "save"
	else
		-- Presence / periodic heartbeat: time tracking only
		lines_changed = 0
		heartbeat_type = opts.is_periodic and "periodic" or (opts.heartbeat_type or "presence")
	end

	send_to_backend(filepath, lines_changed, {
		codeme_bin = opts.codeme_bin,
		verbose = opts.verbose,
		heartbeat_type = heartbeat_type,
	})

	last_heartbeat_time[filepath] = now
end

local function start_periodic_heartbeat()
	-- Stop existing timer if any
	if presence_timer then
		vim.fn.timer_stop(presence_timer)
	end

	-- Create new timer: fire every PRESENCE_INTERVAL seconds
	presence_timer = vim.fn.timer_start(PRESENCE_INTERVAL * 1000, function()
		if active_file then
			M.send_heartbeat({
				is_save = false,
				is_periodic = true,
				filepath = active_file,
			})
		end
	end, { repeats = -1 })
end

--- Wire into BufEnter: file opened or switched
vim.api.nvim_create_autocmd("BufEnter", {
	group = augroup,
	callback = function()
		local bufnr = vim.api.nvim_get_current_buf()
		local filepath = vim.fn.expand("%:p")

		if should_track(bufnr, filepath) then
			-- Track active file for periodic heartbeats
			active_file = filepath

			-- Send immediate presence heartbeat on file change (Layer 1)
			M.send_heartbeat({
				is_save = false,
			})

			-- Start/restart periodic timer
			start_periodic_heartbeat()
		end
	end,
})

--- Wire into BufWritePost: file saved
vim.api.nvim_create_autocmd("BufWritePost", {
	group = augroup,
	callback = function()
		local bufnr = vim.api.nvim_get_current_buf()
		local filepath = vim.fn.expand("%:p")

		if should_track(bufnr, filepath) then
			-- Send save heartbeat with productivity metadata (Layer 3)
			M.send_heartbeat({
				is_save = true,
			})
		end
	end,
})

--- Wire into BufLeave: user switched away
vim.api.nvim_create_autocmd("BufLeave", {
	group = augroup,
	callback = function()
		if presence_timer then
			vim.fn.timer_stop(presence_timer)
			presence_timer = nil
		end
		active_file = nil
	end,
})

function M.clear_state()
	last_heartbeat_time = {}
	last_git_diff_lines = {}
	last_non_git_save_time = {}
	active_file = nil

	if presence_timer then
		vim.fn.timer_stop(presence_timer)
		presence_timer = nil
	end
end

--- Get current tracking state (for debugging)
function M.get_state()
	return {
		last_heartbeat_time = vim.deepcopy(last_heartbeat_time),
		last_git_diff_lines = vim.deepcopy(last_git_diff_lines),
		last_non_git_save_time = vim.deepcopy(last_non_git_save_time),
		active_file = active_file,
		config = {
			PRESENCE_INTERVAL = PRESENCE_INTERVAL,
			COOLDOWN_SAME_FILE = COOLDOWN_SAME_FILE,
			NON_GIT_COOLDOWN = NON_GIT_COOLDOWN,
		},
	}
end

return M
