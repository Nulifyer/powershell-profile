# Connection bookmarks with DPAPI encrypted passwords

function Get-Bookmarks {
    if (Test-Path $script:bookmarkFile) {
        Get-Content $script:bookmarkFile -Raw | ConvertFrom-Json
    } else { @() }
}

function Encrypt-Password {
    param([string]$Plain)
    if (-not $Plain) { return $null }
    $Plain | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString
}

function Decrypt-Password {
    param([string]$Encrypted)
    if (-not $Encrypted) { return $null }
    try {
        $secure = $Encrypted | ConvertTo-SecureString
        [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        )
    } catch {
        return $null
    }
}

function Save-Bookmark {
    param(
        [string]$Server, [string]$Database,
        [string]$User, [string]$Password,
        [string]$Driver = 'mssql',
        [string]$OdbcDriver, [int]$Port, [string]$Dsn,
        [switch]$SavePassword
    )
    $bookmarks = @(Get-Bookmarks)
    $existing = $bookmarks | Where-Object { $_.Server -eq $Server -and $_.Database -eq $Database -and $_.User -eq $User -and $_.Driver -eq $Driver }
    if (-not $existing) {
        $authLabel = if ($User) { "$User@" } else { "" }
        $driverTag = if ($Driver -ne 'mssql') { "[$Driver] " } else { "" }
        $bookmarks += [PSCustomObject]@{
            Server            = $Server
            Database          = $Database
            User              = $User
            EncryptedPassword = if ($SavePassword -and $Password) { Encrypt-Password $Password } else { $null }
            Driver            = $Driver
            OdbcDriver        = $OdbcDriver
            Port              = $Port
            Dsn               = $Dsn
            Label             = "${driverTag}${authLabel}$Server/$Database"
        }
        $bookmarks | ConvertTo-Json -AsArray | Set-Content $script:bookmarkFile -Encoding UTF8
    }
}

function Remove-BookmarkAt {
    param([int]$Index)
    $bookmarks = @(Get-Bookmarks)
    if ($Index -ge 0 -and $Index -lt $bookmarks.Count) {
        $list = [System.Collections.ArrayList]@($bookmarks)
        $list.RemoveAt($Index)
        @($list) | ConvertTo-Json -AsArray | Set-Content $script:bookmarkFile -Encoding UTF8
    }
}

function Migrate-PlaintextPasswords {
    $bookmarks = @(Get-Bookmarks)
    $changed = $false
    foreach ($bm in $bookmarks) {
        if ($bm.PSObject.Properties.Name -contains 'Password' -and $bm.Password) {
            $bm | Add-Member -NotePropertyName EncryptedPassword -NotePropertyValue (Encrypt-Password $bm.Password) -Force
            $bm.PSObject.Properties.Remove('Password')
            $changed = $true
        }
        if ($bm.PSObject.Properties.Name -notcontains 'EncryptedPassword') {
            $bm | Add-Member -NotePropertyName EncryptedPassword -NotePropertyValue $null -Force
            $changed = $true
        }
    }
    if ($changed) {
        $bookmarks | ConvertTo-Json -AsArray | Set-Content $script:bookmarkFile -Encoding UTF8
    }
}

