# manual argument parsing for unix-style flags
$projectsFolder = "$HOME"
$help = $false

for ($i = 0; $i -lt $args.Count; $i++) {
    $arg = $args[$i]
    if ($arg -eq '--') { break }
    elseif ($arg -match '^--?(?<flag>[^=]+)(=(?<val>.*))?$') {
        switch ($Matches.flag) {
            'h' | 'help' { $help = $true }
            'p' | 'projects' {
                if ($Matches.val) { $projectsFolder = $Matches.val }
                elseif ($i + 1 -lt $args.Count) { $projectsFolder = $args[++$i] }
            }
            default {
                Write-Error "Unknown option: $arg"
                exit 1
            }
        }
    }
}

if ($help) {
    Write-Host "Usage: $(Split-Path -Leaf $MyInvocation.MyCommand.Name) [-p|--projects <path>] [--help]"
    Write-Host "  -p, --projects   Root folder to scan (defaults to HOME)"
    Write-Host "  -h, --help       Show this help"
    exit 0
}

$start = Get-Date

# My project folder

# Define the Start Menu folder for VS Code project shortcuts
$startMenuFolder = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\VSCode Projects"

# Create the Start Menu folder if it doesn't exist, and clear existing shortcuts
New-Item -ItemType Directory -Path $startMenuFolder -Force | Out-Null
Remove-Item -Path "$startMenuFolder\*" -Force -Recurse

# Find VS Code executable
$vscodePath = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe"
if (-not (Test-Path $vscodePath)) {
    $vscodePath = "C:\Program Files\Microsoft VS Code\Code.exe"
}
if (-not (Test-Path $vscodePath)) {
    Write-Error "VS Code not found"
    exit 1
}


# Recursive function: only output the topmost folder containing any target folder, skip all its subdirectories
$RootLevelSkipFolders = @(
    'AppData', 
    'go',
    '.vscode', 
    'Downloads'
)
$targetFolders = @(
    '.vscode', 
    '.git'
)
function Get-ProjectFolders {
    param(
        [string]$Path,
        [string]$RootPath = $Path
    )

    $dirs = Get-ChildItem -Path $Path -Directory -Force -ErrorAction SilentlyContinue
    $isRootLevel = $Path -eq $RootPath

    # Check if this directory contains any target folder
    $containsTarget = $false
    foreach ($target in $targetFolders) {
        if ($Path -eq $RootPath -and $target -in $RootLevelSkipFolders) {
            continue            
        }
        elseif (Test-Path (Join-Path $Path $target)) {
            $containsTarget = $true
            break
        }
    }

    if ($containsTarget) {
        # Output this directory and do not recurse further, unless it's the root search path itself
        if ($Path -ne $RootPath) {
            $Path
        }
        return
    }

    foreach ($dir in $dirs) {
        # At root level: skip folders in $RootLevelSkipFolders and hidden folders
        if ($isRootLevel -and ($dir.Name -in $RootLevelSkipFolders -or $dir.Name -like '.*')) {
            continue
        }
        # Otherwise, recurse into this directory
        Get-ProjectFolders -Path $dir.FullName -RootPath $RootPath
    }
}

# Get all project folders (topmost containing a target folder)
$FilePaths = Get-ProjectFolders -Path $projectsFolder |
    Select-Object -Unique

# Create shortcuts for each project
$shell = New-Object -ComObject WScript.Shell
$baseFolderName = Split-Path $projectsFolder -Leaf
Foreach ($path in $FilePaths) {
    $parts = $path.Split('\')    
    $baseIndex = [Array]::IndexOf($parts, $baseFolderName)
    
    $shortcutName = $parts[($baseIndex + 1)..($parts.Length - 1)] -join '\'
    $shortcutName = $shortcutName -replace '[\\\/:*?"<>|]', '-'
    
    $shortcutPath = "$startMenuFolder\$shortcutName.lnk"
    
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $vscodePath
    $shortcut.Arguments = "`"$path`""
    $shortcut.Save()

    echo "Created shortcut `"$shortcutName`""
}

$end = Get-Date
$duration = $end - $start
echo "Done. Created $($FilePaths.Count) shortcuts in $($duration.TotalSeconds) seconds."