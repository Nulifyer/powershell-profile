# Shared terminal configuration helpers for theme.ps1 and font.ps1
# Supports: Windows Terminal, Alacritty, Kitty, Ghostty, WezTerm, VS Code, Windows System

# ── Color utility helpers ───────────────────────────────────────────────────

function Adjust-HexBrightness([string]$hex, [int]$percent) {
    $r = [Convert]::ToInt32($hex.Substring(1,2),16)
    $g = [Convert]::ToInt32($hex.Substring(3,2),16)
    $b = [Convert]::ToInt32($hex.Substring(5,2),16)
    if ($percent -lt 0) {
        $factor = (100 + $percent) / 100.0
        $r = [Math]::Max(0, [int]($r * $factor))
        $g = [Math]::Max(0, [int]($g * $factor))
        $b = [Math]::Max(0, [int]($b * $factor))
    } else {
        $r = [Math]::Min(255, [int]($r + (255 - $r) * $percent / 100.0))
        $g = [Math]::Min(255, [int]($g + (255 - $g) * $percent / 100.0))
        $b = [Math]::Min(255, [int]($b + (255 - $b) * $percent / 100.0))
    }
    return "#{0:X2}{1:X2}{2:X2}" -f $r, $g, $b
}

function Convert-HexToABGR([string]$hex) {
    $r = [Convert]::ToInt32($hex.Substring(1,2),16)
    $g = [Convert]::ToInt32($hex.Substring(3,2),16)
    $b = [Convert]::ToInt32($hex.Substring(5,2),16)
    $abgr = "FF{0:X2}{1:X2}{2:X2}" -f $b, $g, $r
    return [Convert]::ToInt64($abgr, 16)
}

function _Is-LightTheme([string]$themeName) {
    return $themeName -in @('catppuccin_latte','gruvbox_light','everforest_light','tokyonight_light','rose_pine_dawn','flexoki_light','iceberg_light','oxocarbon_light')
}

# ── P/Invoke for Windows theming + wallpaper ────────────────────────────────

if (-not ([System.Management.Automation.PSTypeName]'NativeMethods').Type) {
    Add-Type @"
    using System;
    using System.Runtime.InteropServices;

    [StructLayout(LayoutKind.Sequential)]
    public struct IMMERSIVE_COLOR_PREFERENCE {
        public uint color1;
        public uint color2;
    }

    public class NativeMethods {
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern IntPtr SendMessageTimeout(
            IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
            uint fuFlags, uint uTimeout, out IntPtr lpdwResult);
        public static void BroadcastSettingChange() {
            IntPtr result;
            SendMessageTimeout((IntPtr)0xFFFF, 0x001A, UIntPtr.Zero, "ImmersiveColorSet",
                0x0002, 5000, out result);
        }

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
        public static void SetWallpaper(string path) {
            SystemParametersInfo(0x0014, 0, path, 0x01 | 0x02);
        }


        // uxtheme ordinal 104: GetUserColorPreference
        [DllImport("uxtheme.dll", EntryPoint = "#104")]
        public static extern int GetUserColorPreference(ref IMMERSIVE_COLOR_PREFERENCE pref, bool forceReload);

        // uxtheme ordinal 122: SetUserColorPreference
        [DllImport("uxtheme.dll", EntryPoint = "#122")]
        public static extern int SetUserColorPreference(ref IMMERSIVE_COLOR_PREFERENCE pref, bool forceCommit);

        public static void ApplyAccentColor(uint abgrColor) {
            var pref = new IMMERSIVE_COLOR_PREFERENCE();
            GetUserColorPreference(ref pref, false);
            pref.color1 = abgrColor;
            pref.color2 = abgrColor;
            SetUserColorPreference(ref pref, true);
        }
    }
"@
}

function Set-LockScreen([string]$imagePath) {
    $script = @"
[Windows.System.UserProfile.LockScreen, Windows.System.UserProfile, ContentType = WindowsRuntime] | Out-Null
[Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
Add-Type -AssemblyName System.Runtime.WindowsRuntime
`$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() |
    Where-Object { `$_.Name -eq 'AsTask' -and `$_.GetParameters().Count -eq 1 -and
        `$_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation``1' })[0]
`$asTaskAction = ([System.WindowsRuntimeSystemExtensions].GetMethods() |
    Where-Object { `$_.Name -eq 'AsTask' -and `$_.GetParameters().Count -eq 1 -and
        `$_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction' })[0]
`$op = [Windows.Storage.StorageFile]::GetFileFromPathAsync('$($imagePath -replace "'","''")')
`$task = `$asTask.MakeGenericMethod([Windows.Storage.StorageFile]).Invoke(`$null, @(`$op))
`$task.Wait()
`$file = `$task.Result
`$setOp = [Windows.System.UserProfile.LockScreen]::SetImageFileAsync(`$file)
`$setTask = `$asTaskAction.Invoke(`$null, @(`$setOp))
`$setTask.Wait()
"@
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $script 2>$null
}

# ── Terminal config ─────────────────────────────────────────────────────────

$script:WT_SETTINGS = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$script:NULIFYR_GUID = "{f1a2b3c4-d5e6-4f78-9a0b-1c2d3e4f5a6b}"

# Ensure our WT profile exists in settings.json, create if missing, set as default
function _Ensure-WTProfile {
    if (-not (Test-Path $script:WT_SETTINGS)) { return $null }
    $wt = Get-Content $script:WT_SETTINGS -Raw | ConvertFrom-Json

    $profile = $wt.profiles.list | Where-Object { $_.guid -eq $script:NULIFYR_GUID }
    if (-not $profile) {
        $profile = [PSCustomObject]@{
            guid = $script:NULIFYR_GUID
            name = "Nulifyer's Profile"
            commandline = "pwsh.exe -NoLogo"
            cursorShape = "filledBox"
            font = [PSCustomObject]@{ face = "CaskaydiaMono NF"; size = 11 }
            opacity = 95
            padding = "10"
            scrollbarState = "hidden"
            historySize = 10000
        }
        $newList = [System.Collections.ArrayList]@($wt.profiles.list)
        $newList.Add($profile) | Out-Null
        $wt.profiles | Add-Member -NotePropertyName "list" -NotePropertyValue $newList.ToArray() -Force
    }

    # Set as default
    if ($wt.defaultProfile -ne $script:NULIFYR_GUID) {
        $wt.defaultProfile = $script:NULIFYR_GUID
    }

    return $wt
}

# WezTerm built-in color scheme name mappings
$script:WEZTERM_SCHEMES = @{
    "Catppuccin Mocha"     = "Catppuccin Mocha"
    "Catppuccin Macchiato" = "Catppuccin Macchiato"
    "Catppuccin Frappe"    = "Catppuccin Frappe"
    "Catppuccin Latte"     = "Catppuccin Latte"
    "Gruvbox Dark"         = "GruvboxDarkHard"
    "Gruvbox Light"        = "Gruvbox light, medium (base16)"
    "Everforest Dark"      = "Everforest Dark Hard (Gogh)"
    "Everforest Light"     = "Everforest Light Hard (Gogh)"
    "Tokyo Night"          = "Tokyo Night"
    "Tokyo Night Light"    = "Tokyo Night Light (Gogh)"
    "Nord"                 = "nord"
    "Dracula"              = "Dracula (Official)"
    "Rose Pine"            = "rose-pine"
    "Rose Pine Dawn"       = "rose-pine-dawn"
    "Kanagawa"             = "Kanagawa (Gogh)"
    "Solarized Dark"       = "Solarized Dark (Gogh)"
    "One Dark"             = "One Dark (Gogh)"
}

# ── Config file paths per terminal ───────────────────────────────────────────

function _Get-TerminalConfigs {
    $configs = @{}

    # Alacritty — %APPDATA%\alacritty\alacritty.toml or ~/.config/alacritty/alacritty.toml
    foreach ($p in @("$env:APPDATA\alacritty\alacritty.toml", "$env:USERPROFILE\.config\alacritty\alacritty.toml")) {
        if (Test-Path $p) { $configs.alacritty = $p; break }
    }

    # Kitty — ~/.config/kitty/kitty.conf
    foreach ($p in @("$env:USERPROFILE\.config\kitty\kitty.conf", "$env:APPDATA\kitty\kitty.conf")) {
        if (Test-Path $p) { $configs.kitty = $p; break }
    }

    # Ghostty — %APPDATA%\ghostty\config or ~/.config/ghostty/config
    foreach ($p in @("$env:APPDATA\ghostty\config", "$env:USERPROFILE\.config\ghostty\config")) {
        if (Test-Path $p) { $configs.ghostty = $p; break }
    }

    # WezTerm — ~/.config/wezterm/wezterm.lua or ~/.wezterm.lua
    foreach ($p in @("$env:USERPROFILE\.config\wezterm\wezterm.lua", "$env:USERPROFILE\.wezterm.lua")) {
        if (Test-Path $p) { $configs.wezterm = $p; break }
    }

    # Windows Terminal
    if (Test-Path $script:WT_SETTINGS) { $configs.wt = $script:WT_SETTINGS }

    return $configs
}

# ── Font updates ─────────────────────────────────────────────────────────────

function Update-TerminalFont([string]$FontName) {
    $configs = _Get-TerminalConfigs
    $updated = @()

    # Windows Terminal — settings.json (creates profile + sets default if needed)
    if ($configs.wt) {
        try {
            $wt = _Ensure-WTProfile
            if ($wt) {
                $profile = $wt.profiles.list | Where-Object { $_.guid -eq $script:NULIFYR_GUID }
                if (-not $profile.font) {
                    $profile | Add-Member -NotePropertyName "font" -NotePropertyValue ([PSCustomObject]@{ face = $FontName; size = 11 }) -Force
                } else {
                    $profile.font | Add-Member -NotePropertyName "face" -NotePropertyValue $FontName -Force
                }
                $wt | ConvertTo-Json -Depth 10 | Set-Content $configs.wt -Encoding UTF8
                $updated += "Windows Terminal"
            }
        } catch {}
    }

    # Alacritty — TOML: [font.normal] family = "..."
    if ($configs.alacritty) {
        try {
            $content = Get-Content $configs.alacritty -Raw -ErrorAction Stop
            $content = $content -replace 'family\s*=\s*"[^"]*"', "family = `"$FontName`""
            $content | Set-Content $configs.alacritty -Encoding UTF8
            $updated += "Alacritty"
        } catch {}
    }

    # Kitty — space-delimited: font_family <name>
    if ($configs.kitty) {
        try {
            $content = Get-Content $configs.kitty -Raw -ErrorAction Stop
            if ($content -match '(?m)^font_family\s') {
                $content = $content -replace '(?m)^font_family\s+.*', "font_family $FontName"
                $content = $content -replace '(?m)^bold_font\s+.*', "bold_font auto"
                $content = $content -replace '(?m)^italic_font\s+.*', "italic_font auto"
                $content = $content -replace '(?m)^bold_italic_font\s+.*', "bold_italic_font auto"
            } else {
                $content += "`nfont_family $FontName`nbold_font auto`nitalic_font auto`nbold_italic_font auto`n"
            }
            $content | Set-Content $configs.kitty -Encoding UTF8
            $updated += "Kitty"
        } catch {}
    }

    # Ghostty — key=value: font-family = <name>
    if ($configs.ghostty) {
        try {
            $content = Get-Content $configs.ghostty -Raw -ErrorAction Stop
            if ($content -match '(?m)^font-family\s*=') {
                $content = $content -replace '(?m)^font-family\s*=\s*.*', "font-family = $FontName"
                $content = $content -replace '(?m)^font-family-bold\s*=\s*.*', "font-family-bold = $FontName"
                $content = $content -replace '(?m)^font-family-italic\s*=\s*.*', "font-family-italic = $FontName"
                $content = $content -replace '(?m)^font-family-bold-italic\s*=\s*.*', "font-family-bold-italic = $FontName"
            } else {
                $content += "`nfont-family = $FontName`n"
            }
            $content | Set-Content $configs.ghostty -Encoding UTF8
            $updated += "Ghostty"
        } catch {}
    }

    # WezTerm — Lua: config.font = wezterm.font("...")
    if ($configs.wezterm) {
        try {
            $content = Get-Content $configs.wezterm -Raw -ErrorAction Stop
            if ($content -match "config\.font\s*=") {
                $content = $content -replace "config\.font\s*=\s*wezterm\.font[^)]*\)", "config.font = wezterm.font(`"$FontName`")"
            } elseif ($content -match "font\s*=\s*wezterm\.font") {
                $content = $content -replace "font\s*=\s*wezterm\.font[^)]*\)", "font = wezterm.font(`"$FontName`")"
            }
            $content | Set-Content $configs.wezterm -Encoding UTF8
            $updated += "WezTerm"
        } catch {}
    }

    return $updated
}

