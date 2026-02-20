<#
.SYNOPSIS
    Launches a temporary Alpine Docker container with the current directory mounted.

.DESCRIPTION
    Builds and runs an Alpine-based development container using a local Dockerfile.
    The current directory is mounted to /mnt/c/... in the container (WSL-style).

.PARAMETER Update
    Forces a rebuild of the Docker image.

.PARAMETER Command
    Optional command to run in the container. Defaults to interactive zsh.

.PARAMETER Port
    One or more port mappings to forward from host to container (e.g. 8080:80).
    A bare number (e.g. 8080) maps that port to the same port inside the container.
    Can be specified multiple times or as a comma-separated list.

.EXAMPLE
    wsl-tempcli-alpine
    # Launches interactive zsh in container

.EXAMPLE
    wsl-tempcli-alpine --update
    # Rebuilds the image and launches container

.EXAMPLE
    wsl-tempcli-alpine -Command "python3 --version"
    # Runs a specific command

.EXAMPLE
    wsl-tempcli-alpine -p 8080:80
    # Forward host port 8080 to container port 80

.EXAMPLE
    wsl-tempcli-alpine -p 8080:80,8443:443 -p 3000:3000
    # Multiple mappings via comma and repeated flag
#>

$ErrorActionPreference = 'Stop'

# Manual argument parsing to support --
$Update = $false
$Command = $null
$Distro = $null
$Ports = @()                                       # list of port mappings (host:container)
$preArgs = $args
$containerArgs = @()
$argsIndex = $args.IndexOf('--')
if ($argsIndex -ge 0) {
    $preArgs = $args[0..($argsIndex - 1)]
    $containerArgs = $args[($argsIndex + 1)..($args.Count - 1)]
    $Command = $containerArgs -join ' '
}

# Parse parameters from $preArgs using a unix-style switch loop
for ($i = 0; $i -lt $preArgs.Count; $i++) {
    $arg = $preArgs[$i]
    if ($arg -eq '--') { break }
    elseif ($arg -match '^--?(?<flag>[^=]+)(=(?<val>.*))?$') {
        $flag = $Matches.flag
        switch ($flag) {
            { $_ -in 'u', 'update' } { $Update = $true }
            { $_ -in 'd', 'distro' } {
                if ($Matches.val) { $Distro = $Matches.val }
                elseif ($i + 1 -lt $preArgs.Count) { $Distro = $preArgs[++$i] }
            }
            { $_ -in 'c', 'command' } {
                if ($Matches.val) { $Command = $Matches.val }
                elseif ($i + 1 -lt $preArgs.Count) { $Command = $preArgs[++$i] }
            }
            { $_ -in 'p', 'port' } {
                if ($Matches.val) { $Ports += $Matches.val -split ',' }
                elseif ($i + 1 -lt $preArgs.Count) { $Ports += ($preArgs[++$i] -split ',') }
            }
            default {
                Write-Error "Unknown option: $arg"
                exit 1
            }
        }
    } else {
        # no positional args currently handled
    }
}

# Default distro to 'alpine' if not specified
if (-not $Distro) { $Distro = 'alpine' }

# Explicit paths - script location and Dockerfile
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$dockerfilePath = Join-Path $scriptDir "$Distro.Dockerfile"

if (-not (Test-Path $dockerfilePath)) {
    Write-Host "Dockerfile not found for distro '$Distro' at path: $dockerfilePath" -ForegroundColor Red
    Write-Host "Available Dockerfiles in ${scriptDir}:" -ForegroundColor Yellow
    Get-ChildItem -Path $scriptDir -Filter "*.Dockerfile" | ForEach-Object { Write-Host "  " $_.Name.split('.')[0] -ForegroundColor Cyan }
    exit 1
}

# Image naming: username/script-name:latest
$username = $env:USERNAME.ToLower()
$imageName = "localhost/${username}/wsl-tempcli:$Distro"

# Parse base image from Dockerfile
$baseImage = (Select-String -Path $dockerfilePath -Pattern '^FROM\s+(.+)$' | Select-Object -First 1).Matches.Groups[1].Value

# Convert Windows path to WSL-style path (C:\Users\foo -> /mnt/c/Users/foo)
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

function Get-ImageCreationDate {
    param([string]$Image)
    $created = & docker inspect --format '{{.Created}}' $Image 2>&1
    if ($LASTEXITCODE -eq 0) {
        # Docker returns format like "2026-02-19 19:16:49.364925259 +0000 UTC" - strip " UTC" suffix
        $created = $created -replace '\s+UTC$', ''
        return [datetime]::Parse($created)
    }
    return $null
}

