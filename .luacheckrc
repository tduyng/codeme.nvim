-- Neovim globals
globals = {
	"vim",
}

-- Standard globals
std = "lua51"

-- Don't report unused self arguments of methods
self = false

-- Max line length
max_line_length = 150

-- Ignore certain warnings
ignore = {
	"212", -- Unused argument (common in callbacks)
	"631", -- Line is too long (handled by max_line_length)
}

-- Files/directories to exclude
exclude_files = {
	".luarocks",
	".rocks",
}
