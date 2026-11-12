# Lets shell keys through in VS Code's integrated terminal.
#
# VS Code keeps some keys for itself even when the terminal has focus:
#   Ctrl+E        Quick Open (Windows), instead of the shell's end-of-line
#   Ctrl+K        first key of two-key shortcuts (Ctrl+K Ctrl+S, ...), instead
#                 of the shell's delete-to-end-of-line
#   Ctrl+Shift+C  copies only a mouse selection; with none, the key is lost
#   Ctrl+Insert   (same)
# Only the terminal is affected: in the editor these keys work as before.
# Changes are limited to the entries below, so they can be removed again.
#
# The copy keys are sent as Windows console key events (win32-input-mode,
# ESC [ Vk ; Sc ; Uc ; Kd ; Cs ; Rc _), so PowerShell sees the real key and
# copies its own selection. They apply only in PowerShell tabs (in bash,
# Ctrl+Shift+C would arrive as Ctrl+C), only when nothing is selected with
# the mouse, and not while a full-screen program (fzf, vim) is running.
$script:VSCodeCopyWhen = "terminalFocus && terminalShellType == 'pwsh' && !terminalTextSelected && !terminalAltBufferActive"
$script:VSCodeKeyBindings = @(
    [ordered]@{ key = 'ctrl+e'; command = 'workbench.action.terminal.sendSequence'; args = [ordered]@{ text = "`u{5}" }; when = 'terminalFocus' }
    [ordered]@{ key = 'ctrl+shift+c'; command = 'workbench.action.terminal.sendSequence'; args = [ordered]@{ text = "`e[67;46;3;1;24;1_" }; when = $script:VSCodeCopyWhen }
    [ordered]@{ key = 'ctrl+insert'; command = 'workbench.action.terminal.sendSequence'; args = [ordered]@{ text = "`e[45;82;0;1;264;1_" }; when = $script:VSCodeCopyWhen }
)
# allowChords = false: a key that starts a two-key shortcut goes to the shell
# when the terminal has focus.
$script:VSCodeKeySettings = [ordered]@{ 'terminal.integrated.allowChords' = $false }

function Get-VSCodeUserDirs {
    foreach ($v in @(
            @{ Name = 'VS Code'; Dir = "$env:APPDATA\Code\User" }
            @{ Name = 'VS Code Insiders'; Dir = "$env:APPDATA\Code - Insiders\User" }
            @{ Name = 'VSCodium'; Dir = "$env:APPDATA\VSCodium\User" }
        )) {
        if ([IO.Directory]::Exists($v.Dir)) { $v }
    }
}

function _Read-JsonC([string]$Path, $Empty) {
    if (-not [IO.File]::Exists($Path)) { return $Empty }
    $raw = [IO.File]::ReadAllText($Path)
    # Comments only (VS Code's keybindings.json template) means no entries yet
    $stripped = ($raw -split "`n" | Where-Object { $_ -notmatch '^\s*//' }) -join "`n"
    if (-not $stripped.Trim()) { return $Empty }
    return $raw | ConvertFrom-Json   # throws on invalid JSON: leave the file alone
}

function _Same-Binding($a, $b) {
    $a.key -eq $b.key -and $a.command -eq $b.command -and $a.when -eq $b.when
}

# Adds (-Enable) or removes (-Disable) the entries above in every installed
# variant. Returns the names of the variants changed or already set.
function Set-VSCodeTerminalKeys([switch]$Enable, [switch]$Disable) {
    $done = @()
    foreach ($v in @(Get-VSCodeUserDirs)) {
        $kbPath = [IO.Path]::Combine($v.Dir, 'keybindings.json')
        $setPath = [IO.Path]::Combine($v.Dir, 'settings.json')

        $kb = [System.Collections.Generic.List[object]]::new()
        foreach ($e in @(_Read-JsonC $kbPath @())) { $kb.Add($e) }
        $kbChanged = $false
        foreach ($want in $script:VSCodeKeyBindings) {
            $have = @($kb | Where-Object { _Same-Binding $_ $want })
            if ($Enable -and $have.Count -eq 0) { $kb.Add([PSCustomObject]$want); $kbChanged = $true }
            if ($Disable) { foreach ($h in $have) { [void]$kb.Remove($h); $kbChanged = $true } }
        }

        $set = _Read-JsonC $setPath $null
        if ($null -eq $set) { $set = [PSCustomObject]@{} }
        $setChanged = $false
        foreach ($k in $script:VSCodeKeySettings.Keys) {
            $cur = $set.PSObject.Properties[$k]
            if ($Enable -and (-not $cur -or $cur.Value -ne $script:VSCodeKeySettings[$k])) {
                $set | Add-Member -NotePropertyName $k -NotePropertyValue $script:VSCodeKeySettings[$k] -Force; $setChanged = $true
            }
            if ($Disable -and $cur -and $cur.Value -eq $script:VSCodeKeySettings[$k]) {
                $set.PSObject.Properties.Remove($k); $setChanged = $true
            }
        }

        if ($kbChanged) { [IO.File]::WriteAllText($kbPath, (ConvertTo-Json -InputObject $kb.ToArray() -Depth 10)) }
        if ($setChanged) { [IO.File]::WriteAllText($setPath, ($set | ConvertTo-Json -Depth 20)) }
        $done += $v.Name
    }
    return $done
}