function Pull-NewerImage {
    param(
        [string]$Image
    )

    Write-Host "Checking for image updates: $Image..." -ForegroundColor DarkGray -NoNewline

    $pullOutput = & docker pull --policy "newer" $Image 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "`r❌ Failed to pull image '$Image'.$((' ' * 20))" -ForegroundColor Red
        return $false
    }

    $wasUpdated = $pullOutput | Select-String -Pattern "Downloaded newer image|Copying blob" -Quiet

    if ($wasUpdated) {
        Write-Host "`r🔄 Image '$Image' was updated.$((' ' * 20))" -ForegroundColor Yellow
        return $true
    }
    else {
        Write-Host "`r✅ Image '$Image' is already up to date.$((' ' * 20))" -ForegroundColor Green
        return $false
    }
}

function Test-DockerfileModified {
    param([string]$Image, [string]$Dockerfile)

    $imageCreated = Get-ImageCreationDate $Image
    if (-not $imageCreated) { return $false }

    $dockerfileModified = (Get-Item $Dockerfile).LastWriteTime
    return $dockerfileModified -gt $imageCreated
}

function Build-Image {
    param([switch]$NoCache)

    Write-Host "Building image: $imageName" -ForegroundColor Cyan
    $buildArgs = @('build', '-t', $imageName, '-f', $dockerfilePath)
    if ($NoCache) { $buildArgs += '--no-cache' }
    $buildArgs += $scriptDir

    & docker @buildArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to build Docker image"
    }
}

# Verify Docker is available
if (-not (Test-DockerAvailable)) {
    Write-Error "Docker is not available. Please ensure Docker or Podman is running."
    exit 1
}

# Verify Dockerfile exists
if (-not (Test-Path $dockerfilePath)) {
    Write-Error "Dockerfile not found at: $dockerfilePath"
    exit 1
}

# Build image if needed or if --update specified
$imageExists = Test-ImageExists $imageName

if ($Update) {
    Write-Host "Updating base image and rebuilding..." -ForegroundColor Yellow
    & docker pull $baseImage
    Build-Image -NoCache
} elseif (-not $imageExists) {
    Write-Host "Image not found. Building for first time..." -ForegroundColor Yellow
    Build-Image -NoCache
} else {
    # Check if Dockerfile was modified
    if (Test-DockerfileModified -Image $imageName -Dockerfile $dockerfilePath) {
        Write-Warning "Dockerfile has been modified since image was built. Run with --update to rebuild."
    }
    # Check if base image is outdated
    elseif (Pull-NewerImage -Image $baseImage) {
        Write-Warning "Base image ($baseImage) has been updated. Run with --update to rebuild."
    }
}

# Build docker run arguments
# Mount full drive using Windows path format (C:\)
$drivePath = "${driveLetter}:\"
$dockerArgs = @(
    'run'
    '--rm'
    '-it'
    '--hostname', "wsl-tempcli-$Distro"
    '-w', $wslPath
    '-v', "${drivePath}:/mnt/${driveLetter}:rw"
)

# add any port mappings provided by user
foreach ($p in $Ports) {
    # trim whitespace just in case
    $mapping = $p.Trim()
    if (-not $mapping) { continue }

    # if user just gave a number, map host:container to same port
    if ($mapping -match '^[0-9]+$') {
        $mapping = "${mapping}:${mapping}"
    }

    # validate simple port spec (host:container or host)
    if ($mapping -notmatch '^[0-9]+(:[0-9]+)?$') {
        Write-Warning "Skipping invalid port mapping: $mapping"
        continue
    }

    $dockerArgs += '-p', "127.0.0.1:${mapping}"
}

$dockerArgs += $imageName

# The entrypoint handles dropping to the runtime user.
# Pass the command directly -- if a command was given, run it via zsh -c so
# aliases, PATH, and .zshrc are available. Otherwise default to interactive zsh.
if ($Command) {
    # Run the command and exit, mirroring WSL -- behavior.
    $dockerArgs += 'zsh', '-c', $Command
}
# No else needed -- CMD ["/bin/zsh"] in the Dockerfile is the default

Write-Verbose ("docker {0}" -f ($dockerArgs -join ' '))
& docker @dockerArgs