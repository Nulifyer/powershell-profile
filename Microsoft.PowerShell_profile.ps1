#═══════════════════════════════════════════════════════════════════════════════
# PowerShell Profile Configuration
#═══════════════════════════════════════════════════════════════════════════════

$profileLoadStart = Get-Date
$profileCache = "$env:TEMP\pwsh-profile"
if (-not (Test-Path $profileCache)) { New-Item -ItemType Directory -Path $profileCache -Force | Out-Null }

#───────────────────────────────────────────────────────────────────────────────
# UPDATE CHECKS (PowerShell version + profile repo, once per week)
#───────────────────────────────────────────────────────────────────────────────

$updateCheckFile = "$PSScriptRoot\LastUpdateCheck.txt"
$updateInterval = 7 # days
$runUpdateCheck = $false

if (-not (Test-Path $updateCheckFile)) {
    $runUpdateCheck = $true
} else {
    [datetime]$lastCheck = [datetime]::MinValue
    if ([datetime]::TryParseExact((Get-Content $updateCheckFile -Raw).Trim(), 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$lastCheck)) {
        if (((Get-Date) - $lastCheck).TotalDays -gt $updateInterval) { $runUpdateCheck = $true }
    } else {
        $runUpdateCheck = $true
    }
}

function _Check-PwshVersion {
    param([switch]$AutoUpdate)
    $latestVersion = (Invoke-RestMethod -Uri "https://api.github.com/repos/PowerShell/PowerShell/releases/latest" -TimeoutSec 5).tag_name.TrimStart('v')
    $currentVersion = $PSVersionTable.PSVersion.ToString()
    if ([version]$currentVersion -lt [version]$latestVersion) {
        Write-Host "PowerShell update available: $currentVersion → $latestVersion" -ForegroundColor Yellow
        if ($AutoUpdate) {
            Write-Host "Updating PowerShell via WinGet..." -ForegroundColor Yellow
            winget upgrade Microsoft.PowerShell --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -eq 0) {
                Write-Host "PowerShell updated. Restart your shell to use $latestVersion" -ForegroundColor Green
            } else {
                Write-Warning "Failed to update PowerShell"
            }
        } else {
            Write-Host "  Run 'winget upgrade Microsoft.PowerShell' to update" -ForegroundColor DarkGray
        }
        return $true
    }
    Write-Host "PowerShell is up to date ($currentVersion)" -ForegroundColor Green
    return $false
}

function _Check-ProfileUpdates {
    param([switch]$AutoPull)
    $profileDir = $PSScriptRoot
    $status = git -C $profileDir status --porcelain
    if ($status) {
        Write-Host "You have local changes — stash or commit before updating." -ForegroundColor Yellow
        git -C $profileDir status --short
        return
    }
    git -C $profileDir fetch origin main --quiet
    $local = git -C $profileDir rev-parse HEAD
    $remote = git -C $profileDir rev-parse origin/main
    if ($local -ne $remote) {
        if ($AutoPull) {
            Write-Host "Profile update available. Pulling..." -ForegroundColor Yellow
            git -C $profileDir pull --ff-only origin main
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Profile updated. Restart your shell to apply changes." -ForegroundColor Green
            } else {
                Write-Warning "Failed to pull updates. Try manually: git -C $profileDir pull"
            }
        } else {
            Write-Host "Profile update available! Run 'git -C $profileDir pull' to update" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Profile is up to date." -ForegroundColor Green
    }
}

if ($runUpdateCheck) {
    # Test GitHub connectivity (1s timeout)
    $canConnect = try {
        if ($PSVersionTable.PSEdition -eq "Core") {
            Test-Connection github.com -Count 1 -Quiet -TimeoutSeconds 1
        } else {
            $ping = [System.Net.NetworkInformation.Ping]::new()
            ($ping.Send("github.com", 1000)).Status -eq "Success"
        }
    } catch { $false }

    if ($canConnect) {
        try { _Check-PwshVersion } catch {}
        try { _Check-ProfileUpdates } catch {}
        (Get-Date -Format 'yyyy-MM-dd') | Set-Content $updateCheckFile
    }
}



#───────────────────────────────────────────────────────────────────────────────
# ENVIRONMENT & PATHS
#───────────────────────────────────────────────────────────────────────────────

# UTF-8 output (no BOM) — required for Nerd Font glyphs in the prompt
$_utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $_utf8NoBom
$OutputEncoding = $_utf8NoBom

