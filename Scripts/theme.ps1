#.ALIAS theme
<#
.SYNOPSIS
    Switch prompt color palette.

.DESCRIPTION
    Changes the oh-my-posh prompt colors while keeping the same layout.
    The chosen palette is saved and persists across sessions.

.EXAMPLE
    theme                        # show current + available palettes
    theme gruvbox                # switch to gruvbox colors
    theme catppuccin_mocha       # switch to catppuccin mocha
#>

. "$PSScriptRoot\ScriptUtils.ps1"
. "$PSScriptRoot\lib\TerminalConfig.ps1"

# ── Palette definitions ──────────────────────────────────────────────────────
# Keys: bg (terminal background), os (muted/UI), closer (prompt char), pink (path), lavender (git), blue (user@host)

$palettes = [ordered]@{
    catppuccin_mocha      = @{ bg = "#1E1E2E"; os = "#ACB0BE"; closer = "p:os"; pink = "#F5C2E7"; lavender = "#B4BEFE"; blue = "#89B4FA" }
    catppuccin_macchiato  = @{ bg = "#24273A"; os = "#ACB0BE"; closer = "p:os"; pink = "#F5BDE6"; lavender = "#B7BDF8"; blue = "#8AADF4" }
    catppuccin_frappe     = @{ bg = "#303446"; os = "#ACB0BE"; closer = "p:os"; pink = "#F4B8E4"; lavender = "#BABBF1"; blue = "#8CAAEE" }
    catppuccin_latte      = @{ bg = "#EFF1F5"; os = "#ACB0BE"; closer = "p:os"; pink = "#ea76cb"; lavender = "#7287FD"; blue = "#1e66f5" }
    gruvbox               = @{ bg = "#1D2021"; os = "#A89984"; closer = "p:os"; pink = "#D3869B"; lavender = "#89B482"; blue = "#7DAEA3" }
    gruvbox_light         = @{ bg = "#FBF1C7"; os = "#7C6F64"; closer = "p:os"; pink = "#D3869B"; lavender = "#427B58"; blue = "#076678" }
    everforest            = @{ bg = "#2D353B"; os = "#9DA9A0"; closer = "p:os"; pink = "#D699B6"; lavender = "#A7C080"; blue = "#7FBBB3" }
    everforest_light      = @{ bg = "#FDF6E3"; os = "#829181"; closer = "p:os"; pink = "#B4637A"; lavender = "#8DA101"; blue = "#35A77C" }
    tokyonight            = @{ bg = "#1A1B26"; os = "#565F89"; closer = "p:os"; pink = "#BB9AF7"; lavender = "#7AA2F7"; blue = "#2AC3DE" }
    tokyonight_light      = @{ bg = "#D5D6DB"; os = "#6172B0"; closer = "p:os"; pink = "#9854F1"; lavender = "#34548A"; blue = "#0F4B6E" }
    nord                  = @{ bg = "#2E3440"; os = "#D8DEE9"; closer = "p:os"; pink = "#B48EAD"; lavender = "#81A1C1"; blue = "#88C0D0" }
    dracula               = @{ bg = "#282A36"; os = "#6272A4"; closer = "p:os"; pink = "#FF79C6"; lavender = "#BD93F9"; blue = "#8BE9FD" }
    rose_pine             = @{ bg = "#191724"; os = "#908CAA"; closer = "p:os"; pink = "#EB6F92"; lavender = "#C4A7E7"; blue = "#9CCFD8" }
    rose_pine_dawn        = @{ bg = "#FAF4ED"; os = "#797593"; closer = "p:os"; pink = "#B4637A"; lavender = "#907AA9"; blue = "#56949F" }
    kanagawa              = @{ bg = "#1F1F28"; os = "#727169"; closer = "p:os"; pink = "#D27E99"; lavender = "#957FB8"; blue = "#7E9CD8" }
    solarized             = @{ bg = "#002B36"; os = "#93A1A1"; closer = "p:os"; pink = "#D33682"; lavender = "#6C71C4"; blue = "#268BD2" }
    onedark               = @{ bg = "#282C34"; os = "#ABB2BF"; closer = "p:os"; pink = "#C678DD"; lavender = "#61AFEF"; blue = "#56B6C2" }
}

