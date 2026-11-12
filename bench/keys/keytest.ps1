#Requires -Version 7
# Drives the shell under test with real key presses (pbench type) and checks
# each case's result from the probe log. See bench/README.md, "Key handling".
param(
    [Parameter(Mandatory)][string]$Title,     # part of the test window's title
    [ValidateSet('wt', 'code', 'other')][string]$Target = 'other',
    [string[]]$Only,                          # case ids (or one comma-separated string)
    [string]$Pbench = [IO.Path]::Combine($PSScriptRoot, '..', 'pbench.exe'),
    [string]$CaseFile = [IO.Path]::Combine($PSScriptRoot, 'cases.json'),
    [string]$Out                              # optional JSON results
)
$ErrorActionPreference = 'Stop'
$log = if ($env:KEYTEST_LOG) { $env:KEYTEST_LOG } else { [IO.Path]::Combine([IO.Path]::GetTempPath(), 'keytest-probe.log') }
if (-not (Test-Path $log)) { throw "No probe log at $log. Load keyprobe.ps1 in the shell under test first." }
$cases = Get-Content $CaseFile -Raw | ConvertFrom-Json
if ($Only.Count -eq 1) { $Only = $Only[0] -split ',' }
if ($Only) { $cases = $cases | Where-Object { $_.id -in $Only } }
$cases = @($cases | Where-Object { -not $_.only -or $_.only -eq $Target })

function LineCount { @(Get-Content $log).Count }
function WaitProbe($n, $ms) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $ms) {
        $l = @(Get-Content $log)
        if ($l.Count -gt $n) { return $l[-1] | ConvertFrom-Json }
        Start-Sleep -Milliseconds 100
    }
    $null
}
function Check($c, $got) {
    if (-not $got) { return 'no probe' }
    $bad = foreach ($p in $c.expect.PSObject.Properties) {
        $g = $got.($p.Name); if ($g -is [string]) { $g = $g -replace "`r`n", "`n" }
        if ($g -cne $p.Value) { '{0}={1}' -f $p.Name, (ConvertTo-Json -Compress -InputObject $g) }
    }
    $bad -join ' '
}

$results = foreach ($c in $cases) {
    Set-Clipboard -Value $(if ($c.clip) { $c.clip } else { 'CLIP' })
    $n = LineCount
    & $Pbench type -focus $Title -delay 60ms -text ('{focus}' + $c.keys + '{wait:400}{combo:f9}')
    $got = WaitProbe $n 2500
    $note = ''
    if (-not $got) {
        # a key opened something else (palette, quick open, dialog); close it and resync
        & $Pbench type -focus $Title -text '{focus}{combo:esc}{wait:500}{combo:esc}{wait:500}{combo:f9}'
        $got = WaitProbe $n 2500
        $note = 'keys went elsewhere'
    }
    $diff = Check $c $got
    $r = [pscustomobject]@{ id = $c.id; desc = $c.desc; pass = (-not $diff -and -not $note); detail = (@($diff, $note) | Where-Object { $_ }) -join '; '; got = $got }
    $color = if ($r.pass) { 'Green' } else { 'Red' }
    Write-Host ('{0,-5} {1,-48} {2}' -f $(if ($r.pass) { 'ok' } else { 'FAIL' }), $c.desc, $r.detail) -ForegroundColor $color
    $r
    Start-Sleep -Milliseconds 300
}
$fail = @($results | Where-Object { -not $_.pass }).Count
Write-Host ("{0} cases, {1} failed" -f $results.Count, $fail)
if ($Out) { $results | ConvertTo-Json -Depth 5 | Set-Content $Out -Encoding utf8 }
exit $fail
