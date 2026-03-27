#.ALIAS sqltools
#.ALIAS sql
<#
.SYNOPSIS
    Interactive SQL TUI — terminal-native SQL Server client.

.DESCRIPTION
    Browse databases, tables, columns. Run queries with scrollable results.
    Build SELECTs visually with fzf column picker. Export to CSV.
    Supports Windows auth and SQL auth with encrypted password storage.
#>

. "$PSScriptRoot\..\ScriptUtils.ps1"

# Load all lib modules
Get-ChildItem "$PSScriptRoot\lib\*.ps1" | ForEach-Object { . $_.FullName }

$parsed = Parse-Args $args @{
    Server   = @{ Aliases = @('s', 'server');   Type = 'value' }
    Database = @{ Aliases = @('d', 'database'); Type = 'value' }
    User     = @{ Aliases = @('u', 'user');     Type = 'value' }
    Password = @{ Aliases = @('p', 'password'); Type = 'value' }
    Query    = @{ Aliases = @('q', 'query');    Type = 'value' }
    File     = @{ Aliases = @('f', 'file');     Type = 'value' }
    Raw      = @{ Aliases = @('r', 'raw') }
    NoColor  = @{ Aliases = @('nc', 'no-color') }
    Manage   = @{ Aliases = @('m', 'manage') }
}

if ($parsed._help) {
    Show-ScriptHelp -Name "sql" -Usage "[-s server] [-d database] [-u user] [-p pass] [-q query] [-f file] [-m]" `
        -Description "Interactive SQL TUI. Windows auth by default, SQL auth with -u/-p." `
        -Options ([ordered]@{
            "-s, --server <host>"    = "SQL Server host or host\instance"
            "-d, --database <name>"  = "Database name"
            "-u, --user <login>"     = "SQL auth username (omit for Windows auth)"
            "-p, --password <pass>"  = "SQL auth password"
            "-q, --query <sql>"      = "Execute query and exit"
            "-f, --file <path.sql>"  = "Execute a .sql file"
            "-r, --raw"              = "Output as RFC 4180 CSV"
            "-nc, --no-color"        = "Disable colored output"
            "-m, --manage"           = "Manage saved connections"
            "-h, --help"             = "Show this help"
        }) `
        -Examples @(
            "sql                                            # Interactive TUI",
            "sql -s sql01 -d Inventory                      # Windows auth",
            "sql -s localhost -d mydb -u sa -p Pass1234     # SQL auth",
            "sql -q `"SELECT * FROM Users`" -r > out.csv    # Export CSV",
            "sql -f report.sql                              # Run .sql file"
        )
    exit 0
}

$ErrorActionPreference = 'Stop'
$script:c = Get-Colors -Disabled:$parsed.NoColor
$script:bookmarkFile = "$PSScriptRoot\connections.json"

# Migrate any plaintext passwords to DPAPI on first run
Migrate-PlaintextPasswords

# ─── Manage Bookmarks ─────────────────────────────────────────────────────────

if ($parsed.Manage) {
    Show-ManageBookmarks
    exit 0
}

# ─── Resolve Connection ───────────────────────────────────────────────────────

$Server = $parsed.Server
$Database = $parsed.Database
$User = $parsed.User
$Password = $parsed.Password

function Resolve-Connection {
    if ($script:Server -and $script:Database) {
        Save-Bookmark -Server $script:Server -Database $script:Database -User $script:User -Password $script:Password -Driver $script:activeDriver -OdbcDriver $script:activeOdbcDriver -Port $script:activePort -Dsn $script:activeDsn -SavePassword:([bool]$script:Password)
        return
    }
    # Try last bookmark for -q mode
    if ($parsed.Query -or $parsed.File) {
        $bookmarks = @(Get-Bookmarks)
        if ($bookmarks.Count -gt 0) {
            $last = $bookmarks[-1]
            if (-not $script:Server) { $script:Server = $last.Server }
            if (-not $script:Database) { $script:Database = $last.Database }
            if (-not $script:User -and $last.User) {
                $script:User = $last.User
                $script:Password = Decrypt-Password $last.EncryptedPassword
                if (-not $script:Password) { $script:Password = Read-Host "Password for $($script:User)" }
            }
            return
        }
        Write-Host "No server/database specified and no saved connections." -ForegroundColor Red
        exit 1
    }
    # Interactive picker
    $conn = Show-ConnectionPicker
    if (-not $conn) { exit 0 }
    $script:Server = $conn.Server
    $script:Database = $conn.Database
    $script:User = $conn.User
    $script:Password = $conn.Password
    $script:activeDriver = if ($conn.Driver) { $conn.Driver } else { 'mssql' }
    $script:activeOdbcDriver = $conn.OdbcDriver
    $script:activePort = $conn.Port
    $script:activeDsn = $conn.Dsn
}

