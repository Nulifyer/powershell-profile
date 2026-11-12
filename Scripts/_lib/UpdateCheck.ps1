# PowerShell + profile update checks.
#
# Two ways in:
#   - The profile starts this file in a hidden, below-normal-priority process
#     once a week (-Background). It writes any notices to -NoticeFile, and the
#     next prompt prints them. Nothing here ever blocks shell startup.
#   - `profile-update` / `pu` dot-sources it and calls the functions directly,
#     interactively, with auto-update/auto-pull.
param(
    [switch]$Background,
    [string]$Root,
    [string]$NoticeFile,
    [string]$StampFile
)

# Run a git command with a hard wall-clock timeout (kills the process on expiry).
function _Invoke-GitWithTimeout {
    param(
        [Parameter(Mandatory)][string[]]$ArgumentList,
        [int]$TimeoutMs = 4000
    )
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = 'git'
    foreach ($a in $ArgumentList) { $psi.ArgumentList.Add($a) }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $stdout = $proc.StandardOutput.ReadToEndAsync()
    $null = $proc.StandardError.ReadToEndAsync()
    if (-not $proc.WaitForExit($TimeoutMs)) {
        try { $proc.Kill($true) } catch {}
        return [pscustomobject]@{ Ok = $false; Output = '' }
    }
    return [pscustomobject]@{ Ok = ($proc.ExitCode -eq 0); Output = $stdout.Result.Trim() }
}

function _Get-LatestPwshVersion {
    (Invoke-RestMethod -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest' -TimeoutSec 5).tag_name.TrimStart('v')
}

function _Check-PwshVersion {
    param([switch]$AutoUpdate)
    $latestVersion = _Get-LatestPwshVersion
    $currentVersion = $PSVersionTable.PSVersion.ToString()
    if ([version]$currentVersion -lt [version]$latestVersion) {
        Write-Host "PowerShell update available: $currentVersion → $latestVersion" -ForegroundColor Yellow
        if ($AutoUpdate) {
            Write-Host "Updating PowerShell via WinGet..." -ForegroundColor Yellow
            winget upgrade Microsoft.PowerShell --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -eq 0) {
                Write-Host "PowerShell updated. Restart your shell to use $latestVersion" -ForegroundColor Green
            } else {
                Write-Warning "Failed to update PowerShell"
            }
        } else {
            Write-Host "  Run 'winget upgrade Microsoft.PowerShell' to update" -ForegroundColor DarkGray
        }
        return $true
    }
    Write-Host "PowerShell is up to date ($currentVersion)" -ForegroundColor Green
    return $false
}

function _Check-ProfileUpdates {
    param([string]$ProfileDir, [switch]$AutoPull)
    $status = git -C $ProfileDir status --porcelain
    if ($status) {
        Write-Host "You have local changes — stash or commit before updating." -ForegroundColor Yellow
        git -C $ProfileDir status --short
        return
    }
    if (-not (_Invoke-GitWithTimeout -TimeoutMs 8000 -ArgumentList @('-C', $ProfileDir, 'fetch', 'origin', 'main', '--quiet')).Ok) {
        Write-Host "Profile update check skipped (git fetch timed out or failed)." -ForegroundColor DarkGray
        return
    }
    $local = git -C $ProfileDir rev-parse HEAD
    $remote = git -C $ProfileDir rev-parse origin/main
    if ($local -ne $remote) {
        if ($AutoPull) {
            Write-Host "Profile update available. Pulling..." -ForegroundColor Yellow
            git -C $ProfileDir pull --ff-only origin main
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Profile updated. Restart your shell to apply changes." -ForegroundColor Green
            } else {
                Write-Warning "Failed to pull updates. Try manually: git -C $ProfileDir pull"
            }
        } else {
            Write-Host "Profile update available! Run 'git -C $ProfileDir pull' to update" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Profile is up to date." -ForegroundColor Green
    }
}

if (-not $Background) { return }

# -- Background mode -----------------------------------------------------------
$notices = [System.Collections.Generic.List[string]]::new()
$reachable = $false
try {
    $latest = _Get-LatestPwshVersion
    $reachable = $true
    $current = $PSVersionTable.PSVersion
    if ($current -lt [version]$latest) {
        $notices.Add("PowerShell update available: $current → $latest  (run 'pu' or 'winget upgrade Microsoft.PowerShell')")
    }
} catch {}

if ([IO.Directory]::Exists([IO.Path]::Combine($Root, '.git'))) {
    $fetch = _Invoke-GitWithTimeout -TimeoutMs 15000 -ArgumentList @('-C', $Root, 'fetch', 'origin', 'main', '--quiet')
    if ($fetch.Ok) {
        $reachable = $true
        $behind = _Invoke-GitWithTimeout -ArgumentList @('-C', $Root, 'rev-list', '--count', 'HEAD..origin/main')
        if ($behind.Ok -and [int]$behind.Output -gt 0) {
            $notices.Add("Profile update available ($($behind.Output) new commit(s)). Run 'pu' to pull.")
        }
    }
}

if ($notices.Count -gt 0) { [IO.File]::WriteAllLines($NoticeFile, $notices) }
# Only record the check when the network answered, so an offline week retries.
if ($reachable) { [IO.File]::WriteAllText($StampFile, [datetime]::Now.ToString('yyyy-MM-dd')) }
