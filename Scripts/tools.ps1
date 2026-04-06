#.ALIAS tools
#.HELP Usage: tools [--install] [--core|--extra]
#.HELP
#.HELP Show installation status of CLI tools.
#.HELP   tools                  — show status of all tools
#.HELP   tools --install        — pick missing tools to install via WinGet
#.HELP   tools --install --core — install/select core profile tools only
#.HELP   tools --install --extra — install/select workflow extras only

. "$PSScriptRoot\_lib\ScriptUtils.ps1"

$parsed = Parse-Args $args @{
    Install = @{ Aliases = @('i', 'install') }
    Core    = @{ Aliases = @('core', 'profile') }
    Extra   = @{ Aliases = @('extra', 'extras') }
}

if ($parsed._help) { Show-Help; exit 0 }

function Require-Fzf {
    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
        return $false
    }
    return $true
}

function Install-WinGetPackage {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$WinGetId
    )

    Write-Host "  Installing $Name ($WinGetId)..." -ForegroundColor Yellow
    winget install -e --id $WinGetId --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Installed $Name" -ForegroundColor Green
        return $true
    }

    Write-Warning "  Failed to install $Name"
    return $false
}

function Require-WinGet {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        return
    }

    Write-Host "  winget is required for tool installation, but it is not available." -ForegroundColor Red
    Write-Host "  Install App Installer from Microsoft Store, then run 'tools --install' again." -ForegroundColor DarkGray
    Write-Host ""
    exit 1
}

function Select-InstallTargets {
    param([array]$Choices)

    if (-not $Choices -or $Choices.Count -eq 0) { return @() }

    if (-not (Require-Fzf)) {
        Write-Host "  fzf is required for interactive installs." -ForegroundColor Red
        Write-Host ""
        exit 1
    }

    $lines = foreach ($choice in $Choices) {
        "$($choice.Key)`t$($choice.Label)`t$($choice.Detail)"
    }

    $selected = $lines | fzf --multi --layout=reverse --border --no-info `
        --delimiter="`t" --with-nth=2,3 `
        --prompt="install > " `
        --header="TAB toggles, ENTER installs selected items (or current item if none selected)" `
        --bind "tab:toggle+down,shift-tab:toggle+up"

    if (-not $selected) { return @() }

    return @($selected | ForEach-Object { ($_ -split "`t", 2)[0] })
}

function Write-ToolStatusLine {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Tool,
        [Parameter(Mandatory)]
        [bool]$IsInstalled
    )

    $stateLabel = if ($IsInstalled) { "[OK]" } else { "[  ]" }
    $stateColor = if ($IsInstalled) { "Green" } else { "Yellow" }
    $groupLabel = if ($Tool.Group -eq 'core') { "[core]" } else { "[extra]" }

    Write-Host "  $stateLabel  $($Tool.Name.PadRight(14))" -ForegroundColor $stateColor -NoNewline
    Write-Host " $groupLabel $($Tool.Display)" -ForegroundColor DarkGray
}

