#.ALIAS tools
#.HELP Usage: tools [--install] [--core|--extra]
#.HELP
#.HELP Show installation status of CLI tools.
#.HELP   tools                  — show status of all tools
#.HELP   tools --install        — pick missing tools to install
#.HELP   tools --install --core — install/select core profile tools only
#.HELP   tools --install --extra — install/select workflow extras only
#.HELP
#.HELP The tool list lives in Scripts\_lib\ToolCatalog.ps1 and is shared with
#.HELP profile-setup. Nothing here needs fzf, so it works on a fresh machine.

. "$PSScriptRoot\_lib\ScriptUtils.ps1"
. "$PSScriptRoot\_lib\Tui.ps1"
. "$PSScriptRoot\_lib\ToolCatalog.ps1"

$parsed = Parse-Args $args @{
    Install = @{ Aliases = @('i', 'install') }
    Core    = @{ Aliases = @('core', 'profile') }
    Extra   = @{ Aliases = @('extra', 'extras') }
}

if ($parsed._help) { Show-Help; exit 0 }
if ($parsed.Core -and $parsed.Extra) {
    Write-Host "  Choose either --core or --extra, not both." -ForegroundColor Red
    exit 1
}

$search = Get-ToolSearchDirs
$haveWinget = [bool](Find-ToolExe 'winget.exe' $search)
$homePrefix = $HOME + '\'
$wingetPrefix = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\"

$rows = foreach ($tool in $ToolCatalog) {
    if ($parsed.Core -and $tool.Group -ne 'core') { continue }
    if ($parsed.Extra -and $tool.Group -ne 'extra') { continue }
    $src = Find-ToolExe $tool.Exe $search
    $display = if (-not $src) {
        if ($tool.WinGet) { $tool.WinGet } elseif ($tool.InstallScript) { 'upstream install script' } else { $tool.InstallHint }
    } elseif ($src.StartsWith($wingetPrefix)) {
        "~/AppData/Local/.../$(($src.Substring($wingetPrefix.Length) -split '_')[0])/.../$(Split-Path $src -Leaf)"
    } elseif ($src.StartsWith($homePrefix)) {
        '~/' + $src.Substring($homePrefix.Length).Replace('\', '/')
    } else { $src }
    [pscustomobject]@{ Tool = $tool; Installed = [bool]$src; Display = $display }
}

$missing = @($rows | Where-Object { -not $_.Installed })

if (-not $parsed.Install) {
    Write-Host ""
    Write-Host "  Terminal Tools Status" -ForegroundColor Cyan
    Write-Host "  $("-" * 50)" -ForegroundColor DarkGray
    foreach ($r in $rows) {
        $state = if ($r.Installed) { "[OK]" } else { "[  ]" }
        $group = if ($r.Tool.Group -eq 'core') { "[core]" } else { "[extra]" }
        Write-Host "  $state  $($r.Tool.Name.PadRight(14))" -ForegroundColor $(if ($r.Installed) { 'Green' } else { 'Yellow' }) -NoNewline
        Write-Host " $group $($r.Display)" -ForegroundColor DarkGray
    }
    Write-Host "  $("-" * 50)" -ForegroundColor DarkGray
    Write-Host "  $(@($rows).Count - $missing.Count) installed, $($missing.Count) missing" -ForegroundColor DarkGray
    Write-Host ""
    if ($missing.Count -gt 0) { Write-Host "  Run 'tools --install' to install missing tools." -ForegroundColor Yellow; Write-Host "" }
    exit 0
}

if ($missing.Count -eq 0) {
    Write-Host "  All tools installed." -ForegroundColor Green
    exit 0
}

$items = [System.Collections.Generic.List[hashtable]]::new()
foreach ($group in 'core', 'extra') {
    $inGroup = @($missing | Where-Object { $_.Tool.Group -eq $group })
    if ($inGroup.Count -eq 0) { continue }
    $items.Add(@{ Header = $true; Label = $(if ($group -eq 'core') { 'Core' } else { 'Extras' }) })
    foreach ($r in $inGroup) {
        $t = $r.Tool
        $can = ($t.WinGet -and $haveWinget) -or $t.InstallScript
        $why = if ($can) { $t.Desc } elseif ($t.WinGet) { "$($t.Desc) — needs winget (App Installer)" } else { "$($t.Desc) — $($t.InstallHint)" }
        $items.Add(@{ Key = $t.Name; Label = $t.Name; Detail = $why; Checked = $false; Disabled = -not $can })
    }
}

Write-Host ""
$selected = Show-Checklist -Title 'Install tools' -Items $items -Hint 'Up/Down move   Space toggle   a all   n none   Enter install   Esc cancel'
if (-not $selected -or $selected.Count -eq 0) {
    Write-Host "  No tools selected." -ForegroundColor Yellow
    exit 0
}

foreach ($name in $selected) {
    $tool = $ToolCatalog | Where-Object { $_.Name -eq $name } | Select-Object -First 1
    Write-Step run "Installing $name"
    if (Install-CatalogTool $tool) { Write-Step ok "Installed $name" } else { Write-Step fail "$name was not installed" }
}

# Mirror new winget tools into the user PATH if that was chosen in profile-setup.
Update-WinGetUserPath

# Clear the profile's startup cache so new shells pick up the new tools
# (it usually notices on its own via PATH/WinGet timestamps; this makes it certain).
$cacheFile = Join-Path $env:LOCALAPPDATA 'pwsh-profile\cache.ps1'
if (Test-Path $cacheFile) {
    Remove-Item $cacheFile -Force
    Write-Host "  Profile cache cleared. New shells will pick up the new tools (or run 'profile-rebuild' here)." -ForegroundColor Cyan
}
Write-Host ""
