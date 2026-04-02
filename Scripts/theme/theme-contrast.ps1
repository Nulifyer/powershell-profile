#.ALIAS theme-contrast
<#
.SYNOPSIS
    Audit theme colors for WCAG contrast compliance.

.DESCRIPTION
    Tests foreground/background color pairs across VS Code, File Pilot,
    terminal, and prompt for each theme (or a specific theme).
    Reports pairs that fail the required contrast ratio.

.EXAMPLE
    theme-contrast                    # audit current theme
    theme-contrast gruvbox            # audit a specific theme
    theme-contrast --all              # audit every theme
#>

. "$PSScriptRoot\..\_lib\ScriptUtils.ps1"
. "$PSScriptRoot\..\_lib\TerminalConfig.ps1"
. "$PSScriptRoot\..\_lib\ThemeData.ps1"

$c = Get-Colors

# ── Configuration ──────────────────────────────────────────────────────────
# WCAG contrast ratio threshold.  Common targets:
#   4.5  = WCAG AA normal text
#   3.0  = WCAG AA large text / UI components
#   7.0  = WCAG AAA normal text
$script:RequiredRatio = 4.5

# ── Color math ─────────────────────────────────────────────────────────────

function _HexToRgb([string]$hex) {
    $hex = $hex.TrimStart('#')
    # handle 3-char shorthand
    if ($hex.Length -eq 3) {
        $hex = "$($hex[0])$($hex[0])$($hex[1])$($hex[1])$($hex[2])$($hex[2])"
    }
    # if there's an alpha suffix (e.g. #FF000040) take only first 6
    if ($hex.Length -gt 6) { $hex = $hex.Substring(0, 6) }
    @(
        [Convert]::ToInt32($hex.Substring(0,2), 16),
        [Convert]::ToInt32($hex.Substring(2,2), 16),
        [Convert]::ToInt32($hex.Substring(4,2), 16)
    )
}

function _RelativeLuminance([int]$r, [int]$g, [int]$b) {
    # sRGB to linear per WCAG 2.x
    $channels = @($r, $g, $b) | ForEach-Object {
        $s = $_ / 255.0
        if ($s -le 0.04045) { $s / 12.92 }
        else { [Math]::Pow(($s + 0.055) / 1.055, 2.4) }
    }
    0.2126 * $channels[0] + 0.7152 * $channels[1] + 0.0722 * $channels[2]
}

function _ContrastRatio([string]$fg, [string]$bg) {
    $fRgb = _HexToRgb $fg
    $bRgb = _HexToRgb $bg
    $L1 = _RelativeLuminance @fRgb
    $L2 = _RelativeLuminance @bRgb
    $lighter = [Math]::Max($L1, $L2)
    $darker  = [Math]::Min($L1, $L2)
    ($lighter + 0.05) / ($darker + 0.05)
}

function _Swatch([string]$hex) {
    $rgb = _HexToRgb $hex
    "$([char]27)[48;2;$($rgb[0]);$($rgb[1]);$($rgb[2])m  $([char]27)[0m"
}

# ── Pair testing ───────────────────────────────────────────────────────────

$script:passCount = 0
$script:failCount = 0
$script:warnCount = 0

function _TestPair([string]$context, [string]$label, [string]$fgHex, [string]$bgHex) {
    if (-not $fgHex -or -not $bgHex) { return }
    # skip transparent / partially transparent backgrounds
    $stripped = $fgHex.TrimStart('#')
    if ($stripped.Length -gt 6) { return }
    $stripped = $bgHex.TrimStart('#')
    if ($stripped.Length -gt 6) { return }

    $ratio = _ContrastRatio $fgHex $bgHex
    $ratioStr = "{0:N2}" -f $ratio

    if ($ratio -ge $script:RequiredRatio) {
        $script:passCount++
    } else {
        $script:failCount++
        $fgSwatch = _Swatch $fgHex
        $bgSwatch = _Swatch $bgHex
        Write-Host "  $($c.red)FAIL$($c.reset) ${ratioStr}:1  $($c.dim)[$context]$($c.reset) $label"
        Write-Host "       fg $fgSwatch $($c.dim)$fgHex$($c.reset)  bg $bgSwatch $($c.dim)$bgHex$($c.reset)"
    }
}

# ── Build pairs for a theme ────────────────────────────────────────────────

