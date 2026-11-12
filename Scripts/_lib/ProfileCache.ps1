# Builds the profile's startup cache: everything that is expensive to discover
# (tool locations, theme escape codes, script aliases, completion sources) is
# resolved here once and written as a small PowerShell data file that the
# profile dot-sources on every launch.
#
# The profile calls Build-ProfileCache only when the cache key changes, i.e.
# after a git pull, a theme change, a PATH change, or a tool install. Nothing
# in here runs on a normal startup.

function Build-ProfileCache {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$CacheFile,
        [string]$MachinePath,
        [string]$UserPath,
        # The profile's key function, so the key is computed by exactly the
        # same code that checks it on startup.
        [Parameter(Mandatory)][scriptblock]$KeyFunction
    )

    $q = { param([string]$s) "'" + $s.Replace("'", "''") + "'" }

    # -- PATH merge ----------------------------------------------------------------
    $pathSeen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $pathList = [System.Collections.Generic.List[string]]::new()
    $keyPaths = [System.Collections.Generic.List[string]]::new()
    foreach ($e in "$MachinePath;$UserPath".Split(';', [StringSplitOptions]'RemoveEmptyEntries,TrimEntries')) {
        if ($pathSeen.Add($e.TrimEnd('\'))) {
            $pathList.Add($e)
            # user-writable PATH dirs: tools can appear there without PATH changing
            if ($e.StartsWith($HOME, [StringComparison]::OrdinalIgnoreCase)) { $keyPaths.Add($e) }
        }
    }
    $PathDirs = $pathList.ToArray()

    # -- Tool directories -------------------------------------------------------
    # winget portable packages: every package folder holding .exe files goes on
    # PATH where WinGet\Links sits, so tools work even where policy blocks the
    # links winget normally creates (see WinGetPaths.ps1).
    . ([IO.Path]::Combine($Root, 'Scripts', '_lib', 'WinGetPaths.ps1'))
    $wingetDirs = Get-WinGetToolDirs
    $pathList = Merge-WinGetToolDirs -PathList $pathList -ToolDirs $wingetDirs
    foreach ($d in $pathList) { [void]$pathSeen.Add($d.TrimEnd('\')) }
    $PathDirs = $pathList.ToArray()

    $extraDirs = [System.Collections.Generic.List[string]]::new()
    $gitUsrBin = [IO.Path]::Combine($env:ProgramFiles, 'Git', 'usr', 'bin')
    $hasGitUsrBin = [IO.Directory]::Exists($gitUsrBin)
    if ($hasGitUsrBin) { $extraDirs.Add($gitUsrBin) }

    # -- Tool executables ---------------------------------------------------------
    # Same lookup order Get-Command would use for these names: PATH first, then
    # the extra tool directories appended by the profile.
    $searchDirs = [System.Collections.Generic.List[string]]::new()
    foreach ($d in $PathDirs) { if ($d -and -not $d.StartsWith('\\')) { $searchDirs.Add($d) } }
    foreach ($d in $extraDirs) { $searchDirs.Add($d) }
    $toolNames = 'fzf', 'fd', 'eza', 'bat', 'btop4win', 'podman', 'docker', 'sqlgo', 'code'
    $tools = [ordered]@{}
    foreach ($t in $toolNames) {
        foreach ($d in $searchDirs) {
            foreach ($ext in '.exe', '.cmd') {
                # a dangling or blocked link is skipped; a working one resolves to its target
                $p = Resolve-ToolFile ([IO.Path]::Combine([Environment]::ExpandEnvironmentVariables($d), $t + $ext))
                if ($p) { $tools[$t] = $p; break }
            }
            if ($tools.Contains($t)) { break }
        }
    }
    $projpick = [IO.Path]::Combine($Root, 'bin', 'projpick.exe')
    if ([IO.File]::Exists($projpick)) { $tools['projpick'] = $projpick }

    # -- Theme ------------------------------------------------------------------
    $theme = $null
    $themeNames = @()
    $colorsJson = [IO.Path]::Combine($Root, 'Scripts', '_lib', 'themes', 'colors.json')
    $configJson = [IO.Path]::Combine($env:USERPROFILE, '.config', 'scriptutils', 'config.json')
    if ([IO.File]::Exists($colorsJson)) {
        $all = [IO.File]::ReadAllText($colorsJson) | ConvertFrom-Json -AsHashtable
        $themeNames = @($all.Keys | Sort-Object)
        $palette = $null
        $fontFace = $null
        if ([IO.File]::Exists($configJson)) {
            try {
                $cfg = [IO.File]::ReadAllText($configJson) | ConvertFrom-Json -AsHashtable
                $palette = $cfg.theme.palette
                $fontFace = $cfg.font.face
            } catch {}
        }
        if (-not $fontFace) { $fontFace = 'CaskaydiaMono NF' } # `font`'s default
        if (-not $palette) { $palette = 'gruvbox' } # default until `theme` picks one
        if ($palette -and $all[$palette]) {
            $p = $all[$palette].prompt
            $toAnsi = {
                param([string]$h)
                $h = $h.TrimStart('#')
                "`e[38;2;{0};{1};{2}m" -f [Convert]::ToInt32($h.Substring(0, 2), 16), [Convert]::ToInt32($h.Substring(2, 2), 16), [Convert]::ToInt32($h.Substring(4, 2), 16)
            }
            $theme = [ordered]@{
                muted    = & $toAnsi $p.os
                userhost = & $toAnsi $p.user
                path     = & $toAnsi $p.path
                git      = & $toAnsi $p.git
            }
        }
    }

    # -- Project picker theme --------------------------------------------------------
    # bin\projpick.exe (built by profile-setup) reads this on each summon.
    $pickDir = [IO.Path]::Combine($env:LOCALAPPDATA, 'projpick')
    if ([IO.File]::Exists($colorsJson) -and $palette -and $all[$palette]) {
        $t = $all[$palette]
        $hex = { param($v) '#' + "$v".TrimStart('#').ToUpperInvariant() }
        $ini = @(
            "bg=$(& $hex $t.terminal.bg)", "fg=$(& $hex $t.terminal.fg)", "muted=$(& $hex $t.prompt.os)",
            "accent=$(& $hex $t.prompt.user)", "selection=$(& $hex $t.terminal.selection)", "match=$(& $hex $t.prompt.path)",
            # the terminal font, so the picker matches it (it falls back to Segoe UI if not installed)
            "font=$fontFace"
        ) -join "`n"
        [void][IO.Directory]::CreateDirectory($pickDir)
        $iniPath = [IO.Path]::Combine($pickDir, 'theme.ini')
        if (-not [IO.File]::Exists($iniPath) -or [IO.File]::ReadAllText($iniPath) -ne $ini) { [IO.File]::WriteAllText($iniPath, $ini) }
    }

    # -- Script aliases ---------------------------------------------------------
    # Scripts\*.ps1 and Scripts\<dir>\*.ps1. A script may declare aliases with
    # '#.ALIAS name' in its first 20 lines; otherwise its base name is used.
    $aliases = [ordered]@{}
    $scripts = [IO.Path]::Combine($Root, 'Scripts')
    if ([IO.Directory]::Exists($scripts)) {
        $dirs = @($scripts) + [IO.Directory]::GetDirectories($scripts)
        foreach ($dir in $dirs) {
            foreach ($file in [IO.Directory]::GetFiles($dir, '*.ps1')) {
                $names = [System.Collections.Generic.List[string]]::new()
                $n = 0
                foreach ($line in [IO.File]::ReadLines($file)) {
                    if (++$n -gt 20) { break }
                    if ($line -match '^\s*#\.ALIAS\s+(.+)$') { $names.Add($Matches[1].Trim()) }
                }
                if ($names.Count -eq 0) { $names.Add([IO.Path]::GetFileNameWithoutExtension($file)) }
                foreach ($a in $names) { $aliases[$a] = $file }
            }
        }
    }

    # -- Completion sources ------------------------------------------------------
    # Completions\<command>-completion.ps1 files are loaded on first Tab.
    $completionFiles = [ordered]@{}
    $completionsDir = [IO.Path]::Combine($Root, 'Completions')
    if ([IO.Directory]::Exists($completionsDir)) {
        foreach ($f in [IO.Directory]::GetFiles($completionsDir, '*-completion.ps1')) {
            $cmd = [IO.Path]::GetFileName($f) -replace '-completion\.ps1$', ''
            $completionFiles[$cmd] = $f
        }
    }

    # -- Key inputs ---------------------------------------------------------------
    foreach ($e in $extraDirs) { if ($pathSeen.Add($e.TrimEnd('\'))) { $pathList.Add($e) } }
    $scripts = [IO.Path]::Combine($Root, 'Scripts')
    $keyPaths.AddRange([string[]]@(
        "$Root\Scripts\_lib\ProfileCache.ps1", "$Root\Scripts\_lib\themes\colors.json",
        "$HOME\.config\scriptutils\config.json", "$Root\Completions", "$Root\bin",
        "$env:LOCALAPPDATA\Microsoft\WinGet\Packages", "$env:ProgramFiles\WinGet\Packages", "$env:ProgramFiles\Git\usr\bin", $scripts))
    # A winget upgrade swaps the versioned folder inside a package; the old
    # folder disappearing changes its timestamp to "missing".
    $keyPaths.AddRange([string[]]$wingetDirs)
    if ([IO.Directory]::Exists($scripts)) { $keyPaths.AddRange([IO.Directory]::GetDirectories($scripts)) }
    $Key = & $KeyFunction $keyPaths.ToArray()

    # -- Emit -------------------------------------------------------------------
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# generated by Scripts\_lib\ProfileCache.ps1 - do not edit")
    [void]$sb.AppendLine("`$_ppCacheKey = $(& $q $Key)")
    [void]$sb.AppendLine("`$_ppKeyPaths = [string[]]@($(($keyPaths | ForEach-Object { & $q $_ }) -join ', '))")
    [void]$sb.AppendLine("`$_ppPath = $(& $q ([string]::Join(';', $pathList)))")
    [void]$sb.AppendLine("`$_ppGitUsrBin = $(if ($hasGitUsrBin) { & $q $gitUsrBin } else { '$null' })")
    [void]$sb.AppendLine('$_ppTools = @{')
    foreach ($k in $tools.Keys) { [void]$sb.AppendLine("    $k = $(& $q $tools[$k])") }
    [void]$sb.AppendLine('}')
    if ($theme) {
        [void]$sb.AppendLine('$_ppTheme = @{')
        foreach ($k in $theme.Keys) { [void]$sb.AppendLine("    $k = `"$($theme[$k].Replace("`e", '`e'))`"") }
        [void]$sb.AppendLine('}')
    } else {
        [void]$sb.AppendLine('$_ppTheme = $null')
    }
    [void]$sb.AppendLine("`$_ppThemeNames = @($(($themeNames | ForEach-Object { & $q $_ }) -join ', '))")

    # Aliases, applied in order (later entries win). Built-ins that must go
    # away entirely (not just be replaced) are listed in $_ppUnaliases.
    $all = [System.Collections.Generic.List[string[]]]::new()
    foreach ($k in $aliases.Keys) { $all.Add(@($k, $aliases[$k])) }
    if ($hasGitUsrBin) {
        foreach ($t in 'grep', 'awk', 'sed', 'sort', 'diff', 'tr', 'head', 'tail', 'wc', 'cut', 'uniq',
            'xargs', 'vim', 'nano', 'less', 'ssh-keygen', 'ssh', 'du', 'file') {
            $all.Add(@($t, [IO.Path]::Combine($gitUsrBin, "$t.exe")))
        }
    }
    $all.Add(@('which', 'Get-Command'))
    if (-not $tools.Contains('docker') -and $tools.Contains('podman')) { $all.Add(@('docker', 'podman')) }
    if ($tools.Contains('btop4win')) { $all.Add(@('btop', 'btop4win')) }
    if (-not $tools.Contains('eza')) { $all.Add(@('ll', 'Get-ChildItem')); $all.Add(@('la', 'Get-ChildItem')) }
    $all.Add(@('pu', 'profile-update'))
    if ($tools.Contains('projpick')) { $all.Add(@('projpick', $tools['projpick'])) }
    $unaliases = [System.Collections.Generic.List[string]]@('pwd', 'curl')
    if (-not $hasGitUsrBin) { $unaliases.Add('sort'); $unaliases.Add('diff') }
    if ($tools.Contains('eza')) { $unaliases.Add('ls'); $unaliases.Add('tree') }
    if ($tools.Contains('bat')) { $unaliases.Add('cat') }
    [void]$sb.AppendLine("`$_ppUnaliases = @($(($unaliases | ForEach-Object { & $q $_ }) -join ', '))")
    [void]$sb.AppendLine('$_ppAliases = [string[]]@(')
    foreach ($a in $all) { [void]$sb.AppendLine("    $(& $q $a[0]), $(& $q $a[1])") }
    [void]$sb.AppendLine(')')
    [void]$sb.AppendLine('$_ppCompletionFiles = @{')
    foreach ($k in $completionFiles.Keys) { [void]$sb.AppendLine("    $(& $q $k) = $(& $q $completionFiles[$k])") }
    [void]$sb.AppendLine('}')

    # Keep the user PATH in step with winget packages when that was chosen in profile-setup.
    Update-WinGetUserPath

    # Atomic replace: two shells starting at once must never read a half-written file.
    $dir = [IO.Path]::GetDirectoryName($CacheFile)
    [void][IO.Directory]::CreateDirectory($dir)
    $tmp = [IO.Path]::Combine($dir, "cache.$PID.$([Environment]::TickCount64).tmp")
    [IO.File]::WriteAllText($tmp, $sb.ToString(), [Text.UTF8Encoding]::new($false))
    [IO.File]::Move($tmp, $CacheFile, $true)
}
