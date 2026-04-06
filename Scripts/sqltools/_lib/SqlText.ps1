# SQL text helpers - batch splitting, identifier quoting, and object-name handling

function Split-SqlBatches {
    param(
        [Parameter(Mandatory)][string]$Sql,
        [string]$Driver = $script:activeDriver
    )

    if ($Driver -eq 'sqlite') {
        return @($Sql)
    }

    return @($Sql -split '(?mi)^\s*GO\s*$' | Where-Object { $_.Trim() })
}

function Quote-SqlLiteral {
    param(
        [AllowNull()][object]$Value,
        [string]$Driver = $script:activeDriver
    )

    if ($null -eq $Value -or $Value -is [DBNull]) {
        return 'NULL'
    }

    $text = [string]$Value
    $escaped = $text.Replace("'", "''")
    return "'$escaped'"
}

function Quote-SqlIdentifierPart {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Driver = $script:activeDriver
    )

    if ($Driver -eq 'sqlite') {
        return '"' + $Name.Replace('"', '""') + '"'
    }

    return '[' + $Name.Replace(']', ']]') + ']'
}

function Format-SqlIdentifier {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Driver = $script:activeDriver
    )

    $parts = @($Name -split '\.')
    return ($parts | ForEach-Object { Quote-SqlIdentifierPart -Name $_ -Driver $Driver }) -join '.'
}

function Split-SqlObjectName {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$DefaultSchema = 'dbo'
    )

    $parts = @($Name -split '\.', 2)
    if ($parts.Count -eq 2) {
        return @{
            Schema = $parts[0]
            Name = $parts[1]
        }
    }

    return @{
        Schema = $DefaultSchema
        Name = $parts[0]
    }
}

function New-SqlPreviewQuery {
    param(
        [Parameter(Mandatory)][string]$ObjectName,
        [int]$Limit = 100,
        [string]$Driver = $script:activeDriver
    )

    $qualifiedName = Format-SqlIdentifier -Name $ObjectName -Driver $Driver
    if ($Driver -eq 'sqlite') {
        return "SELECT * FROM $qualifiedName LIMIT $Limit"
    }

    return "SELECT TOP $Limit * FROM $qualifiedName"
}
