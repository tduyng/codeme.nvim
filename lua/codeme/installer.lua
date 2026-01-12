local M = {}

local REPO = "tduyng/codeme"
local INSTALL_DIR = vim.fn.stdpath("data") .. "/codeme"
local BIN_PATH = INSTALL_DIR .. "/codeme"

-- Detect current platform and architecture
local function get_platform()
	local os = vim.loop.os_uname().sysname:lower()
	local arch = vim.loop.os_uname().machine:lower()

	-- Normalize OS
	if os:find("darwin") then
		os = "darwin"
	else
		return nil, "Only macOS is supported"
	end

	-- Normalize architecture
	if arch == "x86_64" or arch == "amd64" then
		arch = "x86_64"
	elseif arch == "arm64" or arch == "aarch64" then
		arch = "arm64"
	else
		return nil, "Unsupported architecture: " .. arch
	end

	return os, arch
end

-- Get latest release version from GitHub
local function get_latest_version(callback)
	local url = string.format("https://api.github.com/repos/%s/releases/latest", REPO)
	local cmd = string.format("curl -s %s", vim.fn.shellescape(url))

	vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		on_stdout = function(_, data)
			if data and #data > 0 then
				local json_str = table.concat(data, "")
				local ok, release = pcall(vim.json.decode, json_str)
				if ok and release.tag_name then
					callback(release.tag_name)
				else
					callback(nil, "Failed to parse GitHub API response")
				end
			end
		end,
		on_exit = function(_, code)
			if code ~= 0 then
				callback(nil, "Failed to fetch latest release")
			end
		end,
	})
end

-- Download and install codeme binary
function M.install(version, callback)
	local os, arch = get_platform()
	if not os then
		callback(false, arch) -- arch contains error message
		return
	end

	-- Create install directory
	vim.fn.mkdir(INSTALL_DIR, "p")

	-- Build download URL
	local filename = string.format("codeme_%s_%s.tar.gz", os:gsub("^%l", string.upper), arch)
	local url = string.format("https://github.com/%s/releases/download/%s/%s", REPO, version, filename)

	local tmp_file = INSTALL_DIR .. "/" .. filename

	vim.notify(string.format("Downloading codeme %s...", version), vim.log.levels.INFO)

	-- Download the release
	local download_cmd = string.format("curl -L -o %s %s", vim.fn.shellescape(tmp_file), vim.fn.shellescape(url))

	vim.fn.jobstart(download_cmd, {
		on_exit = function(_, code)
			if code ~= 0 then
				callback(false, "Failed to download codeme")
				return
			end

			-- Extract the tarball
			local extract_cmd =
				string.format("tar -xzf %s -C %s", vim.fn.shellescape(tmp_file), vim.fn.shellescape(INSTALL_DIR))

			vim.fn.jobstart(extract_cmd, {
				on_exit = function(_, extract_code)
					-- Clean up tarball
					vim.fn.delete(tmp_file)

					if extract_code ~= 0 then
						callback(false, "Failed to extract codeme")
						return
					end

					-- Make binary executable
					vim.fn.system(string.format("chmod +x %s", vim.fn.shellescape(BIN_PATH)))

					vim.notify(string.format("✓ codeme %s installed to %s", version, BIN_PATH), vim.log.levels.INFO)
					callback(true)
				end,
			})
		end,
	})
end

-- Check if codeme binary exists
function M.is_installed()
	return vim.fn.filereadable(BIN_PATH) == 1 or vim.fn.executable("codeme") == 1
end

-- Get installed version
function M.get_version(callback)
	local binary = vim.fn.executable("codeme") == 1 and "codeme" or BIN_PATH

	if vim.fn.executable(binary) ~= 1 then
		callback(nil)
		return
	end

	vim.fn.jobstart(binary .. " version", {
		stdout_buffered = true,
		on_stdout = function(_, data)
			if data and #data > 0 then
				local version_line = data[1] or ""
				local version = version_line:match("codeme (%S+)")
				callback(version)
			end
		end,
	})
end

-- Install or update to latest version
function M.install_latest(callback)
	get_latest_version(function(version, err)
		if not version then
			callback(false, err or "Failed to get latest version")
			return
		end

		M.install(version, callback)
	end)
end

-- Check and prompt for installation if needed
function M.ensure_installed(callback)
	if M.is_installed() then
		callback(true)
		return
	end

	-- Prompt user to install
	vim.ui.select({ "Yes", "No" }, {
		prompt = "codeme binary not found. Install automatically?",
	}, function(choice)
		if choice == "Yes" then
			M.install_latest(function(success, err)
				if success then
					callback(true)
				else
					vim.notify("Failed to install codeme: " .. (err or "unknown error"), vim.log.levels.ERROR)
					callback(false)
				end
			end)
		else
			vim.notify("codeme binary required. Install manually or run :CodeMeInstall", vim.log.levels.WARN)
			callback(false)
		end
	end)
end

-- Get binary path (prefer system-wide, fallback to local)
function M.get_binary()
	if vim.fn.executable("codeme") == 1 then
		return "codeme"
	elseif vim.fn.filereadable(BIN_PATH) == 1 then
		return BIN_PATH
	end
	return nil
end

return M