# ── Windows Terminal color schemes (full ANSI 16-color palettes) ──────────────
# These persist in terminal configs so any program gets the right colors.

$wtSchemes = @{
    catppuccin_mocha = @{
        name = "Catppuccin Mocha"; background = "#1E1E2E"; foreground = "#CDD6F4"; cursorColor = "#F5E0DC"; selectionBackground = "#585B70"
        black = "#45475A"; red = "#F38BA8"; green = "#A6E3A1"; yellow = "#F9E2AF"; blue = "#89B4FA"; purple = "#F5C2E7"; cyan = "#94E2D5"; white = "#BAC2DE"
        brightBlack = "#585B70"; brightRed = "#F38BA8"; brightGreen = "#A6E3A1"; brightYellow = "#F9E2AF"; brightBlue = "#89B4FA"; brightPurple = "#F5C2E7"; brightCyan = "#94E2D5"; brightWhite = "#A6ADC8"
    }
    catppuccin_macchiato = @{
        name = "Catppuccin Macchiato"; background = "#24273A"; foreground = "#CAD3F5"; cursorColor = "#F4DBD6"; selectionBackground = "#5B6078"
        black = "#494D64"; red = "#ED8796"; green = "#A6DA95"; yellow = "#EED49F"; blue = "#8AADF4"; purple = "#F5BDE6"; cyan = "#8BD5CA"; white = "#B8C0E0"
        brightBlack = "#5B6078"; brightRed = "#ED8796"; brightGreen = "#A6DA95"; brightYellow = "#EED49F"; brightBlue = "#8AADF4"; brightPurple = "#F5BDE6"; brightCyan = "#8BD5CA"; brightWhite = "#A5ADCB"
    }
    catppuccin_frappe = @{
        name = "Catppuccin Frappe"; background = "#303446"; foreground = "#C6D0F5"; cursorColor = "#F2D5CF"; selectionBackground = "#626880"
        black = "#51576D"; red = "#E78284"; green = "#A6D189"; yellow = "#E5C890"; blue = "#8CAAEE"; purple = "#F4B8E4"; cyan = "#81C8BE"; white = "#B5BFE2"
        brightBlack = "#626880"; brightRed = "#E78284"; brightGreen = "#A6D189"; brightYellow = "#E5C890"; brightBlue = "#8CAAEE"; brightPurple = "#F4B8E4"; brightCyan = "#81C8BE"; brightWhite = "#A5ADCE"
    }
    catppuccin_latte = @{
        name = "Catppuccin Latte"; background = "#EFF1F5"; foreground = "#4C4F69"; cursorColor = "#DC8A78"; selectionBackground = "#ACB0BE"
        black = "#5C5F77"; red = "#D20F39"; green = "#40A02B"; yellow = "#DF8E1D"; blue = "#1E66F5"; purple = "#EA76CB"; cyan = "#179299"; white = "#ACB0BE"
        brightBlack = "#6C6F85"; brightRed = "#D20F39"; brightGreen = "#40A02B"; brightYellow = "#DF8E1D"; brightBlue = "#1E66F5"; brightPurple = "#EA76CB"; brightCyan = "#179299"; brightWhite = "#BCC0CC"
    }
    gruvbox = @{
        name = "Gruvbox Dark"; background = "#1D2021"; foreground = "#DDC7A1"; cursorColor = "#DDC7A1"; selectionBackground = "#3C3836"
        black = "#141617"; red = "#EA6962"; green = "#A9B665"; yellow = "#D8A657"; blue = "#7DAEA3"; purple = "#D3869B"; cyan = "#89B482"; white = "#DDC7A1"
        brightBlack = "#928374"; brightRed = "#E3746F"; brightGreen = "#ABB578"; brightYellow = "#D6AC67"; brightBlue = "#8CB0A8"; brightPurple = "#D699A9"; brightCyan = "#98B593"; brightWhite = "#DCCDB5"
    }
    gruvbox_light = @{
        name = "Gruvbox Light"; background = "#FBF1C7"; foreground = "#3C3836"; cursorColor = "#3C3836"; selectionBackground = "#EBDBB2"
        black = "#FBF1C7"; red = "#CC241D"; green = "#98971A"; yellow = "#D79921"; blue = "#458588"; purple = "#B16286"; cyan = "#689D6A"; white = "#7C6F64"
        brightBlack = "#928374"; brightRed = "#9D0006"; brightGreen = "#79740E"; brightYellow = "#B57614"; brightBlue = "#076678"; brightPurple = "#8F3F71"; brightCyan = "#427B58"; brightWhite = "#3C3836"
    }
    everforest = @{
        name = "Everforest Dark"; background = "#2D353B"; foreground = "#D3C6AA"; cursorColor = "#D3C6AA"; selectionBackground = "#475258"
        black = "#343F44"; red = "#E67E80"; green = "#A7C080"; yellow = "#DBBC7F"; blue = "#7FBBB3"; purple = "#D699B6"; cyan = "#83C092"; white = "#D3C6AA"
        brightBlack = "#475258"; brightRed = "#E67E80"; brightGreen = "#A7C080"; brightYellow = "#DBBC7F"; brightBlue = "#7FBBB3"; brightPurple = "#D699B6"; brightCyan = "#83C092"; brightWhite = "#D3C6AA"
    }
    everforest_light = @{
        name = "Everforest Light"; background = "#FDF6E3"; foreground = "#5C6A72"; cursorColor = "#5C6A72"; selectionBackground = "#E6E2CC"
        black = "#F3EAD3"; red = "#F85552"; green = "#8DA101"; yellow = "#DFA000"; blue = "#3A94C5"; purple = "#DF69BA"; cyan = "#35A77C"; white = "#5C6A72"
        brightBlack = "#939B8E"; brightRed = "#F85552"; brightGreen = "#8DA101"; brightYellow = "#DFA000"; brightBlue = "#3A94C5"; brightPurple = "#DF69BA"; brightCyan = "#35A77C"; brightWhite = "#5C6A72"
    }
    tokyonight = @{
        name = "Tokyo Night"; background = "#1A1B26"; foreground = "#C0CAF5"; cursorColor = "#C0CAF5"; selectionBackground = "#33467C"
        black = "#15161E"; red = "#F7768E"; green = "#9ECE6A"; yellow = "#E0AF68"; blue = "#7AA2F7"; purple = "#BB9AF7"; cyan = "#7DCFFF"; white = "#A9B1D6"
        brightBlack = "#565F89"; brightRed = "#F7768E"; brightGreen = "#9ECE6A"; brightYellow = "#E0AF68"; brightBlue = "#7AA2F7"; brightPurple = "#BB9AF7"; brightCyan = "#7DCFFF"; brightWhite = "#C0CAF5"
    }
    tokyonight_light = @{
        name = "Tokyo Night Light"; background = "#D5D6DB"; foreground = "#343B58"; cursorColor = "#343B58"; selectionBackground = "#9699A3"
        black = "#0F0F14"; red = "#8C4351"; green = "#485E30"; yellow = "#8F5E15"; blue = "#34548A"; purple = "#5A4A78"; cyan = "#0F4B6E"; white = "#343B58"
        brightBlack = "#9699A3"; brightRed = "#8C4351"; brightGreen = "#485E30"; brightYellow = "#8F5E15"; brightBlue = "#34548A"; brightPurple = "#5A4A78"; brightCyan = "#0F4B6E"; brightWhite = "#343B58"
    }
    nord = @{
        name = "Nord"; background = "#2E3440"; foreground = "#D8DEE9"; cursorColor = "#D8DEE9"; selectionBackground = "#434C5E"
        black = "#3B4252"; red = "#BF616A"; green = "#A3BE8C"; yellow = "#EBCB8B"; blue = "#81A1C1"; purple = "#B48EAD"; cyan = "#88C0D0"; white = "#E5E9F0"
        brightBlack = "#4C566A"; brightRed = "#BF616A"; brightGreen = "#A3BE8C"; brightYellow = "#EBCB8B"; brightBlue = "#81A1C1"; brightPurple = "#B48EAD"; brightCyan = "#8FBCBB"; brightWhite = "#ECEFF4"
    }
    dracula = @{
        name = "Dracula"; background = "#282A36"; foreground = "#F8F8F2"; cursorColor = "#F8F8F2"; selectionBackground = "#44475A"
        black = "#21222C"; red = "#FF5555"; green = "#50FA7B"; yellow = "#F1FA8C"; blue = "#BD93F9"; purple = "#FF79C6"; cyan = "#8BE9FD"; white = "#F8F8F2"
        brightBlack = "#6272A4"; brightRed = "#FF6E6E"; brightGreen = "#69FF94"; brightYellow = "#FFFFA5"; brightBlue = "#D6ACFF"; brightPurple = "#FF92DF"; brightCyan = "#A4FFFF"; brightWhite = "#FFFFFF"
    }
    rose_pine = @{
        name = "Rose Pine"; background = "#191724"; foreground = "#E0DEF4"; cursorColor = "#E0DEF4"; selectionBackground = "#403D52"
        black = "#26233A"; red = "#EB6F92"; green = "#9CCFD8"; yellow = "#F6C177"; blue = "#31748F"; purple = "#C4A7E7"; cyan = "#9CCFD8"; white = "#E0DEF4"
        brightBlack = "#6E6A86"; brightRed = "#EB6F92"; brightGreen = "#9CCFD8"; brightYellow = "#F6C177"; brightBlue = "#31748F"; brightPurple = "#C4A7E7"; brightCyan = "#9CCFD8"; brightWhite = "#E0DEF4"
    }
    rose_pine_dawn = @{
        name = "Rose Pine Dawn"; background = "#FAF4ED"; foreground = "#575279"; cursorColor = "#575279"; selectionBackground = "#DFDAD9"
        black = "#F2E9E1"; red = "#B4637A"; green = "#56949F"; yellow = "#EA9D34"; blue = "#286983"; purple = "#907AA9"; cyan = "#56949F"; white = "#575279"
        brightBlack = "#9893A5"; brightRed = "#B4637A"; brightGreen = "#56949F"; brightYellow = "#EA9D34"; brightBlue = "#286983"; brightPurple = "#907AA9"; brightCyan = "#56949F"; brightWhite = "#575279"
    }
    kanagawa = @{
        name = "Kanagawa"; background = "#1F1F28"; foreground = "#DCD7BA"; cursorColor = "#DCD7BA"; selectionBackground = "#2D4F67"
        black = "#16161D"; red = "#C34043"; green = "#76946A"; yellow = "#C0A36E"; blue = "#7E9CD8"; purple = "#957FB8"; cyan = "#6A9589"; white = "#C8C093"
        brightBlack = "#727169"; brightRed = "#E82424"; brightGreen = "#98BB6C"; brightYellow = "#E6C384"; brightBlue = "#7FB4CA"; brightPurple = "#938AA9"; brightCyan = "#7AA89F"; brightWhite = "#DCD7BA"
    }
    solarized = @{
        name = "Solarized Dark"; background = "#002B36"; foreground = "#839496"; cursorColor = "#839496"; selectionBackground = "#073642"
        black = "#073642"; red = "#DC322F"; green = "#859900"; yellow = "#B58900"; blue = "#268BD2"; purple = "#D33682"; cyan = "#2AA198"; white = "#EEE8D5"
        brightBlack = "#586E75"; brightRed = "#CB4B16"; brightGreen = "#586E75"; brightYellow = "#657B83"; brightBlue = "#839496"; brightPurple = "#6C71C4"; brightCyan = "#93A1A1"; brightWhite = "#FDF6E3"
    }
    onedark = @{
        name = "One Dark"; background = "#282C34"; foreground = "#ABB2BF"; cursorColor = "#ABB2BF"; selectionBackground = "#3E4451"
        black = "#3F4451"; red = "#E06C75"; green = "#98C379"; yellow = "#E5C07B"; blue = "#61AFEF"; purple = "#C678DD"; cyan = "#56B6C2"; white = "#ABB2BF"
        brightBlack = "#4F5666"; brightRed = "#BE5046"; brightGreen = "#98C379"; brightYellow = "#D19A66"; brightBlue = "#61AFEF"; brightPurple = "#C678DD"; brightCyan = "#56B6C2"; brightWhite = "#ABB2BF"
    }
}

