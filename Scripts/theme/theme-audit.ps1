#.ALIAS theme-audit
<#
.SYNOPSIS
    Audit system colors against the selected theme.

.DESCRIPTION
    Reads the current theme from config and checks every themed component
    (Windows Terminal, Alacritty, Kitty, Ghostty, WezTerm, VS Code,
     File Pilot, browsers, Windows accent, Karchy) to verify colors match.

.EXAMPLE
    theme-audit              # audit current theme
    theme-audit gruvbox      # audit as if gruvbox were the target
#>

. "$PSScriptRoot\..\_lib\ScriptUtils.ps1"
. "$PSScriptRoot\..\_lib\TerminalConfig.ps1"
. "$PSScriptRoot\..\_lib\ThemeData.ps1"

$c = Get-Colors

# -- Determine target theme --------------------------------------------------

$parsed = Parse-Args $args @{}
$themeName = $parsed._positional | Select-Object -First 1
if (-not $themeName) {
    $themeName = Get-ScriptConfig "theme" "palette"
    if (-not $themeName) { $themeName = "catppuccin_mocha" }
}

$theme = Get-Theme $themeName
if (-not $theme) {
    Write-Host "Unknown theme: $themeName" -ForegroundColor Red
    exit 1
}

# Aliases for backward compat within this script
$scheme = $theme
$palette = $theme

# -- Helpers -----------------------------------------------------------------

$script:passCount = 0
$script:failCount = 0
$script:skipCount = 0

function _Normalize([string]$hex) {
    return $hex.TrimStart('#').ToUpper()
}

function _Check([string]$label, [string]$expected, [string]$actual) {
    $e = _Normalize $expected
    $a = _Normalize $actual
    if ($e -eq $a) {
        $script:passCount++
    } else {
        $script:failCount++
        Write-Host "  $($c.red)MISMATCH$($c.reset) $label"
        Write-Host "           expected: $($c.dim)#$e$($c.reset)  got: $($c.dim)#$a$($c.reset)"
    }
}

function _Skip([string]$label, [string]$reason) {
    $script:skipCount++
    Write-Host "  $($c.dim)SKIP$($c.reset)     $label $($c.dim)($reason)$($c.reset)"
}

function _Section([string]$name) {
    Write-Host ""
    Write-Host "  $($c.bold)$($c.cyan)$name$($c.reset)"
}

function _SectionResult([string]$name, [int]$checks, [int]$fails) {
    if ($fails -eq 0 -and $checks -gt 0) {
        Write-Host "  $($c.green)OK$($c.reset)       $checks checks passed"
    }
}

# -- Windows Terminal --------------------------------------------------------

$wtSettings = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

_Section "Windows Terminal"
$preFail = $script:failCount

if (Test-Path $wtSettings) {
    $wt = Get-Content $wtSettings -Raw | ConvertFrom-Json
    $schemeName = $scheme.name

    # Check profile color scheme assignment
    $profile = $wt.profiles.list | Where-Object { $_.guid -eq "{f1a2b3c4-d5e6-4f78-9a0b-1c2d3e4f5a6b}" }
    if ($profile) {
        _Check "profile colorScheme" $schemeName $profile.colorScheme
    } else {
        _Skip "profile" "Nulifyer profile not found"
    }

    # Check scheme colors
    $wtScheme = $wt.schemes | Where-Object { $_.name -eq $schemeName }
    if ($wtScheme) {
        foreach ($key in @('background','foreground','cursorColor','selectionBackground',
                           'black','red','green','yellow','blue','purple','cyan','white',
                           'brightBlack','brightRed','brightGreen','brightYellow','brightBlue','brightPurple','brightCyan','brightWhite')) {
            $expected = $scheme[$key]
            $actual = $wtScheme.$key
            if ($expected -and $actual) { _Check "scheme.$key" $expected $actual }
        }
    } else {
        _Skip "scheme" "scheme '$schemeName' not found in settings"
    }
} else {
    _Skip "Windows Terminal" "settings.json not found"
}
_SectionResult "Windows Terminal" ($script:passCount + $script:failCount) ($script:failCount - $preFail)

# -- Alacritty ---------------------------------------------------------------

