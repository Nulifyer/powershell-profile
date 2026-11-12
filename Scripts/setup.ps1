#.ALIAS profile-setup
#.HELP Usage: profile-setup [--auto] [--rebuild]
#.HELP
#.HELP Sets up and maintains everything the profile needs outside the repo:
#.HELP builds the project picker (bin\projpick.exe), offers optional CLI tools,
#.HELP and cleans up files left by older versions.
#.HELP
#.HELP The profile runs this automatically (--auto) in the first terminal after
#.HELP the repo's commit changes (first clone, git pull). --auto only shows the
#.HELP checklist when there is something new to decide; your answers are kept in
#.HELP %LOCALAPPDATA%\pwsh-profile\setup.json.
#.HELP
#.HELP   profile-setup            review every choice again
#.HELP   profile-setup --rebuild  force a rebuild of the project picker

. "$PSScriptRoot\_lib\ScriptUtils.ps1"
. "$PSScriptRoot\_lib\Tui.ps1"
. "$PSScriptRoot\_lib\ToolCatalog.ps1"
. "$PSScriptRoot\_lib\VSCodeKeys.ps1"

$parsed = Parse-Args $args @{
    Auto    = @{ Aliases = @('auto') }
    Rebuild = @{ Aliases = @('rebuild') }
}
if ($parsed._help) { Show-Help; exit 0 }
$auto = [bool]$parsed.Auto

$Root = Split-Path $PSScriptRoot -Parent
$StateDir = [IO.Path]::Combine($env:LOCALAPPDATA, 'pwsh-profile')
$StateFile = [IO.Path]::Combine($StateDir, 'setup.json')
$CommitFile = [IO.Path]::Combine($StateDir, 'setup-commit.txt')
[void][IO.Directory]::CreateDirectory($StateDir)

# Zig version projpick is written against. Zig's standard library changes
# between releases, so an installed zig is used only when it is 0.17.x;
# otherwise this exact build is downloaded (checksum-verified) into
# %LOCALAPPDATA%\pwsh-profile\zig. Bump together with native\projpick.
$ZigVersion = '0.17.1'
$ZigSeries = '0.17.'
$ZigUrl = 'https://ziglang.org/download/0.17.1/zig-x86_64-windows-0.17.1.zip'
# Mirror override for networks that block ziglang.org (the checksum still applies).
if ($env:PWSH_PROFILE_ZIG_URL) { $ZigUrl = $env:PWSH_PROFILE_ZIG_URL }
$ZigSha256 = 'b03f477a1943673e02aca0f570e8030dffd536ce1f45cbc4d3326ec31159562e'

# -- helpers -------------------------------------------------------------------

function Get-RepoHead {
    # Same logic as the profile's fast check: read .git directly, no git process.
    try {
        $git = [IO.Path]::Combine($Root, '.git')
        if ([IO.File]::Exists($git)) {
            $link = [IO.File]::ReadAllText($git).Trim()
            if ($link.StartsWith('gitdir: ')) { $git = [IO.Path]::GetFullPath([IO.Path]::Combine($Root, $link.Substring(8))) }
        }
        if (-not [IO.Directory]::Exists($git)) { return 'nogit-' + [IO.File]::GetLastWriteTimeUtc($PSCommandPath).Ticks }
        $head = [IO.File]::ReadAllText([IO.Path]::Combine($git, 'HEAD')).Trim()
        if (-not $head.StartsWith('ref: ')) { return $head }
        $ref = $head.Substring(5)
        $refFile = [IO.Path]::Combine($git, $ref)
        if ([IO.File]::Exists($refFile)) { return [IO.File]::ReadAllText($refFile).Trim() }
        $packed = [IO.Path]::Combine($git, 'packed-refs')
        if ([IO.File]::Exists($packed)) {
            foreach ($l in [IO.File]::ReadLines($packed)) { if ($l.EndsWith(" $ref")) { return $l.Substring(0, $l.IndexOf(' ')) } }
        }
        return $head
    } catch { return $null }
}

