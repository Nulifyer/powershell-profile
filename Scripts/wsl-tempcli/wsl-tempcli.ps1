#.ALIAS wsl-tempcli
#.ALIAS wtc
<#
.SYNOPSIS
    Launches a temporary Linux container with the current directory mounted.

.DESCRIPTION
    Pulls and runs a pre-built development container from GHCR.
    The current directory is mounted to /mnt/c/... in the container (WSL-style).
    Falls back to local build if pull fails.

.PARAMETER Distro
    Linux distro to use: alpine, debian, kali (default: alpine)

.PARAMETER Variant
    Image variant: slim (shell tools only) or full (slim + dev SDKs) (default: slim)

.PARAMETER Update
    Forces a pull of the latest image from GHCR.

.PARAMETER Command
    Optional command to run in the container. Defaults to interactive zsh.

.PARAMETER Port
    One or more port mappings (e.g. 8080:80). A bare number maps to the same port.

.PARAMETER BuildLocal
    Force a local build from Dockerfiles instead of pulling from GHCR.

.EXAMPLE
    wtc
    # Launches alpine-slim interactive zsh

.EXAMPLE
    wtc -d debian -v full
    # Launches debian-full with dev SDKs

.EXAMPLE
    wtc --update
    # Pulls latest alpine-slim image

.EXAMPLE
    wtc -p 8080:80 -c "python3 -m http.server 80"
    # Run a command with port forwarding
#>

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\..\_lib\ScriptUtils.ps1"

$Update = $false
$UpdateAll = $false
$Command = $null
$Distro = $null
$Variant = $null
$Ports = @()
$Help = $false
$BuildLocal = $false
$SetConfig = $false
$cliArgs = $args

for ($i = 0; $i -lt $cliArgs.Count; $i++) {
    $arg = $cliArgs[$i]
    if ($arg -match '^--?(?<flag>[^=]+)(=(?<val>.*))?$') {
        $flag = $Matches.flag
        switch ($flag) {
            { $_ -in 'u', 'update' } { $Update = $true }
            { $_ -in 'ua', 'update-all' } { $UpdateAll = $true }
            { $_ -in 'd', 'distro' } {
                if ($Matches.val) { $Distro = $Matches.val }
                elseif ($i + 1 -lt $cliArgs.Count) { $Distro = $cliArgs[++$i] }
            }
            { $_ -in 'v', 'variant' } {
                if ($Matches.val) { $Variant = $Matches.val }
                elseif ($i + 1 -lt $cliArgs.Count) { $Variant = $cliArgs[++$i] }
            }
            { $_ -in 'c', 'command' } {
                if ($Matches.val) { $Command = $Matches.val }
                elseif ($i + 1 -lt $cliArgs.Count) { $Command = $cliArgs[++$i] }
            }
            { $_ -in 'p', 'port' } {
                if ($Matches.val) { $Ports += $Matches.val -split ',' }
                elseif ($i + 1 -lt $cliArgs.Count) { $Ports += ($cliArgs[++$i] -split ',') }
            }
            { $_ -in 'build-local', 'local' } { $BuildLocal = $true }
            { $_ -in 'set' } { $SetConfig = $true }
            { $_ -in 'h', 'help' } { $Help = $true }
            default {
                Write-Error "Unknown option: $arg"
                exit 1
            }
        }
    }
}

# Apply saved defaults, then fall back to hardcoded defaults
if (-not $Distro)  { $Distro  = (Get-ScriptConfig "wtc" "distro")  ?? 'alpine' }
if (-not $Variant) { $Variant = (Get-ScriptConfig "wtc" "variant") ?? 'slim' }

if ($Variant -notin 'slim', 'full') {
    Write-Error "Invalid variant '$Variant'. Must be 'slim' or 'full'."
    exit 1
}

if ($SetConfig) {
    if (-not $Distro -and -not $Variant) {
        # Show current config
        $cfg = Get-ScriptConfig "wtc"
        if ($cfg) {
            Write-Host "Current wtc defaults:" -ForegroundColor Cyan
            foreach ($key in $cfg.Keys) { Write-Host "  $key = $($cfg[$key])" }
        } else {
            Write-Host "No saved defaults. Using alpine-slim." -ForegroundColor DarkGray
        }
        exit 0
    }
    if ($Distro)  { Set-ScriptConfig "wtc" "distro" $Distro }
    if ($Variant) { Set-ScriptConfig "wtc" "variant" $Variant }
    Write-Host "Defaults saved: distro=$(Get-ScriptConfig 'wtc' 'distro'), variant=$(Get-ScriptConfig 'wtc' 'variant')" -ForegroundColor Green
    exit 0
}

