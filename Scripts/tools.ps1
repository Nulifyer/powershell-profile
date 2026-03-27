#.ALIAS tools
<#
.SYNOPSIS
    Check and install terminal tools via WinGet.

.DESCRIPTION
    Verifies that all expected CLI tools are installed. Shows status for each
    tool and optionally installs missing ones.

.PARAMETER Install
    Install any missing tools via WinGet.

.EXAMPLE
    tools
    # Show status of all tools

.EXAMPLE
    tools --install
    # Install any missing tools
#>

param(
    [Alias('i')]
    [switch]$Install,

    [Alias('help')]
    [switch]$h
)

if ($h) {
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
    @{ Name = "fd";         Exe = "fd.exe";         WinGet = "sharkdp.fd" }
    @{ Name = "ripgrep";    Exe = "rg.exe";         WinGet = "BurntSushi.ripgrep.MSVC" }
    @{ Name = "fzf";        Exe = "fzf.exe";        WinGet = "junegunn.fzf" }
    @{ Name = "zoxide";     Exe = "zoxide.exe";     WinGet = "ajeetdsouza.zoxide" }
    @{ Name = "eza";        Exe = "eza.exe";        WinGet = "eza-community.eza" }
    @{ Name = "bat";        Exe = "bat.exe";        WinGet = "sharkdp.bat" }
    @{ Name = "delta";      Exe = "delta.exe";      WinGet = "dandavison.delta" }
    @{ Name = "yq";         Exe = "yq.exe";         WinGet = "MikeFarah.yq" }
    @{ Name = "procs";      Exe = "procs.exe";      WinGet = "dalance.procs" }
    @{ Name = "hyperfine";  Exe = "hyperfine.exe";  WinGet = "sharkdp.hyperfine" }
    @{ Name = "tokei";      Exe = "tokei.exe";      WinGet = "XAMPPRocky.tokei" }
    @{ Name = "btop";       Exe = "btop.exe";       WinGet = "aristocratos.btop4win" }
    @{ Name = "glow";       Exe = "glow.exe";       WinGet = "charmbracelet.glow" }
    @{ Name = "jq";         Exe = "jq.exe";         WinGet = "jqlang.jq" }
)

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
Write-Host "  $($installed.Count) installed, $($missing.Count) missing" -ForegroundColor DarkGray
Write-Host ""

if ($missing.Count -eq 0) {
    Write-Host "  All tools installed." -ForegroundColor Green
    Write-Host ""
    exit 0
}

if (-not $Install) {
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

# Clear the winget path cache so profile picks up new tools
$cacheFile = "$env:TEMP\pwsh-profile\winget-tool-paths.txt"
if (Test-Path $cacheFile) {
    Remove-Item $cacheFile -Force
    Write-Host "  Path cache cleared. Restart your shell to pick up new tools." -ForegroundColor Cyan
}
Write-Host ""
