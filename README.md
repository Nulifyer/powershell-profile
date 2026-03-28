# PowerShell Profile

A custom PowerShell 7 profile with a fast startup, Unix-style keybindings, and a collection of useful scripts.

## Features

- **Fast prompt** — pure PowerShell prompt with git branch detection (reads `.git/HEAD` directly, no process spawn), fish-style path shortening, and transient prompt on Enter
- **Theme & font management** — switch terminal color schemes and Nerd Fonts across Windows Terminal, Alacritty, Kitty, Ghostty, and WezTerm with a single fzf picker
- **Unix feel on Windows** — emacs keybindings, aliases for common Unix tools (`grep`, `sed`, `awk`, etc. via Git), and functions like `touch`, `mkcd`, `watch`, `sudo`
- **FZF integration** — `Ctrl+R` for fuzzy history search, `Ctrl+T` for file picker
- **Predictive IntelliSense** — history-based suggestions with ListView

## Scripts

| Command | Description |
|---------|-------------|
| `theme` | Switch terminal color palette (Catppuccin, Gruvbox, Nord, Dracula, etc.) |
| `font` | Change terminal Nerd Font across all configured terminals |
| `tools` | Check/install CLI tools via WinGet |
| `sqltools` | Interactive SQL TUI — SQL Server, SQLite, ODBC with query history and CSV export |
| `wsl-tempcli` | Spin up temporary Linux containers with current directory mounted |
| `file-inventory` | Recursively scan directories for file count and size |

Scripts are auto-loaded as aliases from the `Scripts/` folder using `#.ALIAS` declarations.

## Dependencies

- [PowerShell 7+](https://github.com/PowerShell/PowerShell)
- [Git for Windows](https://git-scm.com/) (provides Unix utilities)
- [fzf](https://github.com/junegunn/fzf) — fuzzy finder (optional but recommended)
- [eza](https://github.com/eza-community/eza) — modern `ls` replacement (optional)
- [bat](https://github.com/sharkdp/bat) — syntax-highlighted `cat` (optional)

Run `tools` to see what's installed and install anything missing.

## Install

Clone into your PowerShell config directory:

```powershell
git clone https://github.com/Nulifyer/powershell-profile.git "$HOME\Documents\PowerShell"
```
