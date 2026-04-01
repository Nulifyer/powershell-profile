#.ALIAS theme
#.HELP Usage: theme [name] [--list] [--current]
#.HELP
#.HELP Switch color theme across terminal emulators, VS Code, browsers, and Windows.
#.HELP   theme            — fzf picker with preview
#.HELP   theme <name>     — apply theme directly
#.HELP   theme --list     — list available themes
#.HELP   theme --current  — show current theme

. "$PSScriptRoot\..\_lib\ScriptUtils.ps1"
. "$PSScriptRoot\..\_lib\TerminalConfig.ps1"
. "$PSScriptRoot\..\_lib\ThemeData.ps1"

# ── Config ───────────────────────────────────────────────────────────────────

$configKey = "theme"
$currentTheme = Get-ScriptConfig $configKey "palette"
if (-not $currentTheme) { $currentTheme = "catppuccin_mocha" }

$parsed = Parse-Args $args @{
    List    = @{ Aliases = @('l', 'list') }
    Current = @{ Aliases = @('c', 'current') }
}
$choice = $parsed._positional | Select-Object -First 1

if ($parsed._help) { Show-Help; exit 0 }

# ── Helpers ─────────────────────────────────────────────────────────────────

function _hex2rgb([string]$hex) {
    $r = [Convert]::ToInt32($hex.Substring(1,2),16)
    $g = [Convert]::ToInt32($hex.Substring(3,2),16)
    $b = [Convert]::ToInt32($hex.Substring(5,2),16)
    return "$r;$g;$b"
}

function _swatch([hashtable]$t) {
    $uh = _hex2rgb $t.userhost; $pa = _hex2rgb $t.path; $g = _hex2rgb $t.git
    return "`e[38;2;${uh}m●`e[0m `e[38;2;${pa}m●`e[0m `e[38;2;${g}m●`e[0m"
}

# ── --list ───────────────────────────────────────────────────────────────────

if ($parsed.List) {
    $themes = Get-Themes
    foreach ($name in $themes.Keys) {
        $swatch = _swatch $themes[$name]
        if ($name -eq $currentTheme) {
            Write-Host "  * $swatch $name" -ForegroundColor Green
        } else {
            Write-Host "    $swatch $name"
        }
    }
    exit 0
}

# ── --current ────────────────────────────────────────────────────────────────

if ($parsed.Current) {
    Write-Host $currentTheme
    exit 0
}

# ── No args: fzf picker ─────────────────────────────────────────────────────

if (-not $choice) {
    $themes = Get-Themes
    $hasFzf = Get-Command fzf -ErrorAction SilentlyContinue
    if ($hasFzf) {
        # Write palette data to temp file for the preview script
        $previewData = "$env:TEMP\pwsh-profile\theme-palettes.txt"
        $paletteLines = @()
        foreach ($name in $themes.Keys) {
            $t = $themes[$name]
            $ansi16 = "$($t.black)|$($t.red)|$($t.green)|$($t.yellow)|$($t.blue)|$($t.purple)|$($t.cyan)|$($t.white)" +
                "|$($t.brightBlack)|$($t.brightRed)|$($t.brightGreen)|$($t.brightYellow)|$($t.brightBlue)|$($t.brightPurple)|$($t.brightCyan)|$($t.brightWhite)"
            $paletteLines += "$name|$($t.bg)|$($t.muted)|$($t.userhost)|$($t.path)|$($t.git)|$ansi16"
        }
        $paletteLines | Set-Content $previewData -Encoding UTF8

        # Preview command calls the separate preview script — {1} is the hidden theme name field
        $previewScript = "$PSScriptRoot\theme-preview.ps1"
        $previewCmd = "pwsh -NoProfile -File `"$previewScript`" {1} `"$previewData`" `"$env:USERNAME`" `"$env:COMPUTERNAME`""

        # Build fzf input lines: "name<TAB>swatches marker name" — fzf shows field 2+ via --with-nth
        $lines = @()
        foreach ($name in $themes.Keys) {
            $swatch = _swatch $themes[$name]
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
        foreach ($name in $themes.Keys) {
            $swatch = _swatch $themes[$name]
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

$theme = Get-Theme $choice
if (-not $theme) {
    Write-Host "Unknown palette: $choice" -ForegroundColor Red
    Write-Host "Available: $((Get-Themes).Keys -join ', ')" -ForegroundColor DarkGray
    exit 1
}

# Save choice
Set-ScriptConfig $configKey "palette" $choice

# ── Update everything ───────────────────────────────────────────────────────

$updated = @()

# Terminal emulators
$updated += Update-TerminalColors $theme

# VS Code theme
try { Update-VSCodeTheme $theme $choice; $updated += "VS Code" } catch {}

# File Pilot
try { if (Update-FilePilotTheme $theme $choice) { $updated += "File Pilot" } } catch {}

# Browsers (Chromium-based via BrowserThemeColor policy)
try { $updated += Update-BrowserTheme $theme } catch {}

# Windows system (dark/light mode + accent color)
try { Update-WindowsTheme $theme $choice; $updated += "Windows" } catch {}

# Karchy launcher
try { if (Update-KarchyTheme $choice) { $updated += "Karchy" } } catch {}

# Re-theme active wallpaper (if set)
try { Update-Wallpaper $choice $theme } catch {}

if ($updated.Count -gt 0) {
    Write-Host "Updated: $($updated -join ', ')" -ForegroundColor DarkGray
}

# Update prompt colors in current session
if ($global:_c) {
    $_e = [char]27
    function _hex2ansi([string]$h) {
        $r = [Convert]::ToInt32($h.Substring(1,2),16)
        $g = [Convert]::ToInt32($h.Substring(3,2),16)
        $b = [Convert]::ToInt32($h.Substring(5,2),16)
        return "$_e[38;2;${r};${g};${b}m"
    }
    $global:_c.muted    = _hex2ansi $theme.muted
    $global:_c.userhost = _hex2ansi $theme.userhost
    $global:_c.path     = _hex2ansi $theme.path
    $global:_c.git      = _hex2ansi $theme.git
}

Write-Host "Switched to $choice" -ForegroundColor Green