# ── Base theme layout ────────────────────────────────────────────────────────

$baseTheme = @{
    '$schema' = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json"
    version = 3
    final_space = $true
    blocks = @(
        @{
            type = "prompt"
            alignment = "left"
            segments = @(
                @{ type = "os";      style = "plain"; foreground = "p:os";       template = "{{.Icon}} " }
                @{ type = "session"; style = "plain"; foreground = "p:blue";     template = "{{ .UserName }}@{{ .HostName }} " }
                @{
                    type = "path"; style = "plain"; foreground = "p:pink"
                    template = "{{ .Path }} "
                    properties = @{
                        folder_icon = "..$([char]0xe5fe).."
                        home_icon = "~"
                        style = "agnoster_short"
                    }
                }
                @{
                    type = "git"; style = "plain"; foreground = "p:lavender"
                    template = "{{ .HEAD }} "
                    properties = @{
                        branch_icon = "$([char]0xe725) "
                        cherry_pick_icon = "$([char]0xe29b) "
                        commit_icon = "$([char]0xf417) "
                        fetch_status = $false
                        fetch_upstream_icon = $false
                        merge_icon = "$([char]0xe727) "
                        no_commits_icon = "$([char]0xf0c3) "
                        rebase_icon = "$([char]0xe728) "
                        revert_icon = "$([char]0xf0e2) "
                        tag_icon = "$([char]0xf412) "
                    }
                }
                @{ type = "text"; style = "plain"; foreground = "p:closer"; template = "$([char]0xf105)" }
            )
        }
    )
}

