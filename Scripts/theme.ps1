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

# Set terminal background via OSC 11 (immediate effect)
$bgColor = $palettes[$choice].bg
Write-Host "`e]11;$bgColor`e\" -NoNewline

# Update Windows Terminal profile background color
$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$wtFragmentPath = "$PSScriptRoot\..\windows-terminal-fragment.json"
$nulifyrGuid = "{f1a2b3c4-d5e6-4f78-9a0b-1c2d3e4f5a6b}"

# Update WT settings.json (live settings — takes effect immediately)
if (Test-Path $wtSettingsPath) {
    try {
        $wtSettings = Get-Content $wtSettingsPath -Raw | ConvertFrom-Json
        $profile = $wtSettings.profiles.list | Where-Object { $_.guid -eq $nulifyrGuid }
        if ($profile) {
            $profile | Add-Member -NotePropertyName "background" -NotePropertyValue $bgColor -Force
            $wtSettings | ConvertTo-Json -Depth 10 | Set-Content $wtSettingsPath -Encoding UTF8
        }
    } catch {}
}

# Update fragment (persists for new installs / resets)
if (Test-Path $wtFragmentPath) {
    try {
        $fragment = Get-Content $wtFragmentPath -Raw | ConvertFrom-Json
        $fragment.profiles[0] | Add-Member -NotePropertyName "background" -NotePropertyValue $bgColor -Force
        $fragment | ConvertTo-Json -Depth 10 | Set-Content $wtFragmentPath -Encoding UTF8
    } catch {}
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
Set-ScriptConfig $configKey "bg" $bgColor

Write-Host "Switched to $choice" -ForegroundColor Green
