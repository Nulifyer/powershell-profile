# Helper script called by fzf reload to search Wallhaven and output fzf lines.
# Usage: _wallhaven-search.ps1 <query> <apikey> <sorting> [page]
param(
    [string]$Query,
    [string]$ApiKey,
    [string]$Sorting = 'toplist',
    [int]$Page = 1
)

$thumbDir = "$env:USERPROFILE\.config\wallpapers\cache\thumbs"
New-Item -ItemType Directory -Path $thumbDir -Force | Out-Null

$params = [ordered]@{ categories = '100'; purity = '100'; page = "$Page" }
if ($Query) {
    $params.q = $Query
    $params.atleast = '1920x1080'
} else {
    $params.atleast = '3840x1600'
    $params.ratios = '21x9'
}
$params.sorting = $Sorting
if ($Sorting -eq 'toplist') { $params.topRange = '1M' }
if ($ApiKey) { $params.apikey = $ApiKey; $params.purity = '110' }

$qs = ($params.GetEnumerator() | ForEach-Object { "$($_.Key)=$([uri]::EscapeDataString($_.Value))" }) -join '&'
$url = "https://wallhaven.cc/api/v1/search?$qs"

try {
    $response = Invoke-RestMethod -Uri $url -TimeoutSec 15
} catch {
    exit 0
}

# Save state for paging
$stateFile = "$env:USERPROFILE\.config\wallpapers\cache\.browse_state"
@{ page = $Page; last_page = $response.meta.last_page; total = $response.meta.total; sorting = $Sorting } |
    ConvertTo-Json | Set-Content $stateFile -Encoding utf8

foreach ($wp in $response.data) {
    $thumbUrl = $wp.thumbs.large
    $fileName = [System.IO.Path]::GetFileName(([uri]$thumbUrl).LocalPath)
    $destPath = Join-Path $thumbDir $fileName
    if (-not (Test-Path $destPath)) {
        try { Invoke-WebRequest -Uri $thumbUrl -OutFile $destPath -TimeoutSec 10 } catch {}
    }
    Write-Output "${fileName}::  $($wp.resolution)  fav:$($wp.favorites)  [$($wp.category)]  $($wp.id)"
}
