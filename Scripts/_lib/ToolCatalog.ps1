# Optional CLI tools the profile and scripts can use, shared by `tools` and
# `profile-setup`.
#
# Detection never calls Get-Command: a missing command makes PowerShell search
# every module (~470 ms each). It checks PATH (fresh from the registry, so
# installs from this session count) and the WinGet package folders directly.

# Name: display name. Exe: file to look for. WinGet: package id.
# InstallScript: upstream PowerShell installer. Group: core | extra.
# Recommended: pre-selected the first time setup runs (the profile uses it).
$ToolCatalog = @(
    # Profile foundations
    @{ Name = 'git';        Exe = 'git.exe';        WinGet = 'Git.Git';                 Group = 'core'; Recommended = $true; Desc = 'version control; also provides grep/sed/awk/less/ssh used by the profile' }
    @{ Name = 'fzf';        Exe = 'fzf.exe';        WinGet = 'junegunn.fzf';            Group = 'core'; Recommended = $true; Desc = 'fuzzy finder: Ctrl+R history, Ctrl+T files, zi, theme picker' }
    @{ Name = 'fd';         Exe = 'fd.exe';         WinGet = 'sharkdp.fd';              Group = 'core'; Recommended = $true; Desc = 'fast file search (used by Ctrl+T)' }
    @{ Name = 'ripgrep';    Exe = 'rg.exe';         WinGet = 'BurntSushi.ripgrep.MSVC'; Group = 'core'; Recommended = $true; Desc = 'fast text search (rg)' }
    @{ Name = 'eza';        Exe = 'eza.exe';        WinGet = 'eza-community.eza';       Group = 'core'; Recommended = $true; Desc = 'ls / ll / la / tree with icons' }
    @{ Name = 'bat';        Exe = 'bat.exe';        WinGet = 'sharkdp.bat';             Group = 'core'; Recommended = $true; Desc = 'cat with syntax highlighting' }
    @{ Name = 'gh';         Exe = 'gh.exe';         WinGet = 'GitHub.cli';              Group = 'core'; Desc = 'GitHub CLI' }
    @{ Name = 'oh-my-posh'; Exe = 'oh-my-posh.exe'; WinGet = 'JanDeDobbeleer.OhMyPosh'; Group = 'core'; Desc = 'Nerd Font installer used by `font --install`' }
    @{ Name = 'neovim';     Exe = 'nvim.exe';       WinGet = 'Neovim.Neovim';           Group = 'core'; Desc = 'editor' }
    @{ Name = 'podman';     Exe = 'podman.exe';     WinGet = 'RedHat.Podman';           Group = 'core'; Desc = 'containers (wsl-tempcli; aliased as docker when docker is absent)' }
    @{ Name = 'btop';       Exe = 'btop4win.exe';   WinGet = 'aristocratos.btop4win';   Group = 'core'; Desc = 'resource monitor' }
    # Workflow extras
    @{ Name = 'delta';      Exe = 'delta.exe';      WinGet = 'dandavison.delta';        Group = 'extra'; Desc = 'git diff pager' }
    @{ Name = 'procs';      Exe = 'procs.exe';      WinGet = 'dalance.procs';           Group = 'extra'; Desc = 'process viewer' }
    @{ Name = 'jq';         Exe = 'jq.exe';         WinGet = 'jqlang.jq';               Group = 'extra'; Desc = 'JSON processor' }
    @{ Name = 'yq';         Exe = 'yq.exe';         WinGet = 'MikeFarah.yq';            Group = 'extra'; Desc = 'YAML processor' }
    @{ Name = 'sqlite';     Exe = 'sqlite3.exe';    WinGet = 'SQLite.SQLite';           Group = 'extra'; Desc = 'SQLite shell' }
    @{ Name = 'sqlgo';      Exe = 'sqlgo.exe';      InstallScript = 'https://raw.githubusercontent.com/Nulifyer/sqlgo/main/.scripts/install.ps1'; Group = 'extra'; Desc = 'TUI SQL client (upstream install script)' }
    @{ Name = 'chafa';      Exe = 'chafa.exe';      WinGet = 'hpjansson.Chafa';         Group = 'extra'; Desc = 'terminal image previews (wallpaper)' }
    @{ Name = 'glow';       Exe = 'glow.exe';       WinGet = 'charmbracelet.glow';      Group = 'extra'; Desc = 'markdown viewer' }
    @{ Name = 'hyperfine';  Exe = 'hyperfine.exe';  WinGet = 'sharkdp.hyperfine';       Group = 'extra'; Desc = 'command benchmarking' }
    @{ Name = 'tokei';      Exe = 'tokei.exe';      WinGet = 'XAMPPRocky.tokei';        Group = 'extra'; Desc = 'code statistics' }
    @{ Name = 'lutgen';     Exe = 'lutgen.exe';     InstallHint = 'github.com/ozwaldorf/lutgen-rs'; Group = 'extra'; Desc = 'wallpaper re-coloring (manual install)' }
    @{ Name = 'karchy';     Exe = 'karchy.exe';     InstallHint = 'github.com/Nulifyer/Karchy';     Group = 'extra'; Desc = 'launcher (manual install)' }
    @{ Name = 'guget';      Exe = 'guget.exe';      InstallScript = 'https://raw.githubusercontent.com/nulifyer/guget/main/.scripts/install.ps1'; Group = 'extra'; Desc = 'NuGet package manager TUI, needs the .NET SDK (upstream install script)' }
)

