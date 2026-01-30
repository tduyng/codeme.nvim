local M = {}

-- State storage
local _state = {
	stats = nil,
	last_fetch = 0,
	active_tab = 1,
	win = nil,
	buf = nil,
}

-- Cache TTL (5 minutes)
local CACHE_TTL = 300

---Get cached stats or nil if expired
---@return table|nil
function M.get_stats()
	if not _state.stats then
		return nil
	end

	local elapsed = os.time() - _state.last_fetch
	if elapsed > CACHE_TTL then
		return nil
	end

	return _state.stats
end

---Set stats cache
---@param stats table
function M.set_stats(stats)
	_state.stats = stats
	_state.last_fetch = os.time()
end

---Invalidate stats cache
function M.invalidate_stats()
	_state.stats = nil
	_state.last_fetch = 0
end

---Get active tab index
---@return number
function M.get_active_tab()
	return _state.active_tab
end

---Set active tab index
---@param tab number
function M.set_active_tab(tab)
	_state.active_tab = tab
end

---Get window handle
---@return number|nil
function M.get_win()
	if _state.win and vim.api.nvim_win_is_valid(_state.win) then
		return _state.win
	end
	return nil
end

---Set window handle
---@param win number
function M.set_win(win)
	_state.win = win
end

---Get buffer handle
---@return number|nil
function M.get_buf()
	if _state.buf and vim.api.nvim_buf_is_valid(_state.buf) then
		return _state.buf
	end
	return nil
end

---Set buffer handle
---@param buf number
function M.set_buf(buf)
	_state.buf = buf
end

---Reset all state
function M.reset()
	_state = {
		stats = nil,
		last_fetch = 0,
		active_tab = 1,
		win = nil,
		buf = nil,
	}
end

return M