function Read-State {
    $s = @{ decisions = @{}; migrations = @(); projpick = @{}; userPath = @(); vscodeKeys = $false }
    if ([IO.File]::Exists($StateFile)) {
        try {
            $j = [IO.File]::ReadAllText($StateFile) | ConvertFrom-Json -AsHashtable
            foreach ($k in 'decisions', 'projpick') { if ($j[$k]) { $s[$k] = $j[$k] } }
            if ($j.migrations) { $s.migrations = @($j.migrations) }
            if ($j.userPath) { $s.userPath = @($j.userPath) }
            if ($j.vscodeKeys) { $s.vscodeKeys = $true }
        } catch {}
    }
    return $s
}

function Save-State($s) {
    $tmp = "$StateFile.tmp"
    [IO.File]::WriteAllText($tmp, ($s | ConvertTo-Json -Depth 5))
    [IO.File]::Move($tmp, $StateFile, $true)
}

function Get-SourceHash {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $src = [IO.Path]::Combine($Root, 'native', 'projpick', 'src')
    foreach ($f in ([IO.Directory]::GetFiles($src, '*.zig') | Sort-Object)) {
        $b = [IO.File]::ReadAllBytes($f)
        [void]$sha.TransformBlock($b, 0, $b.Length, $null, 0)
    }
    [void]$sha.TransformFinalBlock([byte[]]@(), 0, 0)
    return [Convert]::ToHexString($sha.Hash)
}

function Get-Zig {
    $installed = Find-ToolExe 'zig.exe'
    if ($installed) {
        $v = (& $installed version 2>$null | Select-Object -First 1)
        if ("$v".StartsWith($ZigSeries)) { return @{ Exe = $installed; Version = "$v".Trim() } }
        Write-Step info "zig $v on PATH is not $ZigSeries`x; using a private Zig $ZigVersion"
    }
    $dir = [IO.Path]::Combine($StateDir, 'zig', "zig-x86_64-windows-$ZigVersion")
    $exe = [IO.Path]::Combine($dir, 'zig.exe')
    if ([IO.File]::Exists($exe)) { return @{ Exe = $exe; Version = $ZigVersion } }

    $zip = [IO.Path]::Combine($StateDir, "zig-$ZigVersion.zip")
    Write-Step run "Downloading Zig $ZigVersion (100 MB, one time)"
    $old = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue' # the progress bar slows downloads considerably
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $ZigUrl -OutFile $zip
    } finally { $ProgressPreference = $old }
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash
    if ($hash -ne $ZigSha256.ToUpperInvariant()) {
        Remove-Item -LiteralPath $zip -Force
        throw "Zig download checksum mismatch ($hash)"
    }
    Write-Step run 'Extracting Zig'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $parent = [IO.Path]::Combine($StateDir, 'zig')
    [void][IO.Directory]::CreateDirectory($parent)
    $stage = [IO.Path]::Combine($parent, ".extract-$PID")
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, $stage, $true)
    $inner = [IO.Directory]::GetDirectories($stage)[0]
    if ([IO.Directory]::Exists($dir)) { [IO.Directory]::Delete($dir, $true) }
    [IO.Directory]::Move($inner, $dir)
    [IO.Directory]::Delete($stage, $true)
    Remove-Item -LiteralPath $zip -Force
    # Older private Zig versions are no longer needed
    foreach ($d in [IO.Directory]::GetDirectories($parent)) {
        if ($d -ne $dir) { try { [IO.Directory]::Delete($d, $true) } catch {} }
    }
    return @{ Exe = $exe; Version = $ZigVersion }
}

$ProjpickExe = [IO.Path]::Combine($Root, 'bin', 'projpick.exe')

