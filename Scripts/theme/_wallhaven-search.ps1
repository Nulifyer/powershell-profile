# Helper script called by fzf reload to search Wallhaven and output fzf lines.
# Usage: _wallhaven-search.ps1 <query> [apikey] [pages]
param(
    [string]$Query,
    [string]$ApiKey,
    [int]$Pages = 3
)

$thumbDir = "$env:USERPROFILE\.config\wallpapers\cache\thumbs"
New-Item -ItemType Directory -Path $thumbDir -Force | Out-Null

for ($page = 1; $page -le $Pages; $page++) {
    $params = [ordered]@{ categories = '100'; purity = '100'; page = "$page" }
    if ($Query) {
        $params.q = $Query
        $params.atleast = '1920x1080'
    } else {
        $params.sorting = 'toplist'
        $params.topRange = '1M'
        $params.atleast = '3840x1600'
        $params.ratios = '21x9'
    }
    if ($ApiKey) { $params.apikey = $ApiKey; $params.purity = '110' }

    $qs = ($params.GetEnumerator() | ForEach-Object { "$($_.Key)=$([uri]::EscapeDataString($_.Value))" }) -join '&'
    $url = "https://wallhaven.cc/api/v1/search?$qs"

    try {
        $response = Invoke-RestMethod -Uri $url -TimeoutSec 15
    } catch {
        break
    }

    if ($response.data.Count -eq 0) { break }

    foreach ($wp in $response.data) {
        $thumbUrl = $wp.thumbs.large
        $fileName = [System.IO.Path]::GetFileName(([uri]$thumbUrl).LocalPath)
        $destPath = Join-Path $thumbDir $fileName
        if (-not (Test-Path $destPath)) {
            try { Invoke-WebRequest -Uri $thumbUrl -OutFile $destPath -TimeoutSec 10 } catch {}
        }
        Write-Output "${fileName}::  $($wp.resolution)  fav:$($wp.favorites)  [$($wp.category)]  $($wp.id)"
    }

    if ($page -ge $response.meta.last_page) { break }
}
