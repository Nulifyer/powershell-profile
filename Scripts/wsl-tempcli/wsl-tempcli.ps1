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

$Update = $false
$UpdateAll = $false
$Command = $null
$Distro = $null
$Ports = @()
$Help = $false
$cliArgs = $args

# Parse parameters from $cliArgs using a unix-style switch loop
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
            { $_ -in 'c', 'command' } {
                if ($Matches.val) { $Command = $Matches.val }
                elseif ($i + 1 -lt $cliArgs.Count) { $Command = $cliArgs[++$i] }
            }
            { $_ -in 'p', 'port' } {
                if ($Matches.val) { $Ports += $Matches.val -split ',' }
                elseif ($i + 1 -lt $cliArgs.Count) { $Ports += ($cliArgs[++$i] -split ',') }
            }
            { $_ -in 'h', 'help' } { $Help = $true }
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

# Show help/usage if requested
if ($Help) {
    Write-Host "Usage: wsl-tempcli-alpine [options]" -ForegroundColor Cyan
    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host "  -u, --update            Rebuild image for selected distro" -ForegroundColor Yellow
    Write-Host "  -ua, --update-all       Rebuild images for all distros (all *.Dockerfile)" -ForegroundColor Yellow
    Write-Host "  -d, --distro <name>     Choose distro (default: alpine)" -ForegroundColor Yellow
    Write-Host "  -c, --command <cmd>     Command to run inside container (default: interactive zsh)" -ForegroundColor Yellow
    Write-Host "  -p, --port <p[,p...]>   Port mappings (host:container or host)" -ForegroundColor Yellow
    Write-Host "  -h, --help              Show this help and exit" -ForegroundColor Yellow
    exit 0
}

# Explicit paths - script location and Dockerfile
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
# Prepare dockerfile path for single-distro operations (skipped for update-all)
$dockerfilePath = Join-Path $scriptDir "$Distro.Dockerfile"

if (-not $UpdateAll) {
    if (-not (Test-Path $dockerfilePath)) {
        Write-Host "Dockerfile not found for distro '$Distro' at path: $dockerfilePath" -ForegroundColor Red
        Write-Host "Available Dockerfiles in ${scriptDir}:" -ForegroundColor Yellow
        Get-ChildItem -Path $scriptDir -Filter "*.Dockerfile" | ForEach-Object { Write-Host "  " $_.Name.split('.')[0] -ForegroundColor Cyan }
        exit 1
    }
}

# Image naming: username/script-name:latest
$username = $env:USERNAME.ToLower()
$imageName = "localhost/${username}/wsl-tempcli:$Distro"

# Parse base image from Dockerfile for single-distro flows
if (-not $UpdateAll) {
    $baseImage = (Select-String -Path $dockerfilePath -Pattern '^FROM\s+(.+)$' | Select-Object -First 1).Matches.Groups[1].Value
}

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
        [string]$Image,
        [switch]$Quiet = $false
    )

    if (-not $Quiet) {
        Write-Host "Checking for updates to base image '$Image'..." -ForegroundColor Cyan
    }

    $pullOutput = & docker pull --policy "newer" $Image 2>&1

    if ($LASTEXITCODE -ne 0) {
        if (-not $Quiet) {
            Write-Host "`r❌ Failed to pull image '$Image'.$((' ' * 20))" -ForegroundColor Red
        }
        return $false
    }

    $wasUpdated = $pullOutput | Select-String -Pattern "Downloaded newer image|Copying blob" -Quiet

    if ($wasUpdated) {
        if (-not $Quiet) {
            Write-Host "`r🔄 Image '$Image' was updated.$((' ' * 20))" -ForegroundColor Yellow
        }
        return $true
    }
    else {
        if (-not $Quiet) {
            Write-Host "`r✅ Image '$Image' is already up to date.$((' ' * 20))" -ForegroundColor Green
        }
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
    param(
        [Parameter(Mandatory=$true)][string]$Image,
        [Parameter(Mandatory=$true)][string]$Dockerfile,
        [Parameter(Mandatory=$true)][string]$BuildContext,
        [switch]$NoCache
    )

    Write-Host "Building image: $Image" -ForegroundColor Cyan
    $buildArgs = @('build', '-t', $Image, '-f', $Dockerfile)
    if ($NoCache) { $buildArgs += '--no-cache' }
    $buildArgs += $BuildContext

    & docker @buildArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to build Docker image: $Image"
    }
}

# Verify Docker is available
if (-not (Test-DockerAvailable)) {
    Write-Error "Docker is not available. Please ensure Docker or Podman is running."
    exit 1
}

# Handle update-all: iterate all Dockerfiles and rebuild images
if ($UpdateAll) {
    Write-Host "Updating all distros in $scriptDir..." -ForegroundColor Yellow
    $username_local = $env:USERNAME.ToLower()
    $dockerfiles = Get-ChildItem -Path $scriptDir -Filter "*.Dockerfile"
    foreach ($df in $dockerfiles) {
        $distroName = $df.BaseName
        $dfPath = $df.FullName
        $img = "localhost/${username_local}/wsl-tempcli:$distroName"
        $base = (Select-String -Path $dfPath -Pattern '^FROM\s+(.+)$' | Select-Object -First 1).Matches.Groups[1].Value
        Write-Host "\n---\nUpdating distro: $distroName (base: $base)" -ForegroundColor Cyan
        try {
            & docker pull $base
        } catch {
            Write-Warning "Failed to pull base image: $base"
        }
        Build-Image -Image $img -Dockerfile $dfPath -BuildContext $scriptDir -NoCache
    }
    Write-Host "Update-all complete." -ForegroundColor Green
    exit 0
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
    Build-Image -Image $imageName -Dockerfile $dockerfilePath -BuildContext $scriptDir -NoCache
} elseif (-not $imageExists) {
    Write-Host "Image not found. Building for first time..." -ForegroundColor Yellow
    Build-Image -Image $imageName -Dockerfile $dockerfilePath -BuildContext $scriptDir -NoCache
} else {
    $quiet = $false
    if ($Command) { $quiet = $true }

    if (Test-DockerfileModified -Image $imageName -Dockerfile $dockerfilePath) {
        Write-Warning "Dockerfile has been modified since image was built. Run with --update to rebuild."
    }
    # Check if base image is outdated
    elseif (Pull-NewerImage -Image $baseImage -Quiet $quiet) {
        Write-Warning "Base image ($baseImage) has been updated. Run with --update to rebuild."
    }
}

# Build docker run arguments
# Mount full drive using Windows path format (C:\)
$drivePath = "${driveLetter}:\"
$dockerArgs = @('run', '--rm')

# Only allocate a TTY and keep STDIN open when no explicit command was supplied
if (-not $Command) { $dockerArgs += '-it' }

$dockerArgs += '--hostname', "wsl-tempcli-$Distro", '-w', $wslPath, '-v', "${drivePath}:/mnt/${driveLetter}:rw"

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
# Pass the command directly -c if a command was given
# aliases, PATH, and .zshrc are available. Otherwise default to interactive zsh.
if ($Command) {
    # Run the command and exit, mirroring WSL -- behavior.
    $dockerArgs += 'zsh', '-c', $Command
}

Write-Verbose ("docker {0}" -f ($dockerArgs -join ' '))
& docker @dockerArgs