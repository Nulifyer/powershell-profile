#.ALIAS wallpaper
<#
.SYNOPSIS
    Set a theme-matched wallpaper.

.DESCRIPTION
    Pick a wallpaper and remap its colors to the active theme using lutgen.
    Cached outputs avoid regeneration on repeated theme switches.
    Browse Wallhaven for new wallpapers filtered to your monitor resolution.

.EXAMPLE
    wallpaper                    # pick a wallpaper with fzf
    wallpaper forest.jpg         # set a specific wallpaper
    wallpaper --clear            # stop managing wallpaper
    wallpaper browse             # browse top wallpapers on Wallhaven
    wallpaper browse mountains   # search Wallhaven for "mountains"
    wallpaper browse -s toplist  # sort by most popular
    wallpaper browse -r 16x9    # override aspect ratio filter
    wallpaper browse --apikey X  # save API key for future use
#>

. "$PSScriptRoot\..\_lib\ScriptUtils.ps1"
. "$PSScriptRoot\..\_lib\TerminalConfig.ps1"
. "$PSScriptRoot\..\_lib\ThemeData.ps1"

$c = Get-Colors

# ── Helpers ─────────────────────────────────────────────────────────────────

function _Set-SelectedWallpaper([string]$originalPath, [string]$displayName) {
    Set-ScriptConfig "wallpaper" "name" ([System.IO.Path]::GetFileName($originalPath))

    $themeName = Get-ScriptConfig "theme" "palette"
    if (-not $themeName) { $themeName = "catppuccin_mocha" }

    $scheme = $script:wtSchemes[$themeName]
    $hasLutgen = Get-Command lutgen -ErrorAction SilentlyContinue

    if ($hasLutgen -and $scheme) {
        Write-Host "$($c.dim)Applying $themeName palette...$($c.reset)" -NoNewline
        $cachePath = _Apply-ThemeToWallpaper $originalPath $themeName $scheme
        if ($cachePath) {
            [NativeMethods]::SetWallpaper($cachePath)
            try { Set-LockScreen $cachePath } catch {}
            Write-Host "$($c.dim) done$($c.reset)"
        } else {
            Write-Host " $($c.red)failed$($c.reset)"
            [NativeMethods]::SetWallpaper($originalPath)
            try { Set-LockScreen $originalPath } catch {}
        }
    } else {
        [NativeMethods]::SetWallpaper($originalPath)
        try { Set-LockScreen $originalPath } catch {}
    }

    Write-Host "$($c.green)Wallpaper set to $displayName$($c.reset)"
}

function _Search-Wallhaven {
    param(
        [string]$Query,
        [string]$AtLeast,
        [string]$Ratios,
        [string]$Sorting = 'relevance',
        [int]$Page = 1,
        [string]$ApiKey
    )

    $params = [ordered]@{ categories = '100'; purity = '100'; page = "$Page" }
    if ($Query) {
        $params.q = $Query
        $params.atleast = '1920x1080'
    } else {
        $params.sorting = 'toplist'
        $params.topRange = '1M'
        if ($AtLeast) { $params.atleast = $AtLeast }
        if ($Ratios)  { $params.ratios = $Ratios }
    }
    if ($Sorting -ne 'relevance') { $params.sorting = $Sorting }
    if ($ApiKey) { $params.apikey = $ApiKey; $params.purity = '110' }

    $qs = ($params.GetEnumerator() | ForEach-Object { "$($_.Key)=$([uri]::EscapeDataString($_.Value))" }) -join '&'
    $url = "https://wallhaven.cc/api/v1/search?$qs"
    return Invoke-RestMethod -Uri $url -TimeoutSec 15
}

function _Download-File([string]$Url, [string]$DestDir) {
    $fileName = [System.IO.Path]::GetFileName(([uri]$Url).LocalPath)
    $destPath = Join-Path $DestDir $fileName
    if (-not (Test-Path $destPath)) {
        New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
        Invoke-WebRequest -Uri $Url -OutFile $destPath -TimeoutSec 60
    }
    return $destPath
}

