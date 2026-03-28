#.ALIAS theme
<#
.SYNOPSIS
    Switch prompt color palette.

.DESCRIPTION
    Changes the prompt color palette and terminal color scheme.
    The chosen palette is saved and persists across sessions.

.EXAMPLE
    theme                        # show current + available palettes
    theme gruvbox                # switch to gruvbox colors
    theme catppuccin_mocha       # switch to catppuccin mocha
#>

. "$PSScriptRoot\..\_lib\ScriptUtils.ps1"
. "$PSScriptRoot\..\_lib\TerminalConfig.ps1"
. "$PSScriptRoot\..\_lib\ThemeData.ps1"

$palettes = $script:palettes
$wtSchemes = $script:wtSchemes

# ── Config ───────────────────────────────────────────────────────────────────

$configKey = "theme"
$currentTheme = Get-ScriptConfig $configKey "palette"
if (-not $currentTheme) { $currentTheme = "catppuccin_mocha" }

$parsed = Parse-Args $args @{}
$choice = $parsed._positional | Select-Object -First 1

# ── No args: show current + list ─────────────────────────────────────────────

function _hex2rgb([string]$hex) {
    $r = [Convert]::ToInt32($hex.Substring(1,2),16)
    $g = [Convert]::ToInt32($hex.Substring(3,2),16)
    $b = [Convert]::ToInt32($hex.Substring(5,2),16)
    return "$r;$g;$b"
}

function _swatch([hashtable]$p) {
    $b = _hex2rgb $p.blue; $pk = _hex2rgb $p.pink; $l = _hex2rgb $p.lavender
    return "`e[38;2;${b}m●`e[0m `e[38;2;${pk}m●`e[0m `e[38;2;${l}m●`e[0m"
}

function _preview([string]$name, [hashtable]$p) {
    $os = _hex2rgb $p.os; $bl = _hex2rgb $p.blue; $pk = _hex2rgb $p.pink; $lv = _hex2rgb $p.lavender
    $r = "`e[0m"
    $lines = @(
        ""
        "  `e[38;2;${os}m$name`e[0m"
        "  $("─" * 44)"
        ""
        "  `e[38;2;${os}m`e[0m `e[38;2;${bl}m$env:USERNAME@$env:COMPUTERNAME`e[0m `e[38;2;${pk}m~/Projects/my-app`e[0m `e[38;2;${lv}m main`e[0m `e[38;2;${os}m`e[0m"
        ""
        "  `e[1mColors:`e[0m"
        "  `e[38;2;${os}m████`e[0m os        $($p.os)"
        "  `e[38;2;${bl}m████`e[0m blue      $($p.blue)   (user@host)"
        "  `e[38;2;${pk}m████`e[0m pink      $($p.pink)   (path)"
        "  `e[38;2;${lv}m████`e[0m lavender  $($p.lavender)   (git)"
    )
    return $lines -join "`n"
}

if (-not $choice) {
    $hasFzf = Get-Command fzf -ErrorAction SilentlyContinue
    if ($hasFzf) {
        # Write palette data to temp file for the preview script
        $previewData = "$env:TEMP\pwsh-profile\theme-palettes.txt"
        $paletteLines = @()
        foreach ($name in $palettes.Keys) {
            $p = $palettes[$name]
            $paletteLines += "$name|$($p.bg)|$($p.os)|$($p.blue)|$($p.pink)|$($p.lavender)"
        }
        $paletteLines | Set-Content $previewData -Encoding UTF8

        # Preview command calls the separate preview script — {1} is the hidden theme name field
        $previewScript = "$PSScriptRoot\theme-preview.ps1"
        $previewCmd = "pwsh -NoProfile -File `"$previewScript`" {1} `"$previewData`" `"$env:USERNAME`" `"$env:COMPUTERNAME`""

        # Build fzf input lines: "name<TAB>swatches marker name" — fzf shows field 2+ via --with-nth
        $lines = @()
        foreach ($name in $palettes.Keys) {
            $swatch = _swatch $palettes[$name]
            $marker = if ($name -eq $currentTheme) { " *" } else { "  " }
            $lines += "$name`t$swatch$marker $name"
        }

        # Enter alt buffer, run fzf, exit alt buffer
        Write-Host "`e[?1049h" -NoNewline
        try {
            $selected = $lines | fzf --ansi --no-sort `
                --delimiter="`t" `
                --with-nth=2.. `
                --header="Current: $currentTheme  |  ESC to cancel" `
                --prompt="theme> " `
                --reverse `
                --preview="$previewCmd" `
                --preview-window="right:50%:wrap" `
                --no-scrollbar
        } finally {
            Write-Host "`e[?1049l" -NoNewline
        }

        if ($selected) {
            # Extract theme name (first tab-delimited field)
            $choice = $selected.Split("`t")[0]
        } else {
            exit 0
        }
    } else {
        # Fallback: plain list
        Write-Host ""
        Write-Host "  Prompt Palette" -ForegroundColor Cyan
        Write-Host "  $("─" * 40)" -ForegroundColor DarkGray
        foreach ($name in $palettes.Keys) {
            $swatch = _swatch $palettes[$name]
            $marker = if ($name -eq $currentTheme) { "*" } else { " " }
            $color = if ($name -eq $currentTheme) { "Green" } else { "White" }
            Write-Host "  $marker $swatch " -NoNewline
            Write-Host "$name" -ForegroundColor $color
        }
        Write-Host "  $("─" * 40)" -ForegroundColor DarkGray
        Write-Host "  Current: $currentTheme" -ForegroundColor DarkGray
        Write-Host "  Usage:   theme <name>" -ForegroundColor DarkGray
        Write-Host ""
        exit 0
    }
}

# ── Set palette ──────────────────────────────────────────────────────────────

if (-not $palettes.Contains($choice)) {
    Write-Host "Unknown palette: $choice" -ForegroundColor Red
    Write-Host "Available: $($palettes.Keys -join ', ')" -ForegroundColor DarkGray
    exit 1
}

# Save choice
Set-ScriptConfig $configKey "palette" $choice

# ── Update everything ───────────────────────────────────────────────────────

$scheme = $wtSchemes[$choice]
if ($scheme) {
    $updated = @()

    # Terminal emulators
    $updated += Update-TerminalColors $scheme

    # VS Code theme
    try { Update-VSCodeTheme $scheme $choice; $updated += "VS Code" } catch {}

    # File Pilot
    try { if (Update-FilePilotTheme $scheme $choice) { $updated += "File Pilot" } } catch {}

    # Windows system (dark/light mode + accent color)
    try { Update-WindowsTheme $scheme $choice; $updated += "Windows" } catch {}

    # Re-theme active wallpaper (if set)
    try { Update-Wallpaper $choice $scheme } catch {}

    if ($updated.Count -gt 0) {
        Write-Host "Updated: $($updated -join ', ')" -ForegroundColor DarkGray
    }
}

Write-Host "Switched to $choice" -ForegroundColor Green
