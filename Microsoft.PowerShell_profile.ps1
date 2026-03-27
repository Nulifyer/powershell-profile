#═══════════════════════════════════════════════════════════════════════════════
# PowerShell Profile Configuration
#═══════════════════════════════════════════════════════════════════════════════

$profileLoadStart = Get-Date
$profileCache = "$env:TEMP\pwsh-profile"
if (-not (Test-Path $profileCache)) { New-Item -ItemType Directory -Path $profileCache -Force | Out-Null }

#───────────────────────────────────────────────────────────────────────────────
# CONFIG SYMLINKS (Alacritty, Windows Terminal)
#───────────────────────────────────────────────────────────────────────────────

$configLinks = @(
    @{
        Source = "$PSScriptRoot\alacritty.toml"
        Target = "$env:APPDATA\alacritty\alacritty.toml"
    },
    @{
        Source = "$PSScriptRoot\windows-terminal-fragment.json"
        Target = "$env:LOCALAPPDATA\Microsoft\Windows Terminal\Fragments\powershell-profile\fragment.json"
    }
)
foreach ($link in $configLinks) {
    if (-not (Test-Path $link.Source)) { continue }
    $needsCopy = $false
    if (-not (Test-Path $link.Target)) {
        $needsCopy = $true
    } else {
        # Copy again only if source has changed
        $srcHash = (Get-FileHash $link.Source).Hash
        $tgtHash = (Get-FileHash $link.Target).Hash
        if ($srcHash -ne $tgtHash) { $needsCopy = $true }
    }
    if ($needsCopy) {
        $targetDir = Split-Path $link.Target
        if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
        Copy-Item -Path $link.Source -Destination $link.Target -Force
        Write-Host "Updated: $($link.Target)" -ForegroundColor Green
    }
}

# Set Nulifyer's Profile as default in Windows Terminal
$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$nulifyrGuid = "{f1a2b3c4-d5e6-4f78-9a0b-1c2d3e4f5a6b}"
if (Test-Path $wtSettingsPath) {
    $wtSettings = Get-Content $wtSettingsPath -Raw | ConvertFrom-Json
    if ($wtSettings.defaultProfile -ne $nulifyrGuid) {
        $wtSettings.defaultProfile = $nulifyrGuid
        $wtSettings | ConvertTo-Json -Depth 10 | Set-Content $wtSettingsPath -Encoding UTF8
        Write-Host "Windows Terminal default profile set to Nulifyer's Profile" -ForegroundColor Green
    }
}

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

