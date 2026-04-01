# Shared theme data — reads from colors.json (single source of truth)
# API: Get-Themes, Get-Theme <name>

$script:ColorsJsonPath = Join-Path $PSScriptRoot 'themes\colors.json'

function _Load-ThemeJson {
    if (-not (Test-Path $script:ColorsJsonPath)) { return @{} }
    return Get-Content $script:ColorsJsonPath -Raw | ConvertFrom-Json -AsHashtable
}

function _Build-Theme([string]$key, [hashtable]$t) {
    $term = $t.terminal
    return @{
        key             = $key
        name            = $t.name
        variant         = $t.variant
        bat_theme       = $t.bat_theme
        lutgen_palette  = $t.lutgen_palette
        # Prompt colors (with # prefix)
        bg              = $term.bg
        muted           = "#$($t.prompt.os)"
        userhost        = "#$($t.prompt.user)"
        path            = "#$($t.prompt.path)"
        git             = "#$($t.prompt.git)"
        # Terminal scheme
        background          = $term.bg
        foreground          = $term.fg
        cursorColor         = $term.cursor
        selectionBackground = $term.selection
        black               = $term.normal.black
        red                 = $term.normal.red
        green               = $term.normal.green
        yellow              = $term.normal.yellow
        blue                = $term.normal.blue
        purple              = $term.normal.magenta
        cyan                = $term.normal.cyan
        white               = $term.normal.white
        brightBlack         = $term.bright.black
        brightRed           = $term.bright.red
        brightGreen         = $term.bright.green
        brightYellow        = $term.bright.yellow
        brightBlue          = $term.bright.blue
        brightPurple        = $term.bright.magenta
        brightCyan          = $term.bright.cyan
        brightWhite         = $term.bright.white
        # Per-theme vscode role map (accent, link, match, find, bracket)
        vscode              = $t.vscode
    }
}

function Get-Themes {
    $json = _Load-ThemeJson
    $result = [ordered]@{}
    foreach ($key in ($json.Keys | Sort-Object)) {
        $result[$key] = _Build-Theme $key $json[$key]
    }
    return $result
}

function Get-Theme([string]$themeName) {
    $json = _Load-ThemeJson
    $t = $json[$themeName]
    if (-not $t) { return $null }
    return _Build-Theme $themeName $t
}
