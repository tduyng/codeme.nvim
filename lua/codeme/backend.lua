local M = {}

-- Cache backend binary path
local _binary_path = nil

---Find codeme binary
---@return string|nil
local function find_binary()
	if _binary_path then
		return _binary_path
	end

	-- Check environment variable
	local env_path = os.getenv("CODEME_BIN")
	if env_path and vim.fn.executable(env_path) == 1 then
		_binary_path = env_path
		return _binary_path
	end

	-- Check system PATH
	if vim.fn.executable("codeme") == 1 then
		_binary_path = "codeme"
		return _binary_path
	end

	-- Check local installation
	local local_path = vim.fn.stdpath("data") .. "/codeme/codeme"
	if vim.fn.executable(local_path) == 1 then
		_binary_path = local_path
		return _binary_path
	end

	return nil
end

---Execute codeme command asynchronously
---@param args string[] Command arguments
---@param callback fun(success: boolean, data: any, error: string?)
local function exec_async(args, callback)
	local binary = find_binary()
	if not binary then
		callback(false, nil, "codeme binary not found")
		return
	end

	vim.system({ binary, unpack(args) }, { text = true }, function(obj)
		vim.schedule(function()
			if obj.code ~= 0 then
				callback(false, nil, obj.stderr or "Command failed")
				return
			end

			-- Parse JSON output
			local stdout = obj.stdout or ""
			local json_str = stdout:match("({.*})")
			if not json_str then
				callback(false, nil, "No JSON in output")
				return
			end

			local ok, data = pcall(vim.json.decode, json_str)
			if not ok then
				callback(false, nil, "JSON parse error: " .. tostring(data))
				return
			end

			callback(true, data, nil)
		end)
	end)
end

---Get stats from backend
---@param today_only boolean? Only fetch today's stats
---@param callback fun(stats: table)
function M.get_stats(today_only, callback)
	local args = { "api", "--compact" }
	if today_only then
		table.insert(args, "--today")
	end

	exec_async(args, function(success, data, err)
		if not success then
			vim.notify("CodeMe: " .. (err or "Unknown error"), vim.log.levels.ERROR)
			callback({})
			return
		end
		callback(data or {})
	end)
end

---Send heartbeat to backend
---@param opts table Heartbeat options
---@param callback fun(success: boolean)?
function M.send_heartbeat(opts, callback)
	local binary = find_binary()
	if not binary then
		if callback then
			callback(false)
		end
		return
	end

	local args = {
		"track",
		"--file",
		opts.filepath,
		"--lang",
		opts.language or "",
		"--editor",
		"neovim",
		"--lines",
		tostring(opts.lines or 0),
	}

	vim.system({ binary, unpack(args) }, { detach = true }, function(obj)
		if callback then
			vim.schedule(function()
				callback(obj.code == 0)
			end)
		end
	end)
end

---Check if binary is installed
---@return boolean
function M.is_installed()
	return find_binary() ~= nil
end

return M