# Tool definitions: display name, winget package ID, exe to check
$tools = @(
    # Profile foundations
    @{ Name = "git";         Exe = "git.exe";         WinGet = "Git.Git";                  Group = "core" }
    @{ Name = "gh";          Exe = "gh.exe";          WinGet = "GitHub.cli";               Group = "core" }
    @{ Name = "oh-my-posh";  Exe = "oh-my-posh.exe";  WinGet = "JanDeDobbeleer.OhMyPosh";  Group = "core" }
    @{ Name = "neovim";      Exe = "nvim.exe";        WinGet = "Neovim.Neovim";            Group = "core" }
    @{ Name = "podman";      Exe = "podman.exe";      WinGet = "RedHat.Podman";            Group = "core" }
    @{ Name = "fzf";         Exe = "fzf.exe";         WinGet = "junegunn.fzf";             Group = "core" }
    @{ Name = "fd";          Exe = "fd.exe";          WinGet = "sharkdp.fd";               Group = "core" }
    @{ Name = "ripgrep";     Exe = "rg.exe";          WinGet = "BurntSushi.ripgrep.MSVC";  Group = "core" }
    @{ Name = "eza";         Exe = "eza.exe";         WinGet = "eza-community.eza";        Group = "core" }
    @{ Name = "bat";         Exe = "bat.exe";         WinGet = "sharkdp.bat";              Group = "core" }
    @{ Name = "btop";        Exe = "btop4win.exe";    WinGet = "aristocratos.btop4win";    Group = "core" }
    # Workflow extras
    @{ Name = "delta";       Exe = "delta.exe";       WinGet = "dandavison.delta";         Group = "extra" }
    @{ Name = "procs";       Exe = "procs.exe";       WinGet = "dalance.procs";            Group = "extra" }
    @{ Name = "jq";          Exe = "jq.exe";          WinGet = "jqlang.jq";                Group = "extra" }
    @{ Name = "yq";          Exe = "yq.exe";          WinGet = "MikeFarah.yq";             Group = "extra" }
    @{ Name = "sqlite";      Exe = "sqlite3.exe";     WinGet = "SQLite.SQLite";            Group = "extra" }
    @{ Name = "chafa";       Exe = "chafa.exe";       WinGet = "hpjansson.Chafa";          Group = "extra" }
    @{ Name = "lutgen";      Exe = "lutgen.exe";      InstallHint = "github.com/ozwaldorf/lutgen-rs"; Group = "extra" }
    @{ Name = "karchy";      Exe = "karchy.exe";      InstallHint = "github.com/Nulifyer/Karchy";     Group = "extra" }
    @{ Name = "guget";       Exe = "guget.exe";       InstallHint = "manual install";      Group = "extra" }
    @{ Name = "glow";        Exe = "glow.exe";        WinGet = "charmbracelet.glow";       Group = "extra" }
    @{ Name = "hyperfine";   Exe = "hyperfine.exe";   WinGet = "sharkdp.hyperfine";        Group = "extra" }
    @{ Name = "tokei";       Exe = "tokei.exe";       WinGet = "XAMPPRocky.tokei";         Group = "extra" }
)

$missing = @()
$installed = @()

