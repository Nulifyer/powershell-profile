#.ALIAS tools
<#
.SYNOPSIS
    Check and install terminal tools via WinGet.

.DESCRIPTION
    Verifies that all expected CLI tools are installed. Shows status for each
    tool and optionally installs missing ones.

.EXAMPLE
    tools
    # Show status of all tools

.EXAMPLE
    tools --install
    # Install any missing tools
#>

. "$PSScriptRoot\ScriptUtils.ps1"

$parsed = Parse-Args $args @{
    Install = @{ Aliases = @('i', 'install') }
}

if ($parsed._help) {
    Write-Host "Usage: tools [--install]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Check and install terminal tools via WinGet."
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -i, --install   Install missing tools via WinGet"
    Write-Host "  -h, --help      Show this help"
    exit 0
}

# Tool definitions: display name, winget package ID, exe to check
$tools = @(
    # Core
    @{ Name = "git";         Exe = "git.exe";         WinGet = "Git.Git" }
    @{ Name = "gh";          Exe = "gh.exe";          WinGet = "GitHub.cli" }
    @{ Name = "oh-my-posh";  Exe = "oh-my-posh.exe";  WinGet = "JanDeDobbeleer.OhMyPosh" }
    @{ Name = "neovim";      Exe = "nvim.exe";        WinGet = "Neovim.Neovim" }
    @{ Name = "alacritty";   Exe = "alacritty.exe";   WinGet = "Alacritty.Alacritty" }
    @{ Name = "podman";      Exe = "podman.exe";      WinGet = "RedHat.Podman" }
    # CLI replacements
    @{ Name = "fd";          Exe = "fd.exe";          WinGet = "sharkdp.fd" }
    @{ Name = "ripgrep";     Exe = "rg.exe";          WinGet = "BurntSushi.ripgrep.MSVC" }
    @{ Name = "fzf";         Exe = "fzf.exe";         WinGet = "junegunn.fzf" }
    @{ Name = "zoxide";      Exe = "zoxide.exe";      WinGet = "ajeetdsouza.zoxide" }
    @{ Name = "eza";         Exe = "eza.exe";         WinGet = "eza-community.eza" }
    @{ Name = "bat";         Exe = "bat.exe";         WinGet = "sharkdp.bat" }
    @{ Name = "delta";       Exe = "delta.exe";       WinGet = "dandavison.delta" }
    @{ Name = "procs";       Exe = "procs.exe";       WinGet = "dalance.procs" }
    @{ Name = "btop";        Exe = "btop.exe";        WinGet = "aristocratos.btop4win" }
    # Data & text
    @{ Name = "jq";          Exe = "jq.exe";          WinGet = "jqlang.jq" }
    @{ Name = "yq";          Exe = "yq.exe";          WinGet = "MikeFarah.yq" }
    @{ Name = "sqlite";      Exe = "sqlite3.exe";     WinGet = "SQLite.SQLite" }
    @{ Name = "glow";        Exe = "glow.exe";        WinGet = "charmbracelet.glow" }
    # Benchmarking & stats
    @{ Name = "hyperfine";   Exe = "hyperfine.exe";   WinGet = "sharkdp.hyperfine" }
    @{ Name = "tokei";       Exe = "tokei.exe";       WinGet = "XAMPPRocky.tokei" }
)

# Font check (installed via oh-my-posh, not WinGet)
$fontName = "CaskaydiaCove"
$fontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
$fontInstalled = (Get-ChildItem $fontDir -Filter "${fontName}*" -ErrorAction SilentlyContinue).Count -gt 0

$missing = @()
$installed = @()

Write-Host ""
Write-Host "  Terminal Tools Status" -ForegroundColor Cyan
Write-Host "  $("─" * 50)" -ForegroundColor DarkGray

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
        Write-Host "  [OK]  $($tool.Name.PadRight(14))" -ForegroundColor Green -NoNewline
        Write-Host " $display" -ForegroundColor DarkGray
        $installed += $tool
    } else {
        Write-Host "  [  ]  $($tool.Name.PadRight(14))" -ForegroundColor Yellow -NoNewline
        Write-Host " $($tool.WinGet)" -ForegroundColor DarkGray
        $missing += $tool
    }
}

Write-Host "  $("─" * 50)" -ForegroundColor DarkGray

# Font status
if ($fontInstalled) {
    Write-Host "  [OK]  $("$fontName NF".PadRight(14))" -ForegroundColor Green -NoNewline
    Write-Host " oh-my-posh font" -ForegroundColor DarkGray
} else {
    Write-Host "  [  ]  $("$fontName NF".PadRight(14))" -ForegroundColor Yellow -NoNewline
    Write-Host " oh-my-posh font install CascadiaCode" -ForegroundColor DarkGray
}

Write-Host "  $("─" * 50)" -ForegroundColor DarkGray
$totalInstalled = $installed.Count + [int]$fontInstalled
$totalMissing = $missing.Count + [int](-not $fontInstalled)
Write-Host "  $totalInstalled installed, $totalMissing missing" -ForegroundColor DarkGray
Write-Host ""

if ($missing.Count -eq 0 -and $fontInstalled) {
    Write-Host "  All tools installed." -ForegroundColor Green
    Write-Host ""
    exit 0
}

if (-not $parsed.Install) {
    Write-Host "  Run 'tools --install' to install missing tools." -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

# Install missing tools
Write-Host "  Installing missing tools..." -ForegroundColor Cyan
Write-Host ""

foreach ($tool in $missing) {
    Write-Host "  Installing $($tool.Name) ($($tool.WinGet))..." -ForegroundColor Yellow
    winget install -e --id $tool.WinGet --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Installed $($tool.Name)" -ForegroundColor Green
    } else {
        Write-Warning "  Failed to install $($tool.Name)"
    }
    Write-Host ""
}

# Install font if missing
if (-not $fontInstalled) {
    Write-Host "  Installing $fontName Nerd Font via oh-my-posh..." -ForegroundColor Yellow
    oh-my-posh font install CascadiaCode
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Installed $fontName Nerd Font" -ForegroundColor Green
    } else {
        Write-Warning "  Failed to install font. Try manually: oh-my-posh font install CascadiaCode"
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
