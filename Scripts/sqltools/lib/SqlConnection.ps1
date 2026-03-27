# SQL connection abstraction — SqlClient (MSSQL) and ODBC (Sybase/FreeTDS, etc.)

# Detect best SqlClient for MSSQL
$script:SqlClientType = $null
try {
    $null = [Microsoft.Data.SqlClient.SqlConnection]
    $script:SqlClientType = 'Microsoft.Data.SqlClient'
} catch {
    $script:SqlClientType = 'System.Data.SqlClient'
}

# Driver types
$script:DriverTypes = @{
    'mssql' = 'Microsoft SQL Server (SqlClient)'
    'odbc'  = 'ODBC (FreeTDS, Sybase, etc.)'
    'dsn'   = 'ODBC DSN (pre-configured)'
}

function Build-ConnString {
    param(
        [string]$Server, [string]$Database,
        [string]$User, [string]$Password,
        [string]$Driver = 'mssql',
        [string]$OdbcDriver, [int]$Port,
        [string]$Dsn
    )

    switch ($Driver) {
        'odbc' {
            $odbcDrv = if ($OdbcDriver) { $OdbcDriver } else { 'FreeTDS' }
            $p = if ($Port) { $Port } else { 5000 }
            $connStr = "Driver={$odbcDrv};Server=$Server;Port=$p;Database=$Database;"
            if ($User) { $connStr += "UID=$User;PWD=$Password;" }
            else { $connStr += "Trusted_Connection=Yes;" }
            return $connStr
        }
        'dsn' {
            $connStr = "DSN=$Dsn;"
            if ($Database) { $connStr += "Database=$Database;" }
            if ($User) { $connStr += "UID=$User;PWD=$Password;" }
            return $connStr
        }
        default {
            # mssql
            $srv = $Server
            if ($srv -notmatch '^tcp:' -and $srv -notmatch ',') { $srv = "tcp:$srv" }
            if ($User) {
                return "Data Source=$srv;Initial Catalog=$Database;User Id=$User;Password=$Password;TrustServerCertificate=True;"
            }
            return "Data Source=$srv;Initial Catalog=$Database;Integrated Security=True;TrustServerCertificate=True;"
        }
    }
}

function New-DbConnection {
    param([string]$ConnectionString, [string]$Driver = 'mssql')

    if ($Driver -in 'odbc', 'dsn') {
        return [System.Data.Odbc.OdbcConnection]::new($ConnectionString)
    }
    if ($script:SqlClientType -eq 'Microsoft.Data.SqlClient') {
        return [Microsoft.Data.SqlClient.SqlConnection]::new($ConnectionString)
    }
    return [System.Data.SqlClient.SqlConnection]::new($ConnectionString)
}

function New-DbDataAdapter {
    param($Command, [string]$Driver = 'mssql')

    if ($Driver -in 'odbc', 'dsn') {
        return [System.Data.Odbc.OdbcDataAdapter]::new($Command)
    }
    if ($script:SqlClientType -eq 'Microsoft.Data.SqlClient') {
        return [Microsoft.Data.SqlClient.SqlDataAdapter]::new($Command)
    }
    return [System.Data.SqlClient.SqlDataAdapter]::new($Command)
}

# Keep old names as wrappers for backward compat within the codebase
function New-SqlConnection {
    param([string]$ConnectionString)
    New-DbConnection -ConnectionString $ConnectionString -Driver $script:activeDriver
}

function New-SqlDataAdapter {
    param($Command)
    New-DbDataAdapter -Command $Command -Driver $script:activeDriver
}

function Get-InstalledOdbcDrivers {
    try {
        Get-OdbcDriver | Where-Object { $_.Platform -eq '64-bit' } | ForEach-Object { $_.Name }
    } catch {
        @()
    }
}

function Get-InstalledDsns {
    try {
        Get-OdbcDsn | ForEach-Object { "$($_.Name)  ($($_.DriverName))" }
    } catch {
        @()
    }
}