# ── Theme/color updates ──────────────────────────────────────────────────────

function Update-TerminalColors([hashtable]$scheme) {
    $configs = _Get-TerminalConfigs
    $updated = @()
    $schemeName = $scheme.name

    # ── Windows Terminal — settings.json (creates profile + sets default if needed)

    if ($configs.wt) {
        try {
            $wt = _Ensure-WTProfile
            if ($wt) {
                # Add or update the color scheme
                $existingScheme = $wt.schemes | Where-Object { $_.name -eq $schemeName }
                if ($existingScheme) {
                    foreach ($key in $scheme.Keys) { $existingScheme | Add-Member -NotePropertyName $key -NotePropertyValue $scheme[$key] -Force }
                } else {
                    $newSchemes = [System.Collections.ArrayList]@($wt.schemes)
                    $newSchemes.Add([PSCustomObject]$scheme) | Out-Null
                    $wt | Add-Member -NotePropertyName "schemes" -NotePropertyValue $newSchemes.ToArray() -Force
                }

                # Set colorScheme and opacity on the profile
                $profile = $wt.profiles.list | Where-Object { $_.guid -eq $script:NULIFYR_GUID }
                $profile | Add-Member -NotePropertyName "colorScheme" -NotePropertyValue $schemeName -Force
                $profile | Add-Member -NotePropertyName "opacity" -NotePropertyValue 95 -Force
                $profile | Add-Member -NotePropertyName "useAcrylic" -NotePropertyValue $false -Force
                $profile.PSObject.Properties.Remove("background")

                $wt | ConvertTo-Json -Depth 10 | Set-Content $configs.wt -Encoding UTF8
                $updated += "Windows Terminal"
            }
        } catch {}
    }

    # ── Alacritty — TOML [colors.*] sections ─────────────────────────────────

    if ($configs.alacritty) {
        try {
            $content = Get-Content $configs.alacritty -Raw -ErrorAction Stop

            # Remove existing [colors.*] sections and any stray top-level color keys
            $content = $content -replace '(?ms)^\[colors\.primary\].*?(?=^\[[^\]]*\]|\z)', ''
            $content = $content -replace '(?ms)^\[colors\.normal\].*?(?=^\[[^\]]*\]|\z)', ''
            $content = $content -replace '(?ms)^\[colors\.bright\].*?(?=^\[[^\]]*\]|\z)', ''
            $content = $content -replace '(?ms)^\[colors\.cursor\].*?(?=^\[[^\]]*\]|\z)', ''
            $content = $content -replace '(?ms)^\[colors\.selection\].*?(?=^\[[^\]]*\]|\z)', ''
            # Remove stray bare background/foreground keys (not under a [section])
            $content = $content -replace '(?m)^#[^\n]*COLORS[^\n]*\n', ''
            $content = $content -replace '(?m)^background\s*=\s*"[^"]*"\s*$', ''
            $content = $content -replace '(?m)^foreground\s*=\s*"[^"]*"\s*$', ''
            $content = $content -replace '(\r?\n){3,}', "`n`n"
            $content = $content.TrimEnd()

            $colors = @"

[colors.primary]
background = "$($scheme.background)"
foreground = "$($scheme.foreground)"

[colors.cursor]
text = "CellBackground"
cursor = "$($scheme.cursorColor)"

[colors.selection]
text = "CellBackground"
background = "$($scheme.selectionBackground)"

[colors.normal]
black   = "$($scheme.black)"
red     = "$($scheme.red)"
green   = "$($scheme.green)"
yellow  = "$($scheme.yellow)"
blue    = "$($scheme.blue)"
magenta = "$($scheme.purple)"
cyan    = "$($scheme.cyan)"
white   = "$($scheme.white)"

[colors.bright]
black   = "$($scheme.brightBlack)"
red     = "$($scheme.brightRed)"
green   = "$($scheme.brightGreen)"
yellow  = "$($scheme.brightYellow)"
blue    = "$($scheme.brightBlue)"
magenta = "$($scheme.brightPurple)"
cyan    = "$($scheme.brightCyan)"
white   = "$($scheme.brightWhite)"
"@
            ($content + "`n" + $colors) | Set-Content $configs.alacritty -Encoding UTF8
            $updated += "Alacritty"
        } catch {}
    }

    # ── Kitty — space-delimited key value ────────────────────────────────────

    if ($configs.kitty) {
        try {
            $content = Get-Content $configs.kitty -Raw -ErrorAction Stop

            $kittyColors = @(
                "background           $($scheme.background)"
                "foreground           $($scheme.foreground)"
                "cursor               $($scheme.cursorColor)"
                "cursor_text_color    background"
                "selection_foreground none"
                "selection_background $($scheme.selectionBackground)"
                "color0  $($scheme.black)"
                "color1  $($scheme.red)"
                "color2  $($scheme.green)"
                "color3  $($scheme.yellow)"
                "color4  $($scheme.blue)"
                "color5  $($scheme.purple)"
                "color6  $($scheme.cyan)"
                "color7  $($scheme.white)"
                "color8  $($scheme.brightBlack)"
                "color9  $($scheme.brightRed)"
                "color10 $($scheme.brightGreen)"
                "color11 $($scheme.brightYellow)"
                "color12 $($scheme.brightBlue)"
                "color13 $($scheme.brightPurple)"
                "color14 $($scheme.brightCyan)"
                "color15 $($scheme.brightWhite)"
            )

            # Remove existing color lines
            $lines = $content -split "`n" | Where-Object {
                $_ -notmatch '^\s*(background|foreground|cursor|cursor_text_color|selection_foreground|selection_background|color\d+)\s'
            }
            # Remove old theme comment
            $lines = $lines | Where-Object { $_ -notmatch '^\s*#\s*Theme:' }
            $content = ($lines -join "`n").TrimEnd()

            $content += "`n`n# Theme: $schemeName`n"
            $content += ($kittyColors -join "`n") + "`n"
            $content | Set-Content $configs.kitty -Encoding UTF8
            $updated += "Kitty"
        } catch {}
    }

    # ── Ghostty — key = value, palette = N=#hex ──────────────────────────────

    if ($configs.ghostty) {
        try {
            $content = Get-Content $configs.ghostty -Raw -ErrorAction Stop

            $ghosttyColors = @(
                "background = $($scheme.background)"
                "foreground = $($scheme.foreground)"
                "cursor-color = $($scheme.cursorColor)"
                "selection-background = $($scheme.selectionBackground)"
                "palette = 0=$($scheme.black)"
                "palette = 1=$($scheme.red)"
                "palette = 2=$($scheme.green)"
                "palette = 3=$($scheme.yellow)"
                "palette = 4=$($scheme.blue)"
                "palette = 5=$($scheme.purple)"
                "palette = 6=$($scheme.cyan)"
                "palette = 7=$($scheme.white)"
                "palette = 8=$($scheme.brightBlack)"
                "palette = 9=$($scheme.brightRed)"
                "palette = 10=$($scheme.brightGreen)"
                "palette = 11=$($scheme.brightYellow)"
                "palette = 12=$($scheme.brightBlue)"
                "palette = 13=$($scheme.brightPurple)"
                "palette = 14=$($scheme.brightCyan)"
                "palette = 15=$($scheme.brightWhite)"
            )

            # Remove existing color/palette lines
            $lines = $content -split "`n" | Where-Object {
                $_ -notmatch '^\s*(background|foreground|cursor-color|selection-background|palette)\s*='
            }
            $lines = $lines | Where-Object { $_ -notmatch '^\s*#\s*Theme:' }
            $content = ($lines -join "`n").TrimEnd()

            $content += "`n`n# Theme: $schemeName`n"
            $content += ($ghosttyColors -join "`n") + "`n"
            $content | Set-Content $configs.ghostty -Encoding UTF8
            $updated += "Ghostty"
        } catch {}
    }

    # ── WezTerm — Lua config.color_scheme ────────────────────────────────────

    if ($configs.wezterm) {
        try {
            $content = Get-Content $configs.wezterm -Raw -ErrorAction Stop
            $weztermScheme = if ($script:WEZTERM_SCHEMES[$schemeName]) { $script:WEZTERM_SCHEMES[$schemeName] } else { $schemeName }

            if ($content -match "config\.color_scheme\s*=") {
                $content = $content -replace "config\.color_scheme\s*=\s*[`"'][^`"']*[`"']", "config.color_scheme = `"$weztermScheme`""
            } elseif ($content -match "color_scheme\s*=\s*[`"']") {
                $content = $content -replace "color_scheme\s*=\s*[`"'][^`"']*[`"']", "color_scheme = `"$weztermScheme`""
            }
            $content | Set-Content $configs.wezterm -Encoding UTF8
            $updated += "WezTerm"
        } catch {}
    }

    return $updated
}