function _AuditTheme([string]$themeName) {
    $theme = Get-Theme $themeName
    if (-not $theme) {
        Write-Host "  $($c.red)Unknown theme: $themeName$($c.reset)"
        return
    }

    $scheme = $theme
    $isLight = $theme.variant -eq 'light'

    # Derived backgrounds (same formulas as TerminalConfig.ps1)
    $bgBase    = $scheme.background
    $bgMid     = Adjust-HexBrightness $bgBase $(if ($isLight) { 5 } else { -15 })
    $bgDarkest = Adjust-HexBrightness $bgBase $(if ($isLight) { 10 } else { -30 })
    $bgSurface = Adjust-HexBrightness $bgBase $(if ($isLight) { -5 } else { 8 })
    $bgBorder  = Adjust-HexBrightness $bgBase $(if ($isLight) { -8 } else { 12 })

    $fg       = $scheme.foreground
    $fgDim    = $scheme.white
    $fgMuted  = $scheme.brightBlack

    # ── Terminal ───────────────────────────────────────────────────────────
    _TestPair "terminal" "foreground on background"       $fg       $bgBase
    _TestPair "terminal" "cursor on background"           $scheme.cursorColor $bgBase

    # ANSI normal colors on terminal bg
    foreach ($col in @('black','red','green','yellow','blue','magenta','cyan','white')) {
        $hex = $scheme."$col"
        if ($col -eq 'black') { continue } # black on dark bg is expected to be low
        _TestPair "terminal" "normal $col on background"  $hex $bgBase
    }
    # ANSI bright colors on terminal bg
    foreach ($col in @('brightBlack','brightRed','brightGreen','brightYellow','brightBlue','brightMagenta','brightCyan','brightWhite')) {
        $hex = $scheme."$col"
        _TestPair "terminal" "$col on background"         $hex $bgBase
    }

    # ── VS Code: editor ───────────────────────────────────────────────────
    _TestPair "vscode" "editor.foreground on editor.background"     $fg      $bgBase
    _TestPair "vscode" "fgDim on editor.background"                 $fgDim   $bgBase
    _TestPair "vscode" "fgMuted on editor.background"               $fgMuted $bgBase

    # ── VS Code: sidebar / activity bar ────────────────────────────────────
    _TestPair "vscode" "sideBar.foreground on sideBar.background"   $fgDim   $bgMid
    _TestPair "vscode" "activityBar.foreground on activityBar.bg"   $fgDim   $bgMid
    _TestPair "vscode" "activityBar.inactive on activityBar.bg"     $fgMuted $bgMid

    # ── VS Code: status bar ────────────────────────────────────────────────
    _TestPair "vscode" "statusBar.foreground on statusBar.bg"       $fgDim   $bgDarkest
    _TestPair "vscode" "statusBar.debugFg on statusBar.bg"          $scheme.yellow $bgDarkest
    _TestPair "vscode" "statusBar.errorFg on statusBar.bg"          $scheme.red    $bgDarkest
    _TestPair "vscode" "statusBar.warningFg on statusBar.bg"        $scheme.yellow $bgDarkest

    # ── VS Code: title bar ─────────────────────────────────────────────────
    _TestPair "vscode" "titleBar.activeFg on titleBar.bg"           $fgDim   $bgDarkest
    _TestPair "vscode" "titleBar.inactiveFg on titleBar.bg"         $fgMuted $bgDarkest

    # ── VS Code: menu ──────────────────────────────────────────────────────
    _TestPair "vscode" "menu.foreground on menu.background"         $fgDim   $bgDarkest
    _TestPair "vscode" "menu.selectionFg on menu.selectionBg"       $fg      $bgBase

    # ── VS Code: tabs ──────────────────────────────────────────────────────
    _TestPair "vscode" "tab.activeFg on tab.activeBg"               $fg      $bgBase
    _TestPair "vscode" "tab.inactiveFg on tab.inactiveBg"           $fgDim   $bgBase

    # ── VS Code: panel ─────────────────────────────────────────────────────
    _TestPair "vscode" "panelTitle.activeFg on panel.bg"            $fgDim   $bgMid
    _TestPair "vscode" "panelTitle.inactiveFg on panel.bg"          $fgMuted $bgMid

    # ── VS Code: inputs / widgets ──────────────────────────────────────────
    _TestPair "vscode" "input.foreground on editor.bg"              $fg      $bgBase
    _TestPair "vscode" "quickInput.fg on quickInput.bg"             $fg      $bgSurface
    _TestPair "vscode" "editorWidget.fg on editorWidget.bg"         $fg      $bgBase
    _TestPair "vscode" "editorSuggest.fg on editorSuggest.bg"       $fg      $bgSurface

    # ── VS Code: notifications ─────────────────────────────────────────────
    _TestPair "vscode" "notifications.fg on notifications.bg"       $fg      $bgBase

    # ── VS Code: button ────────────────────────────────────────────────────
    $accentName = $theme.vscode.accent   # e.g. "yellow", "blue" — a color role name
    $accent = $scheme."$accentName"
    if ($accent) {
        _TestPair "vscode" "button.fg on button.bg (accent)"       $bgBase  $accent
        _TestPair "vscode" "badge.fg on badge.bg (accent)"         $bgBase  $accent
        _TestPair "vscode" "activityBarBadge.fg on badge (accent)" $bgBase  $accent
    }
    _TestPair "vscode" "button.secondaryFg on button.secondaryBg"  $fg      $bgSurface

    # ── VS Code: peek view ─────────────────────────────────────────────────
    _TestPair "vscode" "peekViewResult.fileFg on peekView.bg"       $fg      $bgSurface
    _TestPair "vscode" "peekViewResult.lineFg on peekView.bg"       $fgDim   $bgSurface

    # ── VS Code: breadcrumb / links ────────────────────────────────────────
    $linkName = $theme.vscode.link
    $link = $scheme."$linkName"
    if (-not $link) { $link = $scheme.blue }
    _TestPair "vscode" "textLink on editor.bg"                      $link    $bgBase

    # ── VS Code: terminal inside editor ────────────────────────────────────
    _TestPair "vscode" "terminal.foreground on terminal.bg"         $fg      $bgBase

    # ── VS Code: editor special colors ─────────────────────────────────────
    _TestPair "vscode" "editorLineNumber on editor.bg"              $fgMuted $bgBase
    _TestPair "vscode" "editorCodeLens on editor.bg"                $fgMuted $bgBase
    _TestPair "vscode" "editorGhostText on editor.bg"               $fgMuted $bgBase

    # ── VS Code: git decorations ───────────────────────────────────────────
    _TestPair "vscode" "git modified on sideBar.bg"                 $scheme.blue    $bgMid
    _TestPair "vscode" "git deleted on sideBar.bg"                  $scheme.red     $bgMid
    _TestPair "vscode" "git untracked on sideBar.bg"                $scheme.yellow  $bgMid

    # ── File Pilot ─────────────────────────────────────────────────────────
    $fpBg    = $bgBase
    $fpSurf  = Adjust-HexBrightness $bgBase -15
    $fpBgDk  = Adjust-HexBrightness $bgBase -30

    _TestPair "filepilot" "Text on Background"              $fg       $fpBg
    _TestPair "filepilot" "Secondary on Background"         $fgMuted  $fpBg
    _TestPair "filepilot" "Secondary (Foreground) on Surface" $fgMuted $fpSurf
    _TestPair "filepilot" "Group on Background"             $scheme.white   $fpBg
    _TestPair "filepilot" "Group on Surface"                $scheme.white   $fpSurf
    _TestPair "filepilot" "File on Background"              $fgMuted  $fpBg
    _TestPair "filepilot" "Folder on Background"            $scheme.white   $fpBg
    _TestPair "filepilot" "Text on Caption (dark bg)"       $fg       $fpBgDk
    _TestPair "filepilot" "Secondary on Caption"            $fgMuted  $fpBgDk
    _TestPair "filepilot" "IconTint on Background"          $scheme.cyan    $fpBg

    # ── Prompt ─────────────────────────────────────────────────────────────
    # Prompt colors are top-level on the theme object with # prefix
    $promptMap = @{
        "os"       = $theme.muted
        "user"     = $theme.userhost
        "path"     = $theme.path
        "git"      = $theme.git
    }
    foreach ($entry in $promptMap.GetEnumerator()) {
        if ($entry.Value) {
            _TestPair "prompt" "$($entry.Key) on terminal bg" $entry.Value $bgBase
        }
    }
}