_Section "Alacritty"
$preFail = $script:failCount
$prePass = $script:passCount

$alacrittyPath = $null
foreach ($p in @("$env:APPDATA\alacritty\alacritty.toml", "$env:USERPROFILE\.config\alacritty\alacritty.toml")) {
    if (Test-Path $p) { $alacrittyPath = $p; break }
}

if ($alacrittyPath) {
    $content = Get-Content $alacrittyPath -Raw

    # Parse TOML color values (simple key = "value" extraction)
    $tomlMap = @{
        'colors\.primary.*background' = 'background'
        'colors\.primary.*foreground' = 'foreground'
        'colors\.cursor.*cursor'      = 'cursorColor'
        'colors\.selection.*background' = 'selectionBackground'
        'colors\.normal.*black'   = 'black';   'colors\.normal.*red'     = 'red'
        'colors\.normal.*green'   = 'green';    'colors\.normal.*yellow'  = 'yellow'
        'colors\.normal.*blue'    = 'blue';     'colors\.normal.*magenta' = 'purple'
        'colors\.normal.*cyan'    = 'cyan';     'colors\.normal.*white'   = 'white'
        'colors\.bright.*black'   = 'brightBlack';   'colors\.bright.*red'     = 'brightRed'
        'colors\.bright.*green'   = 'brightGreen';    'colors\.bright.*yellow'  = 'brightYellow'
        'colors\.bright.*blue'    = 'brightBlue';     'colors\.bright.*magenta' = 'brightPurple'
        'colors\.bright.*cyan'    = 'brightCyan';     'colors\.bright.*white'   = 'brightWhite'
    }

    # Parse section-aware: track current section and extract keys
    $currentSection = ""
    foreach ($line in ($content -split "`n")) {
        $line = $line.Trim()
        if ($line -match '^\[(.+)\]$') { $currentSection = $Matches[1] }
        elseif ($line -match '^(\w+)\s*=\s*"(#[0-9A-Fa-f]{6})"') {
            $key = $Matches[1]
            $val = $Matches[2]
            $fullKey = "$currentSection.$key"
            foreach ($pattern in $tomlMap.Keys) {
                if ($fullKey -match $pattern) {
                    $schemeKey = $tomlMap[$pattern]
                    _Check "alacritty $schemeKey" $scheme[$schemeKey] $val
                }
            }
        }
    }
    if ($script:passCount -eq $prePass -and $script:failCount -eq $preFail) {
        _Skip "Alacritty" "no color sections found in config"
    }
} else {
    _Skip "Alacritty" "config not found"
}
_SectionResult "Alacritty" ($script:passCount - $prePass) ($script:failCount - $preFail)

# -- Kitty -------------------------------------------------------------------

_Section "Kitty"
$preFail = $script:failCount
$prePass = $script:passCount

$kittyPath = $null
foreach ($p in @("$env:USERPROFILE\.config\kitty\kitty.conf", "$env:APPDATA\kitty\kitty.conf")) {
    if (Test-Path $p) { $kittyPath = $p; break }
}

if ($kittyPath) {
    $kittyMap = @{
        'background'  = 'background'; 'foreground'  = 'foreground'; 'cursor' = 'cursorColor'
        'selection_background' = 'selectionBackground'
        'color0' = 'black'; 'color1' = 'red'; 'color2' = 'green'; 'color3' = 'yellow'
        'color4' = 'blue'; 'color5' = 'purple'; 'color6' = 'cyan'; 'color7' = 'white'
        'color8' = 'brightBlack'; 'color9' = 'brightRed'; 'color10' = 'brightGreen'; 'color11' = 'brightYellow'
        'color12' = 'brightBlue'; 'color13' = 'brightPurple'; 'color14' = 'brightCyan'; 'color15' = 'brightWhite'
    }
    foreach ($line in (Get-Content $kittyPath)) {
        if ($line -match '^\s*(\w+)\s+(#[0-9A-Fa-f]{6})') {
            $key = $Matches[1]; $val = $Matches[2]
            if ($kittyMap.ContainsKey($key)) {
                _Check "kitty $($kittyMap[$key])" $scheme[$kittyMap[$key]] $val
            }
        }
    }
    if ($script:passCount -eq $prePass -and $script:failCount -eq $preFail) {
        _Skip "Kitty" "no color values found in config"
    }
} else {
    _Skip "Kitty" "config not found"
}
_SectionResult "Kitty" ($script:passCount - $prePass) ($script:failCount - $preFail)