# Known ODBC drivers with install info
$script:KnownOdbcDrivers = @(
    @{ Name = "ODBC Driver 18 for SQL Server";  WinGet = "Microsoft.msodbcsql.18";    Desc = "Microsoft SQL Server" }
    @{ Name = "ODBC Driver 17 for SQL Server";  WinGet = "Microsoft.msodbcsql.17";    Desc = "Microsoft SQL Server (legacy)" }
    @{ Name = "PostgreSQL Unicode(x64)";        WinGet = "PostgreSQL.psqlODBC";        Desc = "PostgreSQL" }
    @{ Name = "FreeTDS";                         WinGet = $null;                        Desc = "Sybase ASE / older MSSQL"; Url = "https://github.com/FreeTDS/freetds/releases" }
    @{ Name = "MySQL ODBC 8.0 Unicode Driver";  WinGet = $null;                        Desc = "MySQL"; Url = "https://dev.mysql.com/downloads/connector/odbc/" }
    @{ Name = "MariaDB ODBC 3.1 Driver";        WinGet = $null;                        Desc = "MariaDB"; Url = "https://mariadb.com/downloads/connectors/connectors-data-access/odbc-connector" }
    @{ Name = "Oracle in OraDB19Home1";          WinGet = $null;                        Desc = "Oracle"; Url = "https://www.oracle.com/database/technologies/releasenote-odbc-ic.html" }
)

function Show-OdbcDriverPicker {
    $installed = Get-InstalledOdbcDrivers
    $lines = @()

    # Installed drivers first
    foreach ($drv in $installed) {
        $lines += "[installed]  $drv"
    }

    # Known but not installed
    foreach ($known in $script:KnownOdbcDrivers) {
        $isInstalled = $installed | Where-Object { $_ -like "*$($known.Name)*" }
        if (-not $isInstalled) {
            $installable = if ($known.WinGet) { "[winget]" } else { "[manual]" }
            $lines += "$installable    $($known.Name)  ($($known.Desc))"
        }
    }

    $lines += "(type driver name manually)"

    $sel = Invoke-Fzf -Items $lines -Header "Select ODBC driver" -Prompt "Driver > " -HeightPercent 60
    if (-not $sel) { return $null }

    if ($sel -eq "(type driver name manually)") {
        return Read-Host "  ODBC Driver name"
    }

    # If they picked a [winget] driver, offer to install
    if ($sel -match '^\[winget\]') {
        $driverName = ($sel -replace '^\[winget\]\s+', '' -replace '\s+\(.*$', '').Trim()
        $known = $script:KnownOdbcDrivers | Where-Object { $_.Name -eq $driverName }
        if ($known) {
            $installChoice = Invoke-Fzf -Items @("Yes, install via winget", "No, skip") -Header "Install $driverName ?" -Prompt "> " -HeightPercent 20
            if ($installChoice -like "Yes*") {
                Write-Host "  Installing $($known.WinGet)..." -ForegroundColor Cyan
                winget install -e --id $known.WinGet --accept-source-agreements --accept-package-agreements
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  Installed. You may need to restart your shell." -ForegroundColor Green
                } else {
                    Write-Host "  Install failed." -ForegroundColor Red
                }
            }
        }
        return $driverName
    }

    # If they picked a [manual] driver, show the download URL
    if ($sel -match '^\[manual\]') {
        $driverName = ($sel -replace '^\[manual\]\s+', '' -replace '\s+\(.*$', '').Trim()
        $known = $script:KnownOdbcDrivers | Where-Object { $_.Name -eq $driverName }
        if ($known -and $known.Url) {
            Write-Host ""
            Write-Host "  $driverName is not on winget." -ForegroundColor Yellow
            Write-Host "  Download from: $($known.Url)" -ForegroundColor Cyan
            Write-Host ""
            $openChoice = Invoke-Fzf -Items @("Open in browser", "Continue anyway", "Cancel") -Header "Driver not installed" -Prompt "> " -HeightPercent 25
            if ($openChoice -eq "Open in browser") {
                Start-Process $known.Url
            }
            if ($openChoice -eq "Cancel") { return $null }
        }
        return $driverName
    }

    # Installed driver — extract name
    return ($sel -replace '^\[installed\]\s+', '').Trim()
}