# ── Main ───────────────────────────────────────────────────────────────────

$parsed = Parse-Args $args @{
    "all"   = @{ Type = "switch"; Aliases = @("all", "a") }
    "ratio" = @{ Type = "value";  Aliases = @("ratio", "r"); Default = $null }
}

if ($parsed.ratio) {
    $script:RequiredRatio = [double]$parsed.ratio
}

$themeNames = @()
if ($parsed.all) {
    $colorsJson = Get-Content "$PSScriptRoot\..\_lib\themes\colors.json" -Raw | ConvertFrom-Json
    $themeNames = $colorsJson.PSObject.Properties.Name | Sort-Object
} else {
    $name = $parsed._positional | Select-Object -First 1
    if (-not $name) {
        $name = Get-ScriptConfig "theme" "palette"
        if (-not $name) { $name = "catppuccin_mocha" }
    }
    $themeNames = @($name)
}

Write-Host ""
Write-Host "  $($c.bold)Color Contrast Audit$($c.reset)  $($c.dim)(require ${script:RequiredRatio}:1)$($c.reset)"
Write-Host ""

$totalPass = 0
$totalFail = 0
$failedThemes = @()

foreach ($tn in $themeNames) {
    $script:passCount = 0
    $script:failCount = 0

    $theme = Get-Theme $tn
    $displayName = if ($theme) { $theme.name } else { $tn }

    Write-Host "  $($c.bold)$displayName$($c.reset) $($c.dim)($tn)$($c.reset)"

    _AuditTheme $tn

    if ($script:failCount -eq 0) {
        Write-Host "  $($c.green)All $($script:passCount) pairs pass$($c.reset)"
    } else {
        $failedThemes += $tn
    }

    Write-Host "  $($c.dim)$($script:passCount) pass, $($script:failCount) fail$($c.reset)"
    Write-Host ""

    $totalPass += $script:passCount
    $totalFail += $script:failCount
}

# ── Summary ────────────────────────────────────────────────────────────────

Write-Host "  $($c.bold)Summary$($c.reset)  $($c.green)$totalPass pass$($c.reset)  $(if ($totalFail -gt 0) { "$($c.red)$totalFail fail$($c.reset)" } else { "$($c.dim)0 fail$($c.reset)" })"

if ($failedThemes.Count -gt 0) {
    Write-Host "  $($c.dim)Themes with failures: $($failedThemes -join ', ')$($c.reset)"
}

Write-Host ""
