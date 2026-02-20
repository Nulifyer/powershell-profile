<#
.SYNOPSIS
    Get file count and total size for a directory.

.DESCRIPTION
    Recursively scans a directory and returns file count and total size.

.PARAMETER Path
    Directory to scan.

.PARAMETER Filter
    File filter (wildcards supported). Default: *.*

.EXAMPLE
    file-inventory C:\Logs

.EXAMPLE
    file-inventory C:\Logs *.log
#>

# manual parsing for unix-style flags
$Path = $null
$Filter = '*.*'
$Raw = $false
$NoColor = $false
$h = $false

# iterate through arguments
for ($i = 0; $i -lt $args.Count; $i++) {
    $arg = $args[$i]
    if ($arg -eq '--') { break }
    elseif ($arg -match '^--?(?<flag>[^=]+)(=(?<val>.*))?$') {
        $flag = $Matches.flag
        switch ($flag) {
            'r' | 'raw' { $Raw = $true }
            'nc' | 'no-color' { $NoColor = $true }
            'h' | 'help' { $h = $true }
            default {
                Write-Error "Unknown option: $arg"
                exit 1
            }
        }
    } else {
        if (-not $Path) { $Path = $arg }
        elseif ($Filter -eq '*.*') { $Filter = $arg }
    }
}


if ($h -or -not $Path) {
    $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
    Write-Host "Usage: $scriptName <Path> [Filter] [-r|--raw] [-nc|--no-color]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Get file count and total size for a directory."
    Write-Host ""
    Write-Host "Arguments:"
    Write-Host "  Path      Directory to scan"
    Write-Host "  Filter    File filter (default: *.*)"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -r, --raw       Output plain object for piping"
    Write-Host "  -nc, --no-color Disable colored output"
    Write-Host "  -h, --help      Show this help"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  $scriptName C:\Logs"
    Write-Host "  $scriptName C:\Logs *.log"
    exit 0
}

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -Path $Path -PathType Container)) {
    Write-Error "Path does not exist or is not a directory: '$Path'"
    exit 1
}

$resolvedPath = (Resolve-Path -Path $Path).ProviderPath
$files = Get-ChildItem -Path $resolvedPath -Filter $Filter -File -Recurse -ErrorAction Stop
$totalSizeBytes = ($files | Measure-Object -Property Length -Sum).Sum
if (-not $totalSizeBytes) { $totalSizeBytes = 0 }

# Convert to readable size
$readableSize = switch ($totalSizeBytes) {
    { $_ -lt 1KB } { "{0:N0} bytes" -f $_; break }
    { $_ -lt 1MB } { "{0:N2} KB" -f ($_ / 1KB); break }
    { $_ -lt 1GB } { "{0:N2} MB" -f ($_ / 1MB); break }
    { $_ -lt 1TB } { "{0:N2} GB" -f ($_ / 1GB); break }
    default { "{0:N2} TB" -f ($_ / 1TB) }
}

$result = [pscustomobject]@{
    Path       = $resolvedPath
    Filter     = $Filter
    Count      = $files.Count
    TotalBytes = $totalSizeBytes
    TotalSize  = $readableSize
}

if ($Raw) {
    Write-Output "Path:       $resolvedPath"
    Write-Output "Filter:     $Filter"
    Write-Output "Count:      $($files.Count)"
    Write-Output "TotalBytes: $totalSizeBytes"
    Write-Output "TotalSize:  $readableSize"
    exit 0
}

# Visual output
if ($NoColor) {
    $esc = ''; $reset = ''; $bold = ''; $dim = ''
    $cyan = ''; $yellow = ''; $green = ''; $blue = ''; $magenta = ''
} else {
    $esc = [char]27
    $reset = "$esc[0m"
    $bold = "$esc[1m"
    $dim = "$esc[2m"
    $cyan = "$esc[36m"
    $yellow = "$esc[33m"
    $green = "$esc[32m"
    $blue = "$esc[34m"
    $magenta = "$esc[35m"
}

Write-Host ""
Write-Host "$bold$cyan  File Inventory$reset"
Write-Host "$dim$("─" * 50)$reset"
Write-Host ""
Write-Host "$reset  Path:   $yellow$resolvedPath$reset"
Write-Host "$reset  Filter: $Filter"
Write-Host ""
Write-Host "$reset  Files:  $bold$($files.Count)$reset"
Write-Host "$reset  Size:   $bold$readableSize$reset $dim($totalSizeBytes bytes)$reset"
Write-Host ""
Write-Host "$dim$("─" * 50)$reset"
Write-Host ""