foreach ($tool in $tools) {
    $found = Get-Command $tool.Exe -ErrorAction SilentlyContinue
    if ($found) {
        $src = $found.Source
        $display = $src
        $homePrefix = $HOME + "\"
        $wingetPrefix = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\"
        if ($src.StartsWith($wingetPrefix)) {
            $afterPkg = $src.Substring($wingetPrefix.Length)
            $pkgId = ($afterPkg -split '_')[0]
            $exe = Split-Path $src -Leaf
            $display = "~/AppData/Local/.../$pkgId/.../$exe"
        } elseif ($src.StartsWith($homePrefix)) {
            $display = "~/" + $src.Substring($homePrefix.Length).Replace('\', '/')
        }
        $tool.Display = $display
        $installed += $tool
    } else {
        $tool.Display = if ($tool.WinGet) { $tool.WinGet } else { $tool.InstallHint }
        $missing += $tool
    }
}

$totalInstalled = $installed.Count
$totalMissing = $missing.Count

if ($missing.Count -eq 0) {
    if (-not $parsed.Install) {
        Write-Host ""
        Write-Host "  Terminal Tools Status" -ForegroundColor Cyan
        Write-Host "  $("-" * 50)" -ForegroundColor DarkGray
        foreach ($tool in $installed) {
            Write-ToolStatusLine -Tool $tool -IsInstalled $true
        }
        Write-Host "  $("-" * 50)" -ForegroundColor DarkGray
        Write-Host "  $totalInstalled installed, $totalMissing missing" -ForegroundColor DarkGray
        Write-Host ""
    }

    Write-Host "  All tools installed." -ForegroundColor Green
    Write-Host ""
    exit 0
}

if (-not $parsed.Install) {
    Write-Host ""
    Write-Host "  Terminal Tools Status" -ForegroundColor Cyan
    Write-Host "  $("-" * 50)" -ForegroundColor DarkGray
    foreach ($tool in $tools) {
        if ($installed -contains $tool) {
            Write-ToolStatusLine -Tool $tool -IsInstalled $true
        } else {
            Write-ToolStatusLine -Tool $tool -IsInstalled $false
        }
    }
    Write-Host "  $("-" * 50)" -ForegroundColor DarkGray
    Write-Host "  $totalInstalled installed, $totalMissing missing" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Run 'tools --install' to install missing tools." -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

if ($parsed.Core -and $parsed.Extra) {
    Write-Host "  Choose either --core or --extra, not both." -ForegroundColor Red
    Write-Host ""
    exit 1
}

Require-WinGet

if (-not (Require-Fzf)) {
    $fzfTool = $missing | Where-Object { $_.Name -eq 'fzf' } | Select-Object -First 1
    if (-not $fzfTool) {
        Write-Host "  fzf is required for interactive installs. Install fzf first, then run tools --install again." -ForegroundColor Red
        Write-Host ""
        exit 1
    }

    Write-Host "  fzf is required for interactive selection, so we'll install it first." -ForegroundColor Yellow
    Write-Host ""
    if (-not (Install-WinGetPackage -Name $fzfTool.Name -WinGetId $fzfTool.WinGet)) {
        Write-Host ""
        exit 1
    }
    Write-Host ""
}

# Build install choices
$installChoices = @()
$missingTools = if ($parsed.Core) {
    @($missing | Where-Object { $_.Group -eq 'core' })
} elseif ($parsed.Extra) {
    @($missing | Where-Object { $_.Group -eq 'extra' })
} else {
    @($missing)
}

foreach ($tool in $missingTools) {
    if ($tool.Name -eq 'fzf' -and (Require-Fzf)) { continue }
    if (-not $tool.WinGet) { continue }

    $installChoices += @{
        Key = "tool:$($tool.Name)"
        Kind = "tool"
        Name = $tool.Name
        Label = if ($tool.Group -eq 'core') { "[core] $($tool.Name)" } else { "[extra] $($tool.Name)" }
        Detail = $tool.WinGet
        Tool = $tool
    }
}

if ($installChoices.Count -eq 0) {
    $scopeLabel = if ($parsed.Core) { "core tools" } elseif ($parsed.Extra) { "extra tools" } else { "tools" }
    $manualOnly = @($missingTools | Where-Object { -not $_.WinGet })
    if ($manualOnly.Count -gt 0) {
        Write-Host "  No missing $scopeLabel are installable via winget." -ForegroundColor Yellow
        Write-Host "  Manual extras: $($manualOnly.Name -join ', ')" -ForegroundColor DarkGray
    } else {
        Write-Host "  No missing $scopeLabel to install." -ForegroundColor Green
    }
    Write-Host ""
    exit 0
}

$selectedKeys = Select-InstallTargets $installChoices
if ($selectedKeys.Count -eq 0) {
    Write-Host "  No tools selected." -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

$selectedChoices = foreach ($key in $selectedKeys) {
    $installChoices | Where-Object { $_.Key -eq $key } | Select-Object -First 1
}

Write-Host "  Installing selected items..." -ForegroundColor Cyan
Write-Host ""

foreach ($choice in $selectedChoices) {
    if (-not $choice) { continue }

    if ($choice.Kind -eq 'tool') {
        $tool = $choice.Tool
        [void](Install-WinGetPackage -Name $tool.Name -WinGetId $tool.WinGet)
    }
    Write-Host ""
}

# Clear the winget path cache so profile picks up new tools
$cacheFile = "$env:TEMP\pwsh-profile\winget-tool-paths.txt"
if (Test-Path $cacheFile) {
    Remove-Item $cacheFile -Force
    Write-Host "  Path cache cleared. Restart your shell to pick up new tools." -ForegroundColor Cyan
}
Write-Host ""