if ($Help) {
    Write-Host "Usage: wtc [options]" -ForegroundColor Cyan
    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host "  -d, --distro <name>     Distro: alpine, debian, kali (default: alpine)" -ForegroundColor Yellow
    Write-Host "  -v, --variant <type>    Variant: slim, full (default: slim)" -ForegroundColor Yellow
    Write-Host "  -u, --update            Pull latest image from GHCR" -ForegroundColor Yellow
    Write-Host "  -ua, --update-all       Pull all images from GHCR" -ForegroundColor Yellow
    Write-Host "  -c, --command <cmd>     Command to run (default: interactive zsh)" -ForegroundColor Yellow
    Write-Host "  -p, --port <p[,p...]>   Port mappings (host:container or host)" -ForegroundColor Yellow
    Write-Host "  --build-local           Force local build instead of pulling from GHCR" -ForegroundColor Yellow
    Write-Host "  --set                   Save current -d/-v as defaults (or show saved defaults)" -ForegroundColor Yellow
    Write-Host "  -h, --help              Show this help" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Variants:" -ForegroundColor Cyan
    Write-Host "  slim  Shell tools only (zsh, eza, bat, fzf, ripgrep, oh-my-posh, etc.)" -ForegroundColor DarkGray
    Write-Host "  full  Slim + Go, .NET, Bun, Python, build tools, network utilities" -ForegroundColor DarkGray
    exit 0
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$imageName = "ghcr.io/nulifyer/wsl-tempcli:${Distro}-${Variant}"

# Convert Windows path to WSL-style path
$currentPath = (Get-Location).Path
$driveLetter = $currentPath.Substring(0, 1).ToLower()
$wslPath = "/mnt/$driveLetter" + $currentPath.Substring(2).Replace('\', '/')

function Test-DockerAvailable {
    try {
        $null = & docker version 2>&1
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Test-ImageExists {
    param([string]$Image)
    $result = & docker images -q $Image 2>&1
    return -not [string]::IsNullOrWhiteSpace($result)
}

function Build-Image {
    param(
        [Parameter(Mandatory)][string]$Image,
        [Parameter(Mandatory)][string]$Dockerfile,
        [Parameter(Mandatory)][string]$BuildContext
    )
    Write-Host "Building image: $Image" -ForegroundColor Cyan
    & docker build -t $Image -f $Dockerfile $BuildContext
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to build Docker image: $Image"
    }
}

if (-not (Test-DockerAvailable)) {
    Write-Error "Docker is not available. Please ensure Docker or Podman is running."
    exit 1
}

# Handle update-all: pull all images from GHCR
if ($UpdateAll) {
    Write-Host "Pulling all images from GHCR..." -ForegroundColor Yellow
    foreach ($d in @('alpine', 'debian', 'kali')) {
        foreach ($v in @('slim', 'full')) {
            $img = "ghcr.io/nulifyer/wsl-tempcli:${d}-${v}"
            Write-Host "Pulling $img..." -ForegroundColor Cyan
            & docker pull $img
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Failed to pull $img"
            }
        }
    }
    Write-Host "Update-all complete." -ForegroundColor Green
    exit 0
}

# Resolve image
if ($BuildLocal) {
    $dockerfilePath = Join-Path $scriptDir "dockerfiles" $Distro "${Variant}.Dockerfile"
    if (-not (Test-Path $dockerfilePath)) {
        Write-Error "Dockerfile not found: $dockerfilePath"
        exit 1
    }
    Build-Image -Image $imageName -Dockerfile $dockerfilePath -BuildContext $scriptDir
} elseif ($Update) {
    Write-Host "Pulling latest $imageName..." -ForegroundColor Cyan
    & docker pull $imageName
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to pull $imageName"
        exit 1
    }
} elseif (-not (Test-ImageExists $imageName)) {
    Write-Host "Pulling $imageName..." -ForegroundColor Cyan
    & docker pull $imageName 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Pull failed, attempting local build..." -ForegroundColor Yellow
        $dockerfilePath = Join-Path $scriptDir "dockerfiles" $Distro "${Variant}.Dockerfile"
        if (Test-Path $dockerfilePath) {
            Build-Image -Image $imageName -Dockerfile $dockerfilePath -BuildContext $scriptDir
        } else {
            Write-Error "No image available and no Dockerfile found at: $dockerfilePath"
            exit 1
        }
    }
}

# Build docker run arguments
$drivePath = "${driveLetter}:\"
$dockerArgs = @('run', '--rm')

if (-not $Command) { $dockerArgs += '-it' }

$dockerArgs += '--hostname', "wsl-tempcli-$Distro", '-w', $wslPath, '-v', "${drivePath}:/mnt/${driveLetter}:rw"

foreach ($p in $Ports) {
    $mapping = $p.Trim()
    if (-not $mapping) { continue }
    if ($mapping -match '^[0-9]+$') { $mapping = "${mapping}:${mapping}" }
    if ($mapping -notmatch '^[0-9]+(:[0-9]+)?$') {
        Write-Warning "Skipping invalid port mapping: $mapping"
        continue
    }
    $dockerArgs += '-p', "127.0.0.1:${mapping}"
}

$dockerArgs += $imageName

if ($Command) {
    $dockerArgs += 'zsh', '-c', $Command
}

Write-Verbose ("docker {0}" -f ($dockerArgs -join ' '))
& docker @dockerArgs
