#===============================================================================
# PowerShell Profile
#===============================================================================
#
# Startup budget: this file must stay cheap. Rules that keep it that way
# (measured on Windows 11 with Defender real-time protection on):
#
#   - No Get-Command at startup. A miss triggers module auto-discovery
#     (~470 ms). Tool locations come from the startup cache instead.
#   - No cmdlets from Microsoft.PowerShell.Utility / .Management at startup
#     (Set-Alias, Get-Date, Write-Host, Test-Path, Get-Content, Set-Location...).
#     Only PSReadLine is loaded when the profile runs, and the first call into
#     either module costs 35-90 ms. Use .NET and $ExecutionContext APIs.
#   - No child processes at startup. Under real-time protection every spawn is
#     scanned; `sqlgo completion pwsh` alone cost ~100 ms warm, seconds cold.
#   - Anything that is expensive to discover goes into the startup cache
#     (Scripts\_lib\ProfileCache.ps1), rebuilt only when its inputs change.
#
# Set PWSH_PROFILE_TIMING=1 to print a per-section timing breakdown.

$_ppSw = [System.Diagnostics.Stopwatch]::StartNew()
$_ppRoot = $PSScriptRoot
$_ppTiming = "$env:PWSH_PROFILE_TIMING" -in '1', 'true', 'yes', 'on'
function _tm([string]$Label) {
    if ($_ppTiming) { [Console]::WriteLine("`e[90m[tm +{0,7:N1} ms] {1}`e[0m", $_ppSw.Elapsed.TotalMilliseconds, $Label) }
}

$_ppInteractive = $false
try {
    $_ppInteractive = [Environment]::UserInteractive -and
        -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected -and
        $null -ne $Host.UI.RawUI
} catch {}
_tm 'start'

#-------------------------------------------------------------------------------
# ENVIRONMENT & PATH
#-------------------------------------------------------------------------------

# UTF-8 output (no BOM) — required for Nerd Font glyphs in the prompt
$_ppUtf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $_ppUtf8
$OutputEncoding = $_ppUtf8

# PATH is rebuilt from the registry (Machine then User, de-duplicated, order
# kept) so a terminal started by a long-running parent still sees new installs.
# The merge result is cached together with everything else, keyed on the two
# registry strings, so a warm start only reads them and compares.
$_ppMachinePath = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
$_ppUserPath = [Environment]::GetEnvironmentVariable('PATH', 'User')

# Default to Home if launched in System32
if ($PWD.ProviderPath -ieq "$env:windir\System32") { $null = $ExecutionContext.SessionState.Path.SetLocation($HOME) }
_tm 'environment'

#-------------------------------------------------------------------------------
# SETUP (once per repo commit)
#-------------------------------------------------------------------------------
# After a fresh clone or a `git pull`, the first interactive terminal runs
# Scripts\setup.ps1 (`profile-setup`): it builds bin\projpick.exe, offers
# optional tools, and cleans up after older versions. The check reads the
# commit from .git directly (two small files, no git process).
# Set PWSH_PROFILE_NO_SETUP=1 to skip it.

function _ppGitHead {
    $git = "$_ppRoot\.git"
    if ([IO.File]::Exists($git)) {
        $link = [IO.File]::ReadAllText($git).Trim()
        if ($link.StartsWith('gitdir: ')) { $git = [IO.Path]::GetFullPath([IO.Path]::Combine($_ppRoot, $link.Substring(8))) }
    }
    if (-not [IO.Directory]::Exists($git)) { return 'nogit-' + [IO.File]::GetLastWriteTimeUtc("$_ppRoot\Scripts\setup.ps1").Ticks }
    $head = [IO.File]::ReadAllText("$git\HEAD").Trim()
    if (-not $head.StartsWith('ref: ')) { return $head }
    $ref = $head.Substring(5)
    if ([IO.File]::Exists("$git\$ref")) { return [IO.File]::ReadAllText("$git\$ref").Trim() }
    if ([IO.File]::Exists("$git\packed-refs")) {
        foreach ($l in [IO.File]::ReadLines("$git\packed-refs")) { if ($l.EndsWith(" $ref")) { return $l.Substring(0, $l.IndexOf(' ')) } }
    }
    $head
}