# Initialize driver defaults
$script:activeDriver = 'mssql'
$script:activeOdbcDriver = $null
$script:activePort = 0
$script:activeDsn = $null

Resolve-Connection

# ─── Non-Interactive Modes ────────────────────────────────────────────────────

# Run a .sql file
if ($parsed.File) {
    if (-not (Test-Path $parsed.File)) { Write-Error "File not found: $($parsed.File)"; exit 1 }
    $sql = Get-Content $parsed.File -Raw
    # Split on GO batch separator
    $batches = $sql -split '(?mi)^\s*GO\s*$' | Where-Object { $_.Trim() }
    foreach ($batch in $batches) {
        $tables = Invoke-SqlQuery -Server $Server -Database $Database -Query $batch -User $User -Password $Password
        if ($parsed.Raw) {
            foreach ($t in $tables) { (ConvertTo-Rfc4180Csv -Table $t) -join "`n" }
        } else {
            foreach ($t in $tables) {
                if ($t.Rows.Count -gt 0) {
                    $lines = Format-DataTableToLines -Table $t
                    $lines | ForEach-Object { Write-Host $_ }
                }
            }
        }
    }
    exit 0
}

# Direct query
if ($parsed.Query) {
    $tables = Invoke-SqlQuery -Server $Server -Database $Database -Query $parsed.Query -User $User -Password $Password
    if ($parsed.Raw) {
        foreach ($t in $tables) { (ConvertTo-Rfc4180Csv -Table $t) -join "`n" }
    } else {
        Write-Host ""
        Write-Host "  $($c.cyan)$Server$($c.reset) / $($c.bold)$Database$($c.reset)"
        foreach ($t in $tables) {
            if ($t.Rows.Count -eq 0) { Write-Host "  $($c.dim)(no results)$($c.reset)"; continue }
            $lines = Format-DataTableToLines -Table $t
            $lines | ForEach-Object { Write-Host $_ }
        }
        Write-Host ""
    }
    exit 0
}

# ─── Interactive TUI ──────────────────────────────────────────────────────────

