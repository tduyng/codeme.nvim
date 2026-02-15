# codeme.nvim

> Beautiful coding dashboard for Neovim

Zero config. 100% private. Auto-adapts to your colorscheme.

![Overview](./docs/img/overview.png)

## Features

- Local-only, privacy-first SQLite storage
- Heatmaps, streaks, achievements, and daily goals
- Automatic session tracking with idle detection and theme support

## Prerequisites

codeme.nvim requires the [codeme binary](https://github.com/tduyng/codeme) (the backend) to be installed on your system.
The plugin does not install it automatically — you need to set it up once before first use.

### Option 1: Homebrew (macOS / Linux)

```bash
brew install tduyng/tap/codeme
```

Verify:

```bash
codeme stats
```

### Option 2: Go install

Requires [Go 1.25+](https://go.dev/dl/):

```bash
go install github.com/tduyng/codeme@latest
```

Verify:

```bash
codeme stats
```

### Option 3: Download prebuilt binary

No Go or compiler needed.

1. Download the latest release for your platform:

→ [GitHub Releases](https://github.com/tduyng/codeme/releases/latest)

| Your OS        | Download this file                     |
| -------------- | -------------------------------------- |
| macOS (Apple)  | `codeme_<version>_darwin_arm64.tar.gz` |
| macOS (Intel)  | `codeme_<version>_darwin_amd64.tar.gz` |
| Linux (x86_64) | `codeme_<version>_linux_amd64.tar.gz`  |
| Linux (ARM64)  | `codeme_<version>_linux_arm64.tar.gz`  |

2. Extract the archive:

```bash
tar -xzf codeme_<version>_<platform>.tar.gz
```

3. Move the binary to your PATH:

```bash
# User local bin (recommended)
mv codeme ~/.local/bin/codeme

# Or system-wide (requires sudo)
sudo mv codeme /usr/local/bin/codeme
```

4. Verify:

```bash
codeme stats
```

## Install

### lazy.nvim

```lua
{
  "tduyng/codeme.nvim",
  cmd = { "CodeMe", "CodeMeToggle" },
  config = function()
    require("codeme").setup()
  end,
}
```

### vim.pack (Neovim 0.12+)

```lua
vim.pack.add("https://github.com/tduyng/codeme.nvim")
require("codeme").setup()
```

## Usage

```vim
:CodeMe         " Open dashboard
:CodeMeToggle   " Toggle visibility
:CodeMeToday    " Today's stats notification
```

**Keybinding example:**

```lua
vim.keymap.set("n", "<leader>cm", "<cmd>CodeMe<cr>")
```

## Dashboard

**Navigate:**

- `Tab` / `L` → Next tab
- `Shift-Tab` / `H` → Previous tab
- `1-5` → Jump to tab
- `q` / `Esc` → Close

**Tabs:**

| Tab              | Content                                  |
| ---------------- | ---------------------------------------- |
| 📊 **Dashboard** | Goals, streaks, performance overview     |
| ⏰ **Activity**  | Today's sessions, languages, files       |
| 📅 **Weekly**    | Daily breakdown, weekly trends           |
| 📁 **Work**      | Projects and languages breakdown         |
| 🏆 **Records**   | Personal bests, achievements, milestones |

![Today](./docs/img/today.png)

![Languages](./docs/img/languages.png)

![Projects](./docs/img/projects.png)

## Achievements

Unlock achievements as you code:

| Icon | Name              | Unlock              |
| ---- | ----------------- | ------------------- |
| 🔥   | 5-Day Fire        | 5-day streak        |
| 🧨   | 30-Day Streak     | 30-day streak       |
| 💥   | 90-Day Inferno    | 90-day streak       |
| 🌋   | 180-Day Blaze     | 180-day streak      |
| 🌞   | Eternal Flame     | 365-day streak      |
| 🌧️   | 1K Line Wave      | 1,000 lines         |
| ⚡   | 10K Line Surge    | 10,000 lines        |
| ⛈️   | 50K Line Flood    | 50,000 lines        |
| 🌊   | 100K Line Ocean   | 100,000 lines       |
| ⚡   | 50h Spark         | 50 hours total      |
| 🌩️   | 1K h Lightning    | 1,000 hours         |
| ⛈️   | 5K h Thunder      | 5,000 hours         |
| 🌀   | 10K h Mastery     | 10,000 hours        |
| 💡   | 20K h Grandmaster | 20,000 hours        |
| 🚀   | Bilingual         | 2 languages         |
| 🌍   | Polyglot          | 5 languages         |
| 🧠   | Polyglot Master   | 10 languages        |
| 🎓   | Code Polymath     | 15 languages        |
| 🌅   | Dawn Coder        | Code before 6 AM    |
| 🌌   | Night Coder       | Code after midnight |
| ☕   | 2h Warm Up        | 2+ hour session     |
| 🎯   | 4h Focus          | 4+ hour session     |
| 🌊   | 6h Flow State     | 6+ hour session     |
| 🧠   | 8h Deep Work      | 8+ hour session     |
| 🧘‍♂️   | 10h Monk Mode     | 10+ hour session    |
| 👑   | 12h Legendary     | 12+ hour session    |

## Configuration

Here are the default configs:

```lua
require("codeme").setup({
  -- Binary
  codeme_bin = "codeme",     -- Auto-detected

  -- Tracking
  auto_track = true,         -- Track on save
  verbose = false,           -- Show notifications

  -- Goals (0 to disable)
  goals = {
    daily_hours = 4,         -- Hours per day
    daily_lines = 500,       -- Lines per day
  },
})
```

### Binary lookup order

The plugin searches for the `codeme` binary in this order:

1. `CODEME_BIN` environment variable
2. System `PATH` (i.e. the default `codeme` command)
3. `~/.local/share/nvim/codeme/codeme` (local data directory)

If none is found, the plugin will show an error when you open the dashboard. Install the backend using the instructions in [Prerequisites](#prerequisites).

## License

MIT

---

Made with ❤️ for Neovim
