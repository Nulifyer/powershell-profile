#.ALIAS adtools-user-groups
<#
.SYNOPSIS
    List AD groups for a user with visual formatting.

.DESCRIPTION
    Uses LDAP to find groups a user belongs to and displays them in a
    colorful, organized format grouped by OU.

.PARAMETER Username
    The user's samAccountName.

.PARAMETER Raw
    Output raw distinguished names only.

.PARAMETER NoColor
    Output plain objects for piping (no colors).

.EXAMPLE
    user-groups myuser

.EXAMPLE
    user-groups myuser --no-color | Where-Object Name -like '*Admin*'
#>

param(
    [Parameter(Position = 0)]
    [string]$Username,

    [Alias('r')]
    [switch]$Raw,

    [Alias('nc')]
    [switch]$NoColor,

    [Alias('help')]
    [switch]$h
)

if ($h -or -not $Username) {
    $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
    Write-Host "Usage: $scriptName <Username> [-r|-Raw] [-nc|-NoColor]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "List AD groups for a user with visual formatting."
    Write-Host ""
    Write-Host "Arguments:"
    Write-Host "  Username    The user's samAccountName"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -r, -Raw      Output raw distinguished names only"
    Write-Host "  -nc, -NoColor Disable colored output"
    Write-Host "  -h, -Help     Show this help"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  $scriptName jdoe"
    Write-Host "  $scriptName jdoe -nc | Where-Object Name -like '*Admin*'"
    exit 0
}

$ErrorActionPreference = 'Stop'

$filter = "(&(objectCategory=User)(samAccountName=$Username))"
$searcher = [System.DirectoryServices.DirectorySearcher]::new($filter)

try {
    $result = $searcher.FindOne()
}
finally {
    $searcher.Dispose()
}

if (-not $result) {
    Write-Error "No AD user found: '$Username'"
    exit 1
}

$entry = $result.GetDirectoryEntry()
$groups = @($entry.memberOf)

if ($Raw) {
    $groups
    exit 0
}

# Parse groups into objects
$groupObjects = foreach ($dn in $groups) {
    $parts = $dn -split ',(?=(?:CN|OU|DC)=)'
    $name = ($parts | Where-Object { $_ -match '^CN=' }) -replace '^CN=', '' | Select-Object -First 1
    $ou = ($parts | Where-Object { $_ -match '^OU=' } | ForEach-Object { $_ -replace '^OU=', '' }) -join '/'

    [PSCustomObject]@{
        Name               = $name
        OrganizationalUnit = $ou
        DistinguishedName  = $dn
    }
}

$groupObjects = $groupObjects | Sort-Object Name

if ($NoColor) {
    $groupObjects
    exit 0
}

# Visual output
$esc = [char]27
$reset = "$esc[0m"
$bold = "$esc[1m"
$dim = "$esc[2m"
$cyan = "$esc[36m"
$yellow = "$esc[33m"
$green = "$esc[32m"
$magenta = "$esc[35m"
$blue = "$esc[34m"

Write-Host ""
Write-Host "$bold$cyan󰀄  AD Groups for $yellow$Username$reset  $dim($($groupObjects.Count) groups)$reset"
Write-Host "$dim$("─" * 80)$reset"

$byOU = $groupObjects | Group-Object OrganizationalUnit | Sort-Object Name

foreach ($ouGroup in $byOU) {
    $ouPath = if ($ouGroup.Name) { $ouGroup.Name } else { "(Root)" }
    Write-Host ""
    Write-Host "  $magenta  $ouPath$reset"
    
    # Get groups for this OU and sort them
    $ouGroups = $ouGroup.Group | Sort-Object Name
    
    # Calculate column width based on longest name (max 80 chars)
    $maxLen = ($ouGroups | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum
    $colWidth = [Math]::Min([Math]::Max($maxLen + 2, 20), 80)
    
    # Calculate number of columns that fit (assuming ~120 char terminal width, minus indent)
    $numCols = [Math]::Max([Math]::Floor(116 / $colWidth), 1)
    
    # Display in columns
    $items = @($ouGroups)
    for ($i = 0; $i -lt $items.Count; $i += $numCols) {
        $line = "    "
        for ($j = 0; $j -lt $numCols -and ($i + $j) -lt $items.Count; $j++) {
            $name = $items[$i + $j].Name
            if ($name.Length -gt ($colWidth - 2)) {
                $name = $name.Substring(0, $colWidth - 5) + "..."
            }
            $line += "$green$($name.PadRight($colWidth))$reset"
        }
        Write-Host $line
    }
}

Write-Host ""
Write-Host "$dim$("─" * 80)$reset"
Write-Host ""
