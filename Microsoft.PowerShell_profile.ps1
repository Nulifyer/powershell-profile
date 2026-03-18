#═══════════════════════════════════════════════════════════════════════════════
# PowerShell Profile Configuration
#═══════════════════════════════════════════════════════════════════════════════

$profileLoadStart = Get-Date
$profileCache = "$env:TEMP\pwsh-profile"
if (-not (Test-Path $profileCache)) { New-Item -ItemType Directory -Path $profileCache -Force | Out-Null }

#───────────────────────────────────────────────────────────────────────────────
# ENVIRONMENT & PATHS
#───────────────────────────────────────────────────────────────────────────────

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

    # Merge, deduplicate, and filter empty entries
    $mergedPath = ($systemPath + ";" + $userPath) -split ";" |
        Where-Object { $_ -ne "" } |
        Select-Object -Unique

    $env:PATH = $mergedPath -join ";"
} catch {
    Write-Warning "PROFILE: Failed to load PATH from registry - $_"
}
# Default to Home if launched in System32
$sys32 = Join-Path $env:windir 'System32'
if ($PWD.ProviderPath -ieq $sys32) {
    Set-Location $HOME
}

# Git binaries path (for Unix utilities)
$GitUsrBin = "$env:ProgramFiles\Git\usr\bin"
if (Test-Path $GitUsrBin) { $env:PATH += ";$GitUsrBin" }

# Auto-detect WinGet installed tools (fd, ripgrep) — cached to avoid slow recursive scan
$WinGetPackages = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages"
$wingetCache = "$profileCache\winget-tool-paths.txt"
if (Test-Path $WinGetPackages) {
    if (-not (Test-Path $wingetCache)) {
        $paths = Get-ChildItem -Path $WinGetPackages -Recurse -Include "fd.exe","rg.exe" -ErrorAction SilentlyContinue |
            Select-Object -Unique DirectoryName |
            ForEach-Object { $_.DirectoryName }
        Set-Content $wingetCache -Value $paths  # always creates the file, even if empty
    }
    Get-Content $wingetCache | Where-Object { $_ } | ForEach-Object { $env:PATH += ";$_" }
}
#───────────────────────────────────────────────────────────────────────────────
# LOAD SCRIPTS AS ALIASES
#───────────────────────────────────────────────────────────────────────────────

$scriptsFolder = "$HOME\Documents\PowerShell\Scripts"
if (Test-Path $scriptsFolder) {
    Get-ChildItem -Path $scriptsFolder -Filter "*.ps1" -Depth 1 | ForEach-Object {
        $aliasName = $_.BaseName
        Set-Alias -Name $aliasName -Value $_.FullName
    }
}
#───────────────────────────────────────────────────────────────────────────────
# PROMPT
#───────────────────────────────────────────────────────────────────────────────

$ompCmd = Get-Command oh-my-posh -ErrorAction SilentlyContinue
if ($ompCmd) {
    $ompTheme = "catppuccin_mocha"
    $ompMtime = (Get-Item $ompCmd.Source).LastWriteTime.ToString("yyyyMMddHHmmss")
    $ompCache = "$profileCache\omp-${ompTheme}-${ompMtime}.ps1"
    if (-not (Test-Path $ompCache)) {
        oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\${ompTheme}.omp.json" | Set-Content $ompCache -Encoding UTF8
    }
    . $ompCache
}
#───────────────────────────────────────────────────────────────────────────────
# PSREADLINE CONFIGURATION
#───────────────────────────────────────────────────────────────────────────────

# Emacs-style keybindings (Ctrl+A, Ctrl+E, Ctrl+K, etc.)
Set-PSReadLineOption -EditMode Emacs

# Enable predictive IntelliSense (like zsh autosuggestions)
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle InlineView

# Colors for predictions (gray text like zsh)
Set-PSReadLineOption -Colors @{
    InlinePrediction = '#808080'
}

