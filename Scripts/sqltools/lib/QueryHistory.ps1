# Query history — auto-save, search, re-execute

$script:historyFile = "$PSScriptRoot\..\history.json"
$script:maxHistoryEntries = 500

function Get-QueryHistory {
    if (Test-Path $script:historyFile) {
        $data = Get-Content $script:historyFile -Raw | ConvertFrom-Json
        if ($data.entries) { return @($data.entries) }
    }
    return @()
}

function Add-QueryHistory {
    param(
        [string]$Query, [string]$Server, [string]$Database,
        [int]$RowCount, [int]$DurationMs
    )
    $entries = @(Get-QueryHistory)
    $entries = @([PSCustomObject]@{
        query      = $Query
        server     = $Server
        database   = $Database
        timestamp  = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
        rowCount   = $RowCount
        durationMs = $DurationMs
    }) + $entries

    # Cap at max entries
    if ($entries.Count -gt $script:maxHistoryEntries) {
        $entries = $entries[0..($script:maxHistoryEntries - 1)]
    }

    @{ entries = $entries } | ConvertTo-Json -Depth 3 | Set-Content $script:historyFile -Encoding UTF8
}

function Show-QueryHistoryPicker {
    $entries = Get-QueryHistory
    if ($entries.Count -eq 0) {
        Write-Host "  $($script:c.dim)No query history.$($script:c.reset)"
        Read-Host "  Press Enter"
        return $null
    }

    $lines = $entries | ForEach-Object {
        $q = $_.query -replace '[\r\n]+', ' '
        if ($q.Length -gt 80) { $q = $q.Substring(0, 77) + "..." }
        "$($_.timestamp)  $($_.database.PadRight(20))  $($_.rowCount.ToString().PadLeft(6)) rows  $q"
    }

    $selected = Invoke-Fzf -Items $lines -Header "Query History (newest first)" -Prompt "History > " -HeightPercent 80
    if (-not $selected) { return $null }

    $idx = [array]::IndexOf($lines, $selected)
    if ($idx -ge 0) { return $entries[$idx].query }
    return $null
}