# ── VS Code theme generation ───────────────────────────────────────────────
# Uses a local Nulifyer extension with file watcher for live reload.
# The extension source lives in Scripts/theme/vscode-extension/ and is
# synced to ~/.vscode/extensions/nulifyer-theme/ on theme switch.

$script:VS_EXT_SOURCE = "$PSScriptRoot\..\theme\vscode-extension"
function _Sync-VSCodeExtension {
    if (-not (Test-Path $script:VS_EXT_SOURCE)) { return }
    $sourceVersion = (Get-Content "$script:VS_EXT_SOURCE\package.json" -Raw | ConvertFrom-Json).version
    $script:VS_EXT_DEST = "$env:USERPROFILE\.vscode\extensions\nulifyer.nulifyer-theme-$sourceVersion"
    $destPkg = "$script:VS_EXT_DEST\package.json"
    $needsSync = -not (Test-Path $destPkg)
    if (-not $needsSync) {
        $destVersion = (Get-Content $destPkg -Raw | ConvertFrom-Json).version
        $needsSync = $destVersion -ne $sourceVersion
    }
    if ($needsSync) {
        if (Test-Path $script:VS_EXT_DEST) { Remove-Item $script:VS_EXT_DEST -Recurse -Force }
        # Copy only what VS Code needs: package.json + themes/
        New-Item -ItemType Directory -Path "$script:VS_EXT_DEST\themes" -Force | Out-Null
        Copy-Item "$script:VS_EXT_SOURCE\package.json" "$script:VS_EXT_DEST\package.json" -Force
        Copy-Item "$script:VS_EXT_SOURCE\themes\nulifyer.json" "$script:VS_EXT_DEST\themes\nulifyer.json" -Force
        # Register in extensions.json so VS Code recognizes it
        _Register-VSCodeExtension
    }
}

