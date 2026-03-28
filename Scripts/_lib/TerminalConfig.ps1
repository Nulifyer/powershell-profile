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
    return $themeName -in @('catppuccin_latte','gruvbox_light','everforest_light','tokyonight_light','rose_pine_dawn')
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
# Writes directly to settings.json (colorCustomizations + tokenColorCustomizations)
# Both apply live without restart.

function Update-VSCodeTheme([hashtable]$scheme, [string]$themeName) {
    $vsSettingsPath = "$env:APPDATA\Code\User\settings.json"
    if (-not (Test-Path $vsSettingsPath)) { return }

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
        "button.background" = $fgMuted
        "button.foreground" = $bgBase
        "button.hoverBackground" = (Adjust-HexBrightness $fgMuted -15)
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

    # Token color mapping — warm-first: red, orange, yellow, green as primaries; blue/purple sparingly
    $orange = $scheme.brightRed   # brightRed is typically the orange slot in most themes
    $tokenColors = @(
        # Variables & properties — plain foreground (one.two in one.two.three)
        @{ scope = "variable, variable.argument, support.variable, meta.definition.variable, entity.name.variable, constant.other.placeholder, variable.parameter"; settings = @{ foreground = $fg } }
        @{ scope = "variable.language"; settings = @{ foreground = $scheme.red } }

        # Keywords — red (var, const, let, if, return, func, etc.)
        @{ scope = "keyword, storage.modifier"; settings = @{ foreground = $scheme.red } }
        @{ scope = "keyword.control"; settings = @{ foreground = $scheme.red } }

        # Operators & punctuation — orange (., =>, =, +, etc.)
        @{ scope = "keyword.operator, punctuation.accessor, punctuation.separator.dot, punctuation.other.period"; settings = @{ foreground = $orange } }
        @{ scope = "keyword.operator.arrow, storage.type.function.arrow"; settings = @{ foreground = $orange } }

        # Functions & brackets — yellow (function names, (), {})
        @{ scope = "entity.name.function, support.function, meta.function-call.generic, entity.name.command"; settings = @{ foreground = $scheme.yellow } }
        @{ scope = "support.function.builtin"; settings = @{ foreground = $scheme.yellow; fontStyle = "bold" } }
        @{ scope = "punctuation.definition.block, punctuation.section, meta.brace, punctuation.squarebracket, punctuation.definition.attribute, punctuation.curlybrace, punctuation.parenthesis, punctuation.definition.parameters, punctuation.definition.arguments, punctuation.definition.begin.bracket, punctuation.definition.end.bracket"; settings = @{ foreground = $scheme.yellow } }

        # Strings — dim green (distinct from types)
        @{ scope = "string, punctuation.definition.string.begin, punctuation.definition.string.end, punctuation.definition.string.template.begin, punctuation.definition.string.template.end, punctuation.section.embedded"; settings = @{ foreground = $scheme.brightGreen } }
        @{ scope = "string.regexp"; settings = @{ foreground = $scheme.cyan } }

        # Types & classes — green (type names in declarations)
        @{ scope = "support.type, support.class, entity.name.type, entity.name.class, entity.name.namespace, entity.name.scope-resolution, entity.other.attribute, entity.other.inherited-class, keyword.type, storage.type, storage.type.cs, storage.type.generic.cs, storage.type.modifier.cs, storage.type.variable.cs, storage.type.annotation.java, storage.type.generic.java, storage.type.java, storage.type.primitive.java, storage.type.boolean.go, storage.type.byte.go, storage.type.error.go, storage.type.numeric.go, storage.type.rune.go, storage.type.string.go, storage.type.uintptr.go, meta.type.cast.expr, meta.type.new.expr"; settings = @{ foreground = $scheme.green } }

        # Constants & numbers — purple (used sparingly)
        @{ scope = "constant.numeric"; settings = @{ foreground = $scheme.purple } }
        @{ scope = "constant.language"; settings = @{ foreground = $scheme.purple } }
        @{ scope = "variable.other.constant, variable.other.enummember"; settings = @{ foreground = $scheme.purple } }

        # Comments
        @{ scope = "comment, punctuation.definition.comment"; settings = @{ foreground = $fgMuted } }

        # JSON keys, object keys
        @{ scope = "meta.object-literal.key, support.type.property-name.json"; settings = @{ foreground = $scheme.yellow } }

        # CSS
        @{ scope = "support.type.property-name.css, meta.property-name.css"; settings = @{ foreground = $scheme.yellow } }
        @{ scope = "support.constant.property-value.css, constant.other.color.rgb-value.hex.css, support.constant.color"; settings = @{ foreground = $scheme.brightGreen } }

        # HTML/XML
        @{ scope = "entity.name.tag"; settings = @{ foreground = $scheme.yellow } }
        @{ scope = "entity.other.attribute-name"; settings = @{ foreground = $orange } }

        # Decorators/attributes
        @{ scope = "meta.decorator, entity.name.decorator, punctuation.decorator"; settings = @{ foreground = $scheme.yellow } }

        # Markup
        @{ scope = "markup.heading, entity.name.section"; settings = @{ foreground = $scheme.yellow; fontStyle = "bold" } }
        @{ scope = "markup.bold"; settings = @{ fontStyle = "bold" } }
        @{ scope = "markup.italic"; settings = @{ fontStyle = "italic" } }
        @{ scope = "markup.underline.link, markup.link"; settings = @{ foreground = $scheme.blue; fontStyle = "underline" } }
        @{ scope = "markup.inline.raw.string, markup.raw.monospace"; settings = @{ foreground = $scheme.green } }
        @{ scope = "markup.inserted, punctuation.definition.to-file.diff"; settings = @{ foreground = $scheme.green } }
        @{ scope = "markup.deleted, punctuation.definition.from-file.diff"; settings = @{ foreground = $scheme.red } }

        # Text
        @{ scope = "text"; settings = @{ foreground = $fg } }
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

            # Yellow — decorators, macros
            "namespace"                  = $fg
            "decorator"                  = $scheme.yellow
            "macro"                      = $scheme.yellow
        }
    }

    # Write to VS Code settings.json
    try {
        $vsSettings = Get-Content $vsSettingsPath -Raw -ErrorAction Stop | ConvertFrom-Json
        $vsSettings | Add-Member -NotePropertyName "workbench.colorCustomizations" -NotePropertyValue ([PSCustomObject]$colors) -Force
        $vsSettings | Add-Member -NotePropertyName "editor.tokenColorCustomizations" -NotePropertyValue ([PSCustomObject]$tokenCustomizations) -Force
        $vsSettings | Add-Member -NotePropertyName "editor.semanticTokenColorCustomizations" -NotePropertyValue ([PSCustomObject]$semanticTokenCustomizations) -Force
        $vsSettings | Add-Member -NotePropertyName "editor.semanticHighlighting.enabled" -NotePropertyValue $true -Force
        $vsSettings | ConvertTo-Json -Depth 10 | Set-Content $vsSettingsPath -Encoding UTF8
    } catch {}
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
            Selection                 = & $strip ($scheme.blue + "80")
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
        $config = Get-Content $configPath -Raw -ErrorAction Stop | ConvertFrom-Json

        # Ensure Colors array exists
        if (-not $config.Colors) {
            $config | Add-Member -NotePropertyName "Colors" -NotePropertyValue @() -Force
        }

        # Replace or add our scheme
        $colors = [System.Collections.ArrayList]@($config.Colors)
        $existing = $colors | Where-Object { $_.PSObject.Properties.Name -contains "Nulifyer" }
        if ($existing) { $colors.Remove($existing) | Out-Null }
        $colors.Insert(0, [PSCustomObject]$fpScheme) | Out-Null
        $config.Colors = $colors.ToArray()

        # Set active color scheme
        $config.Options.ColorScheme = "Nulifyer"
        $config.Options.SystemColorScheme = $false

        $config | ConvertTo-Json -Depth 5 | Set-Content $configPath -Encoding UTF8
        return $true
    } catch { return $false }
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

    if (Test-Path $cachePath) { return $cachePath }

    New-Item -ItemType Directory -Path $script:WP_CACHE -Force | Out-Null
    $colors = _Get-LutgenColors $scheme
    & lutgen apply -o $cachePath $originalPath -- @colors 2>&1 | Out-Null

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
    }
}