# make sure to load user path
try {
    $systemPath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
    $userPath   = [System.Environment]::GetEnvironmentVariable("PATH", "User")

    if (-not $systemPath) {
        Write-Warning "PROFILE: Could not load system PATH from registry"
    }
    if (-not $userPath) {
        Write-Warning "PROFILE: Could not load user PATH from registry"
    }

    # Merge, deduplicate (case-insensitive), and filter empty entries
    $mergedPath = ($systemPath + ";" + $userPath) -split ";" |
        Where-Object { $_ -ne "" } |
        Sort-Object -Unique -Property { $_.ToLower() }

    $env:PATH = $mergedPath -join ";"
} catch {
    Write-Warning "PROFILE: Failed to load PATH from registry - $_"
}
# Default to Home if launched in System32
$sys32 = Join-Path $env:windir 'System32'
if ($PWD.ProviderPath -ieq $sys32) {
    Set-Location $HOME
}

# Helper to avoid duplicate PATH entries on re-source
function Add-PathEntry([string]$Dir) {
    if ($Dir -and (Test-Path $Dir) -and ($env:PATH -split ';' | ForEach-Object { $_.TrimEnd('\') }) -notcontains $Dir.TrimEnd('\')) {
        $env:PATH += ";$Dir"
    }
}

# Git binaries path (for Unix utilities)
$GitUsrBin = "$env:ProgramFiles\Git\usr\bin"
Add-PathEntry $GitUsrBin

# Auto-detect WinGet installed tools — cached for fast startup
$WinGetPackages = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages"
$wingetCacheFile = "$profileCache\winget-tool-paths.txt"
if (Test-Path $WinGetPackages) {
    if (Test-Path $wingetCacheFile) {
        # Use cached paths
        Get-Content $wingetCacheFile | Where-Object { $_ -and (Test-Path $_) } | ForEach-Object { Add-PathEntry $_ }
    } else {
        # Scan and cache
        $resolvedPaths = @()
        @{
            'sharkdp.fd'            = 'fd.exe'
            'BurntSushi.ripgrep'    = 'rg.exe'
            'junegunn.fzf'          = 'fzf.exe'
            'eza-community.eza'     = 'eza.exe'
            'sharkdp.bat'           = 'bat.exe'
            'dandavison.delta'      = 'delta.exe'
            'MikeFarah.yq'          = 'yq.exe'
            'dalance.procs'         = 'procs.exe'
            'sharkdp.hyperfine'     = 'hyperfine.exe'
            'XAMPPRocky.tokei'      = 'tokei.exe'
            'aristocratos.btop4win' = 'btop4win.exe'
            'charmbracelet.glow'    = 'glow.exe'
            'jqlang.jq'             = 'jq.exe'
            'SQLite.SQLite'         = 'sqlite3.exe'
        }.GetEnumerator() | ForEach-Object {
            $pkgDir = Get-ChildItem $WinGetPackages -Directory -Filter "$($_.Key)_*" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($pkgDir) {
                $exe = Get-ChildItem $pkgDir.FullName -Depth 1 -Filter $_.Value -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($exe) {
                    Add-PathEntry $exe.DirectoryName
                    $resolvedPaths += $exe.DirectoryName
                }
            }
        }
        $resolvedPaths | Set-Content $wingetCacheFile
    }
}
#───────────────────────────────────────────────────────────────────────────────
# LOAD SCRIPTS AS ALIASES
#───────────────────────────────────────────────────────────────────────────────

$scriptsFolder = "$HOME\Documents\PowerShell\Scripts"
if (Test-Path $scriptsFolder) {
    Get-ChildItem -Path $scriptsFolder -Recurse -Filter "*.ps1" | ForEach-Object {
        $script = $_.FullName
        $aliases = @()
        # Read #.ALIAS declarations from the script
        Get-Content $script -TotalCount 20 | ForEach-Object {
            if ($_ -match '^\s*#\.ALIAS\s+(.+)$') {
                $aliases += $Matches[1].Trim()
            }
        }
        # Fall back to filename if no #.ALIAS found
        if ($aliases.Count -eq 0) { $aliases = @($_.BaseName) }
        foreach ($a in $aliases) {
            Set-Alias -Name $a -Value $script -Scope Global
        }
    }
}
#───────────────────────────────────────────────────────────────────────────────
# PROMPT (uses palette truecolors from active theme)
#───────────────────────────────────────────────────────────────────────────────

$_e = [char]27
$global:_c = @{
    reset       = "$_e[0m"
    muted       = "$_e[90m"
    userhost    = "$_e[34m"
    path        = "$_e[35m"
    git         = "$_e[36m"
}

# Load active theme palette and override with truecolors
. "$PSScriptRoot\Scripts\_lib\ScriptUtils.ps1"
. "$PSScriptRoot\Scripts\_lib\ThemeData.ps1"
$_themeName = Get-ScriptConfig "theme" "palette"
if ($_themeName) {
    $_pal = $script:palettes[$_themeName]
    if ($_pal) {
        function _hex2ansi([string]$h) {
            $r = [Convert]::ToInt32($h.Substring(1,2),16)
            $g = [Convert]::ToInt32($h.Substring(3,2),16)
            $b = [Convert]::ToInt32($h.Substring(5,2),16)
            return "$_e[38;2;${r};${g};${b}m"
        }
        $global:_c.muted    = _hex2ansi $_pal.muted
        $global:_c.userhost = _hex2ansi $_pal.userhost
        $global:_c.path     = _hex2ansi $_pal.path
        $global:_c.git      = _hex2ansi $_pal.git
        Remove-Item -Path Function:\_hex2ansi
    }
}

function prompt {
    if ($global:_transientPrompt) {
        $global:_transientPrompt = $false
        return "`e[90m`u{f105}`e[0m "
    }
    $c = $global:_c

    # OS icon
    $os = "$($c.muted)`u{e70f} $($c.reset)"

    # user@host
    $uh = "$($c.userhost)$env:USERNAME@$env:COMPUTERNAME $($c.reset)"

    # Shortened path (fish-style: first char of intermediate dirs)
    $cur = $PWD.ProviderPath
    $home_ = [Environment]::GetFolderPath('UserProfile')
    if ($cur.StartsWith($home_, [StringComparison]::OrdinalIgnoreCase)) {
        $cur = "~" + $cur.Substring($home_.Length)
    }
    $parts = $cur -split '[\\/]'
    if ($parts.Count -gt 2) {
        $short = [System.Collections.Generic.List[string]]::new($parts.Count)
        $short.Add($parts[0])
        for ($i = 1; $i -lt $parts.Count - 1; $i++) {
            if ($parts[$i].Length -gt 0) { $short.Add($parts[$i][0].ToString()) }
        }
        $short.Add($parts[-1])
        $cur = $short -join '\'
    }
    $pathStr = "$($c.path)$cur $($c.reset)"

    # Git branch (read .git/HEAD directly — no process spawn)
    $gitStr = ""
    $d = $PWD.ProviderPath
    while ($d) {
        $gitPath = [IO.Path]::Combine($d, '.git')
        $headFile = $null
        if ([IO.Directory]::Exists($gitPath)) {
            $headFile = [IO.Path]::Combine($gitPath, 'HEAD')
        } elseif ([IO.File]::Exists($gitPath)) {
            # Worktree: .git file contains "gitdir: <path>"
            $link = [IO.File]::ReadAllText($gitPath).Trim()
            if ($link.StartsWith('gitdir: ')) {
                $gd = $link.Substring(8)
                if (-not [IO.Path]::IsPathRooted($gd)) {
                    $gd = [IO.Path]::GetFullPath([IO.Path]::Combine($d, $gd))
                }
                $headFile = [IO.Path]::Combine($gd, 'HEAD')
            }
        }
        if ($headFile -and [IO.File]::Exists($headFile)) {
            $head = [IO.File]::ReadAllText($headFile).Trim()
            $branch = if ($head.StartsWith('ref: refs/heads/')) {
                $head.Substring(16)
            } else {
                $head.Substring(0, [Math]::Min(7, $head.Length))
            }
            $gitStr = "$($c.git)`u{e725} $branch $($c.reset)"
            break
        }
        $parent = [IO.Path]::GetDirectoryName($d)
        if (-not $parent -or $parent -eq $d) { break }
        $d = $parent
    }

    return "${os}${uh}${pathStr}${gitStr}$($c.muted)`u{f105}$($c.reset) "
}

#───────────────────────────────────────────────────────────────────────────────
# PSREADLINE CONFIGURATION
#───────────────────────────────────────────────────────────────────────────────

# Emacs-style keybindings (Ctrl+A, Ctrl+E, Ctrl+K, etc.)
Set-PSReadLineOption -EditMode Emacs

# Enable predictive IntelliSense (like zsh autosuggestions)
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle ListView

# Colors for predictions (uses terminal bright black — follows theme)
Set-PSReadLineOption -Colors @{
    InlinePrediction = $_c.muted
}

# Accept suggestion with Right Arrow or End key
Set-PSReadLineKeyHandler -Key RightArrow -Function ForwardWord
Set-PSReadLineKeyHandler -Key End -Function AcceptSuggestion

# Tab completion menu like zsh
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

# Paste behavior - multiline without auto-execution
$pasteBlock = {
    Add-Type -AssemblyName System.Windows.Forms
    $text = [System.Windows.Forms.Clipboard]::GetText()
    if ($text) {
        # Normalize line endings: remove \r, keep only \n
        $text = $text -replace "`r`n", "`n" -replace "`r", "`n"
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($text)
    }
}
Set-PSReadLineKeyHandler -Key Ctrl+v -ScriptBlock $pasteBlock
Set-PSReadLineKeyHandler -Key Ctrl+Shift+v -ScriptBlock $pasteBlock

# Linux-style keybindings
Set-PSReadLineKeyHandler -Key Ctrl+l -Function ClearScreen
Set-PSReadLineKeyHandler -Key Ctrl+d -Function DeleteCharOrExit
Set-PSReadLineKeyHandler -Key Ctrl+u -Function BackwardDeleteLine
Set-PSReadLineKeyHandler -Key Ctrl+w -Function BackwardDeleteWord

# Word-by-word navigation with Ctrl+Left/Right
Set-PSReadLineKeyHandler -Key Ctrl+LeftArrow  -Function BackwardWord
Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord
Set-PSReadLineKeyHandler -Key Ctrl+Delete     -Function DeleteWord
Set-PSReadLineKeyHandler -Key Ctrl+Backspace  -Function BackwardDeleteWord

# Undo
Set-PSReadLineKeyHandler -Key Ctrl+z -Function Undo

# Transient prompt: collapse previous prompt to just ❯ on Enter
Set-PSReadLineKeyHandler -Key Enter -ScriptBlock {
    $global:_transientPrompt = $true
    [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
    [Console]::Write("`e[J")
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
}

#───────────────────────────────────────────────────────────────────────────────
# ALIASES - Unix Utilities (from Git)
#───────────────────────────────────────────────────────────────────────────────

# Remove conflicting built-in aliases
Remove-Alias -Name pwd -Force -ErrorAction SilentlyContinue
Remove-Alias -Name curl -Force -ErrorAction SilentlyContinue
Remove-Alias -Name sort -Force -ErrorAction SilentlyContinue
Remove-Alias -Name diff -Force -ErrorAction SilentlyContinue

# Core utilities
Set-Alias -Name grep        -Value "$GitUsrBin\grep.exe"
Set-Alias -Name awk         -Value "$GitUsrBin\awk.exe"
Set-Alias -Name sed         -Value "$GitUsrBin\sed.exe"
Set-Alias -Name sort        -Value "$GitUsrBin\sort.exe"
Set-Alias -Name diff        -Value "$GitUsrBin\diff.exe"
Set-Alias -Name tr          -Value "$GitUsrBin\tr.exe"

# Text processing
Set-Alias -Name head        -Value "$GitUsrBin\head.exe"
Set-Alias -Name tail        -Value "$GitUsrBin\tail.exe"
Set-Alias -Name wc          -Value "$GitUsrBin\wc.exe"
Set-Alias -Name cut         -Value "$GitUsrBin\cut.exe"
Set-Alias -Name uniq        -Value "$GitUsrBin\uniq.exe"
Set-Alias -Name xargs       -Value "$GitUsrBin\xargs.exe"

# Editors & pagers
Set-Alias -Name vim         -Value "$GitUsrBin\vim.exe"
Set-Alias -Name nano        -Value "$GitUsrBin\nano.exe"
Set-Alias -Name less        -Value "$GitUsrBin\less.exe"

# SSH
Set-Alias -Name ssh-keygen  -Value "$GitUsrBin\ssh-keygen.exe"
Set-Alias -Name ssh         -Value "$GitUsrBin\ssh.exe"

#───────────────────────────────────────────────────────────────────────────────
# ALIASES - General
#───────────────────────────────────────────────────────────────────────────────

Set-Alias -Name which       -Value Get-Command
Set-Alias -Name docker      -Value podman

#───────────────────────────────────────────────────────────────────────────────
# PODMAN/DOCKER TAB COMPLETION
#───────────────────────────────────────────────────────────────────────────────

if (Get-Command podman -ErrorAction SilentlyContinue) {
    $podmanCompletion = "$HOME\Documents\PowerShell\Completions\podman-completion.ps1"
    $parentDir = Split-Path $podmanCompletion
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
    if (-not (Test-Path $podmanCompletion)) {
        podman completion powershell > $podmanCompletion | Out-Null
    }
    if (Test-Path $podmanCompletion) {
        . $podmanCompletion
    }
}
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if ($dockerCmd -and $dockerCmd.CommandType -ne 'Alias') {
    $dockerCompletion = "$HOME\Documents\PowerShell\Completions\docker-completion.ps1"
    $parentDir = Split-Path $dockerCompletion
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
    if (-not (Test-Path $dockerCompletion)) {
        docker completion powershell > $dockerCompletion | Out-Null
    }
    if (Test-Path $dockerCompletion) {
        . $dockerCompletion
    }
}
#───────────────────────────────────────────────────────────────────────────────
# ENHANCED TOOLS (eza, bat)
#───────────────────────────────────────────────────────────────────────────────

# ls with colors (using eza if installed, fallback to Get-ChildItem)
if (Get-Command eza -ErrorAction SilentlyContinue) {
    Remove-Item Alias:ls   -ErrorAction SilentlyContinue
    Remove-Item Alias:tree -ErrorAction SilentlyContinue
    function ls   { eza --icons --group-directories-first @args }
    function ll   { eza -l --icons --group-directories-first @args }
    function la   { eza -la --icons --group-directories-first @args }
    function tree { eza --tree --icons @args }
} else {
    Set-Alias -Name ll -Value Get-ChildItem
    Set-Alias -Name la -Value Get-ChildItem
}

# cat with syntax highlighting (using bat if installed)
if (Get-Command bat -ErrorAction SilentlyContinue) {
    Remove-Item Alias:cat -ErrorAction SilentlyContinue
    function cat { bat --paging=never @args }
}

#───────────────────────────────────────────────────────────────────────────────
# FZF INTEGRATION
#───────────────────────────────────────────────────────────────────────────────

if (Get-Command fzf -ErrorAction SilentlyContinue) {
    # Ctrl+R: fuzzy history search
    Set-PSReadLineKeyHandler -Key Ctrl+r -ScriptBlock {
        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        $history = [Microsoft.PowerShell.PSConsoleReadLine]::GetHistoryItems() |
            ForEach-Object { $_.CommandLine } |
            Select-Object -Unique
        $selected = $history | fzf --tac --no-sort --query="$line"
        if ($selected) {
            [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert($selected)
        }
    }

    # Ctrl+T: fuzzy file picker (uses fd if available, falls back to Get-ChildItem)
    Set-PSReadLineKeyHandler -Key Ctrl+t -ScriptBlock {
        $selected = if (Get-Command fd -ErrorAction SilentlyContinue) {
            fd --type f --hidden --exclude .git | fzf
        } else {
            Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName } | fzf
        }
        if ($selected) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert($selected)
        }
    }
}

#───────────────────────────────────────────────────────────────────────────────
# FUNCTIONS - File Operations
#───────────────────────────────────────────────────────────────────────────────

function pwd {
    (Get-Location).Path
}

function touch {
    param([Parameter(Mandatory, ValueFromPipeline)]$Path)
    process {
        if (Test-Path $Path) {
            (Get-Item $Path).LastWriteTime = Get-Date
        } else {
            New-Item -ItemType File -Path $Path | Out-Null
        }
    }
}

function mkdirp {
    param([Parameter(Mandatory)]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function rmrf {
    param([Parameter(Mandatory)]$Path)
    Remove-Item -Path $Path -Recurse -Force
}

function mkcd {
    param([Parameter(Mandatory)]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Set-Location $Path
}

function ff {
    param(
        [Parameter(Position=0)][string]$Path = ".",
        [Alias("name")][string]$Filter = "*"
    )
    Get-ChildItem -Path $Path -Recurse -Filter $Filter -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName
}

function open {
    param([Parameter(Mandatory)]$Path)
    Start-Process $Path
}

#───────────────────────────────────────────────────────────────────────────────
# FUNCTIONS - Navigation
#───────────────────────────────────────────────────────────────────────────────

function ..   { Set-Location .. }
function ...  { Set-Location ..\.. }
function .... { Set-Location ..\..\.. }

#───────────────────────────────────────────────────────────────────────────────
# FUNCTIONS - System Info
#───────────────────────────────────────────────────────────────────────────────

function df {
    Get-PSDrive -PSProvider FileSystem |
        Select-Object Name,
            @{N='Used(GB)';E={[math]::Round($_.Used/1GB,2)}},
            @{N='Free(GB)';E={[math]::Round($_.Free/1GB,2)}},
            @{N='Total(GB)';E={[math]::Round(($_.Used+$_.Free)/1GB,2)}},
            @{N='Use%';E={[math]::Round($_.Used/($_.Used+$_.Free)*100,1)}}
}

Set-Alias -Name du -Value "$GitUsrBin\du.exe"

#───────────────────────────────────────────────────────────────────────────────
# FUNCTIONS - Process Management
#───────────────────────────────────────────────────────────────────────────────

function psl {
    Get-Process | Select-Object Id, ProcessName, CPU,
        @{N='Mem(MB)';E={[math]::Round($_.WorkingSet64/1MB,2)}} |
        Sort-Object -Property 'Mem(MB)' -Descending
}

function pkill {
    param([Parameter(Mandatory)]$Name)
    Get-Process -Name $Name -ErrorAction SilentlyContinue | Stop-Process -Force
}

function sudo {
    Start-Process pwsh -Verb RunAs -ArgumentList "-NoExit", "-Command", ($args -join ' ')
}

#───────────────────────────────────────────────────────────────────────────────
# FUNCTIONS - Shell Utilities
#───────────────────────────────────────────────────────────────────────────────

function h { Get-History | Select-Object -Last 50 }

function export {
    param([Parameter(Mandatory)]$Assignment)
    $parts = $Assignment -split '=', 2
    [Environment]::SetEnvironmentVariable($parts[0], $parts[1], 'Process')
}

function watch {
    param(
        [Alias('n')][int]$Interval,
        [Parameter(ValueFromRemainingArguments)]$Command
    )
    # Parse leading -n <seconds> from remaining args (like linux watch)
    if (-not $Interval -and $Command.Count -ge 2 -and $Command[0] -eq '-n') {
        $Interval = [int]$Command[1]
        $Command = @($Command | Select-Object -Skip 2)
    }
    if (-not $Interval) { $Interval = 2 }
    $cmdStr = $Command -join ' '
    if (-not $cmdStr) { Write-Host "Usage: watch [-n secs] <command>"; return }
    while ($true) {
        Clear-Host
        $now = Get-Date -Format "HH:mm:ss"
        Write-Host "Every ${Interval}.0s: $cmdStr    $now" -ForegroundColor DarkGray
        Write-Host ""
        try { Invoke-Expression $cmdStr } catch { Write-Host $_.Exception.Message -ForegroundColor Red }
        Start-Sleep -Seconds $Interval
    }
}

Set-Alias -Name file -Value "$GitUsrBin\file.exe"

#───────────────────────────────────────────────────────────────────────────────
# FUNCTIONS - Profile Update
#───────────────────────────────────────────────────────────────────────────────

function profile-update {
    Write-Host "Checking for PowerShell updates..." -ForegroundColor Cyan
    try { _Check-PwshVersion -AutoUpdate } catch { Write-Warning "Failed to check PowerShell version: $_" }

    Write-Host ""
    Write-Host "Checking for profile updates..." -ForegroundColor Cyan
    try { _Check-ProfileUpdates -AutoPull } catch { Write-Warning "Failed to check profile updates: $_" }

    (Get-Date -Format 'yyyy-MM-dd') | Set-Content "$PSScriptRoot\LastUpdateCheck.txt"
}
Set-Alias -Name pu -Value profile-update

#───────────────────────────────────────────────────────────────────────────────
# PROFILE LOAD TIME
#───────────────────────────────────────────────────────────────────────────────

$profileLoadTime = (Get-Date) - $profileLoadStart
Write-Host "Profile loaded in $([math]::Round($profileLoadTime.TotalMilliseconds))ms" -ForegroundColor DarkGray
