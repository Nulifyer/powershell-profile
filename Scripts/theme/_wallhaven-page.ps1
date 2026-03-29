# Navigate pages — reads state and calls search with next/prev page.
# Usage: _wallhaven-page.ps1 <direction> <query> <apikey>
param(
    [string]$Direction,  # "next" or "prev"
    [string]$Query,
    [string]$ApiKey
)

$stateFile = "$env:USERPROFILE\.config\wallpapers\cache\.browse_state"
$page = 1
$sorting = 'toplist'

if (Test-Path $stateFile) {
    $state = Get-Content $stateFile -Raw | ConvertFrom-Json
    $sorting = $state.sorting
    if ($Direction -eq 'next' -and $state.page -lt $state.last_page) {
        $page = $state.page + 1
    } elseif ($Direction -eq 'prev' -and $state.page -gt 1) {
        $page = $state.page - 1
    } else {
        $page = $state.page
    }
}

& "$PSScriptRoot\_wallhaven-search.ps1" $Query $ApiKey $sorting $page
