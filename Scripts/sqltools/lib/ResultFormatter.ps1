# Result formatting — terminal-width-aware column layout, type-based alignment

function Format-DataTableToLines {
    param([System.Data.DataTable]$Table, [int]$MaxWidth = 0)

    if ($MaxWidth -le 0) { $MaxWidth = (Get-TermSize).Width - 4 }
    $lines = [System.Collections.Generic.List[string]]::new()

    $columns = $Table.Columns | ForEach-Object { $_.ColumnName }
    $colCount = $columns.Count
    if ($colCount -eq 0) { return $lines }

    # Calculate widths
    $colWidths = [ordered]@{}
    foreach ($col in $columns) {
        $maxDataLen = [Math]::Max($col.Length, 4)
        foreach ($row in $Table.Rows) {
            $val = "$($row[$col])"
            if ($val.Length -gt $maxDataLen) { $maxDataLen = $val.Length }
        }
        $colWidths[$col] = [Math]::Min($maxDataLen, 40)
    }

    # Shrink proportionally if total exceeds terminal width
    $totalWidth = ($colWidths.Values | Measure-Object -Sum).Sum + (($colCount - 1) * 2) + 2
    if ($totalWidth -gt $MaxWidth -and $colCount -gt 1) {
        $available = $MaxWidth - (($colCount - 1) * 2) - 2
        $ratio = $available / ($colWidths.Values | Measure-Object -Sum).Sum
        foreach ($col in $columns) {
            $colWidths[$col] = [Math]::Max([Math]::Floor($colWidths[$col] * $ratio), [Math]::Min($col.Length, 10))
        }
    }

    # Detect numeric columns for right-alignment
    $numericTypes = @('Int16','Int32','Int64','Decimal','Double','Single','Byte','Money','SmallMoney')
    $isNumeric = @{}
    foreach ($col in $Table.Columns) {
        $isNumeric[$col.ColumnName] = $col.DataType.Name -in $numericTypes
    }

    # Header
    $header = ($columns | ForEach-Object {
        if ($isNumeric[$_]) { $_.PadLeft($colWidths[$_]) } else { $_.PadRight($colWidths[$_]) }
    }) -join "  "
    $lines.Add("  $($script:c.green)$header$($script:c.reset)")

    $sep = ($columns | ForEach-Object { [string]::new([char]0x2500, $colWidths[$_]) }) -join "  "
    $lines.Add("  $($script:c.dim)$sep$($script:c.reset)")

    # Rows
    foreach ($row in $Table.Rows) {
        $rowStr = ($columns | ForEach-Object {
            $val = $row[$_]
            $str = if ($val -is [DBNull]) { "$($script:c.dim)<NULL>$($script:c.reset)" }
                   elseif ($val -is [datetime]) { $val.ToString("yyyy-MM-dd HH:mm:ss") }
                   elseif ($val -is [bool]) { if ($val) { "true" } else { "false" } }
                   else { "$val" }

            $w = $colWidths[$_]
            $plain = $str -replace "$([char]27)\[[0-9;]*m", ''
            if ($plain.Length -gt $w) {
                $str = $str.Substring(0, [Math]::Max($w - 3, 0)) + "..."
                $plain = $str -replace "$([char]27)\[[0-9;]*m", ''
            }
            $padLen = $w - $plain.Length
            if ($padLen -lt 0) { $padLen = 0 }
            if ($isNumeric[$_]) { (' ' * $padLen) + $str } else { $str + (' ' * $padLen) }
        }) -join "  "
        $lines.Add("  $rowStr")
    }

    return $lines
}

function Show-ResultsInLess {
    param($Tables, [string]$Query = "")
    $tmpFile = [System.IO.Path]::GetTempFileName()
    try {
        $allLines = [System.Collections.Generic.List[string]]::new()
        $tableIdx = 0
        foreach ($table in $Tables) {
            $tableIdx++
            $rowCount = $table.Rows.Count
            $colCount = $table.Columns.Count
            $allLines.Add("")
            $allLines.Add("  $($script:c.dim)Result ${tableIdx}: ${rowCount} rows x ${colCount} columns$($script:c.reset)")
            if ($rowCount -eq 0) {
                $allLines.Add("  $($script:c.dim)(no results)$($script:c.reset)")
            } else {
                $formatted = Format-DataTableToLines -Table $table
                foreach ($fl in $formatted) { $allLines.Add($fl) }
            }
            $allLines.Add("")
        }
        $allLines | Set-Content $tmpFile -Encoding UTF8
        less -RS $tmpFile
    } finally {
        Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
    }
}

function Show-PostResultActions {
    param($Tables)
    $actions = @("Back to menu", "Export to CSV", "Copy to clipboard")
    $action = Invoke-Fzf -Items $actions -Header "What next?" -Prompt "Action > " -HeightPercent 25
    switch ($action) {
        "Export to CSV" {
            $defaultName = "export_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
            $path = Read-Host "  Save to [$defaultName]"
            if (-not $path) { $path = $defaultName }
            Export-TableToCsv -Table $Tables[0] -Path $path
            Write-Host "  $($script:c.green)Saved $($Tables[0].Rows.Count) rows to $path$($script:c.reset)"
            Read-Host "  Press Enter"
        }
        "Copy to clipboard" {
            $csv = ConvertTo-Rfc4180Csv -Table $Tables[0]
            $csv -join "`r`n" | Set-Clipboard
            Write-Host "  $($script:c.green)Copied $($Tables[0].Rows.Count) rows to clipboard$($script:c.reset)"
            Read-Host "  Press Enter"
        }
    }
}
