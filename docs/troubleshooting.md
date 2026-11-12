# Troubleshooting

## Common problems

### Boxes instead of icons in the prompt

Your terminal font isn't a Nerd Font. Run `font --install`, then `font` to select it, and restart the terminal. See [Themes and fonts](themes.md#fonts).

### `Ctrl+Alt+P` does nothing

See [If the hotkey doesn't work](project-picker.md#if-the-hotkey-doesnt-work).

### A tool installed with winget isn't found

Open a new terminal: the profile picks up new winget tools automatically. If it's still missing, run `profile-rebuild` and open another terminal. For programs outside PowerShell, see [Tools on user PATH](setup.md#tools-on-user-path).

### Setup failed

Setup prints the reason next to `fail` and lets the shell start anyway. Run `profile-setup` to try again. If the Zig download is blocked, see [the mirror option](setup.md#the-project-picker-build).

### Setup runs every time I open a terminal

It only runs when the repo's version changes. If it really runs every time, it can't save its state: check that `%LOCALAPPDATA%\pwsh-profile` exists and is writable. `PWSH_PROFILE_NO_SETUP=1` turns the automatic run off.

### Startup got slow

Run `$env:PWSH_PROFILE_TIMING = 1; pwsh` to see which section takes the time, and see [Performance](performance.md#things-outside-the-profile-that-slow-down-powershell). One slow start after an update or a new tool is normal: the startup cache is being rebuilt.

### A command behaves differently than in plain PowerShell

The profile replaces a few built-in aliases with the Unix tools from Git for Windows (`sort`, `diff`, `curl` goes to the real `curl.exe`, `ls`/`cat` go to eza/bat when installed). Use the full cmdlet name (`Sort-Object`, `Get-ChildItem`, `Get-Content`) or `which <name>` to see what a name runs.

### Starting without the profile

```powershell
pwsh -NoProfile
```

## Settings

### Environment variables

| Variable | Effect |
|----------|--------|
| `PWSH_PROFILE_TIMING=1` | Print per-section startup timings |
| `PWSH_PROFILE_NO_SETUP=1` | Don't run setup automatically after updates |
| `PWSH_PROFILE_ZIG_URL` | Download Zig from this URL instead of ziglang.org |
| `Z_PROJECT_EDITOR` | Editor for `zopen` and the picker (default `code`) |
| `Z_PROJECTS_ROOT` | Projects folder (default `~\Projects`) |
| `PROJPICK_IME=1` | Let the picker use the input method editor (for typing CJK project names) |
| `PROJPICK_DEBUG=1` | Log per-use timings to the picker's log file |

### Files

| Location | What it is |
|----------|------------|
| profile folder (`Split-Path $PROFILE`) | This repo |
| `bin\projpick.exe` in the profile folder | The project picker, built by setup |
| `LastUpdateCheck.txt` in the profile folder | Date of the last successful update check |
| `%LOCALAPPDATA%\pwsh-profile\cache.ps1` | Startup cache; safe to delete |
| `%LOCALAPPDATA%\pwsh-profile\setup.json` | Your setup choices |
| `%LOCALAPPDATA%\pwsh-profile\setup-commit.txt` | The version setup last ran for; delete it to rerun setup |
| `%LOCALAPPDATA%\pwsh-profile\zig\` | Private copy of Zig, if setup downloaded one |
| `%APPDATA%\projpick\config.ini` | Picker settings |
| `%LOCALAPPDATA%\projpick\` | Picker project list, recent projects, colors and log |
| `~\.config\scriptutils\config.json` | Active theme and other script settings |

Deleting `%LOCALAPPDATA%\pwsh-profile` is safe: the next terminal rebuilds the cache and runs setup again, asking your choices from scratch. If **Tools on user PATH** is on, untick it in `profile-setup` first, so setup can still tell which PATH entries it added.
