# Object explorer — metadata queries for databases, tables, views, sprocs, columns, indexes, FKs

function Get-Databases {
    param([string]$Server, [string]$User, [string]$Password)
    if ($script:activeDriver -eq 'sqlite') {
        # SQLite is single-database; return the filename
        return @([System.IO.Path]::GetFileName($Server))
    }
    $tables = Invoke-SqlQuery -Server $Server -Database "master" -Query "SELECT name FROM sys.databases WHERE state_desc = 'ONLINE' ORDER BY name" -User $User -Password $Password
    $tables[0] | ForEach-Object { $_.name }
}

function Get-Tables {
    param([string]$Server, [string]$Database, [string]$User, [string]$Password)
    if ($script:activeDriver -eq 'sqlite') {
        $tables = Invoke-SqlQuery -Server $Server -Database $Database -Query "SELECT name AS TableName, 'BASE TABLE' AS TABLE_TYPE FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name" -User $User -Password $Password
        return $tables[0] | ForEach-Object { $_ }
    }
    $tables = Invoke-SqlQuery -Server $Server -Database $Database -Query "SELECT TABLE_SCHEMA + '.' + TABLE_NAME AS TableName, TABLE_TYPE FROM INFORMATION_SCHEMA.TABLES ORDER BY TABLE_SCHEMA, TABLE_NAME" -User $User -Password $Password
    $tables[0] | ForEach-Object { $_ }
}

function Get-Views {
    param([string]$Server, [string]$Database, [string]$User, [string]$Password)
    if ($script:activeDriver -eq 'sqlite') {
        $tables = Invoke-SqlQuery -Server $Server -Database $Database -Query "SELECT name AS ViewName FROM sqlite_master WHERE type='view' ORDER BY name" -User $User -Password $Password
        return $tables[0] | ForEach-Object { $_.ViewName }
    }
    $tables = Invoke-SqlQuery -Server $Server -Database $Database -Query "SELECT TABLE_SCHEMA + '.' + TABLE_NAME AS ViewName FROM INFORMATION_SCHEMA.VIEWS ORDER BY TABLE_SCHEMA, TABLE_NAME" -User $User -Password $Password
    $tables[0] | ForEach-Object { $_.ViewName }
}

function Get-StoredProcedures {
    param([string]$Server, [string]$Database, [string]$User, [string]$Password)
    if ($script:activeDriver -eq 'sqlite') { return @() }
    $tables = Invoke-SqlQuery -Server $Server -Database $Database -Query "SELECT ROUTINE_SCHEMA + '.' + ROUTINE_NAME AS ProcName FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_TYPE = 'PROCEDURE' ORDER BY ROUTINE_SCHEMA, ROUTINE_NAME" -User $User -Password $Password
    $tables[0] | ForEach-Object { $_.ProcName }
}

function Get-Functions {
    param([string]$Server, [string]$Database, [string]$User, [string]$Password)
    if ($script:activeDriver -eq 'sqlite') { return @() }
    $tables = Invoke-SqlQuery -Server $Server -Database $Database -Query "SELECT ROUTINE_SCHEMA + '.' + ROUTINE_NAME AS FuncName FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_TYPE = 'FUNCTION' ORDER BY ROUTINE_SCHEMA, ROUTINE_NAME" -User $User -Password $Password
    $tables[0] | ForEach-Object { $_.FuncName }
}

function Get-ColumnsDetailed {
    param([string]$Server, [string]$Database, [string]$Table, [string]$User, [string]$Password)
    if ($script:activeDriver -eq 'sqlite') {
        $tbl = ($Table -split '\.', 2)[-1]  # strip schema if present
        $tables = Invoke-SqlQuery -Server $Server -Database $Database -Query "PRAGMA table_info('$tbl')" -User $User -Password $Password
        return $tables[0] | ForEach-Object {
            @{
                COLUMN_NAME              = $_.name
                DATA_TYPE                = if ($_.type) { $_.type } else { 'any' }
                CHARACTER_MAXIMUM_LENGTH = [DBNull]::Value
                NUMERIC_PRECISION        = [DBNull]::Value
                NUMERIC_SCALE            = [DBNull]::Value
                IS_NULLABLE              = if ($_.notnull -eq 1) { 'NO' } else { 'YES' }
                IsPK                     = if ($_.pk -ge 1) { 'PK' } else { '' }
            }
        }
    }
    $schema, $tbl = $Table -split '\.', 2
    $q = @"
SELECT c.COLUMN_NAME, c.DATA_TYPE,
       c.CHARACTER_MAXIMUM_LENGTH, c.NUMERIC_PRECISION, c.NUMERIC_SCALE,
       c.IS_NULLABLE,
       CASE WHEN pk.COLUMN_NAME IS NOT NULL THEN 'PK' ELSE '' END AS IsPK
FROM INFORMATION_SCHEMA.COLUMNS c
LEFT JOIN (
    SELECT ku.COLUMN_NAME
    FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
    JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE ku ON tc.CONSTRAINT_NAME = ku.CONSTRAINT_NAME
        AND tc.TABLE_SCHEMA = ku.TABLE_SCHEMA AND tc.TABLE_NAME = ku.TABLE_NAME
    WHERE tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
        AND tc.TABLE_SCHEMA = '$schema' AND tc.TABLE_NAME = '$tbl'
) pk ON c.COLUMN_NAME = pk.COLUMN_NAME
WHERE c.TABLE_SCHEMA = '$schema' AND c.TABLE_NAME = '$tbl'
ORDER BY c.ORDINAL_POSITION
"@
    $tables = Invoke-SqlQuery -Server $Server -Database $Database -Query $q -User $User -Password $Password
    $tables[0] | ForEach-Object { $_ }
}