# -- Ghostty -----------------------------------------------------------------

_Section "Ghostty"
$preFail = $script:failCount
$prePass = $script:passCount

$ghosttyPath = $null
foreach ($p in @("$env:APPDATA\ghostty\config", "$env:USERPROFILE\.config\ghostty\config")) {
    if (Test-Path $p) { $ghosttyPath = $p; break }
}

if ($ghosttyPath) {
    $ghosttyColorMap = @{
        'background' = 'background'; 'foreground' = 'foreground'
        'cursor-color' = 'cursorColor'; 'selection-background' = 'selectionBackground'
    }
    $ghosttyPaletteMap = @{
        '0' = 'black'; '1' = 'red'; '2' = 'green'; '3' = 'yellow'
        '4' = 'blue'; '5' = 'purple'; '6' = 'cyan'; '7' = 'white'
        '8' = 'brightBlack'; '9' = 'brightRed'; '10' = 'brightGreen'; '11' = 'brightYellow'
        '12' = 'brightBlue'; '13' = 'brightPurple'; '14' = 'brightCyan'; '15' = 'brightWhite'
    }
    foreach ($line in (Get-Content $ghosttyPath)) {
        if ($line -match '^\s*palette\s*=\s*(\d+)=(#[0-9A-Fa-f]{6})') {
            $idx = $Matches[1]; $val = $Matches[2]
            if ($ghosttyPaletteMap.ContainsKey($idx)) {
                $sk = $ghosttyPaletteMap[$idx]
                _Check "ghostty palette[$idx] ($sk)" $scheme[$sk] $val
            }
        } elseif ($line -match '^\s*([\w-]+)\s*=\s*(#[0-9A-Fa-f]{6})') {
            $key = $Matches[1]; $val = $Matches[2]
            if ($ghosttyColorMap.ContainsKey($key)) {
                _Check "ghostty $($ghosttyColorMap[$key])" $scheme[$ghosttyColorMap[$key]] $val
            }
        }
    }
    if ($script:passCount -eq $prePass -and $script:failCount -eq $preFail) {
        _Skip "Ghostty" "no color values found in config"
    }
} else {
    _Skip "Ghostty" "config not found"
}
_SectionResult "Ghostty" ($script:passCount - $prePass) ($script:failCount - $preFail)

# -- WezTerm -----------------------------------------------------------------

_Section "WezTerm"
$preFail = $script:failCount
$prePass = $script:passCount

$weztermPath = $null
foreach ($p in @("$env:USERPROFILE\.config\wezterm\wezterm.lua", "$env:USERPROFILE\.wezterm.lua")) {
    if (Test-Path $p) { $weztermPath = $p; break }
}

