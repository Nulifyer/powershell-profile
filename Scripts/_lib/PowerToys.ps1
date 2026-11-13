# PowerToys Keyboard Manager integration for the project picker.
#
# projpick has no global hotkey of its own (endpoint protection reads one as
# keylogging). PowerToys Keyboard Manager owns the shortcut instead: a "Start
# App" remap that runs bin\projpick.exe with "If running: Show Window".
#
# Keyboard Manager keeps its remaps in
#   %LOCALAPPDATA%\Microsoft\PowerToys\Keyboard Manager\<activeConfiguration>.json
# and reloads them when the named event below is signaled. This is what its
# own editor does after saving. Only the projpick entry is added or removed;
# other remaps are left as they are.

$PowerToysData = [IO.Path]::Combine($env:LOCALAPPDATA, 'Microsoft', 'PowerToys')
$KbmDir = [IO.Path]::Combine($PowerToysData, 'Keyboard Manager')
$KbmReloadEvent = 'PowerToys_KeyboardManager_Event_Settings'
# Ctrl+Alt+P as Keyboard Manager stores it: virtual-key codes joined by ';'.
$PickerKeys = '17;18;80'
$PickerKeysText = 'Ctrl+Alt+P'

function Find-PowerToys {
    # Per-user install first, then the machine-wide one.
    foreach ($base in $env:LOCALAPPDATA, $env:ProgramFiles) {
        if (-not $base) { continue }
        $exe = [IO.Path]::Combine($base, 'PowerToys', 'PowerToys.exe')
        if ([IO.File]::Exists($exe)) { return $exe }
    }
    return $null
}

function Install-PowerToys {
    <# Installs PowerToys for the current user with winget. Returns PowerToys.exe or $null. #>
    $winget = Find-ToolExe 'winget.exe'
    if (-not $winget) { return $null }
    & $winget install -e --id Microsoft.PowerToys --scope user --accept-source-agreements --accept-package-agreements --disable-interactivity | Out-Host
    return Find-PowerToys
}

function Test-PowerToysRunning {
    return [bool](Get-Process -Name PowerToys -ErrorAction SilentlyContinue)
}

function Read-Json([string]$Path) {
    if (-not [IO.File]::Exists($Path)) { return $null }
    return [IO.File]::ReadAllText($Path) | ConvertFrom-Json -AsHashtable
}

function Write-Json([string]$Path, $Data) {
    $tmp = "$Path.projpick-tmp"
    [IO.File]::WriteAllText($tmp, ($Data | ConvertTo-Json -Depth 32 -Compress))
    [IO.File]::Move($tmp, $Path, $true)
}

function Get-KbmConfigPath {
    $name = 'default'
    try {
        $v = (Read-Json ([IO.Path]::Combine($KbmDir, 'settings.json'))).properties.activeConfiguration.value
        if ($v) { $name = $v }
    } catch {}
    return [IO.Path]::Combine($KbmDir, "$name.json")
}

function Send-KbmReload {
    $ev = $null
    if ([Threading.EventWaitHandle]::TryOpenExisting($KbmReloadEvent, [ref]$ev)) {
        try { [void]$ev.Set() } finally { $ev.Dispose() }
    }
}