# ── Config ───────────────────────────────────────────────────────────────────

$configKey = "theme"
$currentTheme = Get-ScriptConfig $configKey "palette"
if (-not $currentTheme) { $currentTheme = "catppuccin_mocha" }

$parsed = Parse-Args $args @{}
$choice = $parsed._positional | Select-Object -First 1

# ── No args: show current + list ─────────────────────────────────────────────

function _hex2rgb([string]$hex) {
    $r = [Convert]::ToInt32($hex.Substring(1,2),16)
    $g = [Convert]::ToInt32($hex.Substring(3,2),16)
    $b = [Convert]::ToInt32($hex.Substring(5,2),16)
    return "$r;$g;$b"
}

function _swatch([hashtable]$p) {
    $b = _hex2rgb $p.blue; $pk = _hex2rgb $p.pink; $l = _hex2rgb $p.lavender
    return "`e[38;2;${b}m●`e[0m `e[38;2;${pk}m●`e[0m `e[38;2;${l}m●`e[0m"
}

function _preview([string]$name, [hashtable]$p) {
    $os = _hex2rgb $p.os; $bl = _hex2rgb $p.blue; $pk = _hex2rgb $p.pink; $lv = _hex2rgb $p.lavender
    $r = "`e[0m"
    $lines = @(
        ""
        "  `e[38;2;${os}m$name`e[0m"
        "  $("─" * 44)"
        ""
        "  `e[38;2;${os}m`e[0m `e[38;2;${bl}m$env:USERNAME@$env:COMPUTERNAME`e[0m `e[38;2;${pk}m~/Projects/my-app`e[0m `e[38;2;${lv}m main`e[0m `e[38;2;${os}m`e[0m"
        ""
        "  `e[1mColors:`e[0m"
        "  `e[38;2;${os}m████`e[0m os        $($p.os)"
        "  `e[38;2;${bl}m████`e[0m blue      $($p.blue)   (user@host)"
        "  `e[38;2;${pk}m████`e[0m pink      $($p.pink)   (path)"
        "  `e[38;2;${lv}m████`e[0m lavender  $($p.lavender)   (git)"
    )
    return $lines -join "`n"
}

