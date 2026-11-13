# Performance

## The numbers

Measured in a Windows 11 25H2 virtual machine (4 cores, Defender real-time protection on, offline), comparing this version with the previous one. Startup is measured from the moment the process is created until the prompt is drawn, driving PowerShell through the same console layer Windows Terminal uses.

### Shell

| | Previous version | Now | PowerShell with no profile |
|---|---|---|---|
| New terminal, median (p90) | 1,269 ms (1,287) | **602 ms** (680) | 385 ms |
| First terminal after a reboot | 6.4 – 7.8 s | **0.72 – 0.77 s** | |
| ...if the picker's prewarm is turned off | | 1.5 – 1.8 s | |
| First command after the prompt | 75 ms | 78 ms | 650 ms |
| A keystroke | 2 ms | 2 ms | 2 ms |

21 launches each for new terminals, interleaved, and 3 to 6 reboots for first starts. One new-terminal launch in 24, and one reboot in 6, were slow because the whole machine stalled at the time; the previous version showed the same kind of spike.

About 385 ms of every start is PowerShell itself. The profile adds about 200 ms on top.

### Project picker

| | Previous (Karchy) | Now |
|---|---|---|
| Shortcut → window visible and focused, idle | 516 – 707 ms | **52 ms** mean, focused in 28 of 30 |
| Keystroke → filtered list | | **5.2 ms** median, 8.2 ms p99 |

The shortcut goes through PowerToys Keyboard Manager (see [How the shortcut works](project-picker.md#how-the-shortcut-works)), measured in a VM without a GPU. An earlier version registered its own hotkey and opened in 3.3 ms, but endpoint protection flagged it as a keylogger.

The harness that produced these numbers is in [`bench/`](../bench/README.md).

## Why it's fast

**Nothing slow at startup.** On a Windows machine with real-time antivirus, three things make a PowerShell profile slow, and the profile avoids all of them while starting:

- *Starting programs.* Every program start is scanned. Generating `sqlgo`'s completions at startup alone cost about 100 ms warm and several seconds after a reboot. Completions now load the first time you press <kbd>Tab</kbd>.
- *Looking up commands that don't exist.* `Get-Command podman` on a machine without podman makes PowerShell search every installed module: about 470 ms, every time.
- *Loading modules.* The first use of everyday commands like `Set-Alias`, `Write-Host` or `Test-Path` loads a module, costing 35 – 90 ms. The profile uses lower-level calls instead, then loads those modules the moment you stop to read the prompt, so your first command doesn't pay for them either.

**A startup cache.** Everything slow to find out is worked out once and saved in `%LOCALAPPDATA%\pwsh-profile\cache.ps1`: where your tools are, theme colors, script commands, the full PATH. Each start only checks a handful of file dates to confirm nothing changed. A `git pull`, a theme change or a new tool updates it automatically; `profile-rebuild` forces it.

**Background updates.** The weekly update check runs in a separate low-priority process, and its message shows at a later prompt.

**A warm first start.** After you sign in, the project picker starts PowerShell once in the background, at idle priority. Windows then has the PowerShell runtime cached and already scanned, so your first terminal of the day opens like any other. Turn it off with `prewarm=0` in the [picker settings](project-picker.md#settings).

## Checking your own machine

```powershell
$env:PWSH_PROFILE_TIMING = 1; pwsh
```

prints a timing line per section of the profile, and the normal `Ready in … (profile …)` line shows the total.

```
[tm +   14.5 ms] start
[tm +   31.9 ms] environment
[tm +   46.4 ms] setup check
[tm +   68.2 ms] cache
[tm +   85.1 ms] aliases
[tm +   94.9 ms] prompt
[tm +  161.1 ms] psreadline
[tm +  168.6 ms] completions
[tm +  177.5 ms] updates
Ready in 676ms (profile 188ms)
```

A line saying `cache stale, rebuilding` means the cache was rebuilt on that start, which happens once after something changes.

### Things outside the profile that slow down PowerShell

- **A profile folder in OneDrive.** If Documents is synced with OneDrive and files are "online-only", PowerShell may wait for a download before it can read the profile. Right-click the PowerShell folder and choose *Always keep on this device*.
- **A huge history file.** PSReadLine reads its whole history file at startup. If `(Get-PSReadLineOption).HistorySavePath` is many megabytes, `clear-history` resets it.
- **Network folders on PATH.** Programs that search PATH stall on unreachable network folders. The profile itself never touches them at startup.