if ($weztermPath) {
    $content = Get-Content $weztermPath -Raw
    $m = [regex]::Match($content, '(?ms)^-- BEGIN theme \(managed.*?^-- END theme')
    if ($m.Success) {
        $blk = $m.Value
        foreach ($pair in @(@('foreground', 'foreground'), @('background', 'background'), @('cursor_bg', 'cursorColor'), @('selection_bg', 'selectionBackground'))) {
            if ($blk -match "(?m)^\s*$($pair[0])\s*=\s*'([^']+)'") { _Check "wezterm $($pair[0])" $scheme[$pair[1]] $Matches[1] }
            else { _Check "wezterm $($pair[0])" $scheme[$pair[1]] '(missing)' }
        }
        foreach ($set in @(@('ansi', @('black','red','green','yellow','blue','purple','cyan','white')),
                           @('brights', @('brightBlack','brightRed','brightGreen','brightYellow','brightBlue','brightPurple','brightCyan','brightWhite')))) {
            if ($blk -match "(?m)^\s*$($set[0])\s*=\s*\{([^}]*)\}") {
                $vals = @([regex]::Matches($Matches[1], "'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
                for ($i = 0; $i -lt 8; $i++) { _Check "wezterm $($set[0])[$i]" $scheme[$set[1][$i]] $vals[$i] }
            } else { _Check "wezterm $($set[0])" 'present' '(missing)' }
        }
        if ($content -match '(?m)^\s*config\.color_scheme\s*=') { _Check "wezterm color_scheme disabled" 'commented out' 'still set (overrides the palette)' }
    } elseif ($content -notmatch '(?m)^return\s+config\b') {
        _Skip "WezTerm" "config doesn't end with 'return config', so theme leaves it alone"
    } else {
        _Check "wezterm palette block" 'present' '(missing: run theme again)'
    }
} else {
    _Skip "WezTerm" "config not found"
}
_SectionResult "WezTerm" ($script:passCount - $prePass) ($script:failCount - $preFail)

# -- VS Code -----------------------------------------------------------------

_Section "VS Code"
$preFail = $script:failCount
$prePass = $script:passCount

$vsVariants = @(_Get-VSCodeVariants)
$vsSettingsPath = if ($vsVariants) { $vsVariants[0].Settings } else { $null }
foreach ($v in $vsVariants | Select-Object -Skip 1) {
    $vsOther = if (Test-Path $v.Settings) { (Get-Content $v.Settings -Raw | ConvertFrom-Json).'workbench.colorTheme' } else { '(no settings.json)' }
    _Check "$($v.Name) workbench.colorTheme" "Nulifyer" $vsOther
}
if ($vsVariants -and -not (Test-Path $vsSettingsPath)) {
    _Check "$($vsVariants[0].Name) themed" "settings.json written" "(missing: run theme again)"
} elseif ($vsSettingsPath -and (Test-Path $vsSettingsPath)) {
    $vs = Get-Content $vsSettingsPath -Raw | ConvertFrom-Json

    # Check active theme name
    $activeTheme = $vs.'workbench.colorTheme'
    if ($activeTheme) {
        _Check "workbench.colorTheme" "Nulifyer" $activeTheme
    } else {
        _Skip "colorTheme" "not set in settings"
    }

    # Regenerate full expected color map from the shared VS Code generator
    $cc = $vs.'workbench.colorCustomizations'
    if ($cc) {
        $vsExpected = Get-VSCodeColorCustomizations $scheme $themeName

        foreach ($prop in $vsExpected.Keys) {
            $actual = $cc.$prop
            if ($actual) {
                _Check "vscode $prop" $vsExpected[$prop] $actual
            }
        }

        # Check for extra properties in settings not in expected map
        $ccProps = $cc.PSObject.Properties | ForEach-Object { $_.Name }
        $extras = $ccProps | Where-Object { -not $vsExpected.Contains($_) }
        foreach ($extra in $extras) {
            $script:failCount++
            Write-Host "  $($c.yellow)EXTRA$($c.reset)    vscode $extra = $($cc.$extra) $($c.dim)(not in theme map)$($c.reset)"
        }
    } else {
        _Skip "colorCustomizations" "not set in settings"
    }

    # Check token color rules (textMateRules) — rebuild full expected map from theme logic
    $tc = $vs.'editor.tokenColorCustomizations'
    $vsTokens = Get-VSCodeTokenCustomizations $scheme $themeName
    if ($tc -and $tc.textMateRules) {
        # Expected scope -> color, from the same generator that writes them
        $tcExpected = [ordered]@{}
        foreach ($rule in $vsTokens.TextMateRules) { $tcExpected[$rule.scope] = $rule.settings.foreground }

        # A rule without a color silently falls back to VS Code's defaults
        foreach ($rule in $tc.textMateRules) {
            if (-not $rule.settings.foreground -and -not $rule.settings.fontStyle) { _Check "token $($rule.scope) has a color" 'a color' '(empty)' }
        }
        foreach ($k in $vsTokens.Semantic.rules.Keys) {
            $v = $vsTokens.Semantic.rules[$k]
            if (-not ($(if ($v -is [System.Collections.IDictionary]) { $v.foreground -or $v.fontStyle } else { $v }))) { _Check "semantic $k has a color" 'a color' '(empty)' }
        }

        # Compare every rule in settings against expected
        foreach ($rule in $tc.textMateRules) {
            $scope = $rule.scope
            $actual = $rule.settings.foreground
            if ($tcExpected.Contains($scope)) {
                _Check "token $scope" $tcExpected[$scope] $actual
            } else {
                $script:failCount++
                Write-Host "  $($c.yellow)EXTRA$($c.reset)    token rule: $scope = $actual $($c.dim)(not in expected map)$($c.reset)"
            }
        }

        # Check for expected rules missing from settings
        $actualScopes = @{}
        foreach ($rule in $tc.textMateRules) { $actualScopes[$rule.scope] = $true }
        foreach ($scope in $tcExpected.Keys) {
            if (-not $actualScopes.Contains($scope)) {
                $script:failCount++
                Write-Host "  $($c.red)MISSING$($c.reset)  token rule: $scope $($c.dim)(expected $($tcExpected[$scope]))$($c.reset)"
            }
        }
    } else {
        _Skip "tokenColorCustomizations" "not set in settings"
    }

    # Check semantic token colors
    $stc = $vs.'editor.semanticTokenColorCustomizations'
    if ($stc -and $stc.rules) {
        $semExpected = [ordered]@{}
        foreach ($k in $vsTokens.Semantic.rules.Keys) {
            $v = $vsTokens.Semantic.rules[$k]
            $semExpected[$k] = if ($v -is [System.Collections.IDictionary]) { $v.foreground } else { $v }
        }
        foreach ($k in $semExpected.Keys) {
            $actual = $stc.rules.$k
            if ($actual -and $actual -isnot [string]) { $actual = $actual.foreground }
            if ($actual) {
                _Check "semantic.$k" $semExpected[$k] $actual
            } else {
                $script:failCount++
                Write-Host "  $($c.red)MISSING$($c.reset)  semantic rule: $k $($c.dim)(expected $($semExpected[$k]))$($c.reset)"
            }
        }
        # Check for extra semantic rules
        $stc.rules.PSObject.Properties | ForEach-Object {
            if (-not $semExpected.Contains($_.Name)) {
                $script:failCount++
                Write-Host "  $($c.yellow)EXTRA$($c.reset)    semantic rule: $($_.Name) = $($_.Value) $($c.dim)(not in expected map)$($c.reset)"
            }
        }
    } else {
        _Skip "semanticTokenColorCustomizations" "not set in settings"
    }
} else {
    _Skip "VS Code" "settings.json not found"
}
_SectionResult "VS Code" ($script:passCount - $prePass) ($script:failCount - $preFail)

# -- File Pilot --------------------------------------------------------------

_Section "File Pilot"
$preFail = $script:failCount
$prePass = $script:passCount

$fpConfigPath = "$env:APPDATA\Voidstar\FilePilot\FPilot-Config.json"

if (Test-Path $fpConfigPath) {
    # File Pilot uses non-standard JSON ("key": { } inside arrays) — parse with regex
    $fpContent = Get-Content $fpConfigPath -Raw

    # Check ColorScheme
    if ($fpContent -match '"ColorScheme"\s*:\s*"([^"]+)"') {
        _Check "FilePilot ColorScheme" "Nulifyer" $Matches[1]
    }

    # Extract Nulifyer color block
    $fpColors = @{}
    if ($fpContent -match '(?s)"Nulifyer"\s*:\s*\{([^}]+)\}') {
        $block = $Matches[1]
        foreach ($m in [regex]::Matches($block, '"(\w+)"\s*:\s*"([0-9A-Fa-f]{6})"')) {
            $fpColors[$m.Groups[1].Value] = $m.Groups[2].Value
        }
    }

    if ($fpColors.Count -gt 0) {
        $bgBase = $scheme.background.TrimStart('#')
        $_fg = $scheme.foreground.TrimStart('#')
        $_secondary = $scheme.white.TrimStart('#')
        $_hidden = (Adjust-HexBrightness $scheme.brightBlack $(if (_Is-LightTheme $themeName) { -22 } else { 22 })).TrimStart('#')

        _Check "FilePilot Background" $bgBase $fpColors.Background
        _Check "FilePilot Text" $_fg $fpColors.Text
        _Check "FilePilot Foreground" $_fg $fpColors.Foreground
        _Check "FilePilot Secondary" $_secondary $fpColors.Secondary
        _Check "FilePilot IconTint" $scheme.cyan.TrimStart('#') $fpColors.IconTint
        _Check "FilePilot Selection" $scheme.blue.TrimStart('#') $fpColors.Selection
        _Check "FilePilot Match" $scheme.yellow.TrimStart('#') $fpColors.Match
        _Check "FilePilot Warning" $scheme.red.TrimStart('#') $fpColors.Warning
        _Check "FilePilot File" $_fg $fpColors.File
        _Check "FilePilot Folder" $_fg $fpColors.Folder
        _Check "FilePilot Hidden" $_hidden $fpColors.Hidden
        _Check "FilePilot Disabled" $_hidden $fpColors.Disabled
        _Check "FilePilot Progress" $scheme.blue.TrimStart('#') $fpColors.Progress
    } else {
        _Skip "FilePilot colors" "Nulifyer scheme not found"
    }
} else {
    _Skip "File Pilot" "config not found"
}
_SectionResult "File Pilot" ($script:passCount - $prePass) ($script:failCount - $preFail)

# -- Browsers ----------------------------------------------------------------

_Section "Browsers"
$preFail = $script:failCount
$prePass = $script:passCount

$browsers = @(
    @{ Name = "Chrome";  Policy = "HKCU:\SOFTWARE\Policies\Google\Chrome";  Exe = @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe") }
    @{ Name = "Brave";   Policy = "HKCU:\SOFTWARE\Policies\BraveSoftware\Brave";  Exe = @("$env:ProgramFiles\BraveSoftware\Brave-Browser\Application\brave.exe") }
    @{ Name = "Vivaldi"; Policy = "HKCU:\SOFTWARE\Policies\Vivaldi";  Exe = @("$env:LOCALAPPDATA\Vivaldi\Application\vivaldi.exe") }
)

$anyBrowser = $false
foreach ($b in $browsers) {
    $installed = $b.Exe | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($installed) {
        $anyBrowser = $true
        $regColor = if (Test-Path $b.Policy) { (Get-ItemProperty -Path $b.Policy -Name "BrowserThemeColor" -ErrorAction SilentlyContinue).BrowserThemeColor }
        if ($regColor) {
            _Check "$($b.Name) BrowserThemeColor" (Get-BrowserThemeSeed $scheme) $regColor
        } else {
            _Skip "$($b.Name)" "theme color not applied: browser policies need an administrator shell (sudo theme $themeName)"
        }
    }
}
if ((Get-ItemProperty "HKCU:\SOFTWARE\Policies\Microsoft\Edge" -Name BrowserThemeColor -ErrorAction SilentlyContinue)) {
    _Check "Edge BrowserThemeColor" "(not set: Edge rejects this policy)" "set (shows a policy error in Edge)"
}
if (-not $anyBrowser) {
    _Skip "Browsers" "no Chromium browsers detected"
}
_SectionResult "Browsers" ($script:passCount - $prePass) ($script:failCount - $preFail)

# -- Windows System ----------------------------------------------------------

_Section "Windows System"
$preFail = $script:failCount
$prePass = $script:passCount

$personalizePath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
$dwmPath = "HKCU:\SOFTWARE\Microsoft\Windows\DWM"
$accentPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Accent"

# Dark/Light mode
$expectedMode = if (_Is-LightTheme $themeName) { 1 } else { 0 }
$appsMode = (Get-ItemProperty $personalizePath -Name "AppsUseLightTheme" -ErrorAction SilentlyContinue).AppsUseLightTheme
$sysMode  = (Get-ItemProperty $personalizePath -Name "SystemUsesLightTheme" -ErrorAction SilentlyContinue).SystemUsesLightTheme

if ($null -ne $appsMode) { _Check "AppsUseLightTheme" $expectedMode $appsMode }
if ($null -ne $sysMode)  { _Check "SystemUsesLightTheme" $expectedMode $sysMode }

# Color prevalence
$colorPrev = (Get-ItemProperty $personalizePath -Name "ColorPrevalence" -ErrorAction SilentlyContinue).ColorPrevalence
if ($null -ne $colorPrev) { _Check "ColorPrevalence" 0 $colorPrev }
$dwmPrev = (Get-ItemProperty $dwmPath -Name "ColorPrevalence" -ErrorAction SilentlyContinue).ColorPrevalence
if ($null -ne $dwmPrev) { _Check "DWM ColorPrevalence" 1 $dwmPrev }

# Accent color: same semantic role used by Update-WindowsTheme.
$ctx = Get-VSCodeThemeContext $scheme $themeName
$expectedAccent = if ($ctx -and $ctx.roles -and $ctx.roles.accent) { $ctx.roles.accent } else { $scheme.selectionBackground }
if (-not $expectedAccent) { $expectedAccent = $scheme.background }
$expectedAccent = $expectedAccent.ToUpperInvariant()
$expectedStart = Adjust-HexBrightness $expectedAccent -15

function _CheckDword([string]$label, [int64]$expected, $actual) {
    if ($null -eq $actual) { return }
    $expectedU = [Convert]::ToUInt32($expected -band 0xFFFFFFFF)
    $actualU = [Convert]::ToUInt32([int64]$actual -band 0xFFFFFFFF)
    if ($expectedU -eq $actualU) {
        $script:passCount++
    } else {
        $script:failCount++
        Write-Host "  $($c.red)MISMATCH$($c.reset) $label"
        Write-Host "           expected: $($c.dim)0x$($expectedU.ToString('X8'))$($c.reset)  got: $($c.dim)0x$($actualU.ToString('X8'))$($c.reset)"
    }
}

function _CheckBinary([string]$label, [byte[]]$expected, $actual) {
    if ($null -eq $actual) { return }
    $actualBytes = [byte[]]$actual
    $expectedHex = ($expected | ForEach-Object { $_.ToString('X2') }) -join ' '
    $actualHex = ($actualBytes | ForEach-Object { $_.ToString('X2') }) -join ' '
    if ($expectedHex -eq $actualHex) {
        $script:passCount++
    } else {
        $script:failCount++
        Write-Host "  $($c.red)MISMATCH$($c.reset) $label"
        Write-Host "           expected: $($c.dim)$expectedHex$($c.reset)"
        Write-Host "           got:      $($c.dim)$actualHex$($c.reset)"
    }
}

$dwm = Get-ItemProperty $dwmPath -ErrorAction SilentlyContinue
$accent = Get-ItemProperty $accentPath -ErrorAction SilentlyContinue
$expectedABGR = Convert-HexToABGR $expectedAccent
$expectedStartABGR = Convert-HexToABGR $expectedStart
$expectedInactiveABGR = Convert-HexToABGR (Adjust-HexBrightness $expectedAccent -40)
$expectedColorizationARGB = Convert-HexToARGB $expectedAccent 0xC4

_CheckDword "DWM AccentColor" $expectedABGR $dwm.AccentColor
_CheckDword "DWM AccentColorInactive" $expectedInactiveABGR $dwm.AccentColorInactive
_CheckDword "DWM ColorizationColor" $expectedColorizationARGB $dwm.ColorizationColor
_CheckDword "DWM ColorizationAfterglow" $expectedColorizationARGB $dwm.ColorizationAfterglow
_CheckDword "AccentColor" $expectedABGR $accent.AccentColor
_CheckDword "AccentColorMenu" $expectedABGR $accent.AccentColorMenu
_CheckDword "StartColor" $expectedStartABGR $accent.StartColor
_CheckDword "StartColorMenu" $expectedStartABGR $accent.StartColorMenu
_CheckBinary "AccentPalette" (New-WindowsAccentPalette $expectedAccent) $accent.AccentPalette
_SectionResult "Windows System" ($script:passCount - $prePass) ($script:failCount - $preFail)

# -- Karchy ------------------------------------------------------------------

_Section "Karchy"
$preFail = $script:failCount
$prePass = $script:passCount

$karchyPath = "$env:APPDATA\karchy\config.toml"

if (Test-Path $karchyPath) {
    $expectedAccent = $palette.userhost
    foreach ($line in (Get-Content $karchyPath)) {
        if ($line -match '^\s*accent\s*=\s*"([^"]+)"') {
            _Check "karchy accent" $expectedAccent $Matches[1]
            break
        }
    }
} else {
    _Skip "Karchy" "config not found"
}
_SectionResult "Karchy" ($script:passCount - $prePass) ($script:failCount - $preFail)

# -- Saved Config ------------------------------------------------------------

_Section "Saved Config"
$preFail = $script:failCount
$prePass = $script:passCount

$savedTheme = Get-ScriptConfig "theme" "palette"
if ($savedTheme) {
    _Check "config palette" $themeName $savedTheme
} else {
    _Skip "config" "no palette saved"
}
_SectionResult "Saved Config" ($script:passCount - $prePass) ($script:failCount - $preFail)

# -- Lutgen Palette ----------------------------------------------------------

_Section "Lutgen Palette"
$preFail = $script:failCount
$prePass = $script:passCount

$lutgenName = $scheme.lutgen_palette

if ($lutgenName) {
    $haslutgen = Get-Command lutgen -ErrorAction SilentlyContinue
    if ($haslutgen) {
        $lutgenOutput = & lutgen palette $lutgenName 2>$null
        $lutgenColors = @{}
        foreach ($line in $lutgenOutput) {
            if ($line -is [string] -and $line -match "^#[0-9A-Fa-f]{6}$") {
                $lutgenColors[$line.Trim().ToUpper()] = $true
            }
        }
        if ($lutgenColors.Count -gt 0) {
            $schemeKeys = @('background','foreground','cursorColor','selectionBackground',
                'black','red','green','yellow','blue','purple','cyan','white',
                'brightBlack','brightRed','brightGreen','brightYellow','brightBlue','brightPurple','brightCyan','brightWhite')
            foreach ($key in $schemeKeys) {
                $val = $scheme[$key]
                if (-not $val) { continue }
                if ($lutgenColors.ContainsKey($val.ToUpper())) {
                    $script:passCount++
                } else {
                    $script:failCount++
                    Write-Host "  $($c.red)MISMATCH$($c.reset) $key=$val $($c.dim)(not in $lutgenName palette)$($c.reset)"
                }
            }
        } else {
            _Skip "lutgen" "$lutgenName returned no colors"
        }
    } else {
        _Skip "lutgen" "lutgen not installed"
    }
} else {
    _Skip "lutgen" "no palette mapping for $themeName"
}
_SectionResult "Lutgen Palette" ($script:passCount - $prePass) ($script:failCount - $preFail)

# -- Theme Data Integrity ---------------------------------------------------

_Section "Theme Data"
$preFail = $script:failCount
$prePass = $script:passCount

# palette.bg should match scheme.background
_Check "palette.bg = scheme.background" $scheme.background $palette.bg

# palette colors should exist in scheme
$palSchemeMap = @{
    'muted' = 'brightBlack'
}
foreach ($pk in $palSchemeMap.Keys) {
    $palVal = $palette[$pk]
    $schemeVal = $scheme[$palSchemeMap[$pk]]
    if ($palVal -and $schemeVal) {
        _Check "palette.$pk vs scheme.$($palSchemeMap[$pk])" $schemeVal $palVal
    }
}

# Check wtScheme has all required keys
$requiredKeys = @('name','background','foreground','cursorColor','selectionBackground',
    'black','red','green','yellow','blue','purple','cyan','white',
    'brightBlack','brightRed','brightGreen','brightYellow','brightBlue','brightPurple','brightCyan','brightWhite')
foreach ($key in $requiredKeys) {
    if (-not $scheme[$key]) {
        $script:failCount++
        Write-Host "  $($c.red)MISSING$($c.reset)  wtScheme key: $key"
    } else {
        $script:passCount++
    }
}

_SectionResult "Theme Data" ($script:passCount - $prePass) ($script:failCount - $preFail)

# -- Summary -----------------------------------------------------------------

Write-Host ""
Write-Host "  $($c.bold)Theme: $themeName$($c.reset)"
$total = $script:passCount + $script:failCount
if ($script:failCount -eq 0) {
    Write-Host "  $($c.green)All $total checks passed$($c.reset)" -NoNewline
} else {
    Write-Host "  $($c.red)$($script:failCount) mismatches$($c.reset) / $total checks" -NoNewline
}
if ($script:skipCount -gt 0) {
    Write-Host " $($c.dim)($($script:skipCount) skipped)$($c.reset)"
} else {
    Write-Host ""
}
Write-Host ""
