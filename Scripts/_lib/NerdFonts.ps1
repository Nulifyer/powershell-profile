function Get-NerdFontInstallRoot {
    return "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
}

function Get-NerdFontsRegistryPath {
    return "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
}

function Get-InstalledNerdFonts {
    Add-Type -AssemblyName System.Drawing

    $allFonts = (New-Object System.Drawing.Text.InstalledFontCollection).Families |
        Where-Object { $_.Name -match 'Nerd|NF' } |
        Select-Object -ExpandProperty Name |
        Sort-Object

    return @{
        All  = @($allFonts)
        Base = @($allFonts | Where-Object { $_ -notmatch '(ExtraLight|Light|SemiBold|SemiLight)$' })
    }
}

function Get-NerdFontCatalog {
    $release = Invoke-RestMethod `
        -Uri "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest" `
        -Headers @{ "User-Agent" = "PowerShell-NerdFonts" }

    return @(
        $release.assets |
            Where-Object {
                $_.name -like '*.zip' -and
                $_.name -notmatch 'WindowsCompatible'
            } |
            ForEach-Object {
                $archiveName = [System.IO.Path]::GetFileNameWithoutExtension($_.name)
                @{
                    Name = $archiveName
                    AssetName = $_.name
                    DownloadUrl = $_.browser_download_url
                    SizeMb = [math]::Round(($_.size / 1MB), 1)
                }
            } |
            Sort-Object Name
    )
}

function Get-FontFamilyNameFromFile {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $collection = [System.Drawing.Text.PrivateFontCollection]::new()
    try {
        $collection.AddFontFile($Path)
        return $collection.Families | Select-Object -First 1 -ExpandProperty Name
    } catch {
        return $null
    } finally {
        $collection.Dispose()
    }
}

function Register-NerdFontFile {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $installRoot = Get-NerdFontInstallRoot
    $registryPath = Get-NerdFontsRegistryPath
    if (-not (Test-Path $installRoot)) {
        New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
    }
    if (-not (Test-Path $registryPath)) {
        New-Item -Path $registryPath -Force | Out-Null
    }

    $fileName = Split-Path $Path -Leaf
    $targetPath = Join-Path $installRoot $fileName
    Copy-Item -LiteralPath $Path -Destination $targetPath -Force

    $familyName = Get-FontFamilyNameFromFile -Path $targetPath
    $extension = [System.IO.Path]::GetExtension($targetPath).ToLowerInvariant()
    $kind = if ($extension -eq '.otf') { 'OpenType' } else { 'TrueType' }
    $valueName = if ($familyName) { "$familyName ($kind)" } else { "$fileName ($kind)" }

    New-ItemProperty -Path $registryPath -Name $valueName -Value $fileName -PropertyType String -Force | Out-Null

    return @{
        File = $fileName
        Family = $familyName
    }
}

function Update-FontCache {
    $signature = @"
using System;
using System.Runtime.InteropServices;

public static class FontBroadcast {
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr SendMessageTimeout(
        IntPtr hWnd,
        uint Msg,
        UIntPtr wParam,
        string lParam,
        uint fuFlags,
        uint uTimeout,
        out UIntPtr lpdwResult);
}
"@

    Add-Type -TypeDefinition $signature -ErrorAction SilentlyContinue
    $result = [UIntPtr]::Zero
    [void][FontBroadcast]::SendMessageTimeout([IntPtr]0xffff, 0x001D, [UIntPtr]::Zero, $null, 0x0002, 1000, [ref]$result)
}

function Install-NerdFontAsset {
    param(
        [Parameter(Mandatory)]
        [hashtable]$FontAsset
    )

    $tempRoot = Join-Path $env:TEMP "nerd-fonts"
    $downloadDir = Join-Path $tempRoot "downloads"
    $extractDir = Join-Path $tempRoot ([System.Guid]::NewGuid().ToString())

    foreach ($dir in @($tempRoot, $downloadDir, $extractDir)) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }

    $zipPath = Join-Path $downloadDir $FontAsset.AssetName
    Invoke-WebRequest -Uri $FontAsset.DownloadUrl -OutFile $zipPath -Headers @{ "User-Agent" = "PowerShell-NerdFonts" }
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force

    $fontFiles = Get-ChildItem -Path $extractDir -Recurse -File |
        Where-Object { $_.Extension -in @('.ttf', '.otf') }

    if (-not $fontFiles) {
        throw "No installable font files found in $($FontAsset.AssetName)."
    }

    $installed = foreach ($fontFile in $fontFiles) {
        Register-NerdFontFile -Path $fontFile.FullName
    }

    try {
        Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue
    } catch {}

    Update-FontCache

    return @($installed)
}
