# Query execution — DataAdapter for small results, DataReader streaming for large

function Invoke-SqlQuery {
    param(
        [string]$Server, [string]$Database, [string]$Query,
        [string]$User, [string]$Password
    )
    $connStr = Build-ConnString -Server $Server -Database $Database -User $User -Password $Password `
        -Driver $script:activeDriver -OdbcDriver $script:activeOdbcDriver -Port $script:activePort -Dsn $script:activeDsn
    $conn = New-SqlConnection -ConnectionString $connStr
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = $Query
    $cmd.CommandTimeout = 300
    $adapter = $null
    try {
        $conn.Open()
        if ($script:activeDriver -eq 'sqlite') {
            $ds = Invoke-SqliteReaderToDataSet -Command $cmd
        } else {
            $adapter = New-SqlDataAdapter -Command $cmd
            $ds = New-Object System.Data.DataSet
            $adapter.Fill($ds) | Out-Null
        }
        return , @($ds.Tables)
    } finally {
        if ($adapter) { $adapter.Dispose() }
        $cmd.Dispose()
        if ($conn.State -ne [System.Data.ConnectionState]::Closed) { $conn.Close() }
        $conn.Dispose()
    }
}

function Invoke-SqlQueryToFile {
    param(
        [string]$Server, [string]$Database, [string]$Query,
        [string]$User, [string]$Password,
        [string]$OutFile,
        [int]$MaxRows = 0,
        [switch]$Csv
    )
    $connStr = Build-ConnString -Server $Server -Database $Database -User $User -Password $Password `
        -Driver $script:activeDriver -OdbcDriver $script:activeOdbcDriver -Port $script:activePort -Dsn $script:activeDsn
    $conn = New-SqlConnection -ConnectionString $connStr
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = $Query
    $cmd.CommandTimeout = 300
    $reader = $null
    $rowCount = 0

    try {
        $conn.Open()
        $reader = $cmd.ExecuteReader()
        $colCount = $reader.FieldCount
        $colNames = 0..($colCount - 1) | ForEach-Object { $reader.GetName($_) }

        $writer = [System.IO.StreamWriter]::new($OutFile, $false, [System.Text.Encoding]::UTF8)
        try {
            if ($Csv) {
                $writer.WriteLine(($colNames | ForEach-Object { Quote-CsvField $_ }) -join ',')
            } else {
                # First pass: read up to 100 rows to calculate widths
                $buffer = [System.Collections.Generic.List[object[]]]::new()
                $colWidths = @{}
                foreach ($col in $colNames) { $colWidths[$col] = $col.Length }

                while ($reader.Read() -and $buffer.Count -lt 100) {
                    $vals = [object[]]::new($colCount)
                    $reader.GetValues($vals) | Out-Null
                    $buffer.Add($vals)
                    for ($i = 0; $i -lt $colCount; $i++) {
                        $len = "$($vals[$i])".Length
                        if ($len -gt $colWidths[$colNames[$i]]) {
                            $colWidths[$colNames[$i]] = [Math]::Min($len, 40)
                        }
                    }
                }

                # Write header
                $header = ($colNames | ForEach-Object { $_.PadRight($colWidths[$_]) }) -join "  "
                $writer.WriteLine("  $header")
                $sep = ($colNames | ForEach-Object { [string]::new([char]0x2500, $colWidths[$_]) }) -join "  "
                $writer.WriteLine("  $sep")

                # Write buffered rows
                foreach ($vals in $buffer) {
                    $rowStr = (0..($colCount - 1) | ForEach-Object {
                        $val = "$($vals[$_])"
                        if ($val.Length -gt $colWidths[$colNames[$_]]) { $val = $val.Substring(0, $colWidths[$colNames[$_]] - 3) + "..." }
                        $val.PadRight($colWidths[$colNames[$_]])
                    }) -join "  "
                    $writer.WriteLine("  $rowStr")
                    $rowCount++
                }

                # Continue streaming remaining rows
                while ($reader.Read()) {
                    if ($MaxRows -gt 0 -and $rowCount -ge $MaxRows) {
                        $writer.WriteLine("  ... (truncated at $MaxRows rows)")
                        break
                    }
                    $vals = [object[]]::new($colCount)
                    $reader.GetValues($vals) | Out-Null
                    $rowStr = (0..($colCount - 1) | ForEach-Object {
                        $val = "$($vals[$_])"
                        if ($val.Length -gt $colWidths[$colNames[$_]]) { $val = $val.Substring(0, $colWidths[$colNames[$_]] - 3) + "..." }
                        $val.PadRight($colWidths[$colNames[$_]])
                    }) -join "  "
                    $writer.WriteLine("  $rowStr")
                    $rowCount++
                }
            }
        } finally {
            $writer.Close()
        }
    } finally {
        if ($reader) { $reader.Close() }
        $cmd.Dispose()
        if ($conn.State -ne [System.Data.ConnectionState]::Closed) { $conn.Close() }
        $conn.Dispose()
    }
    return $rowCount
}

function Invoke-SqlQueryToCsv {
    param(
        [string]$Server, [string]$Database, [string]$Query,
        [string]$User, [string]$Password,
        [string]$OutFile
    )
    return Invoke-SqlQueryToFile -Server $Server -Database $Database -Query $Query -User $User -Password $Password -OutFile $OutFile -Csv
}