function Install-Projpick([hashtable]$State, [bool]$Force) {
    $hash = Get-SourceHash
    $needBuild = $Force -or -not [IO.File]::Exists($ProjpickExe) -or $State.projpick.sourceHash -ne $hash
    if ($needBuild) {
        $zig = Get-Zig
        if ([IO.File]::Exists($ProjpickExe)) { & $ProjpickExe --quit | Out-Null }
        Write-Step run "Building project picker with Zig $($zig.Version)"
        $src = [IO.Path]::Combine($Root, 'native', 'projpick', 'src', 'main.zig')
        $cache = [IO.Path]::Combine($StateDir, 'zig-cache')
        [void][IO.Directory]::CreateDirectory([IO.Path]::Combine($Root, 'bin'))
        $out = & $zig.Exe build-exe $src -target x86_64-windows-gnu -O ReleaseFast --subsystem windows -fstrip `
            --name projpick "-femit-bin=$ProjpickExe" --cache-dir "$cache\local" --global-cache-dir "$cache\global" 2>&1
        if ($LASTEXITCODE -ne 0) { throw "zig build failed:`n$($out -join "`n")" }
        foreach ($junk in 'projpick.pdb', 'projpick.lib') { Remove-Item -LiteralPath ([IO.Path]::Combine($Root, 'bin', $junk)) -ErrorAction SilentlyContinue }
        $State.projpick.sourceHash = $hash
        $State.projpick.zig = $zig.Version
        Write-Step ok 'Built bin\projpick.exe'
    }
    # Registers bin\projpick.exe to start at logon and starts it if needed.
    $null = & $ProjpickExe --install
    Write-Step ok 'Project picker ready (Ctrl+Alt+P)'
}

function Uninstall-Projpick {
    if ([IO.File]::Exists($ProjpickExe)) {
        $null = & $ProjpickExe --uninstall
        Remove-Item -LiteralPath $ProjpickExe -Force -ErrorAction SilentlyContinue
    }
    Write-Step ok 'Project picker removed from logon'
}

# -- cleanups of things older versions left behind -----------------------------
# Silent ones only touch files this repo generated. Asked ones are shown in the
# checklist because they delete something you might still use.

