local M = {}

-- Default config
local default_config = {
	auto_track = true,
	verbose = false,
	goals = {
		daily_hours = 4,
		daily_lines = 500,
	},
}

local config = vim.deepcopy(default_config)

---Setup plugin
---@param opts table? User configuration
function M.setup(opts)
	opts = opts or {}
	config = vim.tbl_deep_extend("force", config, opts)

	-- Setup highlights
	local highlights = require("codeme.ui.highlights")
	highlights.setup()
	highlights.setup_autocmd()

	-- Setup tracking if enabled
	if config.auto_track then
		M.setup_tracking()
	end
end

---Setup tracking autocommands
function M.setup_tracking()
	local tracking = require("codeme.tracking")
	local augroup = vim.api.nvim_create_augroup("CodeMeTrack", { clear = true })

	-- Track on save (main tracking event)
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = augroup,
		callback = function()
			tracking.send_heartbeat({ is_save = true })
		end,
	})

	-- Track on buffer enter (lightweight presence)
	vim.api.nvim_create_autocmd("BufEnter", {
		group = augroup,
		callback = function()
			tracking.send_heartbeat({})
		end,
	})
end

---Open dashboard
function M.open_dashboard()
	local dashboard = require("codeme.ui.dashboard")
	dashboard.open()
end

---Toggle dashboard
function M.toggle_dashboard()
	local dashboard = require("codeme.ui.dashboard")
	dashboard.toggle()
end

---Manual track
function M.manual_track()
	local tracking = require("codeme.tracking")
	tracking.send_heartbeat({ is_save = true })

	if config.verbose then
		vim.notify("CodeMe: Heartbeat sent", vim.log.levels.INFO)
	end
end

---Get config
---@return table
function M.get_config()
	return config
end

---Reset plugin state (for testing)
function M.reset()
	local stats = require("codeme.stats")
	local tracking = require("codeme.tracking")
	stats.reset()
	tracking.clear_state()
end

return M