. "$PSScriptRoot\WinGetPaths.ps1"

function Get-ToolSearchDirs {
    # Process PATH plus the current registry PATH (tools installed since this
    # shell started), with winget package folders placed where WinGet\Links is
    # (links may be blocked by policy; see WinGetPaths.ps1).
    $dirs = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $all = "$env:PATH;$([Environment]::GetEnvironmentVariable('PATH', 'Machine'));$([Environment]::GetEnvironmentVariable('PATH', 'User'))"
    foreach ($d in $all.Split(';', [StringSplitOptions]'RemoveEmptyEntries,TrimEntries')) {
        $d = [Environment]::ExpandEnvironmentVariables($d)
        if (-not $d.StartsWith('\\') -and $seen.Add($d.TrimEnd('\'))) { $dirs.Add($d) }
    }
    return , (Merge-WinGetToolDirs -PathList $dirs)
}

function Find-ToolExe {
    <# First runnable copy of $Exe: links resolve to their target, dangling or blocked ones are skipped. #>
    param([Parameter(Mandatory)][string]$Exe, [System.Collections.Generic.List[string]]$SearchDirs)
    if (-not $SearchDirs) { $SearchDirs = Get-ToolSearchDirs }
    foreach ($d in $SearchDirs) {
        $p = Resolve-ToolFile ([IO.Path]::Combine($d, $Exe))
        if ($p) { return $p }
    }
    return $null
}

function Test-WinGetAvailable {
    return [bool](Find-ToolExe 'winget.exe')
}

function Install-CatalogTool {
    <# Installs one catalog entry; streams the installer's output. Returns $true on success. #>
    param([Parameter(Mandatory)][hashtable]$Tool)
    if ($Tool.WinGet) {
        $winget = Find-ToolExe 'winget.exe'
        if (-not $winget) { Write-Warning "winget is not available (install 'App Installer' from the Microsoft Store)"; return $false }
        # Out-Host: the output is for the user; left in the pipeline it would
        # become part of the return value (and make a failure look truthy).
        & $winget install -e --id $Tool.WinGet --accept-source-agreements --accept-package-agreements --disable-interactivity | Out-Host
        # 0 = installed; -1978335189 (0x8A15002B) = already installed / no applicable upgrade
        return ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189)
    }
    if ($Tool.InstallScript) {
        # The project's documented one-liner (irm | iex), run in its own
        # PowerShell. In this process, an installer's `exit` would end setup
        # without saving it, and its PATH and preference changes would leak
        # into the user's shell.
        $shell = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        & $shell -NoProfile -NoLogo -ExecutionPolicy Bypass -Command "`$ProgressPreference = 'SilentlyContinue'; irm '$($Tool.InstallScript)' | iex" | Out-Host
        $code = $LASTEXITCODE
        # Installers add their folder to the user PATH, which Find-ToolExe reads.
        $found = Find-ToolExe $Tool.Exe
        if (-not $found) { Write-Warning "$($Tool.Name): the installer finished (exit code $code) but $($Tool.Exe) was not found"; return $false }
        if ($code -ne 0) { Write-Warning "$($Tool.Name): the installer reported an error (exit code $code); using $found" }
        return $true
    }
    Write-Warning "$($Tool.Name) has no automatic installer ($($Tool.InstallHint))"
    return $false
}
