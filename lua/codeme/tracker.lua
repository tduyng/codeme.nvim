-- CodeMe Tracker
--
-- Key principles:
-- 1. On SAVE: Calculate git diff DELTA (changes since last save), send only new changes
--    - Git-tracked files: Track line count delta using git diff
--    - Non-git files: Track activity (time) but not line counts (can't calculate without git)
-- 2. On OPEN: Send heartbeat with file info (backend logs activity time)
-- 3. Use 2-min cooldown to prevent spam on file opens
-- 4. Track last git diff per file to avoid counting same changes multiple times

local M = {}

-- Last heartbeat time per file
local last_heartbeat = {}
-- Last git diff value per file (for delta tracking)
local last_git_diff = {}
local COOLDOWN_SECONDS = 120

--- Calculate git diff for file (returns lines changed, or nil if not in git)
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

--- Send heartbeat
function M.send_heartbeat(opts)
	opts = opts or {}

	local bufnr = vim.api.nvim_get_current_buf()
	local filepath = vim.fn.expand("%:p")

	-- Validation
	if filepath == "" or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	if vim.bo[bufnr].buftype ~= "" then
		return
	end

	local filetype = vim.bo[bufnr].filetype
	local skip_fts = { "NvimTree", "neo-tree", "dashboard", "help", "qf", "TelescopePrompt", "oil", "noice", "notify" }
	if vim.tbl_contains(skip_fts, filetype) then
		return
	end

	-- Cooldown check (skip for save events)
	local now = os.time()
	local is_save = opts.is_save or false

	if not is_save then
		local last_time = last_heartbeat[filepath]
		if last_time and (now - last_time) < COOLDOWN_SECONDS then
			return -- Too soon
		end
	end

	-- Update heartbeat time
	last_heartbeat[filepath] = now

	-- Calculate lines changed (DELTA, not total)
	local lines_changed = 0
	if is_save then
		local current_diff = get_git_lines_changed(filepath)

		if current_diff ~= nil then
			-- File is git-tracked, use delta tracking
			local last_diff = last_git_diff[filepath] or 0
			local delta = current_diff - last_diff

			-- Only track positive deltas (new changes)
			if delta > 0 then
				lines_changed = delta
				last_git_diff[filepath] = current_diff
			elseif current_diff == 0 and last_diff > 0 then
				-- File was committed (git diff is now 0)
				-- Reset tracking but don't send a heartbeat
				last_git_diff[filepath] = 0
				return
			else
				-- No new changes since last save (delta <= 0)
				return
			end
		else
			-- File is NOT git-tracked (non-git file or new untracked file)
			-- For non-git files, we can't use git diff, so we track file modifications
			-- using Neovim's modified flag and a simple change detection

			-- Check if this is the first save or if file was modified
			local last_modified = last_git_diff[filepath]

			if not last_modified then
				-- First save of this session, count it as activity but don't track lines
				-- (we don't know what changed without git)
				lines_changed = 0
				last_git_diff[filepath] = now -- Use timestamp instead of line count
			elseif (now - last_modified) > 60 then
				-- More than 1 minute since last save, count as new activity
				lines_changed = 0
				last_git_diff[filepath] = now
			else
				-- Saved recently, skip to avoid spam
				return
			end
		end
	end

	local line_count = vim.api.nvim_buf_line_count(bufnr)
	local language = filetype ~= "" and filetype or "unknown"

	-- Send to backend
	local cmd = string.format(
		"%s track --file %s --lang %s --lines %d --total %d",
		opts.codeme_bin or "codeme",
		vim.fn.shellescape(filepath),
		language,
		lines_changed,
		line_count
	)

	vim.fn.jobstart(cmd, {
		detach = true,
		on_exit = function(_, code)
			if opts.verbose then
				if code == 0 then
					vim.notify(
						string.format("CodeMe: ✓ %s (%d lines)", vim.fn.fnamemodify(filepath, ":t"), lines_changed),
						vim.log.levels.INFO
					)
				else
					vim.notify(
						string.format("CodeMe: ✗ Failed to track %s", vim.fn.fnamemodify(filepath, ":t")),
						vim.log.levels.WARN
					)
				end
			end
		end,
	})
end

function M.clear_state()
	last_heartbeat = {}
	last_git_diff = {}
end

function M.get_state()
	return {
		heartbeats = vim.deepcopy(last_heartbeat),
		git_diffs = vim.deepcopy(last_git_diff),
	}
end

return M
