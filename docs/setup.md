# Setup and tools

## How setup works

The profile keeps track of which version you last set up. When that changes (a fresh clone, a `git pull`, `pu`), the next terminal you open runs `profile-setup` once, before the first prompt. Every other terminal skips it, at a cost of about 10 ms.

Setup does three things:

1. **Cleans up** files that older versions of the profile left behind. Files the profile generated itself are removed silently. Anything that might be yours, such as an old Start menu folder, is listed in the checklist instead.
2. **Asks** about anything new, in a checklist. It only asks once: your answers are remembered, so a normal update asks nothing.
3. **Builds and installs** what you chose: the project picker, tools, PATH entries.

Setup needs nothing but PowerShell 7. It never blocks your shell: if a step fails (no network, blocked download), it prints why, and the prompt appears as usual. Run `profile-setup` to retry.

If you open several terminals at once after an update, only one runs setup; the others start normally.

### Running it yourself

```powershell
profile-setup            # show every choice again, including tools you declined
profile-setup --rebuild  # rebuild the project picker
```

### Skipping it

Set `PWSH_PROFILE_NO_SETUP=1` (for example in your user environment variables) to stop the automatic run. `profile-setup` still works.

## The project picker build

The picker ([Project picker](project-picker.md)) is built from source on your machine; no prebuilt program is downloaded or stored in the repo. Setup:

- uses `zig` from your PATH if it's version 0.17.x;
- otherwise downloads Zig 0.17.1 once (about 100 MB) into `%LOCALAPPDATA%\pwsh-profile\zig`, checks it against its published checksum, and uses it from there. It doesn't add Zig to your PATH;
- builds `bin\projpick.exe` in the profile folder (git ignores that folder), registers it to start at sign-in, and starts it.

The first build takes about a minute. After that, setup only rebuilds when the picker's source changes, in about 10 seconds.

If your network blocks ziglang.org, point setup at a mirror of the same file. The checksum is still checked:

```powershell
$env:PWSH_PROFILE_ZIG_URL = 'https://mirror.example.com/zig-x86_64-windows-0.17.1.zip'
profile-setup --rebuild
```

## Optional tools

The checklist offers command-line tools you don't have yet. Most install with [winget](https://learn.microsoft.com/windows/package-manager/winget/), which comes with Windows 11 (as "App Installer").

| Tool | Used for |
|------|----------|
| git | Version control; also provides `grep`, `sed`, `awk`, `less`, `ssh` |
| fzf | <kbd>Ctrl</kbd>+<kbd>R</kbd>, <kbd>Ctrl</kbd>+<kbd>T</kbd>, `zi`, `theme` and `font` pickers |
| fd | Fast file search for <kbd>Ctrl</kbd>+<kbd>T</kbd> |
| ripgrep | Fast text search (`rg`) |
| eza | `ls`, `ll`, `la`, `tree` with icons |
| bat | `cat` with syntax highlighting |
| gh | GitHub CLI |
| neovim | Editor |
| podman | Containers for `wtc` |
| btop | Resource monitor |
| delta, procs, jq, yq, sqlite, glow, hyperfine, tokei | Workflow extras |
| sqlgo | SQL client (upstream install script) |
| guget | NuGet package manager TUI; needs the .NET SDK (upstream install script) |
| chafa | Image previews in `wallpaper browse` |
| lutgen | Listed for reference; install manually |

The first time, the tools the profile uses directly (git, fzf, fd, ripgrep, eza, bat) are pre-ticked. Anything you untick is remembered as declined and not offered again by automatic runs.

`tools` shows what's installed; `tools --install` installs from the same list at any time.

## winget on locked-down machines

winget installs most command-line tools as "portable" packages. It unpacks them under `%LOCALAPPDATA%\Microsoft\WinGet\Packages` and then creates a link for each command in `WinGet\Links`, which is on your PATH. On many company machines, policy blocks those links. winget says the install worked, but the command isn't found.

The profile doesn't rely on the links. It finds the real program folders inside every winget package and adds them to PATH in each PowerShell session, just ahead of `WinGet\Links`, so a missing or broken link can't get in the way. This works for every portable package, not a fixed list, and catches up automatically after `winget install` and `winget upgrade`.

### Tools on user PATH

Inside PowerShell that's all you need. Other programs, such as cmd, VS Code, git hooks, or `delta` as git's pager when git starts outside PowerShell, read your user PATH instead. Tick **Tools on user PATH** in setup and the same folders are kept in your user PATH as well. It's pre-ticked when setup sees that winget isn't creating links.

What it changes:

- Adds the winget tool folders to your user PATH, just before `WinGet\Links`, and keeps them current as you install, upgrade or remove tools.
- Records exactly which entries it added. Unticking it removes those and nothing else.
- Leaves your other entries as they were, including unexpanded ones like `%USERPROFILE%\bin`.

Programs that are already open don't see the change; new ones do.

## VS Code terminal keys

VS Code keeps a few keys for itself even when its terminal has focus, so the same key does different things in VS Code and in Windows Terminal. When VS Code (or VS Code Insiders, or VSCodium) is installed, setup offers **VS Code terminal keys**, which sends these keys to the shell while the terminal has focus:

| Key | VS Code's default in the terminal | With this setting |
|-----|-----------------------------------|-------------------|
| <kbd>Ctrl</kbd>+<kbd>E</kbd> | Opens Quick Open | End of line |
| <kbd>Ctrl</kbd>+<kbd>K</kbd> | Waits for the second key of a shortcut | Deletes to the end of the line |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>C</kbd>, <kbd>Ctrl</kbd>+<kbd>Insert</kbd> | Copies mouse selections only | Also copies text selected with the keyboard |

In the editor, these keys work as before, and <kbd>Ctrl</kbd>+<kbd>P</kbd> still opens Quick Open everywhere. The two copy keys change only in PowerShell tabs, only when nothing is selected with the mouse, and not while a full-screen program such as fzf or vim is running.

What it changes:

- Adds three entries to your `keybindings.json` and sets `"terminal.integrated.allowChords": false` in `settings.json`, which is what lets <kbd>Ctrl</kbd>+<kbd>K</kbd> through.
- Unticking it in `profile-setup` removes exactly those again.
- Rewriting these files drops any comments in them.