function _Register-VSCodeExtension {
    $extJsonPath = "$env:USERPROFILE\.vscode\extensions\extensions.json"
    if (-not (Test-Path $extJsonPath)) { return }
    try {
        $extensions = Get-Content $extJsonPath -Raw -ErrorAction Stop | ConvertFrom-Json
        $extId = "nulifyer.nulifyer-theme"
        $already = $extensions | Where-Object { $_.identifier.id -eq $extId }
        if (-not $already) {
            $entry = [PSCustomObject]@{
                identifier = [PSCustomObject]@{ id = $extId }
                version = (Get-Content "$script:VS_EXT_SOURCE\package.json" -Raw | ConvertFrom-Json).version
                location = [PSCustomObject]@{
                    '$mid' = 1
                    path = ($script:VS_EXT_DEST -replace '\\','/' -replace '^C:','/c:')
                    scheme = "file"
                }
                relativeLocation = Split-Path $script:VS_EXT_DEST -Leaf
                metadata = [PSCustomObject]@{
                    installedTimestamp = [long]([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
                    source = "local"
                }
            }
            $extensions = @($extensions) + @($entry)
            ConvertTo-Json $extensions -Depth 10 | Set-Content $extJsonPath -Encoding UTF8
        }
    } catch {}
}

function Update-VSCodeTheme([hashtable]$scheme, [string]$themeName) {
    _Sync-VSCodeExtension
    $themeFile = "$script:VS_EXT_DEST\themes\nulifyer.json"
    if (-not (Test-Path (Split-Path $themeFile))) { return }

    $vsSettingsPath = "$env:APPDATA\Code\User\settings.json"

    $isLight = _Is-LightTheme $themeName

    # Background tiers
    $bgBase = $scheme.background
    $bgMid = Adjust-HexBrightness $bgBase $(if ($isLight) { 5 } else { -15 })
    $bgDarkest = Adjust-HexBrightness $bgBase $(if ($isLight) { 10 } else { -30 })
    $bgSurface = Adjust-HexBrightness $bgBase $(if ($isLight) { -5 } else { 8 })
    $bgHover = $scheme.foreground + "15"
    $bgBorder = Adjust-HexBrightness $bgBase $(if ($isLight) { -8 } else { 12 })

    $fg = $scheme.foreground
    $fgDim = $scheme.white           # ANSI white — readable UI text (sidebar, statusbar, menus)
    $fgMuted = $scheme.brightBlack   # comments, line numbers, inlay hints
    $cursor = $scheme.cursorColor

    # Build colors object
    $colors = [ordered]@{
        "foreground" = $fgDim
        "errorForeground" = $scheme.red
        "focusBorder" = "#00000000"
        "selection.background" = $scheme.blue + "40"
        "descriptionForeground" = $fgDim
        "widget.shadow" = "#00000070"
        "icon.foreground" = $scheme.yellow
        "editor.background" = $bgBase
        "editor.foreground" = $fg
        "editorCursor.foreground" = $cursor
        "editor.selectionBackground" = $scheme.blue + "40"
        "editor.selectionHighlightBackground" = $scheme.blue + "18"
        "editor.inactiveSelectionBackground" = $scheme.blue + "10"
        "editor.wordHighlightBackground" = $bgSurface + "58"
        "editor.wordHighlightStrongBackground" = $bgSurface + "B0"
        "editor.findMatchBackground" = $scheme.yellow + "40"
        "editor.findMatchHighlightBackground" = $scheme.green + "40"
        "editor.findRangeHighlightBackground" = $scheme.green + "20"
        "editor.lineHighlightBackground" = $bgSurface + "90"
        "editor.lineHighlightBorder" = "#00000000"
        "editor.rangeHighlightBackground" = $bgSurface + "80"
        "editor.foldBackground" = $bgBorder + "80"
        "editorLink.activeForeground" = $scheme.green
        "editorWhitespace.foreground" = $bgBorder
        "editorOverviewRuler.border" = "#00000000"
        "editorLineNumber.foreground" = $fgMuted
        "editorLineNumber.activeForeground" = $fg
        "editorBracketHighlight.foreground1" = $scheme.yellow
        "editorBracketHighlight.foreground2" = $scheme.yellow
        "editorBracketHighlight.foreground3" = $scheme.yellow
        "editorBracketHighlight.foreground4" = $scheme.yellow
        "editorBracketHighlight.foreground5" = $scheme.yellow
        "editorBracketHighlight.foreground6" = $scheme.yellow
        "editorBracketMatch.background" = $fgMuted + "80"
        "editorBracketMatch.border" = "#00000000"
        "editorError.foreground" = $scheme.red
        "editorError.background" = $scheme.red + "20"
        "editorWarning.foreground" = $scheme.yellow
        "editorWarning.background" = $scheme.yellow + "20"
        "editorInfo.foreground" = $scheme.blue
        "editorInfo.background" = $scheme.blue + "20"
        "editorHint.foreground" = $scheme.purple
        "editorGutter.background" = "#00000000"
        "editorGutter.addedBackground" = $scheme.green + "A0"
        "editorGutter.modifiedBackground" = $scheme.blue + "A0"
        "editorGutter.deletedBackground" = $scheme.red + "A0"
        "editorGutter.commentRangeForeground" = $fgMuted
        "editorInlayHint.foreground" = $fgMuted + "A0"
        "editorInlayHint.background" = "#00000000"
        "editorCodeLens.foreground" = $fgMuted
        "editorSuggestWidget.background" = $bgSurface
        "editorSuggestWidget.border" = $bgSurface
        "editorSuggestWidget.foreground" = $fg
        "editorSuggestWidget.highlightForeground" = $scheme.green
        "editorSuggestWidget.selectedBackground" = $bgBorder
        "editorHoverWidget.background" = $bgSurface
        "editorHoverWidget.border" = $bgBorder
        "editorWidget.background" = $bgBase
        "editorWidget.foreground" = $fg
        "editorWidget.border" = $fgMuted
        "editorGhostText.foreground" = $fgMuted
        "editorGroup.border" = $bgDarkest
        "editorGroupHeader.tabsBackground" = $bgBase
        "editorGroupHeader.noTabsBackground" = $bgBase
        "tab.activeBackground" = $bgBase
        "tab.activeForeground" = $fg
        "tab.activeBorder" = $fgMuted
        "tab.inactiveBackground" = $bgBase
        "tab.inactiveForeground" = $fgDim
        "tab.border" = $bgBase
        "tab.hoverBackground" = $bgBase
        "tab.hoverForeground" = $fg
        "tab.lastPinnedBorder" = $fgMuted
        "tab.unfocusedActiveBorder" = $fgMuted
        "tab.unfocusedActiveForeground" = $fgDim
        "tab.unfocusedInactiveForeground" = $fgMuted
        "sideBar.background" = $bgMid
        "sideBar.foreground" = $fgDim
        "sideBarTitle.foreground" = $fgDim
        "sideBarSectionHeader.background" = "#00000000"
        "sideBarSectionHeader.foreground" = $fgDim
        "activityBar.background" = $bgMid
        "activityBar.foreground" = $fgDim
        "activityBar.inactiveForeground" = (Adjust-HexBrightness $fgMuted -30)
        "activityBar.border" = $bgMid
        "activityBar.activeBorder" = $fgMuted
        "activityBarBadge.background" = $scheme.yellow
        "activityBarBadge.foreground" = $bgBase
        "panel.background" = $bgMid
        "panel.border" = $bgMid
        "panelTitle.activeForeground" = $fgDim
        "panelTitle.activeBorder" = $fgDim
        "panelTitle.inactiveForeground" = (Adjust-HexBrightness $fgMuted -30)
        "panelSectionHeader.background" = $bgSurface
        "statusBar.background" = $bgDarkest
        "statusBar.foreground" = $fgDim
        "statusBar.border" = $bgDarkest
        "statusBar.debuggingBackground" = $bgDarkest
        "statusBar.debuggingForeground" = $scheme.yellow
        "statusBar.noFolderBackground" = $bgDarkest
        "statusBar.noFolderForeground" = $fgDim
        "statusBar.noFolderBorder" = $bgDarkest
        "statusBarItem.hoverBackground" = $bgSurface
        "statusBarItem.activeBackground" = $bgSurface + "A0"
        "statusBarItem.remoteBackground" = $bgDarkest
        "statusBarItem.remoteForeground" = $fgDim
        "statusBarItem.errorBackground" = $bgDarkest
        "statusBarItem.errorForeground" = $scheme.red
        "statusBarItem.warningBackground" = $bgDarkest
        "statusBarItem.warningForeground" = $scheme.yellow
        "titleBar.activeBackground" = $bgDarkest
        "titleBar.activeForeground" = $fgDim
        "titleBar.inactiveBackground" = $bgDarkest
        "titleBar.inactiveForeground" = (Adjust-HexBrightness $fgMuted -30)
        "titleBar.border" = $bgDarkest
        "menu.background" = $bgDarkest
        "menu.foreground" = $fgDim
        "menu.selectionBackground" = $bgBase
        "menu.selectionForeground" = $fg
        "menubar.selectionBackground" = $bgBase
        "menubar.selectionBorder" = $bgBase
        "list.focusBackground" = $bgHover
        "list.focusForeground" = $fg
        "list.focusOutline" = "#00000000"
        "list.activeSelectionBackground" = $scheme.foreground + "10"
        "list.activeSelectionForeground" = $fg
        "list.focusAndSelectionOutline" = $fg + "80"
        "list.inactiveSelectionBackground" = $bgBase
        "list.inactiveSelectionForeground" = $fg
        "list.hoverBackground" = $bgHover
        "list.hoverForeground" = $fg
        "list.highlightForeground" = $scheme.green
        "list.errorForeground" = $scheme.red
        "list.warningForeground" = $scheme.yellow
        "tree.indentGuidesStroke" = $fgMuted
        "input.background" = "#00000000"
        "input.border" = $fg + "40"
        "input.foreground" = $fg
        "input.placeholderForeground" = $fg + "80"
        "inputOption.activeBorder" = $scheme.yellow
        "inputOption.activeForeground" = $scheme.yellow
        "inputValidation.errorBackground" = $scheme.red
        "inputValidation.errorBorder" = $scheme.red
        "inputValidation.errorForeground" = $fg
        "inputValidation.warningBackground" = $scheme.yellow
        "inputValidation.warningBorder" = $scheme.yellow
        "inputValidation.warningForeground" = $fg
        "inputValidation.infoBackground" = $scheme.blue
        "inputValidation.infoBorder" = $scheme.blue
        "inputValidation.infoForeground" = $fg
        "button.background" = $scheme.cyan
        "button.foreground" = $bgBase
        "button.hoverBackground" = (Adjust-HexBrightness $scheme.cyan -15)
        "button.secondaryBackground" = $bgSurface
        "button.secondaryForeground" = $fg
        "button.secondaryHoverBackground" = $bgBorder
        "dropdown.background" = $bgBase
        "dropdown.border" = $bgBorder
        "dropdown.foreground" = $fgDim
        "badge.background" = $scheme.yellow
        "badge.foreground" = $bgBase
        "scrollbar.shadow" = "#00000070"
        "scrollbarSlider.background" = $fgMuted + "40"
        "scrollbarSlider.hoverBackground" = $fgMuted + "60"
        "scrollbarSlider.activeBackground" = $fgMuted + "80"
        "minimap.errorHighlight" = $scheme.red
        "minimap.warningHighlight" = $scheme.yellow
        "minimap.selectionHighlight" = $fgMuted + "80"
        "minimap.findMatchHighlight" = $scheme.green + "D0"
        "peekView.border" = $bgSurface
        "peekViewTitle.background" = $bgSurface
        "peekViewTitleLabel.foreground" = $scheme.green
        "peekViewTitleDescription.foreground" = $fg
        "peekViewEditor.background" = $bgSurface
        "peekViewEditor.matchHighlightBackground" = $scheme.yellow + "50"
        "peekViewEditorGutter.background" = $bgSurface
        "peekViewResult.background" = $bgSurface
        "peekViewResult.fileForeground" = $fg
        "peekViewResult.lineForeground" = $fgMuted
        "peekViewResult.matchHighlightBackground" = $scheme.yellow + "50"
        "peekViewResult.selectionBackground" = $scheme.green + "50"
        "diffEditor.insertedTextBackground" = $scheme.green + "40"
        "diffEditor.removedTextBackground" = $scheme.red + "40"
        "diffEditor.diagonalFill" = $bgBorder
        "notificationCenterHeader.background" = $bgBorder
        "notificationCenterHeader.foreground" = $fg
        "notifications.background" = $bgBase
        "notifications.foreground" = $fg
        "notificationsErrorIcon.foreground" = $scheme.red
        "notificationsWarningIcon.foreground" = $scheme.yellow
        "notificationsInfoIcon.foreground" = $scheme.blue
        "notificationLink.foreground" = $scheme.green
        "progressBar.background" = $scheme.yellow
        "gitDecoration.addedResourceForeground" = $scheme.green + "A0"
        "gitDecoration.modifiedResourceForeground" = $scheme.blue + "A0"
        "gitDecoration.deletedResourceForeground" = $scheme.red + "A0"
        "gitDecoration.untrackedResourceForeground" = $scheme.yellow + "A0"
        "gitDecoration.ignoredResourceForeground" = (Adjust-HexBrightness $fgMuted -30)
        "gitDecoration.conflictingResourceForeground" = $scheme.purple + "A0"
        "gitDecoration.stageModifiedResourceForeground" = $scheme.cyan + "A0"
        "gitDecoration.stageDeletedResourceForeground" = $scheme.cyan + "A0"
        "gitDecoration.submoduleResourceForeground" = $scheme.yellow + "A0"
        "quickInputTitle.background" = $bgSurface
        "pickerGroup.foreground" = $fg
        "pickerGroup.border" = $fg + "1A"
        "textLink.foreground" = $scheme.green
        "textLink.activeForeground" = (Adjust-HexBrightness $scheme.green -15)
        "textPreformat.foreground" = $scheme.yellow
        "textBlockQuote.background" = $bgSurface
        "textBlockQuote.border" = $fgMuted
        "textCodeBlock.background" = $bgSurface
        "terminal.background" = $bgBase
        "terminal.foreground" = $fg
        "terminalCursor.foreground" = $fg
        "terminal.ansiBlack" = $scheme.black
        "terminal.ansiRed" = $scheme.red
        "terminal.ansiGreen" = $scheme.green
        "terminal.ansiYellow" = $scheme.yellow
        "terminal.ansiBlue" = $scheme.blue
        "terminal.ansiMagenta" = $scheme.purple
        "terminal.ansiCyan" = $scheme.cyan
        "terminal.ansiWhite" = $scheme.white
        "terminal.ansiBrightBlack" = $scheme.brightBlack
        "terminal.ansiBrightRed" = $scheme.brightRed
        "terminal.ansiBrightGreen" = $scheme.brightGreen
        "terminal.ansiBrightYellow" = $scheme.brightYellow
        "terminal.ansiBrightBlue" = $scheme.brightBlue
        "terminal.ansiBrightMagenta" = $scheme.brightPurple
        "terminal.ansiBrightCyan" = $scheme.brightCyan
        "terminal.ansiBrightWhite" = $scheme.brightWhite
        "debugIcon.startForeground" = $scheme.cyan
        "debugIcon.pauseForeground" = $scheme.yellow
        "debugIcon.stopForeground" = $scheme.red
        "debugIcon.restartForeground" = $scheme.cyan
        "debugIcon.breakpointForeground" = $scheme.yellow
        "debugConsole.errorForeground" = $scheme.red
        "debugConsole.warningForeground" = $scheme.yellow
        "debugConsole.infoForeground" = $scheme.green
        "debugTokenExpression.error" = $scheme.red
        "debugTokenExpression.value" = $scheme.green
        "debugTokenExpression.string" = $scheme.yellow
        "debugTokenExpression.boolean" = $scheme.purple
        "debugTokenExpression.number" = $scheme.purple
        "debugTokenExpression.name" = $scheme.blue
        "testing.iconFailed" = $scheme.red
        "testing.iconErrored" = $scheme.red
        "testing.iconPassed" = $scheme.cyan
        "testing.iconQueued" = $scheme.blue
        "testing.iconSkipped" = $scheme.purple
        "testing.iconUnset" = $scheme.yellow
        "testing.runAction" = $scheme.cyan
        "charts.red" = $scheme.red
        "charts.orange" = $scheme.brightRed
        "charts.yellow" = $scheme.yellow
        "charts.green" = $scheme.green
        "charts.blue" = $scheme.blue
        "charts.purple" = $scheme.purple
        "charts.foreground" = $fg
        "problemsErrorIcon.foreground" = $scheme.red
        "problemsWarningIcon.foreground" = $scheme.yellow
        "problemsInfoIcon.foreground" = $scheme.blue
        "breadcrumb.foreground" = $fgDim
        "breadcrumb.focusForeground" = $fg
        "breadcrumb.activeSelectionForeground" = $fg
        "settings.headerForeground" = $fgDim
        "settings.modifiedItemIndicator" = $fgMuted
        "settings.focusedRowBackground" = $bgSurface
        "settings.rowHoverBackground" = $bgSurface
    }

    # Token color mapping — one rule per scope to ensure specificity over base theme
    $orange = $scheme.brightRed   # brightRed is typically the orange slot in most themes

    # Helper to generate standalone rules — each scope gets its own entry
    function _tc([string]$scope, [string]$color, [string]$style) {
        $s = @{ foreground = $color }
        if ($style) { $s.fontStyle = $style }
        return @{ scope = $scope; settings = $s }
    }

    $tokenColors = @(
        # ── Standalone rules for every base theme scope (prevents Dark VS/Dark+ color leaks) ──

        # Comments — muted
        (_tc "comment" $fgMuted)
        (_tc "punctuation.definition.comment" $fgMuted)

        # Strings — dim green
        (_tc "string" $scheme.brightGreen)
        (_tc "string.tag" $scheme.brightGreen)
        (_tc "string.value" $scheme.brightGreen)
        (_tc "string.regexp" $scheme.cyan)
        (_tc "string meta.image.inline.markdown" $scheme.brightGreen)
        (_tc "meta.embedded.assembly" $scheme.brightGreen)
        (_tc "meta.preprocessor.string" $scheme.brightGreen)
        (_tc "punctuation.definition.string.begin" $scheme.brightGreen)
        (_tc "punctuation.definition.string.end" $scheme.brightGreen)
        (_tc "punctuation.definition.string.template.begin" $scheme.brightGreen)
        (_tc "punctuation.definition.string.template.end" $scheme.brightGreen)

        # Constants — purple
        (_tc "constant.language" $scheme.purple)
        (_tc "constant.numeric" $scheme.purple)
        (_tc "constant.character" $scheme.purple)
        (_tc "constant.other.option" $scheme.purple)
        (_tc "constant.regexp" $scheme.purple)
        (_tc "constant.sha.git-rebase" $scheme.purple)
        (_tc "variable.other.constant" $scheme.purple)
        (_tc "variable.other.enummember" $scheme.purple)
        (_tc "keyword.other.unit" $scheme.purple)
        (_tc "keyword.operator.plus.exponent" $scheme.purple)
        (_tc "keyword.operator.minus.exponent" $scheme.purple)
        (_tc "meta.preprocessor.numeric" $scheme.purple)

        # Format placeholders & escapes — orange
        (_tc "constant.other.placeholder" $orange)
        (_tc "constant.character.format.placeholder" $orange)
        (_tc "constant.character.escape" $orange)
        (_tc "constant.other.color.rgb-value" $scheme.brightGreen)
        (_tc "constant.other.rgb-value" $scheme.brightGreen)

        # Keywords — red
        (_tc "keyword" $scheme.red)
        (_tc "keyword.control" $scheme.red)
        (_tc "keyword.other.using" $scheme.red)
        (_tc "keyword.other.directive.using" $scheme.red)
        (_tc "keyword.other.operator" $scheme.red)
        (_tc "storage" $scheme.red)
        (_tc "storage.modifier" $scheme.red)

        # Storage type — green (types, not keywords)
        (_tc "storage.type" $scheme.green)

        # Word-like operators — red
        (_tc "keyword.operator.expression" $scheme.red)
        (_tc "keyword.operator.new" $scheme.red)
        (_tc "keyword.operator.delete" $scheme.red)
        (_tc "keyword.operator.cast" $scheme.red)
        (_tc "keyword.operator.sizeof" $scheme.red)
        (_tc "keyword.operator.alignof" $scheme.red)
        (_tc "keyword.operator.typeid" $scheme.red)
        (_tc "keyword.operator.alignas" $scheme.red)
        (_tc "keyword.operator.instanceof" $scheme.red)
        (_tc "keyword.operator.logical.python" $scheme.red)
        (_tc "keyword.operator.wordlike" $scheme.red)
        (_tc "keyword.operator.noexcept" $scheme.red)
        (_tc "source.cpp keyword.operator.new" $scheme.red)
        (_tc "entity.name.operator" $scheme.red)

        # Symbolic operators — orange
        (_tc "keyword.operator" $orange)
        (_tc "keyword.operator.quantifier.regexp" $orange)
        (_tc "keyword.operator.negation.regexp" $orange)
        (_tc "keyword.operator.arrow" $orange)
        (_tc "storage.type.function.arrow" $orange)
        (_tc "punctuation.accessor" $orange)
        (_tc "punctuation.separator.dot" $orange)
        (_tc "punctuation.other.period" $orange)
        (_tc "punctuation.separator.namespace" $orange)
        (_tc "punctuation.separator.namespace.ruby" $orange)
        (_tc "punctuation.definition.template-expression.begin" $orange)
        (_tc "punctuation.definition.template-expression.end" $orange)
        (_tc "punctuation.section.embedded" $orange)
        (_tc "punctuation.section.embedded.begin.php" $scheme.red)
        (_tc "punctuation.section.embedded.end.php" $scheme.red)
        (_tc "punctuation.definition.list.begin.markdown" $orange)

        # Regex
        (_tc "support.other.parenthesis.regexp" $scheme.brightGreen)
        (_tc "punctuation.definition.group.regexp" $scheme.brightGreen)
        (_tc "punctuation.definition.group.assertion.regexp" $scheme.brightGreen)
        (_tc "punctuation.definition.character-class.regexp" $scheme.brightGreen)
        (_tc "punctuation.character.set.begin.regexp" $scheme.brightGreen)
        (_tc "punctuation.character.set.end.regexp" $scheme.brightGreen)
        (_tc "constant.character.character-class.regexp" $scheme.red)
        (_tc "constant.other.character-class.set.regexp" $scheme.red)
        (_tc "constant.other.character-class.regexp" $scheme.red)
        (_tc "constant.character.set.regexp" $scheme.red)
        (_tc "keyword.operator.or.regexp" $scheme.yellow)
        (_tc "keyword.control.anchor.regexp" $scheme.yellow)

        # Functions — yellow
        (_tc "entity.name.function" $scheme.yellow)
        (_tc "entity.name.function.macro" $scheme.yellow)
        (_tc "entity.name.function.preprocessor" $scheme.red)
        (_tc "entity.name.function.support.builtin" $scheme.yellow)
        (_tc "entity.name.operator.custom-literal" $scheme.yellow)
        (_tc "entity.name.command" $scheme.yellow)
        (_tc "support.function" $scheme.yellow)
        (_tc "support.function.builtin" $scheme.yellow "bold")
        (_tc "support.function.library" $scheme.yellow "bold")
        (_tc "support.function.git-rebase" $scheme.yellow)
        (_tc "support.constant.handlebars" $scheme.yellow)
        (_tc "source.powershell variable.other.member" $scheme.yellow)

        # Brackets — yellow
        (_tc "punctuation.definition.block" $scheme.yellow)
        (_tc "punctuation.section" $scheme.yellow)
        (_tc "meta.brace" $scheme.yellow)
        (_tc "punctuation.squarebracket" $scheme.yellow)
        (_tc "punctuation.curlybrace" $scheme.yellow)
        (_tc "punctuation.parenthesis" $scheme.yellow)
        (_tc "punctuation.definition.parameters" $scheme.yellow)
        (_tc "punctuation.definition.arguments" $scheme.yellow)
        (_tc "punctuation.definition.begin.bracket" $scheme.yellow)
        (_tc "punctuation.definition.end.bracket" $scheme.yellow)
        (_tc "punctuation.definition.attribute" $scheme.yellow)
        (_tc "punctuation.definition.mapping.begin" $scheme.yellow)
        (_tc "punctuation.definition.mapping.end" $scheme.yellow)

        # Types — green
        (_tc "entity.name.type" $scheme.green)
        (_tc "entity.name.class" $scheme.green)
        (_tc "entity.name.namespace" $scheme.green)
        (_tc "entity.name.module" $scheme.green)
        (_tc "entity.name.scope-resolution" $scheme.green)
        (_tc "entity.other.attribute" $scheme.green)
        (_tc "entity.other.inherited-class" $scheme.green)
        (_tc "support.type" $scheme.green)
        (_tc "support.type.builtin" $scheme.green)
        (_tc "support.type.primitive" $scheme.green)
        (_tc "support.type.exception" $scheme.green)
        (_tc "support.class" $scheme.green)
        (_tc "support.class.builtin" $scheme.green)
        (_tc "support.constant.math" $scheme.green)
        (_tc "support.constant.dom" $scheme.green)
        (_tc "support.constant.json" $scheme.green)
        (_tc "meta.type.cast.expr" $scheme.green)
        (_tc "meta.type.new.expr" $scheme.green)
        (_tc "keyword.type" $scheme.green)
        (_tc "storage.type.cs" $scheme.green)
        (_tc "storage.type.generic.cs" $scheme.green)
        (_tc "storage.type.modifier.cs" $scheme.green)
        (_tc "storage.type.variable.cs" $scheme.green)
        (_tc "storage.type.annotation.java" $scheme.green)
        (_tc "storage.type.generic.java" $scheme.green)
        (_tc "storage.type.java" $scheme.green)
        (_tc "storage.type.object.array.java" $scheme.green)
        (_tc "storage.type.primitive.array.java" $scheme.green)
        (_tc "storage.type.primitive.java" $scheme.green)
        (_tc "storage.type.token.java" $scheme.green)
        (_tc "storage.type.groovy" $scheme.green)
        (_tc "storage.type.annotation.groovy" $scheme.green)
        (_tc "storage.type.parameters.groovy" $scheme.green)
        (_tc "storage.type.generic.groovy" $scheme.green)
        (_tc "storage.type.object.array.groovy" $scheme.green)
        (_tc "storage.type.primitive.array.groovy" $scheme.green)
        (_tc "storage.type.primitive.groovy" $scheme.green)
        (_tc "storage.type.numeric.go" $scheme.green)
        (_tc "storage.type.byte.go" $scheme.green)
        (_tc "storage.type.boolean.go" $scheme.green)
        (_tc "storage.type.string.go" $scheme.green)
        (_tc "storage.type.uintptr.go" $scheme.green)
        (_tc "storage.type.error.go" $scheme.green)
        (_tc "storage.type.rune.go" $scheme.green)

        # Variables — foreground
        (_tc "variable" $fg)
        (_tc "variable.other" $fg)
        (_tc "variable.other.readwrite" $fg)
        (_tc "variable.other.property" $fg)
        (_tc "variable.other.object" $fg)
        (_tc "variable.parameter" $fg)
        (_tc "variable.argument" $fg)
        (_tc "punctuation.definition.variable" $fg)
        (_tc "entity.name.variable" $fg)
        (_tc "support.variable" $fg)
        (_tc "meta.definition.variable.name" $fg)
        (_tc "variable.language" $scheme.red)
        (_tc "variable.legacy.builtin.python" $fg)
        (_tc "variable.language.wildcard.java" $fg)

        # PowerShell-specific
        (_tc "support.function.powershell" $scheme.yellow)
        (_tc "support.function.attribute.powershell" $scheme.yellow)
        (_tc "support.variable.automatic.powershell" $scheme.red)
        (_tc "support.variable.drive.powershell" $fg)
        (_tc "support.constant.variable.powershell" $scheme.purple)
        (_tc "variable.other.member.powershell" $scheme.yellow)
        (_tc "variable.parameter.attribute.powershell" $orange)
        (_tc "storage.modifier.scope.powershell" $scheme.red)
        (_tc "keyword.other.powershell" $scheme.red)
        (_tc "keyword.other.array.begin.powershell" $scheme.yellow)
        (_tc "keyword.other.hashtable.begin.powershell" $scheme.yellow)
        (_tc "keyword.operator.string-format.powershell" $orange)
        (_tc "punctuation.section.embedded.substatement.begin.powershell" $orange)
        (_tc "punctuation.section.embedded.substatement.end.powershell" $orange)
        (_tc "punctuation.section.braces.begin.powershell" $scheme.yellow)
        (_tc "punctuation.section.braces.end.powershell" $scheme.yellow)
        (_tc "punctuation.section.bracket.begin.powershell" $scheme.yellow)
        (_tc "punctuation.section.bracket.end.powershell" $scheme.yellow)
        (_tc "punctuation.section.group.begin.powershell" $scheme.yellow)
        (_tc "punctuation.section.group.end.powershell" $scheme.yellow)
        (_tc "meta.attribute.powershell" $scheme.yellow)

        # Tags — yellow
        (_tc "entity.name.tag" $scheme.yellow)
        (_tc "entity.name.tag.css" $scheme.yellow)
        (_tc "entity.name.tag.less" $scheme.yellow)
        (_tc "entity.name.tag.yaml" $scheme.yellow)
        (_tc "entity.other.attribute-name" $orange)
        (_tc "entity.other.attribute-name.class.css" $orange)
        (_tc "entity.other.attribute-name.id.css" $orange)
        (_tc "entity.other.attribute-name.parent-selector.css" $orange)
        (_tc "entity.other.attribute-name.parent.less" $orange)
        (_tc "entity.other.attribute-name.pseudo-element.css" $orange)
        (_tc "entity.other.attribute-name.scss" $orange)
        (_tc "source.css entity.other.attribute-name.class" $orange)
        (_tc "source.css entity.other.attribute-name.pseudo-class" $orange)
        (_tc "source.css.less entity.other.attribute-name.id" $orange)
        (_tc "punctuation.definition.tag" $fgMuted)

        # CSS
        (_tc "support.type.vendored.property-name" $scheme.yellow)
        (_tc "support.type.property-name" $scheme.yellow)
        (_tc "support.constant.property-value" $scheme.brightGreen)
        (_tc "support.constant.font-name" $scheme.brightGreen)
        (_tc "support.constant.media-type" $scheme.brightGreen)
        (_tc "support.constant.media" $scheme.brightGreen)
        (_tc "support.constant.color" $scheme.brightGreen)
        (_tc "source.css variable" $fg)
        (_tc "source.coffee.embedded" $fg)

        # JSON/object keys
        (_tc "meta.object-literal.key" $scheme.yellow)
        (_tc "support.type.property-name.json" $scheme.yellow)
        (_tc "meta.structure.dictionary.key.python" $scheme.yellow)

        # Decorators
        (_tc "meta.decorator" $scheme.yellow)
        (_tc "entity.name.decorator" $scheme.yellow)
        (_tc "punctuation.decorator" $scheme.yellow)
        (_tc "punctuation.definition.decorator" $scheme.yellow)
        (_tc "punctuation.definition.annotation" $scheme.yellow)
        (_tc "meta.attribute" $scheme.yellow)

        # Rust lifetimes
        (_tc "entity.name.type.lifetime" $orange)
        (_tc "punctuation.definition.lifetime" $orange)

        # Preprocessor
        (_tc "meta.preprocessor" $scheme.red)

        # Resets — foreground
        (_tc "meta.embedded" $fg)
        (_tc "source.groovy.embedded" $fg)
        (_tc "meta.template.expression" $fg)
        (_tc "entity.name.label" $fg)
        (_tc "storage.modifier.import.java" $fg)
        (_tc "storage.modifier.package.java" $fg)

        # Misc
        (_tc "meta.diff.header" $scheme.yellow)
        (_tc "punctuation.definition.quote.begin.markdown" $fgMuted)
        (_tc "entity.other.document.begin" $fgMuted)
        (_tc "entity.other.document.end" $fgMuted)
        (_tc "header" $scheme.yellow)
        (_tc "invalid" $scheme.red)

        # Markup
        (_tc "markup.heading" $scheme.yellow "bold")
        (_tc "markup.bold" $fg "bold")
        (_tc "markup.italic" $fg "italic")
        (_tc "markup.inserted" $scheme.green)
        (_tc "markup.deleted" $scheme.red)
        (_tc "markup.changed" $scheme.yellow)
        (_tc "markup.inline.raw" $scheme.brightGreen)
        (_tc "markup.underline.link" $scheme.blue "underline")
        (_tc "markup.link" $scheme.blue "underline")
        (_tc "punctuation.definition.to-file.diff" $scheme.green)
        (_tc "punctuation.definition.from-file.diff" $scheme.red)

        # Text
        (_tc "text" $fg)
    )

    $tokenCustomizations = [ordered]@{
        semanticHighlighting = $true
        textMateRules = $tokenColors
    }

    $semanticTokenCustomizations = [ordered]@{
        enabled = $true
        rules = [ordered]@{
            # Red — keywords, storage
            "keyword"                    = $scheme.red

            # Yellow — functions, methods
            "function"                   = $scheme.yellow
            "method"                     = $scheme.yellow
            "function.defaultLibrary"    = $scheme.yellow
            "method.defaultLibrary"      = $scheme.yellow

            # Foreground — variables, parameters, properties
            "variable"                   = $fg
            "parameter"                  = $fg
            "property"                   = $fg

            # Green — types, classes
            "class"                      = $scheme.green
            "interface"                  = $scheme.green
            "struct"                     = $scheme.green
            "enum"                       = $scheme.green
            "type"                       = $scheme.green
            "typeAlias"                  = $scheme.green
            "class.defaultLibrary"       = $scheme.green
            "interface.defaultLibrary"   = $scheme.green
            "struct.defaultLibrary"      = $scheme.green
            "enum.defaultLibrary"        = $scheme.green
            "type.defaultLibrary"        = $scheme.green
            "builtinType"               = $scheme.green
            "typeParameter"              = $scheme.green

            # Dim green — strings (distinct from types)
            "string"                     = $scheme.brightGreen

            # Purple — numbers, constants (sparingly)
            "number"                     = $scheme.purple
            "boolean"                    = $scheme.purple
            "enumMember"                 = $scheme.purple
            "const"                      = $scheme.purple

            # Orange — operators
            "operator"                   = $orange
            "punctuation"                = $scheme.yellow

            # Muted — comments
            "comment"                    = $fgMuted

            # Base theme semantic overrides
            "newOperator"                = $scheme.red
            "stringLiteral"              = $scheme.brightGreen
            "customLiteral"              = $scheme.yellow
            "numberLiteral"              = $scheme.purple
            "label"                      = $fg

            # Yellow — decorators, macros
            "namespace"                  = $fg
            "decorator"                  = $scheme.yellow
            "macro"                      = $scheme.yellow
        }
    }

    # Write neutral base theme to extension (prevents flash of default theme colors)
    $baseTheme = [ordered]@{
        '$schema' = "vscode://schemas/color-theme"
        type = if ($isLight) { "light" } else { "dark" }
        semanticHighlighting = $true
        semanticTokenColors = @{}
        colors = [ordered]@{
            "editor.background" = $bgBase
            "editor.foreground" = $fg
        }
        tokenColors = @()
    }
    $baseTheme | ConvertTo-Json -Depth 5 | Set-Content $themeFile -Encoding UTF8

    # Write live colors to settings.json (colorCustomizations update instantly)
    $tokenCustomizations = [ordered]@{
        semanticHighlighting = $true
        textMateRules = $tokenColors
    }

    if (Test-Path $vsSettingsPath) {
        try {
            $vsSettings = Get-Content $vsSettingsPath -Raw -ErrorAction Stop | ConvertFrom-Json
            $vsSettings | Add-Member -NotePropertyName "workbench.colorTheme" -NotePropertyValue "Nulifyer" -Force
            $vsSettings | Add-Member -NotePropertyName "workbench.colorCustomizations" -NotePropertyValue ([PSCustomObject]$colors) -Force
            $vsSettings | Add-Member -NotePropertyName "editor.tokenColorCustomizations" -NotePropertyValue ([PSCustomObject]$tokenCustomizations) -Force
            $vsSettings | Add-Member -NotePropertyName "editor.semanticTokenColorCustomizations" -NotePropertyValue ([PSCustomObject]$semanticTokenCustomizations) -Force
            $vsSettings | Add-Member -NotePropertyName "editor.semanticHighlighting.enabled" -NotePropertyValue $true -Force
            $vsSettings | ConvertTo-Json -Depth 10 | Set-Content $vsSettingsPath -Encoding UTF8
        } catch {}
    }
}

# ── File Pilot theming ─────────────────────────────────────────────────────

function Update-FilePilotTheme([hashtable]$scheme, [string]$themeName) {
    $configPath = "$env:APPDATA\Voidstar\FilePilot\FPilot-Config.json"
    if (-not (Test-Path $configPath)) { return $false }

    $bgBase = $scheme.background
    $bgDark = Adjust-HexBrightness $bgBase -30
    $bgMid = Adjust-HexBrightness $bgBase -15
    $bgLight = Adjust-HexBrightness $bgBase 12
    $bgLighter = Adjust-HexBrightness $bgBase 20
    $fg = $scheme.foreground
    $fgMuted = $scheme.brightBlack

    # Strip # from hex colors for File Pilot format
    $strip = { param($c) $c.TrimStart('#') }

    $fpScheme = [ordered]@{
        "Nulifyer" = [ordered]@{
            Clear                     = & $strip $bgDark
            Caption                   = & $strip $bgDark
            Background                = & $strip $bgBase
            Surface                   = & $strip $bgMid
            Foreground                = & $strip $fgMuted
            Inner                     = & $strip $bgDark
            Border                    = & $strip $bgLight
            Outline                   = & $strip $fgMuted
            Separator                 = & $strip $bgLight
            AlternatingRow            = & $strip $bgMid
            IconTint                  = & $strip $scheme.cyan
            Text                      = & $strip $fg
            Secondary                 = & $strip $fgMuted
            Group                     = & $strip $scheme.white
            File                      = & $strip $fgMuted
            Folder                    = & $strip $scheme.white
            Warning                   = & $strip $scheme.red
            Progress                  = & $strip $scheme.blue
            Selection                 = & $strip $scheme.blue
            RectSelection             = & $strip $scheme.blue
            Match                     = & $strip $scheme.yellow
            Hidden                    = & $strip $bgLighter
            Hover                     = & $strip $bgLighter
            Disabled                  = & $strip $bgLighter
            ContentHover              = & $strip $fg
            ContentSelection          = & $strip $fg
            ContentDisabledSelection  = & $strip $scheme.red
            OutlineHover              = & $strip $scheme.cyan
            OutlineSelection          = & $strip $scheme.blue
            OutlineDisabledSelection  = & $strip $fgMuted
            MatchHover                = & $strip $scheme.yellow
            MatchSelection            = & $strip $scheme.yellow
            MatchDisabledSelection    = & $strip $scheme.yellow
        }
    }

    try {
        $fileLines = [System.Collections.ArrayList]@(Get-Content $configPath -ErrorAction Stop)

        # Build scheme block
        $block = @("`t`t`"Nulifyer`":", "`t`t{")
        $entries = @($fpScheme["Nulifyer"].GetEnumerator())
        for ($i = 0; $i -lt $entries.Count; $i++) {
            $comma = if ($i -lt $entries.Count - 1) { "," } else { "" }
            $block += "`t`t`t`"$($entries[$i].Key)`": `"$($entries[$i].Value)`"$comma"
        }
        $block += "`t`t}"

        # Set ColorScheme and SystemColorScheme
        for ($i = 0; $i -lt $fileLines.Count; $i++) {
            if ($fileLines[$i] -match '"ColorScheme"') { $fileLines[$i] = "`t`t`"ColorScheme`": `"Nulifyer`"," }
            if ($fileLines[$i] -match '"SystemColorScheme"') { $fileLines[$i] = "`t`t`"SystemColorScheme`": false," }
        }

        # Find Colors array and handle Nulifyer entry
        $colorsIdx = -1
        $nulStart = -1
        $nulEnd = -1
        for ($i = 0; $i -lt $fileLines.Count; $i++) {
            if ($fileLines[$i] -match '"Colors"') { $colorsIdx = $i }
            if ($fileLines[$i] -match '"Nulifyer"') { $nulStart = $i }
        }

        if ($nulStart -ge 0) {
            # Find the closing } for our entry (track brace depth)
            $depth = 0
            for ($i = $nulStart; $i -lt $fileLines.Count; $i++) {
                if ($fileLines[$i] -match '\{') { $depth++ }
                if ($fileLines[$i] -match '\}') { $depth--; if ($depth -eq 0) { $nulEnd = $i; break } }
            }
            # Remove old entry (and trailing comma if present)
            if ($nulEnd -ge 0) {
                if ($nulEnd + 1 -lt $fileLines.Count -and $fileLines[$nulEnd] -match '\},') {
                    $fileLines.RemoveRange($nulStart, $nulEnd - $nulStart + 1)
                } else {
                    $fileLines.RemoveRange($nulStart, $nulEnd - $nulStart + 1)
                }
            }
            # Re-find Colors [ since indices shifted
            for ($i = 0; $i -lt $fileLines.Count; $i++) {
                if ($fileLines[$i] -match '"Colors"') { $colorsIdx = $i; break }
            }
        }

        if ($colorsIdx -ge 0) {
            # Colors array exists — find the [ line
            $bracketIdx = $colorsIdx
            if ($fileLines[$colorsIdx] -notmatch '\[') { $bracketIdx++ }

            # Check if there are existing entries after [
            $hasOther = $false
            for ($i = $bracketIdx + 1; $i -lt $fileLines.Count; $i++) {
                if ($fileLines[$i] -match '^\s*\]') { break }
                if ($fileLines[$i] -match '\S') { $hasOther = $true; break }
            }

            # Insert our block after [
            $insertLines = if ($hasOther) { $block + @(",") } else { $block }
            $fileLines.InsertRange($bracketIdx + 1, $insertLines)
        } else {
            # No Colors array — create it before Hotkeys
            $hotkeysIdx = -1
            for ($i = 0; $i -lt $fileLines.Count; $i++) {
                if ($fileLines[$i] -match '"Hotkeys"') { $hotkeysIdx = $i; break }
            }
            if ($hotkeysIdx -ge 0) {
                $colorsBlock = @("`t`"Colors`":", "`t[") + $block + @("`t],")
                $fileLines.InsertRange($hotkeysIdx, $colorsBlock)
            }
        }

        $fileLines | Set-Content $configPath -Encoding UTF8
        return $true
    } catch { return $false }
}

