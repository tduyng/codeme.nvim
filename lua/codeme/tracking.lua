local M = {}

local backend = require("codeme.backend")

-- Tracking state
local last_heartbeat = {}
local last_git_diff = {}
local COOLDOWN = 120 -- Only send heartbeat every 2 minutes per file

---Check if buffer should be tracked
---@param bufnr number
---@param filepath string
---@return boolean
local function should_track(bufnr, filepath)
	if filepath == "" or not vim.api.nvim_buf_is_valid(bufnr) then
		return false
	end

	if vim.bo[bufnr].buftype ~= "" then
		return false
	end

	local skip_fts = { "NvimTree", "neo-tree", "dashboard", "help", "qf", "TelescopePrompt", "oil", "noice", "notify" }
	if vim.tbl_contains(skip_fts, vim.bo[bufnr].filetype) then
		return false
	end

	return true
end

---Get git lines changed
---@param filepath string
---@return number|nil
local function get_git_lines_changed(filepath)
	local dir = vim.fn.fnamemodify(filepath, ":h")
	local filename = vim.fn.fnamemodify(filepath, ":t")

	local cmd = string.format(
		"cd %s && git diff --numstat HEAD -- %s 2>/dev/null",
		vim.fn.shellescape(dir),
		vim.fn.shellescape(filename)
	)

	local output = vim.fn.system(cmd)
	if vim.v.shell_error ~= 0 or output == "" then
		return nil
	end

	local added, deleted = output:match("^(%d+)%s+(%d+)")
	if added and deleted then
		return tonumber(added) + tonumber(deleted)
	end
	return nil
end

---Calculate lines changed since last save
---@param filepath string
---@param bufnr number
---@return number
local function calculate_lines_changed(filepath, bufnr)
	-- Try to get changedtick to detect if buffer was modified
	local ok, changedtick = pcall(vim.api.nvim_buf_get_changedtick, bufnr)
	if not ok then
		return 0
	end

	-- For git-tracked files, try to get line count from git diff
	local current_diff = get_git_lines_changed(filepath)

	if current_diff ~= nil then
		-- Git-tracked file with uncommitted changes
		local last_diff = last_git_diff[filepath] or 0

		if current_diff == 0 and last_diff > 0 then
			-- Changes were committed, return what we tracked before commit
			last_git_diff[filepath] = nil
			return last_diff
		end

		local delta = math.abs(current_diff - last_diff)
		last_git_diff[filepath] = current_diff

		-- If delta is 0 but buffer was modified, use estimate
		if delta == 0 and changedtick > 0 then
			return 1
		end

		return delta
	else
		-- No git diff available (file committed or non-git)
		-- Check if we had tracked changes before that are now gone
		local last_diff = last_git_diff[filepath]

		if last_diff and last_diff > 0 then
			-- Had uncommitted changes before, now they're gone (committed)
			last_git_diff[filepath] = nil
			return last_diff
		end

		-- File was saved but we can't detect changes via git
		-- Use conservative estimate: if buffer is modified, assume at least 1 line
		if changedtick > 0 then
			return 1
		end

		return 0
	end
end

---Send heartbeat
---@param opts table Options
function M.send_heartbeat(opts)
	opts = opts or {}
	local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
	local filepath = opts.filepath or vim.fn.expand("%:p")

	if not should_track(bufnr, filepath) then
		return
	end

	local now = os.time()
	local is_save = opts.is_save or false

	-- Only track on saves OR if cooldown has passed
	if not is_save then
		local last_time = last_heartbeat[filepath]
		if last_time and (now - last_time) < COOLDOWN then
			return
		end
	end

	local lines_changed = 0
	if is_save then
		lines_changed = calculate_lines_changed(filepath, bufnr)
	end

	-- Send to backend
	backend.send_heartbeat({
		filepath = filepath,
		language = vim.bo[bufnr].filetype,
		lines = lines_changed,
	}, function(success)
		if success then
			last_heartbeat[filepath] = now
		end
	end)
end

---Clear tracking state
function M.clear_state()
	last_heartbeat = {}
	last_git_diff = {}
end

return M