function Set-PickerShortcut {
    <#
    Adds (or with -Remove, deletes) the remap that starts $Exe. An existing
    remap for $Exe keeps the keys the user gave it. Returns 'added', 'kept',
    'removed', 'absent', or 'conflict' when Ctrl+Alt+P already does something else.
    #>
    param([Parameter(Mandatory)][string]$Exe, [switch]$Remove)
    $path = Get-KbmConfigPath
    $cfg = Read-Json $path
    if (-not $cfg) {
        if ($Remove) { return 'absent' }
        $cfg = [ordered]@{
            remapKeys = [ordered]@{ inProcess = @() }; remapKeysToText = [ordered]@{ inProcess = @() }
            remapShortcuts = [ordered]@{ global = @(); appSpecific = @() }; remapShortcutsToText = [ordered]@{ global = @(); appSpecific = @() }
        }
    }
    if (-not $cfg.remapShortcuts) { $cfg.remapShortcuts = [ordered]@{ global = @(); appSpecific = @() } }

    $isMine = {
        param($e)
        $e.runProgramFilePath -and [string]::Equals([Environment]::ExpandEnvironmentVariables($e.runProgramFilePath), $Exe, [StringComparison]::OrdinalIgnoreCase)
    }
    $global = @($cfg.remapShortcuts.global)
    $mine = @($global | Where-Object { & $isMine $_ })
    $others = @($global | Where-Object { -not (& $isMine $_) })

    if ($Remove) {
        if (-not $mine) { return 'absent' }
        $cfg.remapShortcuts.global = $others
        Write-Json $path $cfg
        Send-KbmReload
        return 'removed'
    }
    if ($mine) {
        # Keep the user's keys; make sure it shows the running picker.
        foreach ($e in $mine) {
            $e.operationType = 1
            $e.runProgramArgs = '--show'
            $e.runProgramAlreadyRunningAction = 0
        }
        Write-Json $path $cfg
        Send-KbmReload
        return 'kept'
    }
    if ($others | Where-Object { $_.originalKeys -eq $PickerKeys }) { return 'conflict' }

    $cfg.remapShortcuts.global = $others + [ordered]@{
        originalKeys                   = $PickerKeys
        exactMatch                     = $false
        operationType                  = 1                # Start App
        runProgramElevationLevel       = 0                # Normal
        runProgramAlreadyRunningAction = 0                # Show Window: PowerToys activates the running picker
        runProgramStartWindowType      = 0                # Normal
        runProgramFilePath             = $Exe
        runProgramArgs                 = '--show'         # used when the picker isn't running yet
        runProgramStartInDir           = ''
        unicodeText                    = '*Unsupported*'  # what the editor writes for Start App remaps
    }
    [void][IO.Directory]::CreateDirectory($KbmDir)
    Write-Json $path $cfg
    Send-KbmReload
    return 'added'
}

function Enable-KeyboardManager {
    <#
    Turns Keyboard Manager on and makes sure PowerToys is running. PowerToys
    only reads its enabled list at start, and its DSC tool resets other
    utilities when given one, so a running PowerToys is stopped, the setting
    changed, and PowerToys started again. Returns 'on', 'enabled', or 'enabled-restarted'.
    #>
    param([Parameter(Mandatory)][string]$PowerToysExe)
    $settings = [IO.Path]::Combine($PowerToysData, 'settings.json')
    if (-not [IO.File]::Exists($settings) -and -not (Test-PowerToysRunning)) {
        # First run: PowerToys writes its settings when it starts.
        Start-Process $PowerToysExe
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while (-not [IO.File]::Exists($settings) -and $sw.Elapsed.TotalSeconds -lt 30) { Start-Sleep -Milliseconds 250 }
    }
    $data = Read-Json $settings
    if (-not $data) { throw "PowerToys settings not found ($settings)" }
    if ($data.enabled -and $data.enabled['Keyboard Manager'] -eq $true) {
        if (-not (Test-PowerToysRunning)) { Start-Process $PowerToysExe }
        return 'on'
    }
    $wasRunning = Test-PowerToysRunning
    if ($wasRunning) {
        Get-Process -Name 'PowerToys', 'PowerToys.*' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ((Test-PowerToysRunning) -and $sw.Elapsed.TotalSeconds -lt 10) { Start-Sleep -Milliseconds 200 }
        $data = Read-Json $settings
    }
    if (-not $data.enabled) { $data.enabled = [ordered]@{} }
    $data.enabled['Keyboard Manager'] = $true
    Write-Json $settings $data
    Start-Process $PowerToysExe
    return $(if ($wasRunning) { 'enabled-restarted' } else { 'enabled' })
}

function Test-PowerToysStartsAtLogon {
    try { return (Read-Json ([IO.Path]::Combine($PowerToysData, 'settings.json'))).startup -eq $true } catch { return $false }
}