# ── Browser theming (Chromium-based) ───────────────────────────────────────
# Uses BrowserThemeColor managed policy via registry. Works on stock browsers.

function Update-BrowserTheme([hashtable]$scheme) {
    $color = $scheme.background
    $updated = @()

    # Map of browser name → policy registry path → exe detection paths
    $browsers = @(
        @{ Name = "Chrome";  Policy = "HKCU:\SOFTWARE\Policies\Google\Chrome";  Exe = @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe") }
        @{ Name = "Brave";   Policy = "HKCU:\SOFTWARE\Policies\BraveSoftware\Brave";  Exe = @("$env:ProgramFiles\BraveSoftware\Brave-Browser\Application\brave.exe") }
        @{ Name = "Edge";    Policy = "HKCU:\SOFTWARE\Policies\Microsoft\Edge";  Exe = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") }
        @{ Name = "Vivaldi"; Policy = "HKCU:\SOFTWARE\Policies\Vivaldi";  Exe = @("$env:LOCALAPPDATA\Vivaldi\Application\vivaldi.exe") }
    )

    foreach ($b in $browsers) {
        $installed = $b.Exe | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($installed) {
            try {
                if (-not (Test-Path $b.Policy)) {
                    New-Item -Path $b.Policy -Force | Out-Null
                }
                Set-ItemProperty -Path $b.Policy -Name "BrowserThemeColor" -Value $color -Type String -Force -ErrorAction Stop
                $updated += $b.Name
            } catch {}
        }
    }

    return $updated
}

# ── Windows system theming ─────────────────────────────────────────────────

function Update-WindowsTheme([hashtable]$scheme, [string]$themeName) {
    $personalizePath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    $dwmPath = "HKCU:\SOFTWARE\Microsoft\Windows\DWM"
    $accentPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Accent"

    # Dark/Light mode
    $modeValue = if (_Is-LightTheme $themeName) { 1 } else { 0 }
    Set-ItemProperty $personalizePath -Name "AppsUseLightTheme" -Value $modeValue -Type Dword -Force
    Set-ItemProperty $personalizePath -Name "SystemUsesLightTheme" -Value $modeValue -Type Dword -Force

    # Accent color from background
    $accentABGR = Convert-HexToABGR $scheme.background
    $hex = $scheme.background
    $colorizationARGB = [Convert]::ToInt64("C4" + $hex.Substring(1), 16)

    # Step 1: Apply via undocumented API (updates taskbar/start menu live)
    Set-ItemProperty $personalizePath -Name "ColorPrevalence" -Value 1 -Type Dword -Force
    Set-ItemProperty $dwmPath -Name "ColorPrevalence" -Value 1 -Type Dword -Force
    try { [NativeMethods]::ApplyAccentColor([uint32]$accentABGR) } catch {}

    # Step 2: Brief pause to let the API finish its work
    Start-Sleep -Milliseconds 200

    # Step 3: Overwrite registry with our exact values
    Set-ItemProperty $dwmPath -Name "AccentColor" -Value $accentABGR -Type Dword -Force
    Set-ItemProperty $dwmPath -Name "ColorizationColor" -Value $colorizationARGB -Type Dword -Force
    Set-ItemProperty $dwmPath -Name "ColorizationAfterglow" -Value $colorizationARGB -Type Dword -Force
    Set-ItemProperty $accentPath -Name "AccentColorMenu" -Value $accentABGR -Type Dword -Force
    Set-ItemProperty $accentPath -Name "StartColorMenu" -Value $accentABGR -Type Dword -Force

    # AccentPalette — 8 shades, each 4 bytes BBGGRRAA
    $shadePercents = @(60, 40, 20, 0, -15, -30, -45, -60)
    $paletteBytes = [byte[]]::new(32)
    for ($i = 0; $i -lt 8; $i++) {
        $shade = Adjust-HexBrightness $scheme.background $shadePercents[$i]
        $paletteBytes[$i*4 + 0] = [Convert]::ToInt32($shade.Substring(5,2), 16) # BB
        $paletteBytes[$i*4 + 1] = [Convert]::ToInt32($shade.Substring(3,2), 16) # GG
        $paletteBytes[$i*4 + 2] = [Convert]::ToInt32($shade.Substring(1,2), 16) # RR
        $paletteBytes[$i*4 + 3] = if ($i -eq 7) { 0x00 } else { 0xFF }         # AA
    }
    Set-ItemProperty $accentPath -Name "AccentPalette" -Value $paletteBytes -Type Binary -Force

    # Step 4: Broadcast for other listeners
    try { [NativeMethods]::BroadcastSettingChange() } catch {}
}

# ── Wallpaper theming ──────────────────────────────────────────────────────

$script:WP_ORIGINALS = "$env:USERPROFILE\.config\wallpapers\originals"
$script:WP_CACHE = "$env:USERPROFILE\.config\wallpapers\cache"

function _Get-LargestMonitorResolution {
    Add-Type -AssemblyName System.Windows.Forms
    $largest = [System.Windows.Forms.Screen]::AllScreens |
        Sort-Object { $_.Bounds.Width * $_.Bounds.Height } -Descending |
        Select-Object -First 1
    return @{
        Width  = $largest.Bounds.Width
        Height = $largest.Bounds.Height
    }
}

function _Get-MonitorRatioString([int]$w, [int]$h) {
    $r = [math]::Round($w / $h, 2)
    if     ($r -ge 2.3)  { return "21x9"  }  # ultrawide: 3440x1440, 3840x1600
    elseif ($r -ge 1.7)  { return "16x9"  }
    elseif ($r -ge 1.5)  { return "16x10" }
    else                  { return $null   }  # unusual — don't filter
}

$script:LutgenPalettes = @{
    catppuccin_mocha     = "catppuccin-mocha"
    catppuccin_macchiato = "catppuccin-macchiato"
    catppuccin_frappe    = "catppuccin-frappe"
    catppuccin_latte     = "catppuccin-latte"
    gruvbox              = "gruvbox-material-dark-hard"
    gruvbox_light        = "gruvbox-light"
    everforest           = "everforest-dark-medium"
    everforest_light     = "everforest-light-medium"
    tokyonight           = "tokyo-night-terminal-dark"
    tokyonight_light     = "tokyo-night-light"
    nord                 = "nord"
    dracula              = "dracula"
    rose_pine            = "rose-pine"
    rose_pine_dawn       = "rose-pine-dawn"
    kanagawa             = "kanagawa"
    solarized            = "solarized-dark"
    onedark              = "onedark"
    monokai              = "monokai"
    ayu_dark             = "ayu-dark"
    ayu_mirage           = "ayu-mirage"
    vesper               = "vesper"
    nightfox             = "nightfox"
    horizon              = "horizon-terminal-dark"
    palenight            = "material-palenight"
    zenburn              = "zenburn"
    challengerdeep       = "challengerdeep"
    flexoki              = "flexoki-dark"
    flexoki_light        = "flexoki-light"
    github_dark          = "github-dark"
    iceberg              = "iceberg-dark"
    iceberg_light        = "iceberg-light"
    material_darker      = "material-darker"
    oxocarbon            = "oxocarbon-dark"
    oxocarbon_light      = "oxocarbon-light"
    spaceduck            = "spaceduck"
}

function _Get-LutgenColors([hashtable]$scheme) {
    return @(
        $scheme.background, $scheme.foreground,
        $scheme.black, $scheme.red, $scheme.green, $scheme.yellow,
        $scheme.blue, $scheme.purple, $scheme.cyan, $scheme.white,
        $scheme.brightBlack, $scheme.brightRed, $scheme.brightGreen, $scheme.brightYellow,
        $scheme.brightBlue, $scheme.brightPurple, $scheme.brightCyan, $scheme.brightWhite
    )
}

function _Apply-ThemeToWallpaper([string]$originalPath, [string]$themeName, [hashtable]$scheme) {
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($originalPath)
    $ext = [System.IO.Path]::GetExtension($originalPath)
    $cachePath = "$script:WP_CACHE\${themeName}_${fileName}${ext}"

    New-Item -ItemType Directory -Path $script:WP_CACHE -Force | Out-Null
    if (Test-Path $cachePath) { Remove-Item $cachePath -Force }
    $lutgenPalette = $script:LutgenPalettes[$themeName]
    if ($lutgenPalette) {
        & lutgen apply -P -L 0.1 -o $cachePath -p $lutgenPalette $originalPath 2>&1 | Out-Null
    } else {
        $colors = _Get-LutgenColors $scheme
        & lutgen apply -S -o $cachePath $originalPath -- @colors 2>&1 | Out-Null
    }

    if (Test-Path $cachePath) { return $cachePath }
    return $null
}

function Update-Wallpaper([string]$themeName, [hashtable]$scheme) {
    $wpName = Get-ScriptConfig "wallpaper" "name"
    if (-not $wpName) { return }

    $originalPath = "$script:WP_ORIGINALS\$wpName"
    if (-not (Test-Path $originalPath)) { return }
    if (-not (Get-Command lutgen -ErrorAction SilentlyContinue)) { return }

    $cachePath = _Apply-ThemeToWallpaper $originalPath $themeName $scheme
    if ($cachePath) {
        try { [NativeMethods]::SetWallpaper($cachePath) } catch {}
        try { Set-LockScreen $cachePath } catch {}
    }
}

function Update-KarchyTheme([string]$accent) {
    $configPath = "$env:APPDATA\karchy\config.toml"
    if (-not (Test-Path $configPath)) { return $false }

    $lines = [System.Collections.Generic.List[string]](Get-Content $configPath)

    # Find existing [theme] section
    $themeIdx = -1
    $accentIdx = -1
    $nextSectionIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\[theme\]') { $themeIdx = $i }
        elseif ($themeIdx -ge 0 -and $accentIdx -lt 0 -and $lines[$i] -match '^accent\s*=') { $accentIdx = $i }
        elseif ($themeIdx -ge 0 -and $nextSectionIdx -lt 0 -and $i -gt $themeIdx -and $lines[$i] -match '^\[') { $nextSectionIdx = $i }
    }

    $accentLine = "accent = `"$accent`""

    if ($accentIdx -ge 0) {
        $lines[$accentIdx] = $accentLine
    } elseif ($themeIdx -ge 0) {
        $lines.Insert($themeIdx + 1, $accentLine)
    } else {
        $lines.Add("")
        $lines.Add("[theme]")
        $lines.Add($accentLine)
    }

    $lines | Set-Content $configPath -Encoding utf8
    return $true
}