function _Browse-Wallhaven {
    param(
        [string]$Query,
        [string]$RatioOverride,
        [string]$Sorting,
        [string]$ApiKey
    )

    # Require fzf
    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
        Write-Host "$($c.red)fzf is required for browsing. Install: winget install junegunn.fzf$($c.reset)"
        exit 1
    }

    $hasChafa = Get-Command chafa -ErrorAction SilentlyContinue
    if (-not $hasChafa) {
        Write-Host "$($c.dim)Tip: install chafa for thumbnail previews (winget install hpjansson.Chafa)$($c.reset)"
    }

    $thumbDir = "$script:WP_CACHE\thumbs"
    $thumbDirFwd = ($thumbDir -replace '\\', '/')
    $searchScript = ("$PSScriptRoot\_wallhaven-search.ps1" -replace '\\', '/')
    $apiKeyArg = if ($ApiKey) { $ApiKey } else { "" }

    # Initial search
    $defaultSort = if ($Query) { 'relevance' } else { 'toplist' }
    Write-Host "$($c.dim)Searching Wallhaven...$($c.reset)"
    $initialLines = & pwsh -NoProfile -File "$PSScriptRoot\_wallhaven-search.ps1" $Query $ApiKey $defaultSort

    if (-not $initialLines) {
        Write-Host "$($c.yellow)No wallpapers found.$($c.reset)"
        exit 0
    }

    [Console]::Clear()

    # Sort and page reload commands
    $reloadToplist    = "pwsh -NoProfile -File `"$searchScript`" {q} `"$apiKeyArg`" toplist"
    $reloadFavorites  = "pwsh -NoProfile -File `"$searchScript`" {q} `"$apiKeyArg`" favorites"
    $reloadViews      = "pwsh -NoProfile -File `"$searchScript`" {q} `"$apiKeyArg`" views"
    $reloadDateAdded  = "pwsh -NoProfile -File `"$searchScript`" {q} `"$apiKeyArg`" date_added"
    $reloadRandom     = "pwsh -NoProfile -File `"$searchScript`" {q} `"$apiKeyArg`" random"
    $reloadDefault    = "pwsh -NoProfile -File `"$searchScript`" {q} `"$apiKeyArg`" $defaultSort"
    $pageScript = ("$PSScriptRoot\_wallhaven-page.ps1" -replace '\\', '/')
    $reloadNext       = "pwsh -NoProfile -File `"$pageScript`" next {q} `"$apiKeyArg`""
    $reloadPrev       = "pwsh -NoProfile -File `"$pageScript`" prev {q} `"$apiKeyArg`""

    $previewCmd = if ($hasChafa) {
        "chafa -f sixels --polite on --animate off -s %FZF_PREVIEW_COLUMNS%x%FZF_PREVIEW_LINES% $thumbDirFwd/{1}"
    } else { "" }

    $sortHints = "^t󰓒 ^f󰋑 ^e󰈈 ^d󰃭 ^r󰒝 ^n/^p󰁍"
    $fzfArgs = @(
        "--ansi", "--no-sort",
        "--height=-1",
        "--delimiter=::", "--with-nth=2..",
        "--layout=default",
        "--prompt=> ",
        "--no-scrollbar",
        "--disabled",
        "--ghost=type to search wallhaven...",
        "--bind=change:change-border-label( wallhaven | searching... | $sortHints)+reload($reloadDefault)+first",
        "--bind=ctrl-t:change-border-label( wallhaven | 󰓒 toplist | $sortHints)+reload($reloadToplist)+first",
        "--bind=ctrl-f:change-border-label( wallhaven | 󰋑 favorites | $sortHints)+reload($reloadFavorites)+first",
        "--bind=ctrl-e:change-border-label( wallhaven | 󰈈 views | $sortHints)+reload($reloadViews)+first",
        "--bind=ctrl-d:change-border-label( wallhaven | 󰃭 newest | $sortHints)+reload($reloadDateAdded)+first",
        "--bind=ctrl-r:change-border-label( wallhaven | 󰒝 random | $sortHints)+reload($reloadRandom)+first",
        "--bind=ctrl-n:change-border-label( wallhaven | 󰁍 next page... | $sortHints)+reload($reloadNext)+first",
        "--bind=ctrl-p:change-border-label( wallhaven | 󰁍 prev page... | $sortHints)+reload($reloadPrev)+first",
        "--border=rounded",
        "--border-label= wallhaven | $defaultSort | $sortHints",
        "--border-label-pos=0:top",
        "--info=inline-right"
    )
    if ($Query) {
        $fzfArgs += "--query=$Query"
    }
    if ($previewCmd) {
        $fzfArgs += @("--preview=$previewCmd", "--preview-window=right,75%,border-left")
    }

    $selection = $initialLines | fzf @fzfArgs
    if (-not $selection) { exit 0 }

    # Get the wallpaper ID from the selection
    # Selection format: thumbFile::  resolution  fav:N  [category]  id
    $parts = ($selection -split '::')
    $thumbFile = $parts[0]
    $wpId = ($parts[1] -split '\s+' | Where-Object { $_ } | Select-Object -Last 1).Trim()

    # Fetch wallpaper details to get the download URL
    Write-Host "$($c.dim)Fetching wallpaper info...$($c.reset)" -NoNewline
    try {
        $apiUrl = "https://wallhaven.cc/api/v1/w/$wpId"
        if ($ApiKey) { $apiUrl += "?apikey=$ApiKey" }
        $wpInfo = Invoke-RestMethod -Uri $apiUrl -TimeoutSec 15
        $downloadUrl = $wpInfo.data.path
        $resolution = $wpInfo.data.resolution
    } catch {
        Write-Host " $($c.red)failed$($c.reset)"
        exit 1
    }
    Write-Host "$($c.dim) done$($c.reset)"

    # Download full resolution
    Write-Host "$($c.dim)Downloading $resolution...$($c.reset)" -NoNewline
    try {
        New-Item -ItemType Directory -Path $script:WP_ORIGINALS -Force | Out-Null
        $localPath = _Download-File $downloadUrl $script:WP_ORIGINALS
        Write-Host "$($c.dim) done$($c.reset)"
    } catch {
        Write-Host " $($c.red)failed$($c.reset)"
        Write-Host "$($c.red)$($_.Exception.Message)$($c.reset)"
        exit 1
    }

    _Set-SelectedWallpaper $localPath ([System.IO.Path]::GetFileName($localPath))
}