function Get-TableRowCount {
    param([string]$Server, [string]$Database, [string]$Table, [string]$User, [string]$Password)
    if ($script:activeDriver -eq 'sqlite') {
        $tbl = ($Table -split '\.', 2)[-1]
        $tables = Invoke-SqlQuery -Server $Server -Database $Database -Query "SELECT COUNT(*) AS RowCount FROM [$tbl]" -User $User -Password $Password
        return $tables[0].Rows[0].RowCount
    }
    $schema, $tbl = $Table -split '\.', 2
    $q = "SELECT SUM(p.rows) AS RowCount FROM sys.partitions p JOIN sys.tables t ON p.object_id = t.object_id JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = '$schema' AND t.name = '$tbl' AND p.index_id IN (0,1)"
    $tables = Invoke-SqlQuery -Server $Server -Database $Database -Query $q -User $User -Password $Password
    $tables[0].Rows[0].RowCount
}

function Get-Indexes {
    param([string]$Server, [string]$Database, [string]$Table, [string]$User, [string]$Password)
    if ($script:activeDriver -eq 'sqlite') {
        $tbl = ($Table -split '\.', 2)[-1]
        $idxList = Invoke-SqlQuery -Server $Server -Database $Database -Query "PRAGMA index_list('$tbl')" -User $User -Password $Password
        $results = @()
        foreach ($idx in $idxList[0]) {
            $idxInfo = Invoke-SqlQuery -Server $Server -Database $Database -Query "PRAGMA index_info('$($idx.name)')" -User $User -Password $Password
            $cols = ($idxInfo[0] | ForEach-Object { $_.name }) -join ', '
            $results += @{
                IndexName = $idx.name
                Type      = if ($idx.unique -eq 1) { 'UQ' } else { 'IX' }
                IndexType = if ($idx.origin -eq 'pk') { 'PRIMARY KEY' } else { 'NONCLUSTERED' }
                Columns   = $cols
            }
        }
        return $results
    }
    $schema, $tbl = $Table -split '\.', 2
    $q = @"
SELECT i.name AS IndexName,
       CASE WHEN i.is_primary_key = 1 THEN 'PK'
            WHEN i.is_unique = 1 THEN 'UQ'
            ELSE 'IX' END AS Type,
       i.type_desc AS IndexType,
       STRING_AGG(c.name, ', ') WITHIN GROUP (ORDER BY ic.key_ordinal) AS Columns
FROM sys.indexes i
JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
JOIN sys.tables t ON i.object_id = t.object_id
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = '$schema' AND t.name = '$tbl' AND i.name IS NOT NULL
GROUP BY i.name, i.is_primary_key, i.is_unique, i.type_desc
ORDER BY i.is_primary_key DESC, i.name
"@
    $tables = Invoke-SqlQuery -Server $Server -Database $Database -Query $q -User $User -Password $Password
    $tables[0] | ForEach-Object { $_ }
}

function Get-ForeignKeys {
    param([string]$Server, [string]$Database, [string]$Table, [string]$User, [string]$Password)
    if ($script:activeDriver -eq 'sqlite') {
        $tbl = ($Table -split '\.', 2)[-1]
        $fkList = Invoke-SqlQuery -Server $Server -Database $Database -Query "PRAGMA foreign_key_list('$tbl')" -User $User -Password $Password
        return $fkList[0] | ForEach-Object {
            @{
                FK_Name    = "fk_$($_.id)"
                FromTable  = $tbl
                FromColumn = $_.from
                ToTable    = $_.table
                ToColumn   = $_.to
            }
        }
    }
    $schema, $tbl = $Table -split '\.', 2
    $q = @"
SELECT fk.name AS FK_Name,
       OBJECT_SCHEMA_NAME(fk.parent_object_id) + '.' + OBJECT_NAME(fk.parent_object_id) AS FromTable,
       COL_NAME(fkc.parent_object_id, fkc.parent_column_id) AS FromColumn,
       OBJECT_SCHEMA_NAME(fk.referenced_object_id) + '.' + OBJECT_NAME(fk.referenced_object_id) AS ToTable,
       COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id) AS ToColumn
FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
WHERE (OBJECT_SCHEMA_NAME(fk.parent_object_id) = '$schema' AND OBJECT_NAME(fk.parent_object_id) = '$tbl')
   OR (OBJECT_SCHEMA_NAME(fk.referenced_object_id) = '$schema' AND OBJECT_NAME(fk.referenced_object_id) = '$tbl')
ORDER BY fk.name
"@
    $tables = Invoke-SqlQuery -Server $Server -Database $Database -Query $q -User $User -Password $Password
    $tables[0] | ForEach-Object { $_ }
}