if ($_ppInteractive -and -not $env:PWSH_PROFILE_NO_SETUP) {
    try {
        # Common case inline (.git folder + loose ref); the function covers
        # packed refs, worktrees and copies without .git.
        $_ppHead = $null
        $_ppGit = "$_ppRoot\.git\"
        if ([IO.File]::Exists("${_ppGit}HEAD")) {
            $_ppHead = [IO.File]::ReadAllText("${_ppGit}HEAD").Trim()
            if ($_ppHead.StartsWith('ref: ') -and [IO.File]::Exists($_ppGit + $_ppHead.Substring(5))) {
                $_ppHead = [IO.File]::ReadAllText($_ppGit + $_ppHead.Substring(5)).Trim()
            }
        }
        if (-not $_ppHead -or $_ppHead.StartsWith('ref: ')) { $_ppHead = _ppGitHead }
        $_ppSetupFile = "$env:LOCALAPPDATA\pwsh-profile\setup-commit.txt"
        if (-not [IO.File]::Exists($_ppSetupFile) -or [IO.File]::ReadAllText($_ppSetupFile).Trim() -ne $_ppHead) {
            & "$_ppRoot\Scripts\setup.ps1" --auto
            # Tools installed by setup change the registry PATH
            $_ppMachinePath = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
            $_ppUserPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
        }
    } catch {
        [Console]::WriteLine("`e[33mprofile: setup failed ($_); run profile-setup to retry`e[0m")
    }
}
_tm 'setup check'

#-------------------------------------------------------------------------------
# STARTUP CACHE
#-------------------------------------------------------------------------------
# The key is a handful of timestamp reads plus the registry PATH strings. It
# changes after a git pull (git rewrites changed files, which bumps directory
# times), theme changes (config.json), tool installs (PATH, WinGet packages,
# user-writable PATH dirs such as scoop shims) and new scripts. Network paths
# are never touched. `profile-rebuild` forces a rebuild.

$_ppCacheDir = "$env:LOCALAPPDATA\pwsh-profile"
$_ppCacheFile = "$_ppCacheDir\cache.ps1"

function _ppComputeKey([string[]]$Paths) {
    $k = [System.Text.StringBuilder]::new('v5')
    foreach ($p in $Paths) { $null = $k.Append('|').Append([IO.File]::GetLastWriteTimeUtc($p).Ticks) }
    $k.Append('|').Append($_ppMachinePath).Append('|').Append($_ppUserPath).ToString()
}

function profile-rebuild {
    <# Rebuild the startup cache (tool paths, theme colors, script aliases, PATH). #>
    param([switch]$Quiet)
    . "$_ppRoot\Scripts\_lib\ProfileCache.ps1"
    Build-ProfileCache -Root $_ppRoot -CacheFile $_ppCacheFile -MachinePath $_ppMachinePath -UserPath $_ppUserPath -KeyFunction ${function:_ppComputeKey}
    if (-not $Quiet) { Write-Host 'Profile cache rebuilt. Open a new shell to use it.' -ForegroundColor DarkGray }
}

$_ppCacheKey = $null
if ([IO.File]::Exists($_ppCacheFile)) { . $_ppCacheFile }
if (-not $_ppCacheKey -or $_ppCacheKey -ne (_ppComputeKey $_ppKeyPaths)) {
    _tm 'cache stale, rebuilding'
    if ($_ppTiming -and $_ppCacheKey) {
        $_ppOld = $_ppCacheKey.Split('|'); $_ppNew = (_ppComputeKey $_ppKeyPaths).Split('|')
        for ($_ppI = 1; $_ppI -lt $_ppNew.Length; $_ppI++) {
            if ($_ppOld[$_ppI] -ne $_ppNew[$_ppI]) { [Console]::WriteLine("  key changed: $(if ($_ppI -le $_ppKeyPaths.Length) { $_ppKeyPaths[$_ppI - 1] } else { 'registry PATH' })") }
        }
    }
    try {
        profile-rebuild -Quiet
        . $_ppCacheFile
    } catch {
        [Console]::WriteLine("`e[33mprofile: startup cache rebuild failed ($_); continuing without it`e[0m")
    }
}
# A failed rebuild must degrade gracefully, never leave PATH empty.
if (-not $_ppPath) { $_ppPath = "$_ppMachinePath;$_ppUserPath" }
if (-not $_ppTools) { $_ppTools = @{} }
if (-not $_ppAliases) { $_ppAliases = [string[]]@() }
if (-not $_ppUnaliases) { $_ppUnaliases = @() }
if (-not $_ppCompletionFiles) { $_ppCompletionFiles = @{} }
$env:PATH = $_ppPath
_tm 'cache'

#-------------------------------------------------------------------------------
# ALIASES
#-------------------------------------------------------------------------------
# Script aliases (#.ALIAS headers), Git for Windows Unix tools, and the rest
# come from the cache as one flat name/value list. They are created through
# the provider API (what Set-Alias does underneath) so that
# Microsoft.PowerShell.Utility is never loaded at startup; force=$true replaces
# built-ins such as sort/diff in one step.

$_ppItems = $ExecutionContext.SessionState.InvokeProvider.Item
foreach ($_ppEntry in $_ppUnaliases) {
    if ($_ppItems.Exists("Alias:\$_ppEntry")) { $null = $_ppItems.Remove([string[]]"Alias:\$_ppEntry", $false, $true, $true) }
}
$_ppEntry = [string[]]'Alias:\'
for ($_ppI = 0; $_ppI -lt $_ppAliases.Length; $_ppI += 2) {
    $null = $_ppItems.New($_ppEntry, $_ppAliases[$_ppI], '', $_ppAliases[$_ppI + 1], $true)
}
_tm 'aliases'

