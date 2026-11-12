# Builds bin\projpick.exe. Requires Zig on PATH (winget install zig.zig).
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    [void][IO.Directory]::CreateDirectory("$PSScriptRoot\..\..\bin")
    zig test src/fuzzy.zig --cache-dir .zig-cache
    if ($LASTEXITCODE) { throw "projpick tests failed (exit $LASTEXITCODE)" }
    zig build-exe src/main.zig -target x86_64-windows-gnu -O ReleaseFast --subsystem windows -fstrip --name projpick "-femit-bin=..\..\bin\projpick.exe" --cache-dir .zig-cache
    if ($LASTEXITCODE) { throw "projpick build failed (exit $LASTEXITCODE)" }
    Remove-Item ..\..\bin\projpick.pdb, ..\..\bin\projpick.lib -ErrorAction SilentlyContinue
    Get-Item ..\..\bin\projpick.exe
} finally { Pop-Location }