if (-not $choice) {
    $hasFzf = Get-Command fzf -ErrorAction SilentlyContinue
    if ($hasFzf) {
        # Write palette data to temp file for the preview script
        $previewData = "$env:TEMP\pwsh-profile\theme-palettes.txt"
        $paletteLines = @()
        foreach ($name in $palettes.Keys) {
            $p = $palettes[$name]
            $paletteLines += "$name|$($p.bg)|$($p.os)|$($p.blue)|$($p.pink)|$($p.lavender)"
        }
        $paletteLines | Set-Content $previewData -Encoding UTF8

        # Preview command calls the separate preview script — {1} is the hidden theme name field
        $previewScript = "$PSScriptRoot\theme-preview.ps1"
        $previewCmd = "pwsh -NoProfile -File `"$previewScript`" {1} `"$previewData`" `"$env:USERNAME`" `"$env:COMPUTERNAME`""

        # Build fzf input lines: "name<TAB>swatches marker name" — fzf shows field 2+ via --with-nth
        $lines = @()
        foreach ($name in $palettes.Keys) {
            $swatch = _swatch $palettes[$name]
            $marker = if ($name -eq $currentTheme) { " *" } else { "  " }
            $lines += "$name`t$swatch$marker $name"
        }

        # Enter alt buffer, run fzf, exit alt buffer
        Write-Host "`e[?1049h" -NoNewline
        try {
            $selected = $lines | fzf --ansi --no-sort `
                --delimiter="`t" `
                --with-nth=2.. `
                --header="Current: $currentTheme  |  ESC to cancel" `
                --prompt="theme> " `
                --reverse `
                --preview="$previewCmd" `
                --preview-window="right:50%:wrap" `
                --no-scrollbar
        } finally {
            Write-Host "`e[?1049l" -NoNewline
        }

        if ($selected) {
            # Extract theme name (first tab-delimited field)
            $choice = $selected.Split("`t")[0]
        } else {
            exit 0
        }
    } else {
        # Fallback: plain list
        Write-Host ""
        Write-Host "  Prompt Palette" -ForegroundColor Cyan
        Write-Host "  $("─" * 40)" -ForegroundColor DarkGray
        foreach ($name in $palettes.Keys) {
            $swatch = _swatch $palettes[$name]
            $marker = if ($name -eq $currentTheme) { "*" } else { " " }
            $color = if ($name -eq $currentTheme) { "Green" } else { "White" }
            Write-Host "  $marker $swatch " -NoNewline
            Write-Host "$name" -ForegroundColor $color
        }
        Write-Host "  $("─" * 40)" -ForegroundColor DarkGray
        Write-Host "  Current: $currentTheme" -ForegroundColor DarkGray
        Write-Host "  Usage:   theme <name>" -ForegroundColor DarkGray
        Write-Host ""
        exit 0
    }
}

