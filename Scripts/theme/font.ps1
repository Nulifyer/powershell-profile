#.ALIAS font
#.HELP Usage: font [name] [--list] [--current] [--install]
#.HELP
#.HELP Select terminal font from installed Nerd Fonts, or install new Nerd Fonts.
#.HELP   font            — fzf picker of installed Nerd Fonts
#.HELP   font <name>     — set font directly
#.HELP   font --list     — list installed Nerd Fonts
#.HELP   font --current  — show current font
#.HELP   font --install  — install Nerd Fonts with a native PowerShell picker

. "$PSScriptRoot\..\_lib\ScriptUtils.ps1"
. "$PSScriptRoot\..\_lib\NerdFonts.ps1"
. "$PSScriptRoot\..\_lib\TerminalConfig.ps1"

$parsed = Parse-Args $args @{
    Install = @{ Aliases = @('i', 'install') }
    List    = @{ Aliases = @('l', 'list') }
    Current = @{ Aliases = @('c', 'current') }
}

if ($parsed._help) { Show-Help; exit 0 }

function Require-Fzf {
    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
        Write-Host "fzf is required for interactive font selection." -ForegroundColor Red
        Write-Host "Run 'tools --install' to install it." -ForegroundColor DarkGray
        exit 1
    }
}

function Select-NerdFontAssets {
    param([array]$Catalog)

    Require-Fzf
    $lines = foreach ($font in $Catalog) {
        "$($font.Name)`t$($font.AssetName)`t$($font.SizeMb) MB"
    }

    $selected = $lines | fzf --multi --layout=reverse --border --no-info `
        --delimiter="`t" --with-nth=1,3 `
        --prompt="font install > " `
        --header="TAB toggles, ENTER installs selected fonts (or current font if none selected)" `
        --bind "tab:toggle+down,shift-tab:toggle+up"

    if (-not $selected) { return @() }
    return @($selected | ForEach-Object { ($_ -split "`t", 2)[0] })
}

# Install mode — native PowerShell downloader/installer
if ($parsed.Install) {
    try {
        $catalog = Get-NerdFontCatalog
    } catch {
        Write-Host "Could not fetch Nerd Fonts catalog." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor DarkGray
        exit 1
    }

    if (-not $catalog -or $catalog.Count -eq 0) {
        Write-Host "No Nerd Fonts were returned by the catalog." -ForegroundColor Red
        exit 1
    }

    $selectedNames = Select-NerdFontAssets -Catalog $catalog
    if ($selectedNames.Count -eq 0) {
        Write-Host "No fonts selected." -ForegroundColor Yellow
        exit 0
    }

    $selectedAssets = foreach ($name in $selectedNames) {
        $catalog | Where-Object { $_.Name -eq $name } | Select-Object -First 1
    }

    Write-Host "Installing selected fonts..." -ForegroundColor Cyan
    Write-Host ""

    $installedFamilies = @()
    foreach ($asset in $selectedAssets) {
        if (-not $asset) { continue }

        Write-Host "Installing $($asset.Name)..." -ForegroundColor Yellow
        try {
            $results = Install-NerdFontAsset -FontAsset $asset
            $families = @($results | ForEach-Object { $_.Family } | Where-Object { $_ } | Sort-Object -Unique)
            if ($families.Count -gt 0) {
                Write-Host "Installed: $($families -join ', ')" -ForegroundColor Green
                $installedFamilies += $families
            } else {
                Write-Host "Installed font files for $($asset.Name)." -ForegroundColor Green
            }
        } catch {
            Write-Warning "Failed to install $($asset.Name): $($_.Exception.Message)"
        }
        Write-Host ""
    }

    if ($installedFamilies.Count -gt 0) {
        Write-Host "Run 'font' to select one of the newly installed fonts." -ForegroundColor Cyan
    }
    exit 0
}

# -- Get installed Nerd Fonts -------------------------------------------------
$fontState = Get-InstalledNerdFonts
$allFonts = $fontState.All
$fonts = $fontState.Base

if ($fonts.Count -eq 0) {
    Write-Host "No Nerd Fonts installed." -ForegroundColor Yellow
    Write-Host "Run 'font --install' to install one." -ForegroundColor DarkGray
    exit 0
}

# -- Current font -------------------------------------------------------------

$currentFont = Get-ScriptConfig "font" "face"
if (-not $currentFont) { $currentFont = "CaskaydiaMono NF" }

# -- --current ----------------------------------------------------------------

if ($parsed.Current) {
    Write-Host $currentFont
    exit 0
}

# -- --list -------------------------------------------------------------------

if ($parsed.List) {
    foreach ($f in $fonts) {
        if ($f -eq $currentFont) {
            Write-Host "  * $f" -ForegroundColor Green
        } else {
            Write-Host "    $f"
        }
    }
    exit 0
}

# -- Select font --------------------------------------------------------------

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
        Write-Host "  $("-" * 40)" -ForegroundColor DarkGray
        foreach ($f in $fonts) {
            $marker = if ($f -eq $currentFont) { "*" } else { " " }
            $color = if ($f -eq $currentFont) { "Green" } else { "White" }
            Write-Host "  $marker $f" -ForegroundColor $color
        }
        Write-Host "  $("-" * 40)" -ForegroundColor DarkGray
        Write-Host "  Current: $currentFont" -ForegroundColor DarkGray
        Write-Host "  Usage:   font <name>" -ForegroundColor DarkGray
        Write-Host ""
        exit 0
    }
}

# -- Validate choice ----------------------------------------------------------

if ($choice -notin $allFonts) {
    Write-Host "Font not found: $choice" -ForegroundColor Red
    Write-Host "Installed Nerd Fonts:" -ForegroundColor DarkGray
    $fonts | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
    exit 1
}

# -- Update all terminal emulators --------------------------------------------

$updatedTerminals = Update-TerminalFont $choice
if ($updatedTerminals.Count -gt 0) {
    Write-Host "Updated: $($updatedTerminals -join ', ')" -ForegroundColor DarkGray
}

# -- Save ---------------------------------------------------------------------

Set-ScriptConfig "font" "face" $choice
Write-Host "Font set to: $choice" -ForegroundColor Green
Write-Host "Restart your terminal to apply." -ForegroundColor DarkGray
