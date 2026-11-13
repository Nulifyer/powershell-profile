# Makes winget "portable" packages usable when winget can't link them.
#
# winget extracts portable packages (fzf, rg, bat, eza, ...) under
# WinGet\Packages\<id>\ and normally exposes each command as a symbolic link in
# WinGet\Links. Where policy blocks link files, that step fails and the
# command is not on PATH. These helpers find the real folders instead:
#
#   Get-WinGetToolDirs    folders inside winget packages that contain .exe files
#   Merge-WinGetToolDirs  insert them into a PATH list where WinGet\Links sits,
#                         so a broken or blocked link never shadows the real exe
#   Test-WinGetLinksBroken  portable packages exist but WinGet\Links has no links
#   Sync-WinGetUserPath   optionally mirror the folders into the user PATH (for
#                         cmd, VS Code, git hooks), touching only entries it added

function Get-WinGetRoots {
    $roots = @(
        @{ Packages = [IO.Path]::Combine($env:LOCALAPPDATA, 'Microsoft', 'WinGet', 'Packages'); Links = [IO.Path]::Combine($env:LOCALAPPDATA, 'Microsoft', 'WinGet', 'Links') }
        @{ Packages = [IO.Path]::Combine($env:ProgramFiles, 'WinGet', 'Packages'); Links = [IO.Path]::Combine($env:ProgramFiles, 'WinGet', 'Links') }
    )
    if (${env:ProgramFiles(x86)}) {
        $roots += @{ Packages = [IO.Path]::Combine(${env:ProgramFiles(x86)}, 'WinGet', 'Packages'); Links = [IO.Path]::Combine(${env:ProgramFiles(x86)}, 'WinGet', 'Links') }
    }
    return $roots
}

function Get-WinGetToolDirs {
    <# Folders (package root and up to two levels below) that contain .exe files, one list for all packages. #>
    $dirs = [System.Collections.Generic.List[string]]::new()
    foreach ($root in Get-WinGetRoots) {
        if (-not [IO.Directory]::Exists($root.Packages)) { continue }
        foreach ($pkg in ([IO.Directory]::GetDirectories($root.Packages) | Sort-Object)) {
            $queue = [System.Collections.Generic.Queue[object]]::new()
            $queue.Enqueue(@($pkg, 0))
            while ($queue.Count -gt 0) {
                $dir, $depth = $queue.Dequeue()
                try {
                    if ([IO.Directory]::EnumerateFiles($dir, '*.exe').GetEnumerator().MoveNext()) { $dirs.Add($dir) }
                    if ($depth -lt 2) {
                        foreach ($sub in [IO.Directory]::GetDirectories($dir)) {
                            # (parentheses: a bare `$sub, $depth + 1` parses as ($sub, $depth) + 1)
                            if (([IO.File]::GetAttributes($sub) -band [IO.FileAttributes]::ReparsePoint) -eq 0) { $queue.Enqueue(@($sub, ($depth + 1))) }
                        }
                    }
                } catch {}
            }
        }
    }
    return , $dirs
}

