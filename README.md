# codeme.nvim

> 🎨 **Beautiful coding activity dashboard** for Neovim - Track your coding journey with style.

## ✨ Features

- Beautiful Tab-based Dashboard with 3 interactive views
- GitHub-style Activity Calendar showing 7 months of coding history
- Language Breakdown with visual bar graphs and smart summaries
- Streak Tracking to maintain coding momentum
- Auto-tracking on file save
- Zero Config - works out of the box
- Theme-aware - adapts to your colorscheme

## 📸 Preview

```
┌─────────────────────────────────────────────────────┐
│  1 󰃰 Overview  |  2 💻 Languages  |  3 📅 Activity  │
├─────────────────────────────────────────────────────┤
│                                                      │
│  🔥 Streak: 7 days | 📊 Total: 24h 30m | 📝 12,543 lines │
│                                                      │
│   󱑈  Coding Time ~ 24h / 50h                        │
│   ████████████████████░░░░░░░░░░ 48%                │
│                                                      │
│  <Tab>: Next Tab | <S-Tab>: Prev Tab | q: Close    │
└─────────────────────────────────────────────────────┘
```

## 📦 Installation

### Prerequisites

1. **Neovim >= 0.11+**
2. **[volt.nvim](https://github.com/nvzone/volt)** - UI framework dependency
3. **CodeMe server binary** - automatically installed on first use

### Using lazy.nvim

```lua
{
  "tduyng/codeme.nvim",
  dependencies = { "nvzone/volt" },
  config = function()
    require("codeme").setup({
      -- Optional configuration
      auto_install = true,  -- Auto-install binary if not found (default: true)
      auto_track = true,    -- Auto track on save (default: true)
    })
  end,
  cmd = { "CodeMe", "CodeMeToggle", "CodeMeInstall" },
}
```

### Using vim.pack

```lua
vim.pack.add({
  "https://github.com/tduyng/codeme.nvim",
  "https://github.com/nvzone/volt",
})

require("codeme").setup()
```

### Binary Installation

The codeme binary will be **automatically installed** on first use. If you prefer manual installation:

```bash
# Download from GitHub releases
# Go to https://github.com/tduyng/codeme/releases
# Download for your platform (macOS arm64 or x86_64)

# Or use the Neovim command
:CodeMeInstall
```

## 🚀 Usage

### Commands

| Command            | Description                              |
| ------------------ | ---------------------------------------- |
| `:CodeMe`          | Open the beautiful dashboard             |
| `:CodeMeToggle`    | Toggle dashboard visibility              |
| `:CodeMeToday`     | Show today's stats notification          |
| `:CodeMeProjects`  | Show project breakdown                   |
| `:CodeMeInstall`   | Install/update codeme binary from GitHub |
| `:CodeMeVersion`   | Show installed codeme version            |

### Dashboard Navigation

**Tab System:**

- `<Tab>` or `L` - Next tab
- `<S-Tab>` or `H` - Previous tab
- `1`, `2`, `3` - Jump to specific tab
- `q` or `<Esc>` - Close dashboard

**Three Tabs:**

#### 1. 󰃰 Overview

- Coding streak and total stats
- Progress bars for time, lines, and projects
- Quick stats table

#### 2. 💻 Languages

- Visual bar graphs showing language distribution
- Summary text: "You code primarily in TypeScript, with Go and Lua close behind"
- Top 5 languages with percentages

#### 3. 📅 Activity

- GitHub-style heatmap calendar
- 7 months of coding activity
- Color-coded activity levels (more active = darker green)

### Auto-tracking

The plugin automatically tracks your files when you save them (`BufWritePost`). Files are tracked with:

- File path
- Language/filetype
- Line count

## ⚙️ Configuration

```lua
require("codeme").setup({
  -- Binary settings
  codeme_bin = "codeme",      -- Binary name (auto-detected if installed)
  auto_install = true,        -- Auto-install binary if not found

  -- Tracking settings
  auto_track = true,          -- Track files on save
  track_on_idle = false,      -- Track on cursor idle (not implemented)
  
  -- UI settings
  verbose = false,            -- Show tracking notifications
})
```

### Custom Keybinding

```lua
vim.keymap.set("n", "<leader>cm", "<cmd>CodeMe<cr>", { desc = "Open CodeMe Dashboard" })
vim.keymap.set("n", "<leader>ct", "<cmd>CodeMeToggle<cr>", { desc = "Toggle CodeMe" })
```

## 🎨 How It Works

1. **Tracking:** When you save a file, the plugin calls `codeme track --file <path> --lang <ft> --lines <count>`
2. **Storage:** The Go server stores activity data in SQLite
3. **Visualization:** When you run `:CodeMe`, it fetches stats with `codeme stats --json` and renders the beautiful dashboard using volt.nvim

## 🏗️ Architecture

```
codeme.nvim/
├── lua/
│   └── codeme/
│       ├── init.lua        # Main setup and auto-tracking
│       ├── dashboard.lua   # Entry point wrapper
│       ├── profile.lua     # Tab-based UI system (3 tabs)
│       ├── highlights.lua  # Theme-aware color system
│       ├── util.lua        # Date/time/number formatting helpers
│       └── stats.lua       # Stats notifications
└── plugin/
    └── codeme.lua          # Plugin commands
```

## 🌟 Inspiration

This plugin is inspired by and uses design patterns from:

- **[typr](https://github.com/nvzone/typr)** - Beautiful typing practice with gorgeous UI
- **[triforce.nvim](https://github.com/gisketch/triforce.nvim)** - RPG-style coding gamification
- **[volt.nvim](https://github.com/nvzone/volt)** - The UI framework that makes it all possible

## 🤝 Contributing

Contributions are welcome! This is a minimal, focused plugin. When adding features:

1. Keep it simple and beautiful
2. Don't add gamification (use triforce.nvim for that)
3. Focus on coding insights and visualizations
4. Maintain the clean UI aesthetic

## 📄 License

MIT

---

Made with ❤️ for the Neovim community

⭐ Star this repo if you find it useful!
