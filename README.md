# codeme.nvim

> Beautiful coding activity dashboard for Neovim

## Features

- 100% private and local - all data stored in SQLite on your machine
- Tab-based dashboard with 6 interactive views
- GitHub-style contribution heatmap (12 weeks)
- Language and project breakdowns with visual bar graphs
- Daily goals with progress tracking
- Streak tracking with flame visualization
- Achievements and gamification
- Session tracking for focused coding periods
- Trend comparisons (today vs yesterday, this week vs last)
- Peak productivity insights
- Auto-tracking on file save
- Zero config - works out of the box
- Theme-aware - adapts to your colorscheme

## Privacy

Your coding data never leaves your machine:

- SQLite database stored locally at `~/.local/share/codeme/`
- No accounts, no cloud sync, no telemetry
- You own your data

## Installation

### Prerequisites

- Neovim >= 0.11
- [Codeme binary](https://github.com/tduyng/codeme) - auto-installed on first use

### Using lazy.nvim

```lua
{
  "tduyng/codeme.nvim",
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

### Using native vim.pack (Neovim 0.12+)

```lua
vim.pack.add({
  "https://github.com/tduyng/codeme.nvim",
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

## Usage

### Commands

| Command           | Description                              |
| ----------------- | ---------------------------------------- |
| `:CodeMe`         | Open the beautiful dashboard             |
| `:CodeMeToggle`   | Toggle dashboard visibility              |
| `:CodeMeToday`    | Show today's stats notification          |
| `:CodeMeProjects` | Show project breakdown                   |
| `:CodeMeInstall`  | Install/update codeme binary from GitHub |
| `:CodeMeVersion`  | Show installed codeme version            |

### Dashboard

**Navigation**

- `<Tab>` or `L` - Next tab
- `<S-Tab>` or `H` - Previous tab
- `1-6` - Jump to specific tab
- `q` or `<Esc>` - Close dashboard

**Tabs**

1. **☀️ Today** - Today's coding session with time, lines, files, languages, top files, sessions, hourly activity, and daily goal progress
2. **📅 Weekly** - Week summary with comparison to last week and GitHub-style contribution heatmap
3. **📊 Overview** - Overall stats with streak flames, coding trends, and totals
4. **💡 Insights** - Peak productivity times, comparisons, and achievements
5. **💻 Languages** - Top languages breakdown with time and lines
6. **🔥 Projects** - Active projects breakdown

#### Today

![today](./docs/img/today.png)

#### Overview

![overview](./docs/img/overview.png)

#### Languages

![languages](./docs/img/languages.png)

#### Projects

![projects](./docs/img/projects.png)

## Configuration

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

  -- Daily goals (set to 0 to disable)
  goals = {
    daily_hours = 4,          -- Daily goal in hours
    daily_lines = 500,        -- Daily goal in lines
  },
})
```

### Custom Keybinding

```lua
vim.keymap.set("n", "<leader>cm", "<cmd>CodeMe<cr>", { desc = "Open CodeMe Dashboard" })
vim.keymap.set("n", "<leader>ct", "<cmd>CodeMeToggle<cr>", { desc = "Toggle CodeMe" })
```

## Achievements

Unlock achievements as you code:

| Achievement            | Description                      |
| ---------------------- | -------------------------------- |
| 🎯 First Steps         | Track your first coding activity |
| 🔥 Getting Started     | Maintain a 3-day coding streak   |
| ⚡ Weekly Warrior      | Maintain a 7-day coding streak   |
| 👑 Monthly Master      | Maintain a 30-day coding streak  |
| 💻 Code Machine        | Write 1,000 lines of code        |
| 🚀 Prolific Programmer | Write 10,000 lines of code       |
| ⏰ Dedicated Developer | Code for 10 hours total          |
| 🏆 Century Coder       | Code for 100 hours total         |
| 🌍 Polyglot            | Code in 5 different languages    |
| 🌅 Early Bird          | Code before 7 AM                 |
| 🦉 Night Owl           | Code after midnight              |

## License

MIT

---

Made with ❤️ for the Neovim community