Require-Fzf
Enter-AltScreen
try {
    while ($true) {
        Clear-Host
        Write-Host ""
        $drvLabel = if ($script:activeDriver -ne 'mssql') { "[$($script:activeDriver)] " } else { "" }
        $authLabel = if ($User) { $User } else { 'Windows Auth' }
        Write-StatusBar "  SQL: ${drvLabel}$Server / $Database" "$authLabel  "
        Write-Host ""

        $actions = @(
            "  Run Query",
            "  SELECT Builder",
            "  Query History",
            "  Browse Tables",
            "  Browse Objects",
            "  Switch Database",
            "  Switch Connection",
            "  Exit"
        )

        $action = Invoke-Fzf -Items $actions -Header "$Server / $Database" -Prompt "Action > " -HeightPercent 50
        if (-not $action) { Exit-AltScreen; exit 0 }

        switch -Wildcard ($action) {
            "*Run Query*" {
                $query = Read-SqlInput
                if ($query) {
                    try {
                        Write-Host "  $($c.dim)Executing...$($c.reset)"
                        $sw = [System.Diagnostics.Stopwatch]::StartNew()
                        $tables = Invoke-SqlQuery -Server $Server -Database $Database -Query $query -User $User -Password $Password
                        $sw.Stop()
                        $rowCount = ($tables | ForEach-Object { $_.Rows.Count } | Measure-Object -Sum).Sum
                        Add-QueryHistory -Query $query -Server $Server -Database $Database -RowCount $rowCount -DurationMs $sw.ElapsedMilliseconds
                        Show-ResultsInLess -Tables $tables -Query $query
                        Show-PostResultActions -Tables $tables
                    } catch {
                        Write-Host "  $($c.red)Error: $_$($c.reset)"
                        Read-Host "  Press Enter"
                    }
                }
            }
            "*SELECT Builder*" {
                try {
                    $query = Show-SelectBuilder -Server $Server -Database $Database -User $User -Password $Password
                    if ($query) {
                        Write-Host "  $($c.dim)Executing...$($c.reset)"
                        $sw = [System.Diagnostics.Stopwatch]::StartNew()
                        $tables = Invoke-SqlQuery -Server $Server -Database $Database -Query $query -User $User -Password $Password
                        $sw.Stop()
                        $rowCount = ($tables | ForEach-Object { $_.Rows.Count } | Measure-Object -Sum).Sum
                        Add-QueryHistory -Query $query -Server $Server -Database $Database -RowCount $rowCount -DurationMs $sw.ElapsedMilliseconds
                        Show-ResultsInLess -Tables $tables -Query $query
                        Show-PostResultActions -Tables $tables
                    }
                } catch {
                    Write-Host "  $($c.red)Error: $_$($c.reset)"
                    Read-Host "  Press Enter"
                }
            }
            "*Query History*" {
                $query = Show-QueryHistoryPicker
                if ($query) {
                    try {
                        Write-Host "  $($c.dim)Executing...$($c.reset)"
                        $sw = [System.Diagnostics.Stopwatch]::StartNew()
                        $tables = Invoke-SqlQuery -Server $Server -Database $Database -Query $query -User $User -Password $Password
                        $sw.Stop()
                        $rowCount = ($tables | ForEach-Object { $_.Rows.Count } | Measure-Object -Sum).Sum
                        Add-QueryHistory -Query $query -Server $Server -Database $Database -RowCount $rowCount -DurationMs $sw.ElapsedMilliseconds
                        Show-ResultsInLess -Tables $tables -Query $query
                        Show-PostResultActions -Tables $tables
                    } catch {
                        Write-Host "  $($c.red)Error: $_$($c.reset)"
                        Read-Host "  Press Enter"
                    }
                }
            }
            "*Browse Tables*" {
                try {
                    $tbls = Get-Tables -Server $Server -Database $Database -User $User -Password $Password
                    $tableLines = $tbls | ForEach-Object {
                        $type = if ($_.TABLE_TYPE -eq 'VIEW') { "[VIEW]" } else { "[TABLE]" }
                        "$($type.PadRight(8)) $($_.TableName)"
                    }
                    $sel = Invoke-Fzf -Items $tableLines -Header "Tables in $Database (select to preview TOP 100)" -Prompt "Table > " -HeightPercent 80
                    if ($sel) {
                        $tableName = ($sel -replace '^\[.*?\]\s+', '').Trim()
                        Write-Host "  $($c.dim)Loading $tableName...$($c.reset)"
                        $tables = Invoke-SqlQuery -Server $Server -Database $Database -Query "SELECT TOP 100 * FROM $tableName" -User $User -Password $Password
                        Show-ResultsInLess -Tables $tables
                        Show-PostResultActions -Tables $tables
                    }
                } catch {
                    Write-Host "  $($c.red)Error: $_$($c.reset)"
                    Read-Host "  Press Enter"
                }
            }
            "*Browse Objects*" {
                try {
                    $objType = Invoke-Fzf -Items @("Tables", "Views", "Stored Procedures", "Functions") -Header "Object type" -Prompt "Browse > " -HeightPercent 30
                    if (-not $objType) { continue }

                    $objName = $null
                    switch ($objType) {
                        "Tables" {
                            $items = Get-Tables -Server $Server -Database $Database -User $User -Password $Password | ForEach-Object { $_.TableName }
                            $objName = Invoke-Fzf -Items $items -Header "Tables" -Prompt "Table > " -HeightPercent 80
                        }
                        "Views" {
                            $items = Get-Views -Server $Server -Database $Database -User $User -Password $Password
                            $objName = Invoke-Fzf -Items $items -Header "Views" -Prompt "View > " -HeightPercent 80
                        }
                        "Stored Procedures" {
                            $items = Get-StoredProcedures -Server $Server -Database $Database -User $User -Password $Password
                            $objName = Invoke-Fzf -Items $items -Header "Stored Procedures" -Prompt "Proc > " -HeightPercent 80
                        }
                        "Functions" {
                            $items = Get-Functions -Server $Server -Database $Database -User $User -Password $Password
                            $objName = Invoke-Fzf -Items $items -Header "Functions" -Prompt "Func > " -HeightPercent 80
                        }
                    }
                    if (-not $objName) { continue }

                    # Show object details
                    if ($objType -in "Tables", "Views") {
                        $detailAction = Invoke-Fzf -Items @("Columns", "Preview Data (TOP 100)", "Indexes", "Foreign Keys", "Row Count") -Header "$objName" -Prompt "Detail > " -HeightPercent 40
                        switch ($detailAction) {
                            "Columns" {
                                $cols = Get-ColumnsDetailed -Server $Server -Database $Database -Table $objName -User $User -Password $Password
                                $colLines = @("", "  Columns: $objName", "  $([string]::new([char]0x2500, 70))")
                                foreach ($col in $cols) {
                                    $pk = if ($col.IsPK -eq 'PK') { "[PK] " } else { "     " }
                                    $typeStr = $col.DATA_TYPE
                                    if ($col.CHARACTER_MAXIMUM_LENGTH -and $col.CHARACTER_MAXIMUM_LENGTH -ne [DBNull]::Value) {
                                        $maxLen = if ([int]$col.CHARACTER_MAXIMUM_LENGTH -eq -1) { "max" } else { $col.CHARACTER_MAXIMUM_LENGTH }
                                        $typeStr += "($maxLen)"
                                    }
                                    $nullable = if ($col.IS_NULLABLE -eq 'YES') { "NULL" } else { "NOT NULL" }
                                    $colLines += "  $pk$($col.COLUMN_NAME.PadRight(30)) $($typeStr.PadRight(20)) $nullable"
                                }
                                $colLines += ""
                                $colLines | less -R
                            }
                            "Preview Data (TOP 100)" {
                                $tables = Invoke-SqlQuery -Server $Server -Database $Database -Query "SELECT TOP 100 * FROM $objName" -User $User -Password $Password
                                Show-ResultsInLess -Tables $tables
                                Show-PostResultActions -Tables $tables
                            }
                            "Indexes" {
                                $idxs = Get-Indexes -Server $Server -Database $Database -Table $objName -User $User -Password $Password
                                $idxLines = @("", "  Indexes: $objName", "  $([string]::new([char]0x2500, 70))")
                                foreach ($idx in $idxs) {
                                    $idxLines += "  $($idx.Type.PadRight(4)) $($idx.IndexName.PadRight(40)) $($idx.IndexType.PadRight(15)) $($idx.Columns)"
                                }
                                $idxLines += ""
                                $idxLines | less -R
                            }
                            "Foreign Keys" {
                                $fks = Get-ForeignKeys -Server $Server -Database $Database -Table $objName -User $User -Password $Password
                                $fkLines = @("", "  Foreign Keys: $objName", "  $([string]::new([char]0x2500, 70))")
                                if ($fks) {
                                    foreach ($fk in $fks) {
                                        $fkLines += "  $($fk.FK_Name)"
                                        $fkLines += "    $($fk.FromTable).$($fk.FromColumn) -> $($fk.ToTable).$($fk.ToColumn)"
                                    }
                                } else { $fkLines += "  (none)" }
                                $fkLines += ""
                                $fkLines | less -R
                            }
                            "Row Count" {
                                $count = Get-TableRowCount -Server $Server -Database $Database -Table $objName -User $User -Password $Password
                                Write-Host "  $($c.bold)$objName$($c.reset): $($c.cyan)$count$($c.reset) rows"
                                Read-Host "  Press Enter"
                            }
                        }
                    } else {
                        # Sproc/Function — show definition
                        $schema, $name = $objName -split '\.', 2
                        $tables = Invoke-SqlQuery -Server $Server -Database $Database -Query "SELECT ROUTINE_DEFINITION FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_SCHEMA = '$schema' AND ROUTINE_NAME = '$name'" -User $User -Password $Password
                        if ($tables[0].Rows.Count -gt 0) {
                            $def = $tables[0].Rows[0].ROUTINE_DEFINITION
                            $def -split "`n" | less -R
                        }
                    }
                } catch {
                    Write-Host "  $($c.red)Error: $_$($c.reset)"
                    Read-Host "  Press Enter"
                }
            }
            "*Switch Database*" {
                try {
                    $dbs = Get-Databases -Server $Server -User $User -Password $Password
                    $newDb = Invoke-Fzf -Items $dbs -Header "Databases on $Server" -Prompt "Database > "
                    if ($newDb) {
                        $Database = $newDb
                        Save-Bookmark -Server $Server -Database $Database -User $User -Password $Password -SavePassword:([bool]$Password)
                    }
                } catch {
                    Write-Host "  $($c.red)Error: $_$($c.reset)"
                    Read-Host "  Press Enter"
                }
            }
            "*Switch Connection*" {
                Exit-AltScreen
                $conn = Show-ConnectionPicker
                Enter-AltScreen
                if ($conn) {
                    $Server = $conn.Server
                    $Database = $conn.Database
                    $User = $conn.User
                    $Password = $conn.Password
                    $script:activeDriver = if ($conn.Driver) { $conn.Driver } else { 'mssql' }
                    $script:activeOdbcDriver = $conn.OdbcDriver
                    $script:activePort = $conn.Port
                    $script:activeDsn = $conn.Dsn
                }
            }
            "*Exit*" { Exit-AltScreen; exit 0 }
        }
    }
} finally {
    Exit-AltScreen
}
