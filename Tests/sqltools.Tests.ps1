$repoRoot = Split-Path $PSScriptRoot -Parent

. (Join-Path $repoRoot 'Scripts/sqltools/_lib/CsvExport.ps1')
. (Join-Path $repoRoot 'Scripts/sqltools/_lib/SqlText.ps1')
. (Join-Path $repoRoot 'Scripts/sqltools/_lib/SqlConnection.ps1')
. (Join-Path $repoRoot 'Scripts/sqltools/_lib/SqlExecution.ps1')
. (Join-Path $repoRoot 'Scripts/sqltools/_lib/ObjectExplorer.ps1')

$script:activeDriver = 'sqlite'
$script:activeOdbcDriver = $null
$script:activePort = 0
$script:activeDsn = $null

function New-TestSqliteDatabase {
    $dbPath = Join-Path ([System.IO.Path]::GetTempPath()) ("sqltools-test-{0}.db" -f [guid]::NewGuid().ToString('N'))
    $conn = New-DbConnection -ConnectionString (Build-ConnString -Database $dbPath -Driver 'sqlite') -Driver 'sqlite'
    $conn.Open()
    try {
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = @"
CREATE TABLE "order details" (
    "id" INTEGER PRIMARY KEY,
    "line item" TEXT NOT NULL,
    "notes" TEXT NULL
);
INSERT INTO "order details" ("line item", "notes")
VALUES ('widget', 'line one'),
       ('gadget', 'line two, with comma'),
       ('thing', 'multi
line');
"@
        $cmd.ExecuteNonQuery() | Out-Null
        $cmd.Dispose()
    } finally {
        $conn.Close()
        $conn.Dispose()
    }

    return $dbPath
}

Describe 'sqltools text helpers' {
    It 'splits GO batches for non-sqlite drivers' {
        $batches = Split-SqlBatches -Sql "SELECT 1`nGO`nSELECT 2`n`nGO`nSELECT 3" -Driver 'mssql'
        $batches.Count | Should Be 3
        $batches[0].Trim() | Should Be 'SELECT 1'
        $batches[2].Trim() | Should Be 'SELECT 3'
    }

    It 'does not split sqlite scripts on GO' {
        $batches = Split-SqlBatches -Sql "SELECT 1`nGO`nSELECT 2" -Driver 'sqlite'
        $batches.Count | Should Be 1
    }

    It 'quotes identifiers and literals safely' {
        Format-SqlIdentifier -Name 'dbo.order details' -Driver 'mssql' | Should Be '[dbo].[order details]'
        Format-SqlIdentifier -Name 'order details' -Driver 'sqlite' | Should Be '"order details"'
        Quote-SqlLiteral -Value "O'Brien" | Should Be "'O''Brien'"
    }
}

Describe 'sqltools csv export' {
    It 'emits every row in RFC 4180 format' {
        $table = New-Object System.Data.DataTable
        [void]$table.Columns.Add('name')
        [void]$table.Columns.Add('notes')
        [void]$table.Rows.Add('alpha', 'plain')
        [void]$table.Rows.Add('beta', 'needs,quotes')

        $csv = ConvertTo-Rfc4180Csv -Table $table
        $csv.Count | Should Be 3
        $csv[0] | Should Be 'name,notes'
        $csv[2] | Should Be 'beta,"needs,quotes"'
    }
}

Describe 'sqltools sqlite smoke' {
    It 'can query and export a temp sqlite database' {
        if (-not $script:SqliteAvailable) {
            return
        }

        $dbPath = New-TestSqliteDatabase
        $outFile = Join-Path ([System.IO.Path]::GetTempPath()) ("sqltools-export-{0}.csv" -f [guid]::NewGuid().ToString('N'))

        try {
            $tables = Invoke-SqlQuery -Server $dbPath -Database $dbPath -Query 'SELECT "line item", notes FROM "order details" ORDER BY id' -User $null -Password $null
            $tables.Count | Should Be 1
            $tables[0].Rows.Count | Should Be 3

            $rowCount = Invoke-SqlQueryToCsv -Server $dbPath -Database $dbPath -Query 'SELECT "line item", notes FROM "order details" ORDER BY id' -User $null -Password $null -OutFile $outFile
            $rowCount | Should Be 3

            $content = Get-Content $outFile
            $content.Count | Should Be 4
            $content[0] | Should Be '"line item",notes'
            $content[2] | Should Be 'gadget,"line two, with comma"'

            $columns = Get-ColumnsDetailed -Server $dbPath -Database $dbPath -Table 'order details' -User $null -Password $null
            @($columns).Count | Should Be 3

            $count = Get-TableRowCount -Server $dbPath -Database $dbPath -Table 'order details' -User $null -Password $null
            $count | Should Be 3
        } finally {
            Remove-Item $dbPath -Force -ErrorAction SilentlyContinue
            Remove-Item $outFile -Force -ErrorAction SilentlyContinue
        }
    }
}
