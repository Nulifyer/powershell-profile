#.ALIAS file-inventory
#.ALIAS finv
<#
.SYNOPSIS
    Get file count and total size for a directory.

.DESCRIPTION
    Recursively scans a directory and returns file count and total size.
#>

. "$PSScriptRoot\..\_lib\ScriptUtils.ps1"

$parsed = Parse-Args $args @{
    Raw     = @{ Aliases = @('r', 'raw') }
    NoColor = @{ Aliases = @('nc', 'no-color') }
}

$Path   = $parsed._positional[0]
$Filter = if ($parsed._positional[1]) { $parsed._positional[1] } else { '*.*' }

if ($parsed._help -or -not $Path) {
    Show-ScriptHelp -Usage "<Path> [Filter] [-r|--raw] [-nc|--no-color]" `
        -Description "Get file count and total size for a directory." `
        -Arguments ([ordered]@{
            Path   = "Directory to scan"
            Filter = "File filter (default: *.*)"
        }) `
        -Options ([ordered]@{
            "-r, --raw"      = "Output plain text for piping"
            "-nc, --no-color" = "Disable colored output"
            "-h, --help"     = "Show this help"
        }) `
        -Examples @(
            "finv C:\Logs",
            "finv C:\Logs *.log"
        )
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

$readableSize = switch ($totalSizeBytes) {
    { $_ -lt 1KB } { "{0:N0} bytes" -f $_; break }
    { $_ -lt 1MB } { "{0:N2} KB" -f ($_ / 1KB); break }
    { $_ -lt 1GB } { "{0:N2} MB" -f ($_ / 1MB); break }
    { $_ -lt 1TB } { "{0:N2} GB" -f ($_ / 1GB); break }
    default { "{0:N2} TB" -f ($_ / 1TB) }
}

if ($parsed.Raw) {
    Write-Output "Path:       $resolvedPath"
    Write-Output "Filter:     $Filter"
    Write-Output "Count:      $($files.Count)"
    Write-Output "TotalBytes: $totalSizeBytes"
    Write-Output "TotalSize:  $readableSize"
    exit 0
}

$c = Get-Colors -Disabled:$parsed.NoColor

Write-Host ""
Write-Host "$($c.bold)$($c.cyan)  File Inventory$($c.reset)"
Write-Host "$($c.dim)$("─" * 50)$($c.reset)"
Write-Host ""
Write-Host "$($c.reset)  Path:   $($c.yellow)$resolvedPath$($c.reset)"
Write-Host "$($c.reset)  Filter: $Filter"
Write-Host ""
Write-Host "$($c.reset)  Files:  $($c.bold)$($files.Count)$($c.reset)"
Write-Host "$($c.reset)  Size:   $($c.bold)$readableSize$($c.reset) $($c.dim)($totalSizeBytes bytes)$($c.reset)"
Write-Host ""
Write-Host "$($c.dim)$("─" * 50)$($c.reset)"
Write-Host ""