function Show-ConnectionPicker {
    Require-Fzf
    $bookmarks = @(Get-Bookmarks)
    $choices = @("+ New Connection")
    $choices += $bookmarks | ForEach-Object {
        $pwdHint = if ($_.User -and $_.EncryptedPassword) { " [key]" } elseif ($_.User) { " [no pwd]" } else { "" }
        "$($_.Label)$pwdHint"
    }

    $selected = Invoke-Fzf -Items $choices -Header "Select a connection" -Prompt "Connection > "
    if (-not $selected) { return $null }

    if ($selected -eq "+ New Connection") {
        Write-Host ""

        # Pick driver type
        $driverChoice = Invoke-Fzf -Items @(
            "Microsoft SQL Server",
            "ODBC (FreeTDS / Sybase / Other)",
            "ODBC DSN (pre-configured)"
        ) -Header "Connection type" -Prompt "Type > " -HeightPercent 30

        if (-not $driverChoice) { return $null }

        $drv = 'mssql'; $odbcDrv = $null; $port = 0; $dsn = $null

        switch -Wildcard ($driverChoice) {
            "*SQL Server*" { $drv = 'mssql' }
            "*FreeTDS*" {
                $drv = 'odbc'
                $odbcDrv = Show-OdbcDriverPicker
                if (-not $odbcDrv) { return $null }
                $portStr = Read-Host "  Port [5000]"
                $port = if ($portStr) { [int]$portStr } else { 5000 }
            }
            "*DSN*" {
                $drv = 'dsn'
                $installedDsns = Get-InstalledDsns
                if ($installedDsns.Count -gt 0) {
                    $dsnSel = Invoke-Fzf -Items (@($installedDsns) + @("(type manually)")) -Header "Select DSN" -Prompt "DSN > " -HeightPercent 50
                    if ($dsnSel -eq "(type manually)") {
                        $dsn = Read-Host "  DSN name"
                    } elseif ($dsnSel) {
                        $dsn = ($dsnSel -split '\s+\(')[0].Trim()
                    }
                } else {
                    $dsn = Read-Host "  DSN name"
                }
                if (-not $dsn) { return $null }
            }
        }

        $srv = $null
        if ($drv -ne 'dsn') {
            $srv = Read-Host "  Server (host or host\instance)"
            if (-not $srv) { return $null }
        }

        # Auth
        $usr = $null; $pwd = $null
        if ($drv -eq 'mssql') {
            $authChoice = Invoke-Fzf -Items @("Windows Authentication", "SQL Authentication") -Header "Auth method" -Prompt "Auth > " -HeightPercent 30
            if ($authChoice -eq "SQL Authentication") {
                $usr = Read-Host "  Username"
                $pwd = Read-Host "  Password"
            }
        } else {
            $usr = Read-Host "  Username"
            $pwd = Read-Host "  Password"
        }

        # Set active driver before fetching databases
        $script:activeDriver = $drv
        $script:activeOdbcDriver = $odbcDrv
        $script:activePort = $port
        $script:activeDsn = $dsn

        # Try to list databases
        $db = $null
        Write-Host "  $($script:c.dim)Fetching databases...$($script:c.reset)"
        try {
            $dbs = Get-Databases -Server $srv -User $usr -Password $pwd
            $db = Invoke-Fzf -Items $dbs -Header "Select database" -Prompt "Database > "
        } catch {
            Write-Host "  $($script:c.yellow)Could not list databases, enter manually.$($script:c.reset)"
            $db = Read-Host "  Database"
        }
        if (-not $db) { return $null }

        # Save password prompt
        $savePass = $false
        if ($usr) {
            $savePwdChoice = Invoke-Fzf -Items @("No", "Yes") -Header "Save password? (encrypted, this machine only)" -Prompt "> " -HeightPercent 20
            $savePass = $savePwdChoice -eq "Yes"
        }

        Save-Bookmark -Server $srv -Database $db -User $usr -Password $pwd -Driver $drv -OdbcDriver $odbcDrv -Port $port -Dsn $dsn -SavePassword:$savePass
        return @{ Server = $srv; Database = $db; User = $usr; Password = $pwd; Driver = $drv; OdbcDriver = $odbcDrv; Port = $port; Dsn = $dsn }
    }

    $idx = $choices.IndexOf($selected) - 1
    $bm = $bookmarks[$idx]
    $pwd = Decrypt-Password $bm.EncryptedPassword
    if ($bm.User -and -not $pwd) {
        $pwd = Read-Host "  Password for $($bm.User)@$($bm.Server)"
    }
    $drv = if ($bm.Driver) { $bm.Driver } else { 'mssql' }
    return @{
        Server = $bm.Server; Database = $bm.Database; User = $bm.User; Password = $pwd
        Driver = $drv; OdbcDriver = $bm.OdbcDriver; Port = $bm.Port; Dsn = $bm.Dsn
    }
}

function Show-ManageBookmarks {
    Require-Fzf
    $bookmarks = @(Get-Bookmarks)
    if ($bookmarks.Count -eq 0) {
        Write-Host "  No saved connections." -ForegroundColor Yellow
        return
    }
    $choices = $bookmarks | ForEach-Object {
        $pwdStatus = if ($_.User -and $_.EncryptedPassword) { " [encrypted]" } elseif ($_.User) { " [no pwd]" } else { "" }
        "$($_.Label)$pwdStatus"
    }
    $selected = Invoke-Fzf -Items $choices -Header "Select connections to remove (Tab=select)" -Prompt "Remove > " -Multi
    if (-not $selected) { Write-Host "  Nothing removed."; return }
    $toRemove = @($selected) | ForEach-Object { [array]::IndexOf($choices, $_) } | Sort-Object -Descending
    foreach ($idx in $toRemove) {
        Write-Host "  Removed: $($bookmarks[$idx].Label)" -ForegroundColor Yellow
    }
    $list = [System.Collections.ArrayList]@($bookmarks)
    foreach ($idx in $toRemove) { $list.RemoveAt($idx) }
    @($list) | ConvertTo-Json -AsArray | Set-Content $script:bookmarkFile -Encoding UTF8
}