# Auto-detect WinGet installed tools — targeted by package ID
$WinGetPackages = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages"
if (Test-Path $WinGetPackages) {
    @{
        'sharkdp.fd'            = 'fd.exe'
        'BurntSushi.ripgrep'    = 'rg.exe'
        'junegunn.fzf'          = 'fzf.exe'
        'ajeetdsouza.zoxide'    = 'zoxide.exe'
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
    }.GetEnumerator() | ForEach-Object {
        $pkgDir = Get-ChildItem $WinGetPackages -Directory -Filter "$($_.Key)_*" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($pkgDir) {
            $exe = Get-ChildItem $pkgDir.FullName -Depth 1 -Filter $_.Value -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($exe) { $env:PATH += ";$($exe.DirectoryName)" }
        }
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
Set-PSReadLineOption -PredictionViewStyle ListView

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

function file {
    param([Parameter(Mandatory, Position=0)][string]$Path)
    if (-not (Test-Path $Path)) { Write-Host "$Path`: cannot open (No such file or directory)"; return }
    $item = Get-Item $Path -Force
    if ($item.PSIsContainer) { Write-Host "$Path`: directory"; return }

    $ext = $item.Extension.ToLower()
    $size = $item.Length

    # Read magic bytes
    $magic = [byte[]]::new([Math]::Min(16, $size))
    if ($size -gt 0) {
        $stream = [System.IO.File]::OpenRead($item.FullName)
        try { $stream.Read($magic, 0, $magic.Length) | Out-Null } finally { $stream.Close() }
    }
    $hex = ($magic | ForEach-Object { $_.ToString("X2") }) -join ''

    # Identify by magic bytes
    $type = switch -Wildcard ($hex) {
        '89504E47*'       { "PNG image data" }
        'FFD8FF*'         { "JPEG image data" }
        '47494638*'       { "GIF image data" }
        '52494646*'       {
            $sub = [System.Text.Encoding]::ASCII.GetString($magic[8..11])
            if ($sub -eq 'WEBP') { "WebP image data" }
            elseif ($sub -eq 'AVI ') { "AVI video" }
            elseif ($sub -eq 'WAVE') { "WAVE audio" }
            else { "RIFF data" }
        }
        '504B0304*'       {
            switch -Wildcard ($ext) {
                '.docx'  { "Microsoft Word document (OOXML)" }
                '.xlsx'  { "Microsoft Excel spreadsheet (OOXML)" }
                '.pptx'  { "Microsoft PowerPoint presentation (OOXML)" }
                '.jar'   { "Java archive (JAR)" }
                '.apk'   { "Android application package" }
                default  { "Zip archive data" }
            }
        }
        '25504446*'       { "PDF document" }
        '7F454C46*'       { "ELF executable" }
        '4D5A*'           { "PE32 executable (Windows)" }
        '1F8B*'           { "gzip compressed data" }
        '425A68*'         { "bzip2 compressed data" }
        'FD377A585A*'     { "XZ compressed data" }
        '377ABCAF271C*'   { "7-zip archive data" }
        '526172211A07*'   { "RAR archive data" }
        '000001BA*'       { "MPEG video" }
        '000001B3*'       { "MPEG video" }
        '1A45DFA3*'       { "Matroska video (MKV/WebM)" }
        '66747970*'       { "ISO Media (MP4/M4A/MOV)" }
        '4F676753*'       { "Ogg data" }
        '664C6143*'       { "FLAC audio" }
        '494433*'         { "MP3 audio (ID3 tag)" }
        'FFFB*'           { "MP3 audio" }
        'FFF3*'           { "MP3 audio" }
        '49492A00*'       { "TIFF image data (little-endian)" }
        '4D4D002A*'       { "TIFF image data (big-endian)" }
        '00000100*'       { "ICO image" }
        '00000200*'       { "CUR cursor" }
        '7B*'             { "JSON data" }
        '3C3F786D6C*'     { "XML document" }
        '3C21444F43*'     { "HTML document" }
        '3C68746D6C*'     { "HTML document" }
        'EFBBBF*'         { "UTF-8 text (with BOM)" }
        'FFFE*'           { "UTF-16 text (little-endian BOM)" }
        'FEFF*'           { "UTF-16 text (big-endian BOM)" }
        'D0CF11E0A1B11AE1*' { "Microsoft Office document (OLE2)" }
        '53514C697465*'   { "SQLite database" }
        default           { $null }
    }

    # Fall back to extension-based or text detection
    if (-not $type) {
        if ($size -eq 0) {
            $type = "empty"
        } else {
            # Check if it looks like text
            $isText = $true
            foreach ($b in $magic) {
                if ($b -eq 0) { $isText = $false; break }
            }
            if ($isText) {
                $type = switch -Wildcard ($ext) {
                    '.ps1'    { "PowerShell script" }
                    '.py'     { "Python script" }
                    '.js'     { "JavaScript source" }
                    '.ts'     { "TypeScript source" }
                    '.cs'     { "C# source" }
                    '.go'     { "Go source" }
                    '.rs'     { "Rust source" }
                    '.java'   { "Java source" }
                    '.c'      { "C source" }
                    '.cpp'    { "C++ source" }
                    '.h'      { "C/C++ header" }
                    '.sh'     { "shell script" }
                    '.bat'    { "DOS batch file" }
                    '.cmd'    { "Windows command script" }
                    '.json'   { "JSON data" }
                    '.xml'    { "XML document" }
                    '.yaml'   { "YAML data" }
                    '.yml'    { "YAML data" }
                    '.toml'   { "TOML data" }
                    '.ini'    { "INI configuration" }
                    '.cfg'    { "configuration file" }
                    '.conf'   { "configuration file" }
                    '.md'     { "Markdown document" }
                    '.txt'    { "ASCII text" }
                    '.csv'    { "CSV text" }
                    '.tsv'    { "TSV text" }
                    '.log'    { "log file" }
                    '.html'   { "HTML document" }
                    '.htm'    { "HTML document" }
                    '.css'    { "CSS stylesheet" }
                    '.sql'    { "SQL script" }
                    '.dockerfile' { "Dockerfile" }
                    default   { "ASCII text" }
                }
            } else {
                $type = "data"
            }
        }
    }

    Write-Host "$Path`: $type, $size bytes"
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