# Accept suggestion with Right Arrow or End key
Set-PSReadLineKeyHandler -Key RightArrow -Function ForwardWord
Set-PSReadLineKeyHandler -Key End -Function AcceptSuggestion

# Tab completion menu like zsh
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

# Paste behavior - multiline without auto-execution
Set-PSReadLineKeyHandler -Key Ctrl+v -ScriptBlock {
    Add-Type -AssemblyName System.Windows.Forms
    $text = [System.Windows.Forms.Clipboard]::GetText()
    if ($text) {
        # Normalize line endings: remove \r, keep only \n
        $text = $text -replace "`r`n", "`n" -replace "`r", "`n"
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($text)
    }
}

Set-PSReadLineKeyHandler -Key Ctrl+Shift+v -ScriptBlock {
    Add-Type -AssemblyName System.Windows.Forms
    $text = [System.Windows.Forms.Clipboard]::GetText()
    if ($text) {
        $text = $text -replace "`r`n", "`n" -replace "`r", "`n"
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($text)
    }
}

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
Set-Alias -Name Ssh-Keygen  -Value "$GitUsrBin\ssh-keygen.exe"
Set-Alias -Name Ssh         -Value "$GitUsrBin\ssh.exe"

#───────────────────────────────────────────────────────────────────────────────
# ALIASES - General
#───────────────────────────────────────────────────────────────────────────────

Set-Alias -Name which       -Value Get-Command
Set-Alias -Name ll          -Value Get-ChildItem
Set-Alias -Name la          -Value Get-ChildItem
Set-Alias -Name clear       -Value Clear-Host
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

# ls with colors (using eza if installed)
if (Get-Command eza -ErrorAction SilentlyContinue) {
    Remove-Item Alias:ls   -ErrorAction SilentlyContinue
    Remove-Item Alias:ll   -ErrorAction SilentlyContinue
    Remove-Item Alias:la   -ErrorAction SilentlyContinue
    Remove-Item Alias:tree -ErrorAction SilentlyContinue
    function ls   { eza --icons --group-directories-first @args }
    function ll   { eza -l --icons --group-directories-first @args }
    function la   { eza -la --icons --group-directories-first @args }
    function tree { eza --tree --icons @args }
}

# cat with syntax highlighting (using bat if installed)
if (Get-Command bat -ErrorAction SilentlyContinue) {
    Remove-Item Alias:cat -ErrorAction SilentlyContinue
    function cat { bat --paging=never @args }
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

function find {
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

function whoami  { $env:USERNAME }
function hostname { $env:COMPUTERNAME }

function df {
    Get-PSDrive -PSProvider FileSystem |
        Select-Object Name,
            @{N='Used(GB)';E={[math]::Round($_.Used/1GB,2)}},
            @{N='Free(GB)';E={[math]::Round($_.Free/1GB,2)}},
            @{N='Total(GB)';E={[math]::Round(($_.Used+$_.Free)/1GB,2)}},
            @{N='Use%';E={[math]::Round($_.Used/($_.Used+$_.Free)*100,1)}}
}

function du {
    param([string]$Path = ".")
    Get-ChildItem $Path -Recurse -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum |
        Select-Object @{N='Size(MB)';E={[math]::Round($_.Sum/1MB,2)}}, Count
}

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

function source {
    param([Parameter(Mandatory)]$Path)
    . $Path
}

#───────────────────────────────────────────────────────────────────────────────
# FUNCTIONS - Custom Scripts
#───────────────────────────────────────────────────────────────────────────────

# function my-function {
#     & "$HOME\.scripts\script.ps1" @args
# }

#───────────────────────────────────────────────────────────────────────────────
# PROFILE LOAD TIME
#───────────────────────────────────────────────────────────────────────────────

$profileLoadTime = (Get-Date) - $profileLoadStart
Write-Host "Profile loaded in $([math]::Round($profileLoadTime.TotalMilliseconds))ms" -ForegroundColor DarkGray
