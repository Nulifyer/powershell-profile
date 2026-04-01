# One-off utility: export $palettes + $wtSchemes from ThemeData.ps1 into colors.json
# Run: pwsh -NoProfile -File Scripts\_lib\export-colors-json.ps1

. "$PSScriptRoot\ThemeData.ps1"
. "$PSScriptRoot\TerminalConfig.ps1"

$palettes = $script:palettes
$wtSchemes = $script:wtSchemes
$lutgenPalettes = $script:LutgenPalettes

# Bat theme overrides (themes with named bat themes instead of "ansi")
$batThemes = @{
    catppuccin_mocha     = "Catppuccin Mocha"
    catppuccin_macchiato = "Catppuccin Macchiato"
    catppuccin_frappe    = "Catppuccin Frappe"
    catppuccin_latte     = "Catppuccin Latte"
}

# Light theme detection
$lightThemes = @('catppuccin_latte','gruvbox_light','everforest_light','tokyonight_light','rose_pine_dawn','flexoki_light','iceberg_light','oxocarbon_light')

function Strip([string]$hex) { return $hex.TrimStart('#') }

$output = [ordered]@{}

foreach ($key in ($palettes.Keys | Sort-Object)) {
    $p = $palettes[$key]
    $s = $wtSchemes[$key]
    if (-not $s) { Write-Warning "No wtScheme for $key"; continue }

    $variant = if ($key -in $lightThemes) { "light" } else { "dark" }
    $batTheme = if ($batThemes[$key]) { $batThemes[$key] } else { "ansi" }
    $lutgen = if ($lutgenPalettes[$key]) { $lutgenPalettes[$key] } else { $null }

    $entry = [ordered]@{
        name    = $s.name
        variant = $variant
        bat_theme = $batTheme
    }
    if ($lutgen) { $entry.lutgen_palette = $lutgen }

    $entry.prompt = [ordered]@{
        os       = Strip $p.muted
        user     = Strip $p.userhost
        path     = Strip $p.path
        git      = Strip $p.git
        ok       = Strip $s.green
        err      = Strip $s.red
        duration = Strip $s.yellow
    }

    $entry.terminal = [ordered]@{
        bg        = $s.background
        fg        = $s.foreground
        cursor    = $s.cursorColor
        selection = $s.selectionBackground
        normal = [ordered]@{
            black   = $s.black
            red     = $s.red
            green   = $s.green
            yellow  = $s.yellow
            blue    = $s.blue
            magenta = $s.purple
            cyan    = $s.cyan
            white   = $s.white
        }
        bright = [ordered]@{
            black   = $s.brightBlack
            red     = $s.brightRed
            green   = $s.brightGreen
            yellow  = $s.brightYellow
            blue    = $s.brightBlue
            magenta = $s.brightPurple
            cyan    = $s.brightCyan
            white   = $s.brightWhite
        }
    }

    $output[$key] = $entry
}

$json = $output | ConvertTo-Json -Depth 10
$outPath = "$PSScriptRoot\themes\colors.json"
$json | Set-Content $outPath -Encoding utf8
Write-Host "Exported $($output.Count) themes to $outPath"