function Merge-WinGetToolDirs {
    <#
    Returns a new PATH list where the winget tool folders sit immediately before
    the first WinGet\Links entry (moved there if they already appear later), so
    real exes always win over links. Without a Links entry, missing folders are
    appended. Works on raw entries (%VAR% references are compared expanded).
    #>
    param([Parameter(Mandatory)][System.Collections.Generic.List[string]]$PathList, [System.Collections.Generic.List[string]]$ToolDirs)
    if ($null -eq $ToolDirs) { $ToolDirs = Get-WinGetToolDirs }
    $norm = { param($p) [Environment]::ExpandEnvironmentVariables($p).TrimEnd('\') }
    $tools = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($d in $ToolDirs) { [void]$tools.Add((& $norm $d)) }
    $links = @(Get-WinGetRoots | ForEach-Object { $_.Links.TrimEnd('\') })
    $at = -1
    for ($i = 0; $i -lt $PathList.Count; $i++) {
        if ($links -contains (& $norm $PathList[$i])) { $at = $i; break }
    }
    $out = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    if ($at -lt 0) {
        foreach ($p in $PathList) { if ($seen.Add((& $norm $p))) { $out.Add($p) } }
        foreach ($d in $ToolDirs) { if ($seen.Add((& $norm $d))) { $out.Add($d) } }
        return , $out
    }
    for ($i = 0; $i -lt $PathList.Count; $i++) {
        $n = & $norm $PathList[$i]
        if ($i -eq $at) {
            foreach ($d in $ToolDirs) { if ($seen.Add((& $norm $d))) { $out.Add($d) } }
        }
        if ($tools.Contains($n) -and $i -gt $at) { continue } # already placed before Links
        if ($seen.Add($n)) { $out.Add($PathList[$i]) }
    }
    return , $out
}

function Test-WinGetLinksBroken {
    <# True when portable packages are installed but WinGet\Links holds no working link for them. #>
    $root = (Get-WinGetRoots)[0]
    if (-not [IO.Directory]::Exists($root.Packages) -or [IO.Directory]::GetDirectories($root.Packages).Count -eq 0) { return $false }
    if (-not [IO.Directory]::Exists($root.Links)) { return $true }
    foreach ($f in [IO.DirectoryInfo]::new($root.Links).EnumerateFiles('*.exe')) {
        if ($f.LinkTarget -and [IO.File]::Exists($f.LinkTarget)) { return $false }
        if (-not $f.LinkTarget) { return $false } # a real file or shim works
    }
    return $true
}

function Resolve-ToolFile {
    <# A usable executable path for $Path: symbolic links resolve to their target; dangling links return $null. #>
    param([string]$Path)
    if (-not [IO.File]::Exists($Path)) { return $null }
    $fi = [IO.FileInfo]::new($Path)
    if (($fi.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) { return $Path }
    # App execution aliases (winget.exe, wt.exe in WindowsApps) run fine, but
    # their targets live in a folder normal users can't list.
    if ($fi.DirectoryName.EndsWith('\WindowsApps', [StringComparison]::OrdinalIgnoreCase)) { return $Path }
    $target = $fi.LinkTarget
    if (-not $target) { return $Path }
    if (-not [IO.Path]::IsPathRooted($target)) { $target = [IO.Path]::GetFullPath([IO.Path]::Combine($fi.DirectoryName, $target)) }
    if ([IO.File]::Exists($target)) { return $target }
    return $null
}

function Sync-WinGetUserPath {
    <#
    Adds the winget tool folders to the user PATH (HKCU\Environment), or with
    -Remove takes them out again. Only entries recorded in $Owned (the ones this
    function added before) are ever removed. Other entries keep their text
    (%VAR% references stay unexpanded), order and the value type; the only
    changes are tool folders moving in front of WinGet\Links and exact
    duplicate entries being dropped.
    Returns the new list of owned entries.
    #>
    param([string[]]$Owned = @(), [switch]$Remove)
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
    try {
        $raw = [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        $kind = if ($key.GetValueNames() -contains 'Path') { $key.GetValueKind('Path') } else { [Microsoft.Win32.RegistryValueKind]::ExpandString }
        $entries = [System.Collections.Generic.List[string]]::new()
        foreach ($e in $raw.Split(';')) { if ($e.Trim()) { $entries.Add($e.Trim()) } }
        $ownedSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($o in $Owned) { if ($o) { [void]$ownedSet.Add($o) } }
        # (an `if` that yields @() assigns $null, hence the explicit list)
        $want = [System.Collections.Generic.List[string]]::new()
        if (-not $Remove) { foreach ($d in (Get-WinGetToolDirs)) { $want.Add($d) } }
        $wantSet = [System.Collections.Generic.HashSet[string]]::new($want, [StringComparer]::OrdinalIgnoreCase)

        # drop entries we added earlier that are no longer wanted (package removed or feature off)
        $kept = [System.Collections.Generic.List[string]]::new()
        foreach ($e in $entries) { if (-not ($ownedSet.Contains($e) -and -not $wantSet.Contains($e))) { $kept.Add($e) } }
        $present = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($e in $kept) { [void]$present.Add([Environment]::ExpandEnvironmentVariables($e).TrimEnd('\')) }
        $newOwned = [System.Collections.Generic.List[string]]::new()
        foreach ($d in $want) {
            # ours if we added it before, or if it isn't there yet (we add it now)
            if ($ownedSet.Contains($d) -or -not $present.Contains($d.TrimEnd('\'))) { $newOwned.Add($d) }
        }
        # Same placement rule as the session PATH: before WinGet\Links.
        $kept = Merge-WinGetToolDirs -PathList $kept -ToolDirs $want
        $value = $kept -join ';'
        if ($value -ne ($entries -join ';')) {
            $key.SetValue('Path', $value, $kind)
            # Tell running apps (Explorer, terminals started later) the environment changed:
            # setting and clearing a variable through .NET broadcasts WM_SETTINGCHANGE.
            [Environment]::SetEnvironmentVariable('PWSH_PROFILE_PATH_SYNC', '1', 'User')
            [Environment]::SetEnvironmentVariable('PWSH_PROFILE_PATH_SYNC', $null, 'User')
        }
        return , $newOwned.ToArray()
    } finally {
        $key.Dispose()
    }
}

function Update-WinGetUserPath {
    <#
    Applies the saved profile-setup choice ("Tools on user PATH") outside of
    setup: after `tools --install`, and when the profile cache rebuilds because
    winget packages changed. Does nothing unless the choice is on.
    #>
    $file = [IO.Path]::Combine($env:LOCALAPPDATA, 'pwsh-profile', 'setup.json')
    if (-not [IO.File]::Exists($file)) { return }
    try {
        $s = [IO.File]::ReadAllText($file) | ConvertFrom-Json -AsHashtable
        if (-not $s.decisions -or $s.decisions['component:winget-path'] -ne 'on') { return }
        $owned = Sync-WinGetUserPath -Owned @($s.userPath)
        if ((@($owned) -join ';') -ne (@($s.userPath) -join ';')) {
            $s.userPath = @($owned)
            [IO.File]::WriteAllText($file, ($s | ConvertTo-Json -Depth 5))
        }
    } catch {}
}