#-------------------------------------------------------------------------------
# PROMPT
#-------------------------------------------------------------------------------

$global:_c = @{
    reset    = "`e[0m"
    muted    = "`e[90m"
    userhost = "`e[34m"
    path     = "`e[35m"
    git      = "`e[36m"
}
if ($_ppTheme) { foreach ($_ppEntry in $_ppTheme.Keys) { $global:_c[$_ppEntry] = $_ppTheme[$_ppEntry] } }

$_ppHome = [Environment]::GetFolderPath('UserProfile')
$_ppUserHost = "$env:USERNAME@$env:COMPUTERNAME"

function prompt {
    if ($global:_transientPrompt) {
        $global:_transientPrompt = $false
        return "`e[90m`u{f105}`e[0m "
    }
    $c = $global:_c
    $notice = ''
    if ($global:_ppUpdateProc -and $global:_ppUpdateProc.HasExited) { $notice = _ppTakeNotice; $global:_ppUpdateProc = $null }

    $loc = $ExecutionContext.SessionState.Path.CurrentLocation
    $full = $loc.ProviderPath

    # Fish-style path: first char of intermediate dirs
    $cur = $full
    if ($cur.StartsWith($_ppHome, [StringComparison]::OrdinalIgnoreCase)) { $cur = '~' + $cur.Substring($_ppHome.Length) }
    $parts = $cur.Split([char[]]'\/')
    if ($parts.Length -gt 2) {
        $sb = [System.Text.StringBuilder]::new($parts[0])
        for ($i = 1; $i -lt $parts.Length - 1; $i++) {
            if ($parts[$i].Length -gt 0) { [void]$sb.Append('\').Append($parts[$i][0]) }
        }
        $cur = $sb.Append('\').Append($parts[-1]).ToString()
    }

    # Git branch: read HEAD directly (no process). FileSystem only, so registry
    # paths are never resolved against the process working directory.
    $gitStr = ''
    if ($loc.Provider.Name -eq 'FileSystem') {
        $d = $full
        while ($d) {
            $gitPath = [IO.Path]::Combine($d, '.git')
            $headFile = $null
            if ([IO.Directory]::Exists($gitPath)) {
                $headFile = [IO.Path]::Combine($gitPath, 'HEAD')
            } elseif ([IO.File]::Exists($gitPath)) {
                # Worktree / submodule: .git file contains "gitdir: <path>"
                $link = [IO.File]::ReadAllText($gitPath).Trim()
                if ($link.StartsWith('gitdir: ')) {
                    $gd = $link.Substring(8)
                    if (-not [IO.Path]::IsPathRooted($gd)) { $gd = [IO.Path]::GetFullPath([IO.Path]::Combine($d, $gd)) }
                    $headFile = [IO.Path]::Combine($gd, 'HEAD')
                }
            }
            if ($headFile -and [IO.File]::Exists($headFile)) {
                $head = [IO.File]::ReadAllText($headFile).Trim()
                $branch = if ($head.StartsWith('ref: refs/heads/')) { $head.Substring(16) } else { $head.Substring(0, [Math]::Min(7, $head.Length)) }
                $gitStr = "$($c.git)`u{e725} $branch $($c.reset)"
                break
            }
            $parent = [IO.Path]::GetDirectoryName($d)
            if (-not $parent -or $parent -eq $d) { break }
            $d = $parent
        }
    }

    "$notice$($c.muted)`u{e70f} $($c.reset)$($c.userhost)$_ppUserHost $($c.reset)$($c.path)$cur $($c.reset)$gitStr$($c.muted)`u{f105}$($c.reset) "
}
_tm 'prompt'

#-------------------------------------------------------------------------------
# PSREADLINE
#-------------------------------------------------------------------------------

if ($_ppInteractive) {
    Set-PSReadLineOption -EditMode Emacs -PredictionSource HistoryAndPlugin -PredictionViewStyle ListView `
        -Colors @{ InlinePrediction = $global:_c.muted }

    # Right/Left move one character and Home/End go to the ends of the line
    # (Emacs-mode defaults). Up/Down pick from the prediction list.

    # Tab completion menu like zsh
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

    # Paste without executing. PSReadLine's own Paste strips \r (and turns tabs
    # into spaces) and reads the clipboard natively — no WinForms load.
    # Windows Terminal handles these keys itself and types the text in; the
    # Enter handler below keeps that from running a multi-line paste.
    Set-PSReadLineKeyHandler -Key Ctrl+v, Ctrl+Shift+v, Shift+Insert -Function Paste

    # Linux-style keybindings
    Set-PSReadLineKeyHandler -Key Ctrl+l -Function ClearScreen
    Set-PSReadLineKeyHandler -Key Ctrl+d -Function DeleteCharOrExit
    Set-PSReadLineKeyHandler -Key Ctrl+u -Function BackwardDeleteLine
    Set-PSReadLineKeyHandler -Key Ctrl+w -Function BackwardDeleteWord
    Set-PSReadLineKeyHandler -Key Ctrl+LeftArrow -Function BackwardWord
    Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord
    # KillWord (to the end of the word), like Alt+D: VS Code turns Ctrl+Delete
    # into Alt+D, so this keeps both terminals the same.
    Set-PSReadLineKeyHandler -Key Ctrl+Delete -Function KillWord
    Set-PSReadLineKeyHandler -Key Ctrl+Backspace -Function BackwardDeleteWord
    Set-PSReadLineKeyHandler -Key Ctrl+z -Function Undo

    # Selection and clipboard, Windows-style. Ctrl+C copies a selection (or
    # cancels the line when nothing is selected), which is the Emacs default.
    # Binding Ctrl+X replaces the Emacs Ctrl+X chords (Ctrl+X Ctrl+U is Ctrl+Z).
    Set-PSReadLineKeyHandler -Key Ctrl+Shift+LeftArrow -Function SelectBackwardWord
    Set-PSReadLineKeyHandler -Key Ctrl+Shift+RightArrow -Function SelectForwardWord
    Set-PSReadLineKeyHandler -Key Ctrl+x, Shift+Delete -Function Cut
    Set-PSReadLineKeyHandler -Key Ctrl+Insert, Ctrl+Shift+c -Function Copy

    # Transient prompt: collapse the previous prompt to ❯ on Enter.
    #   - only when the buffer parses cleanly (multi-line `if () {` still gets a newline)
    #   - not for multi-line input (pasted blocks stay expanded)
    #   - flag reset in `finally` so a throw can't leave the next prompt stuck transient
    #   - $key/$arg forwarded to AcceptLine so predictions/history stay in sync
    #   - ESC[0J afterwards wipes ListView prediction rows below the prompt
    # An Enter with more input already waiting is part of a paste that the
    # terminal typed in (Windows Terminal's Ctrl+V): it becomes a new line
    # instead of running the first line of the paste. PSReadLine reads ahead
    # into a private queue, so the console buffer alone looks empty. Finding
    # that queue costs ~9 ms, so it happens on idle (below) or at the first
    # Enter; if a future PSReadLine renames it, only the console check remains.
    function global:_ppFindKeyQueue {
        $global:_ppKeyQueue = $false
        try {
            $rl = [Microsoft.PowerShell.PSConsoleReadLine]
            $global:_ppKeyQueue = $rl.GetField('_queuedKeys', [Reflection.BindingFlags]'NonPublic,Instance').GetValue(
                $rl.GetField('_singleton', [Reflection.BindingFlags]'NonPublic,Static').GetValue($null))
        } catch {}
    }
    Set-PSReadLineKeyHandler -Key Enter -ScriptBlock {
        param($key, $arg)
        if ($null -eq $global:_ppKeyQueue) { _ppFindKeyQueue }
        $q = $global:_ppKeyQueue
        if (($q -is [System.Collections.ICollection] -and $q.Count -gt 0) -or [Console]::KeyAvailable) {
            [Microsoft.PowerShell.PSConsoleReadLine]::AddLine()
            return
        }
        $ast = $null; $cursor = $null; $parseErrors = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$null, [ref]$parseErrors, [ref]$cursor)
        $line = $ast.Extent.Text
        if ($line -and $parseErrors.Count -eq 0 -and -not $line.Contains("`n")) {
            $global:_transientPrompt = $true
            try {
                [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
                [Console]::Write("`e[0J")
            } finally {
                $global:_transientPrompt = $false
            }
        }
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine($key, $arg)
    }

    if ($_ppTools.fzf) {
        # Ctrl+R: fuzzy history, newest first, de-duplicated
        Set-PSReadLineKeyHandler -Key Ctrl+r -ScriptBlock {
            $line = $null; $cursor = $null
            [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
            $items = [Microsoft.PowerShell.PSConsoleReadLine]::GetHistoryItems()
            $seen = [System.Collections.Generic.HashSet[string]]::new()
            $list = [System.Collections.Generic.List[string]]::new($items.Count)
            for ($i = $items.Count - 1; $i -ge 0; $i--) {
                $cl = $items[$i].CommandLine
                if ($seen.Add($cl)) { $list.Add($cl) }
            }
            $selected = $list | & $_ppTools.fzf --no-sort --scheme=history "--query=$line"
            if ($selected) {
                [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
                [Microsoft.PowerShell.PSConsoleReadLine]::Insert(($selected -join "`n"))
            }
        }

        # Ctrl+T: fuzzy file picker (fd when installed)
        Set-PSReadLineKeyHandler -Key Ctrl+t -ScriptBlock {
            $selected = if ($_ppTools.fd) {
                & $_ppTools.fd --type f --hidden --exclude .git | & $_ppTools.fzf
            } else {
                [IO.Directory]::EnumerateFiles($PWD.ProviderPath, '*', [IO.EnumerationOptions]@{ RecurseSubdirectories = $true; IgnoreInaccessible = $true }) | & $_ppTools.fzf
            }
            if ($selected) { [Microsoft.PowerShell.PSConsoleReadLine]::Insert($selected) }
        }
    }
}
_tm 'psreadline'

#-------------------------------------------------------------------------------
# COMPLETIONS (loaded on first Tab, never at startup)
#-------------------------------------------------------------------------------
# A stub completer is registered per command. On first use it loads the real
# completion script into a dynamic module (so its helper functions survive),
# which replaces the stub, then re-runs the completion so that first Tab
# already returns real results.

$_ppLazyCompletion = @{}
if ($_ppTools.sqlgo) {
    $_ppLazyCompletion.sqlgo = {
        $exe = $_ppTools.sqlgo
        $file = [IO.Path]::Combine($_ppCacheDir, "completion-sqlgo-$([IO.File]::GetLastWriteTimeUtc($exe).Ticks).ps1")
        if (-not [IO.File]::Exists($file)) {
            [IO.File]::WriteAllText($file, ((& $exe completion pwsh) -join "`n"))
        }
        [IO.File]::ReadAllText($file)
    }
}
if ($_ppThemeNames -and -not $_ppCompletionFiles.theme) {
    # theme <Tab>: palette names from the cache (a Completions\theme-completion.ps1 file takes precedence)
    $_ppLazyCompletion.theme = {
        'Register-ArgumentCompleter -Native -CommandName theme -ScriptBlock { param($w) foreach ($n in $_ppThemeNames) { if ($n.StartsWith($w, [StringComparison]::OrdinalIgnoreCase)) { [System.Management.Automation.CompletionResult]::new($n, $n, ''ParameterValue'', $n) } } }'
    }
}
foreach ($_ppEntry in $_ppCompletionFiles.GetEnumerator()) {
    $_ppLazyCompletion[$_ppEntry.Key] = [scriptblock]::Create("[IO.File]::ReadAllText('$($_ppEntry.Value.Replace("'", "''"))')")
}
if ($_ppLazyCompletion.Count -gt 0) {
    $_ppCompletionStub = {
        param($wordToComplete, $commandAst, $cursorPosition)
        $name = [IO.Path]::GetFileNameWithoutExtension($commandAst.GetCommandName())
        $loader = $_ppLazyCompletion[$name]
        if (-not $loader) { return }
        $_ppLazyCompletion.Remove($name)
        # Completion scripts written for -CommandName without -Native (cobra) are
        # registered as native here, so they replace this stub.
        $prelude = 'function Register-ArgumentCompleter { param([string[]]$CommandName, [string]$ParameterName, [scriptblock]$ScriptBlock, [switch]$Native) ' +
            '$a = @{ CommandName = $CommandName; ScriptBlock = $ScriptBlock }; if ($ParameterName) { $a.ParameterName = $ParameterName } else { $a.Native = $true }; ' +
            'Microsoft.PowerShell.Core\Register-ArgumentCompleter @a }' + "`n"
        try {
            $null = New-Module -Name "completion-$name" -ScriptBlock ([scriptblock]::Create($prelude + (& $loader)))
        } catch { return }
        $full = $commandAst.Extent.StartScriptPosition.GetFullScript()
        (TabExpansion2 -inputScript $full -cursorColumn $cursorPosition).CompletionMatches
    }
    Register-ArgumentCompleter -Native -CommandName ([string[]]$_ppLazyCompletion.Keys) -ScriptBlock $_ppCompletionStub
}
_tm 'completions'

#-------------------------------------------------------------------------------
# ENHANCED TOOLS (eza, bat)
#-------------------------------------------------------------------------------

if ($_ppTools.eza) {
    function ls   { eza --icons --group-directories-first @args }
    function ll   { eza -l --icons --group-directories-first @args }
    function la   { eza -la --icons --group-directories-first @args }
    function tree { eza --tree --icons @args }
}
if ($_ppTools.bat) {
    function cat { bat --paging=never @args }
}

#-------------------------------------------------------------------------------
# PROJECTS (z, zi, zopen) — shares the index kept by bin\projpick.exe
#-------------------------------------------------------------------------------

$_ppProjectIndex = [IO.Path]::Combine($env:LOCALAPPDATA, 'projpick', 'projects.tsv')

function _ppProjectList {
    # name<TAB>path per line; projpick keeps it fresh in the background
    if (-not [IO.File]::Exists($_ppProjectIndex) -and $_ppTools.projpick) {
        & $_ppTools.projpick --scan | Out-Null
    }
    if (-not [IO.File]::Exists($_ppProjectIndex)) { return }
    foreach ($l in [IO.File]::ReadAllLines($_ppProjectIndex)) {
        $tab = $l.IndexOf("`t")
        if ($tab -gt 0) { [pscustomobject]@{ Name = $l.Substring(0, $tab); Path = $l.Substring($tab + 1) } }
    }
}

function _ppResolveProject([string]$Name) {
    if (-not $Name) { return $(if ($env:Z_PROJECTS_ROOT) { $env:Z_PROJECTS_ROOT } else { [IO.Path]::Combine($HOME, 'Projects') }) }
    if ([IO.Path]::IsPathRooted($Name) -and [IO.Directory]::Exists($Name)) { return $Name }
    $all = @(_ppProjectList)
    foreach ($test in { $_.Name -eq $Name }, { $_.Name.StartsWith($Name, [StringComparison]::OrdinalIgnoreCase) },
        { $_.Name.Contains($Name, [StringComparison]::OrdinalIgnoreCase) }, { $_.Path.Contains($Name, [StringComparison]::OrdinalIgnoreCase) }) {
        $hits = @($all.Where($test))
        if ($hits.Count -eq 1) { return $hits[0].Path }
        if ($hits.Count -gt 1) {
            if ($_ppTools.fzf) {
                $pick = $hits | ForEach-Object { "$($_.Name)`t$($_.Path)" } | & $_ppTools.fzf --delimiter "`t" --with-nth 1,2 --select-1 "--query=$Name"
                if ($pick) { return $pick.Split("`t")[1] }
                return
            }
            return $hits[0].Path
        }
    }
    if ([IO.Directory]::Exists($Name)) { return [IO.Path]::GetFullPath($Name, $PWD.ProviderPath) }
    Write-Host "z: project not found: $Name" -ForegroundColor Red
}

$_ppProjectCompleter = {
    # Unique names complete to the name; names shared by several projects
    # complete to the full path so the result is unambiguous.
    param($commandName, $parameterName, $wordToComplete)
    $all = @(_ppProjectList)
    $count = @{}
    foreach ($p in $all) { $count[$p.Name] = 1 + [int]$count[$p.Name] }
    foreach ($p in $all) {
        if (-not $p.Name.StartsWith($wordToComplete, [StringComparison]::OrdinalIgnoreCase)) { continue }
        $text = if ($count[$p.Name] -gt 1) { "'$($p.Path.Replace("'", "''"))'" } else { $p.Name }
        $shown = if ($count[$p.Name] -gt 1) { "$($p.Name)  $($p.Path.Replace($HOME, '~'))" } else { $p.Name }
        [System.Management.Automation.CompletionResult]::new($text, $shown, 'ParameterValue', $p.Path)
    }
}

function z {
    <# Jump to a project by name (exact, prefix, then substring match). No name: ~\Projects. #>
    param([ArgumentCompleter({ & $_ppProjectCompleter @args })][string]$Name)
    $dir = _ppResolveProject $Name
    if ($dir) { Set-Location -LiteralPath $dir }
}

function zi {
    <# Pick a project with fzf and jump to it. #>
    if (-not $_ppTools.fzf) { Write-Host 'zi: fzf is required' -ForegroundColor Red; return }
    $pick = _ppProjectList | ForEach-Object { "$($_.Name)`t$($_.Path)" } | & $_ppTools.fzf --delimiter "`t" --with-nth 1,2
    if ($pick) { Set-Location -LiteralPath $pick.Split("`t")[1] }
}

function zopen {
    <# Open a project in the editor ($env:Z_PROJECT_EDITOR, default code). #>
    param([ArgumentCompleter({ & $_ppProjectCompleter @args })][string]$Name)
    $dir = if ($Name) { _ppResolveProject $Name } else { $PWD.ProviderPath }
    if (-not $dir) { return }
    $editor = if ($env:Z_PROJECT_EDITOR) { $env:Z_PROJECT_EDITOR } else { 'code' }
    & $editor $dir
}

#-------------------------------------------------------------------------------
# FUNCTIONS - File Operations
#-------------------------------------------------------------------------------

function pwd { $ExecutionContext.SessionState.Path.CurrentLocation.Path }

function touch {
    param([Parameter(Mandatory, ValueFromPipeline)]$Path)
    process {
        if (Test-Path $Path) {
            (Get-Item $Path).LastWriteTime = Get-Date
        } else {
            New-Item -ItemType File -Path $Path | Out-Null
        }
    }
}

function mkdirp {
    param([Parameter(Mandatory)]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function rmrf {
    param([Parameter(Mandatory)]$Path)
    Remove-Item -Path $Path -Recurse -Force
}

function mkcd {
    param([Parameter(Mandatory)]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Set-Location $Path
}

function ff {
    param(
        [Parameter(Position = 0)][string]$Path = '.',
        [Alias('name')][string]$Filter = '*'
    )
    Get-ChildItem -Path $Path -Recurse -Filter $Filter -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName
}

function open {
    param([Parameter(Mandatory)]$Path)
    Start-Process $Path
}

#-------------------------------------------------------------------------------
# FUNCTIONS - Navigation
#-------------------------------------------------------------------------------

function .. { Set-Location .. }
function ... { Set-Location ..\.. }
function .... { Set-Location ..\..\.. }

#-------------------------------------------------------------------------------
# FUNCTIONS - System Info & Processes
#-------------------------------------------------------------------------------

function df {
    Get-PSDrive -PSProvider FileSystem |
        Select-Object Name,
        @{N = 'Used(GB)'; E = { [math]::Round($_.Used / 1GB, 2) } },
        @{N = 'Free(GB)'; E = { [math]::Round($_.Free / 1GB, 2) } },
        @{N = 'Total(GB)'; E = { [math]::Round(($_.Used + $_.Free) / 1GB, 2) } },
        @{N = 'Use%'; E = { [math]::Round($_.Used / ($_.Used + $_.Free) * 100, 1) } }
}

function psl {
    Get-Process | Select-Object Id, ProcessName, CPU,
        @{N = 'Mem(MB)'; E = { [math]::Round($_.WorkingSet64 / 1MB, 2) } } |
        Sort-Object -Property 'Mem(MB)' -Descending
}

function pkill {
    param([Parameter(Mandatory)]$Name)
    Get-Process -Name $Name -ErrorAction SilentlyContinue | Stop-Process -Force
}

function Format-CommandInvocation {
    param([object[]]$Tokens)
    if (-not $Tokens -or $Tokens.Count -eq 0) { return $null }
    $quoted = foreach ($token in $Tokens) {
        [System.Management.Automation.Language.CodeGeneration]::QuoteArgument([string]$token)
    }
    return '& ' + ($quoted -join ' ')
}

function Invoke-ArgumentCommand {
    param([object[]]$CommandTokens)
    if (-not $CommandTokens -or $CommandTokens.Count -eq 0) { throw 'No command provided.' }
    $commandName = [string]$CommandTokens[0]
    $commandArgs = @($CommandTokens | Select-Object -Skip 1)
    & $commandName @commandArgs
}

function sudo {
    if (-not $args -or $args.Count -eq 0) {
        Start-Process pwsh -Verb RunAs
        return
    }
    $commandText = Format-CommandInvocation $args
    Start-Process pwsh -Verb RunAs -ArgumentList '-NoExit', '-Command', $commandText
}

#-------------------------------------------------------------------------------
# FUNCTIONS - Shell Utilities
#-------------------------------------------------------------------------------

function h { Get-History | Select-Object -Last 50 }

function clear-history {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $historyPath = $null
    try { $historyPath = (Get-PSReadLineOption).HistorySavePath } catch {}

    $target = if ($historyPath) {
        "PowerShell session history and PSReadLine history file '$historyPath'"
    } else {
        'PowerShell session history'
    }
    if (-not $PSCmdlet.ShouldProcess($target, 'Clear')) { return }

    Microsoft.PowerShell.Core\Clear-History
    $psConsoleReadLine = 'Microsoft.PowerShell.PSConsoleReadLine' -as [type]
    if ($psConsoleReadLine) { $psConsoleReadLine::ClearHistory() }
    if ($historyPath -and (Test-Path -LiteralPath $historyPath)) {
        Set-Content -LiteralPath $historyPath -Value $null -NoNewline
    }
    Write-Host 'Command history cleared.' -ForegroundColor DarkGray
}

function export {
    param([Parameter(Mandatory)]$Assignment)
    $parts = $Assignment -split '=', 2
    [Environment]::SetEnvironmentVariable($parts[0], $parts[1], 'Process')
}

function watch {
    param(
        [Alias('n')][int]$Interval,
        [Parameter(ValueFromRemainingArguments)]$Command
    )
    # Parse leading -n <seconds> from remaining args (like linux watch)
    if (-not $Interval -and $Command.Count -ge 2 -and $Command[0] -eq '-n') {
        $Interval = [int]$Command[1]
        $Command = @($Command | Select-Object -Skip 2)
    }
    if (-not $Interval) { $Interval = 2 }
    $cmdStr = Format-CommandInvocation $Command
    if (-not $cmdStr) { Write-Host 'Usage: watch [-n secs] <command>'; return }
    while ($true) {
        Clear-Host
        $now = Get-Date -Format 'HH:mm:ss'
        Write-Host "Every ${Interval}.0s: $cmdStr    $now" -ForegroundColor DarkGray
        Write-Host ''
        try { Invoke-ArgumentCommand $Command } catch { Write-Host $_.Exception.Message -ForegroundColor Red }
        Start-Sleep -Seconds $Interval
    }
}

function time {
    param([Parameter(ValueFromRemainingArguments)]$Command)
    if (-not $Command -or $Command.Count -eq 0) {
        Write-Host 'Usage: time <command>' -ForegroundColor Yellow
        return
    }
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Invoke-ArgumentCommand $Command
    } finally {
        $stopwatch.Stop()
        Write-Host ("`nreal {0:mm\:ss\.fff}" -f $stopwatch.Elapsed) -ForegroundColor DarkGray
    }
}

#-------------------------------------------------------------------------------
# UPDATES (weekly, in the background — never blocks startup)
#-------------------------------------------------------------------------------

$_ppStampFile = [IO.Path]::Combine($_ppRoot, 'LastUpdateCheck.txt')
$_ppNoticeFile = [IO.Path]::Combine($_ppCacheDir, 'update-notice.txt')
$_ppUpdateProc = $null

function _ppTakeNotice {
    if (-not [IO.File]::Exists($_ppNoticeFile)) { return '' }
    $text = ''
    try {
        $text = ([IO.File]::ReadAllLines($_ppNoticeFile) | ForEach-Object { "`e[33m$_`e[0m`n" }) -join ''
        [IO.File]::Delete($_ppNoticeFile)
    } catch {}
    $text
}

function profile-update {
    . ([IO.Path]::Combine($_ppRoot, 'Scripts', '_lib', 'UpdateCheck.ps1'))
    Write-Host 'Checking for PowerShell updates...' -ForegroundColor Cyan
    try { $null = _Check-PwshVersion -AutoUpdate } catch { Write-Warning "Failed to check PowerShell version: $_" }
    Write-Host ''
    Write-Host 'Checking for profile updates...' -ForegroundColor Cyan
    try { _Check-ProfileUpdates -ProfileDir $_ppRoot -AutoPull } catch { Write-Warning "Failed to check profile updates: $_" }
    [IO.File]::WriteAllText($_ppStampFile, [datetime]::Now.ToString('yyyy-MM-dd'))
}

if ($_ppInteractive) {
    # LastUpdateCheck.txt is rewritten after each successful check
    $_ppDue = ([datetime]::UtcNow - [IO.File]::GetLastWriteTimeUtc($_ppStampFile)).TotalDays -gt 7
    # The marker records the last attempt: at most one background check per
    # 6 hours across all shells, even while offline (when no stamp is written).
    $_ppLock = [IO.Path]::Combine($_ppCacheDir, 'update-check.attempt')
    if ($_ppDue -and ([datetime]::UtcNow - [IO.File]::GetLastWriteTimeUtc($_ppLock)).TotalHours -gt 6) {
        try {
            [IO.File]::WriteAllText($_ppLock, "$PID")
            $psi = [System.Diagnostics.ProcessStartInfo]::new([Environment]::ProcessPath)
            foreach ($a in '-NoProfile', '-NonInteractive', '-Command',
                "& '$([IO.Path]::Combine($_ppRoot, 'Scripts', '_lib', 'UpdateCheck.ps1').Replace("'", "''"))' -Background -Root '$($_ppRoot.Replace("'", "''"))' -NoticeFile '$($_ppNoticeFile.Replace("'", "''"))' -StampFile '$($_ppStampFile.Replace("'", "''"))'") {
                $psi.ArgumentList.Add($a)
            }
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
            $_ppUpdateProc = [System.Diagnostics.Process]::Start($psi)
            $_ppUpdateProc.PriorityClass = 'BelowNormal'
        } catch {}
    }
}
_tm 'updates'

#-------------------------------------------------------------------------------
# IDLE WARMUP
#-------------------------------------------------------------------------------
# The first `cd`/`ls`/formatting command in a fresh session loads
# Microsoft.PowerShell.Management and .Utility (60-600 ms). Load them the first
# time PSReadLine sits idle (~300 ms without a keypress) instead, so that cost
# lands while the user is reading the prompt, not after they press Enter.
# $ExecutionContext.Events is the engine API behind Register-EngineEvent,
# which itself lives in .Utility.

if ($_ppInteractive) {
    $null = $ExecutionContext.Events.SubscribeEvent($null, $null, 'PowerShell.OnIdle', $null, {
            Import-Module Microsoft.PowerShell.Management, Microsoft.PowerShell.Utility -Global
            if ($null -eq $global:_ppKeyQueue) { _ppFindKeyQueue }
        }, $true, $false, 1)
}

#-------------------------------------------------------------------------------
# PROFILE LOAD TIME
#-------------------------------------------------------------------------------

if ($_ppInteractive) {
    # Notices left by a check that finished after the previous shell closed
    $_ppNotice = _ppTakeNotice
    if ($_ppNotice) { [Console]::Write($_ppNotice) }
    $_ppTotal = ([datetime]::Now - [System.Diagnostics.Process]::GetCurrentProcess().StartTime).TotalMilliseconds
    [Console]::WriteLine("`e[90mReady in {0:N0}ms (profile {1:N0}ms)`e[0m", $_ppTotal, $_ppSw.Elapsed.TotalMilliseconds)
}