# ── Args ────────────────────────────────────────────────────────────────────

$parsed = Parse-Args $args @{
    clear  = @{ Aliases = @('c', 'clear');           Type = 'switch' }
    ratio  = @{ Aliases = @('r', 'ratio');             Type = 'value'  }
    sort   = @{ Aliases = @('s', 'sort');               Type = 'value'; Default = 'relevance' }
    apikey = @{ Aliases = @('apikey');                   Type = 'value'  }
}

$subcommand = $parsed._positional | Select-Object -First 1

# ── Clear ───────────────────────────────────────────────────────────────────

if ($parsed.clear) {
    Set-ScriptConfig "wallpaper" "name" ""
    Write-Host "$($c.dim)Wallpaper management cleared$($c.reset)"
    exit 0
}

# ── Browse ──────────────────────────────────────────────────────────────────

if ($subcommand -eq 'browse') {
    $browseQuery = ($parsed._positional | Select-Object -Skip 1) -join ' '

    # API key: save if provided, otherwise load from config
    $apiKey = $parsed.apikey
    if ($apiKey) {
        Set-ScriptConfig "wallpaper" "apikey" $apiKey
    } else {
        $apiKey = Get-ScriptConfig "wallpaper" "apikey"
    }

    _Browse-Wallhaven -Query $browseQuery -RatioOverride $parsed.ratio `
        -Sorting $parsed.sort -ApiKey $apiKey
    exit 0
}

# ── Local picker / direct set ──────────────────────────────────────────────

$choice = $subcommand

# Ensure originals folder exists
if (-not (Test-Path $script:WP_ORIGINALS)) {
    New-Item -ItemType Directory -Path $script:WP_ORIGINALS -Force | Out-Null
    Write-Host "$($c.dim)Created $script:WP_ORIGINALS$($c.reset)"
    Write-Host "$($c.dim)Add wallpapers there, or run 'wallpaper browse' to find some.$($c.reset)"
    exit 0
}

$wallpapers = Get-ChildItem $script:WP_ORIGINALS -File | Where-Object { $_.Extension -match '\.(jpg|jpeg|png|webp|bmp)$' }
if ($wallpapers.Count -eq 0) {
    Write-Host "$($c.red)No wallpapers in $script:WP_ORIGINALS$($c.reset)"
    Write-Host "$($c.dim)Run 'wallpaper browse' to find some.$($c.reset)"
    exit 1
}

# No args: fzf picker
if (-not $choice) {
    $hasFzf = Get-Command fzf -ErrorAction SilentlyContinue
    $hasChafa = Get-Command chafa -ErrorAction SilentlyContinue
    $currentWp = Get-ScriptConfig "wallpaper" "name"

    if ($hasFzf) {
        $originalsDirFwd = ($script:WP_ORIGINALS -replace '\\', '/')
        $previewCmd = if ($hasChafa) {
            "chafa -f sixels --polite on --animate off -s %FZF_PREVIEW_COLUMNS%x%FZF_PREVIEW_LINES% $originalsDirFwd/{1}"
        } else { "" }

        $lines = $wallpapers | ForEach-Object {
            $marker = if ($_.Name -eq $currentWp) { "*" } else { " " }
            "$($_.Name)::  $marker $($_.Name)"
        }

        $currentLabel = if ($currentWp) { $currentWp } else { "none" }
        $fzfArgs = @(
            "--ansi", "--no-sort",
            "--height=-1",
            "--delimiter=::", "--with-nth=2..",
            "--layout=default",
            "--prompt=> ",
            "--no-scrollbar",
            "--border=rounded",
            "--header=current: $currentLabel",
            "--header-first",
            "--footer= enter select  |  esc cancel ",
            "--footer-border=none",
            "--info=hidden"
        )
        if ($previewCmd) {
            $fzfArgs += @("--preview=$previewCmd", "--preview-window=right,75%,border-left")
        }

        $selected = $lines | fzf @fzfArgs

        if ($selected) {
            $choice = ($selected -split '::')[0]
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
        Write-Host "  $($c.dim)Usage: wallpaper <filename> | wallpaper browse [query]$($c.reset)"
        Write-Host ""
        exit 0
    }
}

# Set wallpaper
$originalPath = "$script:WP_ORIGINALS\$choice"
if (-not (Test-Path $originalPath)) {
    Write-Host "$($c.red)Not found: $choice$($c.reset)"
    exit 1
}

_Set-SelectedWallpaper $originalPath $choice
