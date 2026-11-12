# Working on the profile

## Layout

| Path | What it is |
|------|------------|
| `Microsoft.PowerShell_profile.ps1` | The profile. Kept cheap; see the rules below |
| `Scripts\*.ps1`, `Scripts\<folder>\*.ps1` | Commands (one per file; `#.ALIAS` lines rename them) |
| `Scripts\setup.ps1` | `profile-setup`: per-update setup, checklist, picker build, cleanups |
| `Scripts\_lib\ProfileCache.ps1` | Builds the startup cache (the slow path) |
| `Scripts\_lib\ToolCatalog.ps1` | Optional tools offered by setup and `tools` |
| `Scripts\_lib\WinGetPaths.ps1` | Finding winget tools when links are blocked; user PATH sync |
| `Scripts\_lib\Tui.ps1` | The checklist UI (plain PowerShell) |
| `Scripts\_lib\VSCodeKeys.ps1` | VS Code terminal key settings offered by setup |
| `Scripts\_lib\UpdateCheck.ps1` | Weekly background update check and `pu` |
| `Scripts\_lib\themes\colors.json` | All theme palettes |
| `native\projpick\` | The project picker (Zig) |
| `bench\` | Startup and hotkey benchmark harness (Go) |
| `bench\keys\` | Key handling test for Windows Terminal and VS Code ([how to run](../bench/README.md#key-handling)) |

## Keeping startup fast

The profile runs on every new terminal, so it follows a few rules (each measured on Windows 11 with Defender on):

- **No `Get-Command` for things that may not exist.** A miss searches every module (~470 ms). Look tools up in the cache (`$_ppTools`) instead.
- **No cmdlets from `Microsoft.PowerShell.Utility` or `.Management`** (`Set-Alias`, `Write-Host`, `Get-Date`, `Test-Path`, `Get-Content`, …). Only PSReadLine is loaded when the profile runs; the first call into those modules costs 35–90 ms. Use .NET (`[IO.File]::Exists`) and `$ExecutionContext` APIs. Functions that run later, when you call them, can use anything.
- **No programs started.** Every start is scanned by antivirus.
- **Slow discovery goes in the cache.** Add it to `Build-ProfileCache`, emit a variable into the cache file, and use that variable in the profile. If the result depends on a file or folder, add its path to the key list in the generator so changes invalidate the cache.

Check with `$env:PWSH_PROFILE_TIMING = 1; pwsh`, and measure before and after with the harness in [`bench/`](../bench/README.md). After changing key bindings, run the key handling test in both Windows Terminal and VS Code.

## Adding a tool to setup

Add an entry to `$ToolCatalog` in `Scripts\_lib\ToolCatalog.ps1`:

```powershell
@{ Name = 'lazygit'; Exe = 'lazygit.exe'; WinGet = 'JesseDuffield.lazygit'; Group = 'extra'; Desc = 'git TUI' }
```

`Recommended = $true` pre-ticks it on first setup. Users who already declined other tools are only asked about the new one.

## Cleaning up after a change

When a new version stops using something an older one created, add an entry to `$Cleanups` in `Scripts\setup.ps1` with an `Id`, an `Applies` test and a `Run` block. Set `Ask = $true` when the files could matter to the user; those show up in the checklist. Each cleanup runs once per machine.

## Building the project picker

Setup builds it automatically. While working on it:

```powershell
native\projpick\build.ps1     # tests + bin\projpick.exe (needs Zig 0.17)
projpick --quit; projpick     # restart with the new build
```

`./native/projpick/build.sh` cross-compiles the same exe from Linux or macOS. When moving to a new Zig version, update `$ZigVersion`, `$ZigUrl` and `$ZigSha256` at the top of `Scripts\setup.ps1`.
