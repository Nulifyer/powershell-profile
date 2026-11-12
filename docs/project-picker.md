# Project picker

Press <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>P</kbd> in any app to open a list of every project on your machine. Type a few letters, press <kbd>Enter</kbd>, and the project opens in your editor.

![The project picker](images/project-picker.png)

The picker opens in about 3 ms. It also works while an administrator window has focus, and when the computer is busy.

## Opening projects

| Key | Opens |
|-----|-------|
| <kbd>Enter</kbd> or double-click | Your editor (`code` unless you set another, see [Settings](#settings)) |
| <kbd>Ctrl</kbd>+<kbd>E</kbd> | Windows Terminal in the project folder |
| <kbd>Ctrl</kbd>+<kbd>O</kbd> | The folder in your default file manager |
| <kbd>Ctrl</kbd>+<kbd>Y</kbd> | Nothing; copies the path instead |

Projects you open move to the top of the list next time. All keys are in [Keybindings](keybindings.md#project-picker).

## What counts as a project

- Every folder directly inside `~\Projects` (or `%Z_PROJECTS_ROOT%`). A folder that only *contains* projects, such as `~\Projects\work`, lists the projects inside it instead.
- Any folder under your home folder that contains one of: `.git`, `.hg`, `.svn`, `.jj`, `.vscode`, `.idea`, `.devcontainer`, `package.json`, `deno.json`, `go.mod`, `Cargo.toml`, `pyproject.toml`, `composer.json`, `Gemfile`, `mix.exs`, `pubspec.yaml`, `pom.xml`, `build.gradle`, `CMakeLists.txt`, `flake.nix`, `build.zig`, a `*.sln` file, or a Unity `ProjectSettings` folder.

The search skips dependency and build folders (`node_modules`, `bin`, `obj`, `target`, `dist`, `vendor`, …), dot-folders such as `.cache`, Windows library folders (Downloads, Pictures, Music, …), OneDrive, junctions and symbolic links. It never opens files, so it doesn't download OneDrive files on demand.

The list refreshes in the background when the picker starts and whenever you open it more than two minutes after the last refresh. Press <kbd>Ctrl</kbd>+<kbd>R</kbd> in the picker to refresh right away.

To search more places, add them to `roots=` in the settings file.

## From the shell

The `z` commands use the same list:

```powershell
z api          # jump to "api" (exact name, then prefix, then partial match)
z <Tab>        # complete project names
zi             # pick with fzf
zopen api      # open in your editor
```

When two projects share a name, <kbd>Tab</kbd> offers their full paths.

## Settings

Settings live in `%APPDATA%\projpick\config.ini`. The picker creates the file, with every option commented out, the first time it starts. After changing it, restart the picker:

```powershell
projpick --quit; projpick
```

(`projpick` is available as a command in the shell; the program itself is `bin\projpick.exe` in the profile folder. It starts automatically at sign-in.)

| Setting | Default | Meaning |
|---------|---------|---------|
| `hotkey` | `Ctrl+Alt+P` | Any of Ctrl, Alt, Shift, Win plus a letter, digit, F1–F24 or Space |
| `editor` | `%Z_PROJECT_EDITOR%`, else `code` | Command for <kbd>Enter</kbd>. `{path}` is replaced with the project folder; if it's missing, the folder is added at the end. Example: `editor=nvim-qt "{path}"` |
| `terminal` | `wt.exe -d "{path}"` | Command for <kbd>Ctrl</kbd>+<kbd>E</kbd> |
| `projects` | `%Z_PROJECTS_ROOT%`, else `~\Projects` | Folder whose subfolders are all projects |
| `roots` | | More folders to search, separated by `;`, e.g. `D:\src;E:\work` |
| `font` | `Segoe UI` | Font for the list |
| `font_size` | `15` | Font size in pixels at 100% scaling |
| `rows` | `10` | Visible rows |
| `monitor` | `cursor` | Where to open: `cursor`, `active` (the focused window's monitor) or `primary` |
| `prewarm` | `1` | After sign-in, start PowerShell once in the background so your first terminal opens fast. `0` turns it off |
| `priority` | `normal` | `high` runs the picker at high priority. Measurements showed no benefit, so it's off by default |

Colors follow your [theme](themes.md) automatically.

## Command line

| Command | Description |
|---------|-------------|
| `projpick` | Show the picker (starts it if it isn't running) |
| `projpick --quit` | Stop it until the next sign-in |
| `projpick --install` | Start it at sign-in and start it now (setup does this) |
| `projpick --uninstall` | Stop it and remove it from sign-in |
| `projpick --scan` | Search for projects now and print a summary |
| `projpick --list` | Print the project list (`name<TAB>path`) |
| `projpick --version` | Print the version |

To turn the picker off for good, untick **Project picker** in `profile-setup`.

## If the hotkey doesn't work

- **Another program already uses <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>P</kbd>.** The picker tells you once, with a message box, and keeps trying every 10 seconds in case the other program lets go. Pick another `hotkey=` in the settings file, then restart the picker.
- **The picker isn't running.** Run `projpick`. If it doesn't stay running, check `%LOCALAPPDATA%\projpick\projpick.log`.
- **It isn't installed.** Run `profile-setup` and tick **Project picker**.

Hotkeys never work on the sign-in screen, the lock screen, or a UAC prompt; Windows doesn't allow it.

## Why it's fast and reliable

- The hotkey is registered with Windows itself (`RegisterHotKey`), not watched by a keyboard hook. Windows can't silently disconnect it, and it works over administrator windows.
- The window is created once at sign-in and is only shown and hidden. Opening it doesn't start a program or a terminal, and the list is already in memory.
- The background search runs at low CPU and disk priority, so it never competes with you.
