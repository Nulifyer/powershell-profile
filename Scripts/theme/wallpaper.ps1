#.ALIAS wallpaper
<#
.SYNOPSIS
    Set a theme-matched wallpaper.

.DESCRIPTION
    Pick a wallpaper and remap its colors to the active theme using lutgen.
    Cached outputs avoid regeneration on repeated theme switches.

.EXAMPLE
    wallpaper                    # pick a wallpaper with fzf
    wallpaper forest.jpg         # set a specific wallpaper
    wallpaper --clear            # stop managing wallpaper
#>

. "$PSScriptRoot\..\_lib\ScriptUtils.ps1"
. "$PSScriptRoot\..\_lib\TerminalConfig.ps1"
. "$PSScriptRoot\..\_lib\ThemeData.ps1"

# ── Args ────────────────────────────────────────────────────────────────────

$parsed = Parse-Args $args @{
    clear = @{ Aliases = @('c'); Type = 'switch' }
}
$choice = $parsed._positional | Select-Object -First 1

# ── Clear ───────────────────────────────────────────────────────────────────

if ($parsed.clear) {
    Set-ScriptConfig "wallpaper" "name" $null
    Write-Host "Wallpaper management cleared" -ForegroundColor DarkGray
    exit 0
}

# ── Ensure originals folder exists ──────────────────────────────────────────

if (-not (Test-Path $script:WP_ORIGINALS)) {
    New-Item -ItemType Directory -Path $script:WP_ORIGINALS -Force | Out-Null
    Write-Host "Created $script:WP_ORIGINALS" -ForegroundColor DarkGray
    Write-Host "Add wallpapers there and run 'wallpaper' again." -ForegroundColor DarkGray
    exit 0
}

$wallpapers = Get-ChildItem $script:WP_ORIGINALS -File | Where-Object { $_.Extension -match '\.(jpg|jpeg|png|webp|bmp)$' }
if ($wallpapers.Count -eq 0) {
    Write-Host "No wallpapers in $script:WP_ORIGINALS" -ForegroundColor Red
    exit 1
}

# ── No args: fzf picker ────────────────────────────────────────────────────

if (-not $choice) {
    $hasFzf = Get-Command fzf -ErrorAction SilentlyContinue
    $hasChafa = Get-Command chafa -ErrorAction SilentlyContinue
    $currentWp = Get-ScriptConfig "wallpaper" "name"

    if ($hasFzf) {
        $previewCmd = if ($hasChafa) {
            "chafa --format sixel --size `$FZF_PREVIEW_COLUMNS`x`$FZF_PREVIEW_LINES `"$script:WP_ORIGINALS\{1}`""
        } else { "" }

        $lines = $wallpapers | ForEach-Object {
            $marker = if ($_.Name -eq $currentWp) { " *" } else { "  " }
            "$($_.Name)`t$marker $($_.Name)"
        }

        $fzfArgs = @(
            "--ansi", "--no-sort",
            "--delimiter=`t", "--with-nth=2..",
            "--header=Current: $(if ($currentWp) { $currentWp } else { 'none' })  |  ESC to cancel",
            "--prompt=wallpaper> ",
            "--reverse", "--no-scrollbar"
        )
        if ($previewCmd) {
            $fzfArgs += @("--preview=$previewCmd", "--preview-window=right:60%:wrap")
        }

        $selected = $lines | fzf @fzfArgs

        if ($selected) {
            $choice = $selected.Split("`t")[0]
        } else {
            exit 0
        }
    } else {
        Write-Host ""
        foreach ($wp in $wallpapers) {
            $marker = if ($wp.Name -eq $currentWp) { "*" } else { " " }
            Write-Host "  $marker $($wp.Name)"
        }
        Write-Host ""
        Write-Host "  Usage: wallpaper <filename>" -ForegroundColor DarkGray
        Write-Host ""
        exit 0
    }
}

# ── Set wallpaper ───────────────────────────────────────────────────────────

$originalPath = "$script:WP_ORIGINALS\$choice"
if (-not (Test-Path $originalPath)) {
    Write-Host "Not found: $choice" -ForegroundColor Red
    exit 1
}

# Save choice
Set-ScriptConfig "wallpaper" "name" $choice

# Apply with current theme colors
$themeName = Get-ScriptConfig "theme" "palette"
if (-not $themeName) { $themeName = "catppuccin_mocha" }

$scheme = $script:wtSchemes[$themeName]
$hasLutgen = Get-Command lutgen -ErrorAction SilentlyContinue

if ($hasLutgen -and $scheme) {
    Write-Host "Applying $themeName palette..." -ForegroundColor DarkGray -NoNewline
    $cachePath = _Apply-ThemeToWallpaper $originalPath $themeName $scheme
    if ($cachePath) {
        [NativeMethods]::SetWallpaper($cachePath)
        Write-Host " done" -ForegroundColor DarkGray
    } else {
        Write-Host " failed" -ForegroundColor Red
        [NativeMethods]::SetWallpaper($originalPath)
    }
} else {
    [NativeMethods]::SetWallpaper($originalPath)
}

Write-Host "Wallpaper set to $choice" -ForegroundColor Green
