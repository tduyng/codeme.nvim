if vim.g.loaded_codeme then
	return
end
vim.g.loaded_codeme = 1

-- Lazy command registration
vim.api.nvim_create_user_command("CodeMe", function()
	require("codeme").open_dashboard()
end, { desc = "Open CodeMe dashboard" })

vim.api.nvim_create_user_command("CodeMeToggle", function()
	require("codeme").toggle_dashboard()
end, { desc = "Toggle CodeMe dashboard" })

vim.api.nvim_create_user_command("CodeMeTrack", function()
	require("codeme").manual_track()
end, { desc = "Manually send heartbeat" })

-- Auto-setup on VimEnter (deferred)
vim.api.nvim_create_autocmd("VimEnter", {
	once = true,
	callback = function()
		vim.schedule(function()
			require("codeme").setup()
		end)
	end,
})
