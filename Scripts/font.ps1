#.ALIAS font
<#
.SYNOPSIS
    Select terminal font from installed Nerd Fonts.

.DESCRIPTION
    Lists installed Nerd Fonts, lets you pick one with fzf, then updates
    the Windows Terminal fragment and Alacritty config.

.EXAMPLE
    font                   # pick a font with fzf
    font --install         # install a new Nerd Font via oh-my-posh
    font "CaskaydiaMono NF"  # set font directly
#>

. "$PSScriptRoot\ScriptUtils.ps1"
. "$PSScriptRoot\lib\TerminalConfig.ps1"

$parsed = Parse-Args $args @{
    Install = @{ Aliases = @('i', 'install') }
}

if ($parsed._help) {
    Write-Host "Usage: font [name] [--install]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Select terminal font from installed Nerd Fonts."
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -i, --install   Install a new Nerd Font via oh-my-posh"
    Write-Host "  -h, --help      Show this help"
    exit 0
}

# Install mode — hand off to oh-my-posh interactive installer
if ($parsed.Install) {
    oh-my-posh font install
    Write-Host ""
    Write-Host "Run 'font' to select the installed font." -ForegroundColor Cyan
    exit 0
}

# ── Get installed Nerd Fonts ─────────────────────────────────────────────────

Add-Type -AssemblyName System.Drawing
$allFonts = (New-Object System.Drawing.Text.InstalledFontCollection).Families |
    Where-Object { $_.Name -match 'Nerd|NF' } |
    Select-Object -ExpandProperty Name |
    Sort-Object

# Filter to base weights only (skip ExtraLight, Light, SemiBold, SemiLight variants)
$fonts = $allFonts | Where-Object { $_ -notmatch '(ExtraLight|Light|SemiBold|SemiLight)$' }

if ($fonts.Count -eq 0) {
    Write-Host "No Nerd Fonts installed." -ForegroundColor Yellow
    Write-Host "Run 'font --install' to install one." -ForegroundColor DarkGray
    exit 0
}

# ── Current font ─────────────────────────────────────────────────────────────

$currentFont = Get-ScriptConfig "font" "face"
if (-not $currentFont) {
    # Read from WT fragment as default
    $fragmentPath = "$PSScriptRoot\..\windows-terminal-fragment.json"
    if (Test-Path $fragmentPath) {
        try {
            $fragment = Get-Content $fragmentPath -Raw | ConvertFrom-Json
            $currentFont = $fragment.profiles[0].font.face
        } catch {}
    }
}
if (-not $currentFont) { $currentFont = "CaskaydiaMono NF" }

# ── Select font ──────────────────────────────────────────────────────────────

$choice = $parsed._positional | Select-Object -First 1

if (-not $choice) {
    $hasFzf = Get-Command fzf -ErrorAction SilentlyContinue
    if ($hasFzf) {
        # Build lines with current marker
        $lines = @()
        foreach ($f in $fonts) {
            $marker = if ($f -eq $currentFont) { " * " } else { "   " }
            $lines += "$marker$f"
        }

        # Preview script is a separate file so $([char]0x...) expressions are evaluated at runtime
        $previewScript = "$PSScriptRoot\font-preview.ps1"
        $previewCmd = "pwsh -NoProfile -File `"$previewScript`" {}"

        Write-Host "`e[?1049h" -NoNewline
        try {
            $selected = $lines | fzf --no-sort `
                --header="Current: $currentFont  |  ESC to cancel" `
                --prompt="font> " `
                --reverse `
                --preview="$previewCmd" `
                --preview-window="right:45%:wrap" `
                --no-scrollbar
        } finally {
            Write-Host "`e[?1049l" -NoNewline
        }

        if ($selected) {
            $choice = $selected.Trim().TrimStart('*').Trim()
        } else {
            exit 0
        }
    } else {
        # Fallback: plain list
        Write-Host ""
        Write-Host "  Installed Nerd Fonts" -ForegroundColor Cyan
        Write-Host "  $("─" * 40)" -ForegroundColor DarkGray
        foreach ($f in $fonts) {
            $marker = if ($f -eq $currentFont) { "*" } else { " " }
            $color = if ($f -eq $currentFont) { "Green" } else { "White" }
            Write-Host "  $marker $f" -ForegroundColor $color
        }
        Write-Host "  $("─" * 40)" -ForegroundColor DarkGray
        Write-Host "  Current: $currentFont" -ForegroundColor DarkGray
        Write-Host "  Usage:   font <name>" -ForegroundColor DarkGray
        Write-Host ""
        exit 0
    }
}

# ── Validate choice ──────────────────────────────────────────────────────────

if ($choice -notin $allFonts) {
    Write-Host "Font not found: $choice" -ForegroundColor Red
    Write-Host "Installed Nerd Fonts:" -ForegroundColor DarkGray
    $fonts | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
    exit 1
}

# ── Update all terminal emulators ────────────────────────────────────────────

$updatedTerminals = Update-TerminalFont $choice
if ($updatedTerminals.Count -gt 0) {
    Write-Host "Updated: $($updatedTerminals -join ', ')" -ForegroundColor DarkGray
}

# ── Save ─────────────────────────────────────────────────────────────────────

Set-ScriptConfig "font" "face" $choice
Write-Host "Font set to: $choice" -ForegroundColor Green
Write-Host "Restart your terminal to apply." -ForegroundColor DarkGray