$Cleanups = @(
    @{
        Id = 'old-winget-path-cache'; Ask = $false
        Applies = { [IO.File]::Exists("$env:TEMP\pwsh-profile\winget-tool-paths.txt") }
        Run = { Remove-Item "$env:TEMP\pwsh-profile\winget-tool-paths.txt" -Force }
        Label = 'Old tool path cache in %TEMP%'
    }
    @{
        Id = 'projpick-localappdata-copy'; Ask = $false
        Applies = { [IO.File]::Exists("$env:LOCALAPPDATA\projpick\projpick.exe") }
        Run = {
            & "$env:LOCALAPPDATA\projpick\projpick.exe" --quit | Out-Null
            Remove-Item "$env:LOCALAPPDATA\projpick\projpick.exe" -Force
        }
        Label = 'Old projpick copy in %LOCALAPPDATA% (now runs from bin\)'
    }
    @{
        Id = 'vscode-projects-startmenu'; Ask = $true
        Applies = { [IO.Directory]::Exists("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\VSCode Projects") }
        Run = { Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\VSCode Projects" -Recurse -Force }
        Label = 'Remove "VSCode Projects" Start menu folder'
        Detail = 'shortcuts from the retired vscode-project-shortcut-gen script; Ctrl+Alt+P replaces them'
    }
)

# -- run -------------------------------------------------------------------------

# One setup at a time: the lock is an open file handle, released even on a crash.
$lockPath = [IO.Path]::Combine($StateDir, 'setup.lock')
try {
    $lock = [IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None')
} catch {
    if (-not $auto) { Write-Host 'profile-setup is already running in another terminal.' -ForegroundColor Yellow }
    exit 0
}

try {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $state = Read-State
    $head = Get-RepoHead
    $previous = if ([IO.File]::Exists($CommitFile)) { [IO.File]::ReadAllText($CommitFile).Trim() } else { $null }
    $short = if ($head -and $head.Length -ge 7 -and -not $head.StartsWith('nogit')) { $head.Substring(0, 7) } else { 'local' }
    $e = [char]27
    if ($auto) {
        $what = if ($previous) { "updated to $short" } else { "first run ($short)" }
        [Console]::WriteLine("$e[1mProfile setup$e[0m $e[90m— $what. Runs once per update; 'profile-setup' reviews choices.$e[0m")
    } else {
        [Console]::WriteLine("$e[1mProfile setup$e[0m $e[90m($short)$e[0m")
    }

    # 1. Silent cleanups
    foreach ($c in $Cleanups | Where-Object { -not $_.Ask }) {
        if ($state.migrations -contains $c.Id) { continue }
        try {
            if (& $c.Applies) { & $c.Run; Write-Step ok "Removed: $($c.Label)" }
            $state.migrations += $c.Id
        } catch { Write-Step fail "$($c.Label): $_" }
    }

    # 2. Decide what to show
    $search = Get-ToolSearchDirs
    $haveWinget = [bool](Find-ToolExe 'winget.exe' $search)
    $items = [System.Collections.Generic.List[hashtable]]::new()

    $pickKey = 'component:projpick'
    $pickDecision = $state.decisions[$pickKey]
    $pickItems = @()
    if (-not $auto -or -not $pickDecision) {
        $pickItems += @{ Key = $pickKey; Label = 'Project picker'; Checked = ($pickDecision -ne 'off')
            Detail = "Ctrl+Alt+P from anywhere; builds bin\projpick.exe (downloads Zig $ZigVersion if needed)" }
    }

    $pathKey = 'component:winget-path'
    $pathDecision = $state.decisions[$pathKey]
    if (-not $auto -or -not $pathDecision) {
        $broken = Test-WinGetLinksBroken
        $pickItems += @{ Key = $pathKey; Label = 'Tools on user PATH'
            Checked = $(if ($pathDecision) { $pathDecision -eq 'on' } else { $broken })
            Detail = $(if ($broken) { "winget can't create command links on this machine; add its package folders to your user PATH so cmd, VS Code and git find the tools too" }
                else { 'add winget package folders to your user PATH (winget links work here, so this is usually not needed)' }) }
    }

    $vsKey = 'component:vscode-keys'
    $vsDecision = $state.decisions[$vsKey]
    if (@(Get-VSCodeUserDirs).Count -gt 0 -and (-not $auto -or -not $vsDecision)) {
        $pickItems += @{ Key = $vsKey; Label = 'VS Code terminal keys'; Checked = ($vsDecision -ne 'off')
            Detail = 'Ctrl+E, Ctrl+K and Ctrl+Shift+C reach the shell, as in Windows Terminal' }
    }

    $installed = 0
    $toolItems = @()
    foreach ($t in $ToolCatalog) {
        if (Find-ToolExe $t.Exe $search) { $installed++; continue }
        $key = "tool:$($t.Name)"
        $decision = $state.decisions[$key]
        if ($auto -and $decision -eq 'declined') { continue }
        $canInstall = ($t.WinGet -and $haveWinget) -or $t.InstallScript
        if ($auto -and -not $canInstall) { continue }
        $checked = if ($decision) { $decision -eq 'accepted' } else { [bool]$t.Recommended }
        $detail = if ($canInstall) { $t.Desc } elseif ($t.WinGet) { "$($t.Desc) — needs winget (App Installer)" } else { "$($t.Desc) — $($t.InstallHint)" }
        $toolItems += @{ Key = $key; Label = $t.Name; Detail = $detail; Checked = ($checked -and $canInstall); Disabled = -not $canInstall }
    }

    $cleanItems = @()
    foreach ($c in $Cleanups | Where-Object { $_.Ask }) {
        if ($state.migrations -contains $c.Id) { continue }
        if (-not (& $c.Applies)) { $state.migrations += $c.Id; continue }
        $cleanItems += @{ Key = "cleanup:$($c.Id)"; Label = $c.Label; Detail = $c.Detail; Checked = $true }
    }

    if ($pickItems) { $items.Add(@{ Header = $true; Label = 'Components' }); foreach ($i in $pickItems) { $items.Add($i) } }
    if ($toolItems) {
        $items.Add(@{ Header = $true; Label = "Tools $(if ($haveWinget) { '(installed with winget)' } else { '(winget not found: install App Installer from the Store)' })$(if ($installed) { " — $installed already installed" })" })
        foreach ($i in $toolItems) { $items.Add($i) }
    }
    if ($cleanItems) { $items.Add(@{ Header = $true; Label = 'Cleanup' }); foreach ($i in $cleanItems) { $items.Add($i) } }

    # 3. Ask
    $selected = $null
    $asked = @($items | Where-Object { -not $_.Header -and -not $_.Disabled })
    if ($asked.Count -gt 0) {
        [Console]::WriteLine('')
        $selected = Show-Checklist -Title 'Choose what to set up' -Items $items
        if ($null -eq $selected) {
            Write-Step skip 'Choices skipped for now; you will be asked again next update (or run profile-setup)'
        } else {
            foreach ($i in $asked) {
                $on = $selected -contains $i.Key
                switch -Wildcard ($i.Key) {
                    'component:*' { $state.decisions[$i.Key] = if ($on) { 'on' } else { 'off' } }
                    'tool:*' { $state.decisions[$i.Key] = if ($on) { 'accepted' } else { 'declined' } }
                    'cleanup:*' { if (-not $on) { $state.migrations += $i.Key.Substring(8) } }
                }
            }
        }
    }

    # 4. Apply
    if ($selected) {
        foreach ($c in $Cleanups | Where-Object { $_.Ask }) {
            if ($selected -contains "cleanup:$($c.Id)") {
                try { & $c.Run; $state.migrations += $c.Id; Write-Step ok $c.Label } catch { Write-Step fail "$($c.Label): $_" }
            }
        }
        foreach ($t in $ToolCatalog) {
            if ($selected -notcontains "tool:$($t.Name)") { continue }
            Write-Step run "Installing $($t.Name)"
            if (Install-CatalogTool $t) { Write-Step ok "Installed $($t.Name)" } else { Write-Step fail "$($t.Name) was not installed" }
        }
    }

    $pick = $state.decisions[$pickKey]
    try {
        if ($pick -eq 'on') {
            Install-Projpick $state ([bool]$parsed.Rebuild)
        } elseif ($pick -eq 'off' -and [IO.File]::Exists($ProjpickExe)) {
            Uninstall-Projpick
        }
    } catch {
        Write-Step fail "Project picker: $($_.Exception.Message)"
        Write-Step info 'Run profile-setup to retry.'
    }

    # The profile always finds winget tools in its own sessions; this mirrors
    # them into the user PATH for other programs when chosen.
    try {
        if ($state.decisions[$pathKey] -eq 'on') {
            $state.userPath = Sync-WinGetUserPath -Owned @($state.userPath)
            Write-Step ok "winget tool folders on your user PATH ($(@($state.userPath).Count))"
        } elseif (@($state.userPath).Count -gt 0) {
            $state.userPath = Sync-WinGetUserPath -Owned @($state.userPath) -Remove
            Write-Step ok 'Removed winget tool folders from your user PATH'
        }
    } catch { Write-Step fail "User PATH: $_" }

    try {
        $vsOn = $state.decisions[$vsKey]
        if ($vsOn -eq 'on') {
            $names = @(Set-VSCodeTerminalKeys -Enable)
            if ($names) { Write-Step ok "VS Code terminal keys set ($($names -join ', '))" }
            $state.vscodeKeys = $true
        } elseif ($state.vscodeKeys) {
            $null = Set-VSCodeTerminalKeys -Disable
            $state.vscodeKeys = $false
            Write-Step ok 'VS Code terminal keys back to VS Code defaults'
        }
    } catch { Write-Step fail "VS Code terminal keys: $($_.Exception.Message)" }

    # 5. The profile rebuilds its startup cache on next load (new tools, PATH, picker).
    Remove-Item ([IO.Path]::Combine($StateDir, 'cache.ps1')) -ErrorAction SilentlyContinue
    Save-State $state
    if ($head) { [IO.File]::WriteAllText($CommitFile, $head) }
    Write-Step ok ("Setup finished in {0:N1} s" -f $sw.Elapsed.TotalSeconds)
    [Console]::WriteLine('')
} finally {
    $lock.Dispose()
}
