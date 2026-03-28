# RFC 4180 CSV export

function Quote-CsvField {
    param([string]$Field)
    if ($Field -match '[,"\r\n]') {
        '"' + ($Field -replace '"', '""') + '"'
    } else {
        $Field
    }
}

function ConvertTo-Rfc4180Csv {
    param([System.Data.DataTable]$Table)
    $lines = [System.Collections.Generic.List[string]]::new()
    $columns = $Table.Columns | ForEach-Object { $_.ColumnName }
    $lines.Add(($columns | ForEach-Object { Quote-CsvField $_ }) -join ',')
    foreach ($row in $Table.Rows) {
        $fields = $columns | ForEach-Object {
            $val = $row[$_]
            if ($val -is [DBNull]) { '' } else { Quote-CsvField "$val" }
        }
        $lines.Add($fields -join ',')
    }
    return $lines
}

function Export-TableToCsv {
    param([System.Data.DataTable]$Table, [string]$Path)
    $csv = ConvertTo-Rfc4180Csv -Table $Table
    $csv | Set-Content -Path $Path -Encoding UTF8
}
