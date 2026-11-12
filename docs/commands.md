# Commands

Commands marked *(tool)* need the tool installed; `profile-setup` or `tools --install` offers it.

## Projects

| Command | Description |
|---------|-------------|
| `z <name>` | Jump to a project. Matches the exact name, then a prefix, then any part of the name or path. <kbd>Tab</kbd> completes names. If several projects match, you pick one with fzf |
| `z` | Jump to your projects folder (`~\Projects`, or `%Z_PROJECTS_ROOT%`) |
| `zi` | Pick any project with fzf and jump to it *(fzf)* |
| `zopen [name]` | Open a project, or the current folder, in your editor (`%Z_PROJECT_EDITOR%`, default `code`) |

The same list powers the <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>P</kbd> picker. See [Project picker](project-picker.md).

## Profile

| Command | Description |
|---------|-------------|
| `profile-setup` | Review setup choices: project picker, optional tools, PATH, cleanups. See [Setup and tools](setup.md) |
| `profile-setup --rebuild` | Rebuild the project picker |
| `profile-update`, `pu` | Update PowerShell (winget) and pull the latest profile |
| `profile-rebuild` | Rebuild the startup cache now (normally automatic) |
| `tools` | Show which optional tools are installed |
| `tools --install [--core\|--extra]` | Install missing tools from a checklist |
| `clear-history` | Clear this session's history and PSReadLine's saved history file |
| `h` | Show the last 50 commands |

## Look and feel

| Command | Description |
|---------|-------------|
| `theme` | Pick a color theme with a live preview *(fzf)* |
| `theme <name>` | Apply a theme everywhere: terminals, VS Code, File Pilot, browsers, Windows accent, prompt, project picker |
| `theme --list` / `--current` | List themes / show the active one |
| `font` | Pick the terminal font from installed Nerd Fonts *(fzf)* |
| `font <name>` / `--list` / `--current` | Set, list, or show the font |
| `font --install` | Install Nerd Fonts from a checklist |
| `wallpaper` | Pick a wallpaper, recolored to match the theme *(fzf, lutgen)* |
| `wallpaper browse [query]` | Search Wallhaven with image previews *(chafa)* |
| `wallpaper --clear` / `--current` | Stop managing the wallpaper / show it |
| `theme-audit [name]` | Check that every themed app actually uses the theme's colors |
| `theme-contrast [name\|--all]` | Check theme colors for WCAG contrast |

More in [Themes and fonts](themes.md).

## Files and folders

| Command | Description |
|---------|-------------|
| `ls`, `ll`, `la`, `tree` | Listings with icons and folders first *(eza; otherwise `Get-ChildItem`)* |
| `cat <file>` | Syntax-highlighted output *(bat)* |
| `touch <path>` | Create a file, or update its timestamp |
| `mkdirp <path>` | Create a folder, including parents |
| `mkcd <path>` | Create a folder and change into it |
| `rmrf <path>` | Delete recursively, without prompts |
| `ff [path] [-name pattern]` | Find files by name under a folder |
| `open <path>` | Open with the default app |
| `..`, `...`, `....` | Go up one, two, three folders |
| `pwd` | Print the current folder as plain text |
| `finv <path> [filter]` | Count files and total size under a folder (`file-inventory`) |

## System

| Command | Description |
|---------|-------------|
| `df` | Disk usage per drive |
| `du` | Folder sizes *(Git for Windows)* |
| `psl` | Processes sorted by memory |
| `pkill <name>` | Kill processes by name |
| `btop` | Resource monitor *(btop)* |
| `sudo [command]` | Run a command (or open a shell) as administrator in a new window |
| `which <command>` | Show where a command comes from |
| `export NAME=value` | Set an environment variable for this session |
| `watch [-n secs] <command>` | Re-run a command every few seconds |
| `time <command>` | Run a command and print how long it took |

## Unix tools from Git for Windows

When Git for Windows is installed, these run the real GNU tools: `grep`, `sed`, `awk`, `sort`, `diff`, `tr`, `head`, `tail`, `wc`, `cut`, `uniq`, `xargs`, `less`, `vim`, `nano`, `file`, `ssh`, `ssh-keygen`.

## Containers and work tools

| Command | Description |
|---------|-------------|
| `wtc`, `wsl-tempcli` | Throwaway Linux container (Alpine, Debian or Kali) with the current folder mounted *(podman or docker)* |
| `docker` | Runs `podman` when Docker isn't installed |
| `adtools-user-info <user>` | All Active Directory properties of a user |
| `adtools-user-groups <user>` | A user's AD groups |
| `adtools-group-users <group>` | Members of an AD group |
| `sqlgo` | SQL client; its <kbd>Tab</kbd> completion loads on first use *(sqlgo)* |

Every script also prints its own help with `-h` or `--help`.

## Adding your own commands

Drop a `.ps1` file in `Scripts\` (or a subfolder of it) and open a new terminal: it becomes a command named after the file. To pick a different name, or several, put `#.ALIAS name` lines near the top of the script.