# ── Set palette ──────────────────────────────────────────────────────────────

if (-not $palettes.Contains($choice)) {
    Write-Host "Unknown palette: $choice" -ForegroundColor Red
    Write-Host "Available: $($palettes.Keys -join ', ')" -ForegroundColor DarkGray
    exit 1
}

# Build theme JSON with chosen palette (exclude bg — it's for the terminal, not oh-my-posh)
$theme = $baseTheme.Clone()
$ompPalette = @{}
foreach ($k in $palettes[$choice].Keys) {
    if ($k -ne 'bg') { $ompPalette[$k] = $palettes[$choice][$k] }
}
$theme.palette = $ompPalette
$themeJson = $theme | ConvertTo-Json -Depth 10

# Write theme file
$themeFile = "$PSScriptRoot\..\omp-theme.json"
$themeJson | Set-Content $themeFile -Encoding UTF8

# Re-init oh-my-posh with new theme
$initScript = (oh-my-posh init pwsh --config $themeFile) -join "`n"
Invoke-Expression $initScript

# ── Update all terminal emulators ────────────────────────────────────────────

$scheme = $wtSchemes[$choice]
if ($scheme) {
    $updatedTerminals = Update-TerminalColors $scheme
    if ($updatedTerminals.Count -gt 0) {
        Write-Host "Updated: $($updatedTerminals -join ', ')" -ForegroundColor DarkGray
    }
}

# Cache the init script for fast profile load
$ompCmd = Get-Command oh-my-posh -ErrorAction SilentlyContinue
if ($ompCmd) {
    $ompMtime = (Get-Item $ompCmd.Source).LastWriteTime.ToString("yyyyMMddHHmmss")
    $cacheFile = "$env:TEMP\pwsh-profile\omp-custom-${ompMtime}.ps1"
    $initScript | Set-Content $cacheFile -Encoding UTF8
}

# Save choice
Set-ScriptConfig $configKey "palette" $choice

Write-Host "Switched to $choice" -ForegroundColor Green
