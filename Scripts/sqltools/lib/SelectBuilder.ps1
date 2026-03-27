# SELECT builder — fzf-based column picker, WHERE, ORDER BY, query generation

function Show-SelectBuilder {
    param([string]$Server, [string]$Database, [string]$User, [string]$Password)

    # Step 1: Pick table
    $tbls = Get-Tables -Server $Server -Database $Database -User $User -Password $Password
    $tableLines = $tbls | ForEach-Object {
        $type = if ($_.TABLE_TYPE -eq 'VIEW') { "[VIEW]" } else { "[TABLE]" }
        "$($type.PadRight(8)) $($_.TableName)"
    }
    $tableSel = Invoke-Fzf -Items $tableLines -Header "Select a table" -Prompt "Table > " -HeightPercent 80
    if (-not $tableSel) { return $null }
    $tableName = ($tableSel -replace '^\[.*?\]\s+', '').Trim()

    # Step 2: Get columns with metadata
    $cols = Get-ColumnsDetailed -Server $Server -Database $Database -Table $tableName -User $User -Password $Password

    # Build display lines for fzf
    $colLines = $cols | ForEach-Object {
        $pk = if ($_.IsPK -eq 'PK') { "[PK] " } else { "     " }
        $typeStr = $_.DATA_TYPE
        if ($_.CHARACTER_MAXIMUM_LENGTH -and $_.CHARACTER_MAXIMUM_LENGTH -ne [DBNull]::Value) {
            $maxLen = if ([int]$_.CHARACTER_MAXIMUM_LENGTH -eq -1) { "max" } else { $_.CHARACTER_MAXIMUM_LENGTH }
            $typeStr += "($maxLen)"
        } elseif ($_.NUMERIC_PRECISION -and $_.NUMERIC_PRECISION -ne [DBNull]::Value -and $_.DATA_TYPE -in 'decimal','numeric') {
            $typeStr += "($($_.NUMERIC_PRECISION),$($_.NUMERIC_SCALE))"
        }
        $nullable = if ($_.IS_NULLABLE -eq 'YES') { "NULL" } else { "NOT NULL" }
        "$pk$($_.COLUMN_NAME.PadRight(30)) $($typeStr.PadRight(20)) $nullable"
    }

    # Step 3: Pick columns (multi-select)
    $selectedCols = Invoke-Fzf -Items $colLines -Header "Select columns (Tab=toggle, Ctrl-A=all, Enter=confirm)" -Prompt "Columns > " -Multi -HeightPercent 80
    if (-not $selectedCols) { return $null }

    # Parse selected column names
    $selectedNames = @($selectedCols) | ForEach-Object {
        ($_ -replace '^\[(PK|  )\]\s*', '').Trim() -replace '\s+.*$', ''
    }

    # Step 4: TOP N
    $topN = Read-Host "  TOP N rows [100]"
    if (-not $topN) { $topN = "100" }
    if ($topN -eq "0" -or $topN -eq "all") { $topN = $null }

    # Step 5: WHERE clause (optional)
    Write-Host "  $($script:c.dim)WHERE clause (optional, leave blank to skip):$($script:c.reset)"
    $where = Read-Host "  WHERE"

    # Step 6: ORDER BY (pick from selected columns)
    $orderCol = Invoke-Fzf -Items (@("(none)") + $selectedNames) -Header "ORDER BY column" -Prompt "Order > " -HeightPercent 40
    $orderBy = $null
    if ($orderCol -and $orderCol -ne "(none)") {
        $orderDir = Invoke-Fzf -Items @("ASC", "DESC") -Header "Direction" -Prompt "> " -HeightPercent 20
        if (-not $orderDir) { $orderDir = "ASC" }
        $orderBy = "$orderCol $orderDir"
    }

    # Step 7: Build query
    $colList = ($selectedNames | ForEach-Object { "[$_]" }) -join ", "
    $query = "SELECT"
    if ($topN) { $query += " TOP $topN" }
    $query += " $colList FROM $tableName"
    if ($where) { $query += " WHERE $where" }
    if ($orderBy) { $query += " ORDER BY $orderBy" }

    # Step 8: Preview and confirm
    Write-Host ""
    Write-Host "  $($script:c.cyan)Generated query:$($script:c.reset)"
    Write-Host "  $($script:c.dim)$query$($script:c.reset)"
    Write-Host ""

    $confirm = Invoke-Fzf -Items @("Execute", "Edit manually", "Copy to clipboard", "Cancel") -Header "Query ready" -Prompt "> " -HeightPercent 30
    switch ($confirm) {
        "Execute" { return $query }
        "Edit manually" {
            Write-Host "  $($script:c.dim)Edit the query (end with ;):$($script:c.reset)"
            Write-Host "  $query"
            $edited = Read-SqlInput
            if ($edited) { return $edited }
        }
        "Copy to clipboard" {
            $query | Set-Clipboard
            Write-Host "  $($script:c.green)Copied to clipboard$($script:c.reset)"
            Read-Host "  Press Enter"
        }
    }
    return $null
}
