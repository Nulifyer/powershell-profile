# Shared terminal configuration helpers for theme.ps1 and font.ps1
# Supports: Windows Terminal, Alacritty, Kitty, Ghostty, WezTerm

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
            useAcrylic = $false
            padding = "10"
            scrollbarState = "hidden"
            historySize = 10000
        }
        $wt.profiles.list = @($wt.profiles.list) + $profile
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
            $content = Get-Content $configs.alacritty -Raw
            $content = $content -replace 'family\s*=\s*"[^"]*"', "family = `"$FontName`""
            $content | Set-Content $configs.alacritty -Encoding UTF8
            $updated += "Alacritty"
        } catch {}
    }

    # Kitty — space-delimited: font_family <name>
    if ($configs.kitty) {
        try {
            $content = Get-Content $configs.kitty -Raw
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
            $content = Get-Content $configs.ghostty -Raw
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
            $content = Get-Content $configs.wezterm -Raw
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
                    $wt.schemes = @($wt.schemes) + [PSCustomObject]$scheme
                }

                # Set colorScheme, opacity, acrylic on the profile
                $profile = $wt.profiles.list | Where-Object { $_.guid -eq $script:NULIFYR_GUID }
                $profile | Add-Member -NotePropertyName "colorScheme" -NotePropertyValue $schemeName -Force
                $profile | Add-Member -NotePropertyName "opacity" -NotePropertyValue 95 -Force
                $profile | Add-Member -NotePropertyName "useAcrylic" -NotePropertyValue $true -Force
                $profile.PSObject.Properties.Remove("background")

                $wt | ConvertTo-Json -Depth 10 | Set-Content $configs.wt -Encoding UTF8
                $updated += "Windows Terminal"
            }
        } catch {}
    }

    # ── Alacritty — TOML [colors.*] sections ─────────────────────────────────

    if ($configs.alacritty) {
        try {
            $content = Get-Content $configs.alacritty -Raw

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
            $content = Get-Content $configs.kitty -Raw

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
            $content = Get-Content $configs.ghostty -Raw

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
            $content = Get-Content $configs.wezterm -Raw
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
