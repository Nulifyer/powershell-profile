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
    $weztermExpected = if ($script:WEZTERM_SCHEMES[$scheme.name]) { $script:WEZTERM_SCHEMES[$scheme.name] } else { $scheme.name }

    if ($content -match "config\.color_scheme\s*=\s*[`"']([^`"']+)[`"']") {
        _Check "wezterm color_scheme" $weztermExpected $Matches[1]
    } elseif ($content -match "color_scheme\s*=\s*[`"']([^`"']+)[`"']") {
        _Check "wezterm color_scheme" $weztermExpected $Matches[1]
    } else {
        _Skip "WezTerm" "no color_scheme found in config"
    }
} else {
    _Skip "WezTerm" "config not found"
}
_SectionResult "WezTerm" ($script:passCount - $prePass) ($script:failCount - $preFail)

# -- VS Code -----------------------------------------------------------------

_Section "VS Code"
$preFail = $script:failCount
$prePass = $script:passCount

$vsSettingsPath = "$env:APPDATA\Code\User\settings.json"

if (Test-Path $vsSettingsPath) {
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
    if ($tc -and $tc.textMateRules) {
        $orange = $scheme.brightRed

        # Build scope -> expected foreground map (mirrors _tc calls in TerminalConfig.ps1)
        $tcExpected = [ordered]@{}
        # Comments
        foreach ($s in @("comment","punctuation.definition.comment")) { $tcExpected[$s] = $fgMuted }
        # Strings
        foreach ($s in @("string","string.tag","string.value","string meta.image.inline.markdown",
            "meta.embedded.assembly","meta.preprocessor.string",
            "punctuation.definition.string.begin","punctuation.definition.string.end",
            "punctuation.definition.string.template.begin","punctuation.definition.string.template.end")) { $tcExpected[$s] = $scheme.brightGreen }
        $tcExpected["string.regexp"] = $scheme.cyan
        # Constants
        foreach ($s in @("constant.language","constant.numeric","constant.character","constant.other.option",
            "constant.regexp","constant.sha.git-rebase","variable.other.constant","variable.other.enummember",
            "keyword.other.unit","keyword.operator.plus.exponent","keyword.operator.minus.exponent",
            "meta.preprocessor.numeric")) { $tcExpected[$s] = $scheme.purple }
        # Format/escape -> orange
        foreach ($s in @("constant.other.placeholder","constant.character.format.placeholder",
            "constant.character.escape")) { $tcExpected[$s] = $orange }
        foreach ($s in @("constant.other.color.rgb-value","constant.other.rgb-value")) { $tcExpected[$s] = $scheme.brightGreen }
        # Keywords -> red
        foreach ($s in @("keyword","keyword.control","keyword.other.using","keyword.other.directive.using",
            "keyword.other.operator","storage","storage.modifier")) { $tcExpected[$s] = $scheme.red }
        $tcExpected["storage.type"] = $scheme.green
        # Word-like operators -> red
        foreach ($s in @("keyword.operator.expression","keyword.operator.new","keyword.operator.delete",
            "keyword.operator.cast","keyword.operator.sizeof","keyword.operator.alignof","keyword.operator.typeid",
            "keyword.operator.alignas","keyword.operator.instanceof","keyword.operator.logical.python",
            "keyword.operator.wordlike","keyword.operator.noexcept","source.cpp keyword.operator.new",
            "entity.name.operator")) { $tcExpected[$s] = $scheme.red }
        # Symbolic operators -> orange
        foreach ($s in @("keyword.operator","keyword.operator.quantifier.regexp","keyword.operator.negation.regexp",
            "keyword.operator.arrow","storage.type.function.arrow","punctuation.accessor","punctuation.separator.dot",
            "punctuation.other.period","punctuation.separator.namespace","punctuation.separator.namespace.ruby",
            "punctuation.definition.template-expression.begin","punctuation.definition.template-expression.end",
            "punctuation.section.embedded","punctuation.definition.list.begin.markdown")) { $tcExpected[$s] = $orange }
        foreach ($s in @("punctuation.section.embedded.begin.php","punctuation.section.embedded.end.php")) { $tcExpected[$s] = $scheme.red }
        # Regex
        foreach ($s in @("support.other.parenthesis.regexp","punctuation.definition.group.regexp",
            "punctuation.definition.group.assertion.regexp","punctuation.definition.character-class.regexp",
            "punctuation.character.set.begin.regexp","punctuation.character.set.end.regexp")) { $tcExpected[$s] = $scheme.brightGreen }
        foreach ($s in @("constant.character.character-class.regexp","constant.other.character-class.set.regexp",
            "constant.other.character-class.regexp","constant.character.set.regexp")) { $tcExpected[$s] = $scheme.red }
        foreach ($s in @("keyword.operator.or.regexp","keyword.control.anchor.regexp")) { $tcExpected[$s] = $scheme.yellow }
        # Functions -> yellow
        foreach ($s in @("entity.name.function","entity.name.function.macro","entity.name.function.support.builtin",
            "entity.name.operator.custom-literal","entity.name.command","support.function",
            "support.function.builtin","support.function.library","support.function.git-rebase",
            "support.constant.handlebars","source.powershell variable.other.member")) { $tcExpected[$s] = $scheme.yellow }
        $tcExpected["entity.name.function.preprocessor"] = $scheme.red
        # Brackets
        foreach ($s in @("punctuation.definition.block","punctuation.section","meta.brace",
            "punctuation.squarebracket","punctuation.curlybrace","punctuation.parenthesis",
            "punctuation.definition.parameters","punctuation.definition.arguments",
            "punctuation.definition.begin.bracket","punctuation.definition.end.bracket",
            "punctuation.definition.attribute","punctuation.definition.mapping.begin",
            "punctuation.definition.mapping.end")) { $tcExpected[$s] = $bracket }
        # Types -> green
        foreach ($s in @("entity.name.type","entity.name.class","entity.name.namespace","entity.name.module",
            "entity.name.scope-resolution","entity.other.attribute","entity.other.inherited-class",
            "support.type","support.type.builtin","support.type.primitive","support.type.exception",
            "support.class","support.class.builtin","support.constant.math","support.constant.dom",
            "support.constant.json","meta.type.cast.expr","meta.type.new.expr","keyword.type",
            "storage.type.cs","storage.type.generic.cs","storage.type.modifier.cs","storage.type.variable.cs",
            "storage.type.annotation.java","storage.type.generic.java","storage.type.java",
            "storage.type.object.array.java","storage.type.primitive.array.java","storage.type.primitive.java",
            "storage.type.token.java","storage.type.groovy","storage.type.annotation.groovy",
            "storage.type.parameters.groovy","storage.type.generic.groovy","storage.type.object.array.groovy",
            "storage.type.primitive.array.groovy","storage.type.primitive.groovy",
            "storage.type.numeric.go","storage.type.byte.go","storage.type.boolean.go",
            "storage.type.string.go","storage.type.uintptr.go","storage.type.error.go",
            "storage.type.rune.go")) { $tcExpected[$s] = $scheme.green }
        # Variables -> fg
        foreach ($s in @("variable","variable.other","variable.other.readwrite","variable.other.property",
            "variable.other.object","variable.parameter","variable.argument","punctuation.definition.variable",
            "entity.name.variable","support.variable","meta.definition.variable.name",
            "variable.legacy.builtin.python","variable.language.wildcard.java")) { $tcExpected[$s] = $fg }
        $tcExpected["variable.language"] = $scheme.red
        # PowerShell-specific
        foreach ($s in @("support.function.powershell","support.function.attribute.powershell",
            "variable.other.member.powershell")) { $tcExpected[$s] = $scheme.yellow }
        $tcExpected["support.variable.automatic.powershell"] = $scheme.red
        $tcExpected["support.variable.drive.powershell"] = $fg
        $tcExpected["support.constant.variable.powershell"] = $scheme.purple
        $tcExpected["variable.parameter.attribute.powershell"] = $orange
        foreach ($s in @("storage.modifier.scope.powershell","keyword.other.powershell")) { $tcExpected[$s] = $scheme.red }
        foreach ($s in @("keyword.other.array.begin.powershell","keyword.other.hashtable.begin.powershell")) { $tcExpected[$s] = $scheme.yellow }
        $tcExpected["keyword.operator.string-format.powershell"] = $orange
        foreach ($s in @("punctuation.section.embedded.substatement.begin.powershell",
            "punctuation.section.embedded.substatement.end.powershell")) { $tcExpected[$s] = $orange }
        foreach ($s in @("punctuation.section.braces.begin.powershell","punctuation.section.braces.end.powershell",
            "punctuation.section.bracket.begin.powershell","punctuation.section.bracket.end.powershell",
            "punctuation.section.group.begin.powershell","punctuation.section.group.end.powershell",
            "meta.attribute.powershell")) { $tcExpected[$s] = $bracket }
        # Tags
        foreach ($s in @("entity.name.tag","entity.name.tag.css","entity.name.tag.less",
            "entity.name.tag.yaml")) { $tcExpected[$s] = $scheme.yellow }
        foreach ($s in @("entity.other.attribute-name","entity.other.attribute-name.class.css",
            "entity.other.attribute-name.id.css","entity.other.attribute-name.parent-selector.css",
            "entity.other.attribute-name.parent.less","entity.other.attribute-name.pseudo-element.css",
            "entity.other.attribute-name.scss","source.css entity.other.attribute-name.class",
            "source.css entity.other.attribute-name.pseudo-class",
            "source.css.less entity.other.attribute-name.id")) { $tcExpected[$s] = $orange }
        $tcExpected["punctuation.definition.tag"] = $fgMuted
        # CSS
        foreach ($s in @("support.type.vendored.property-name","support.type.property-name")) { $tcExpected[$s] = $scheme.yellow }
        foreach ($s in @("support.constant.property-value","support.constant.font-name",
            "support.constant.media-type","support.constant.media","support.constant.color")) { $tcExpected[$s] = $scheme.brightGreen }
        $tcExpected["source.css variable"] = $fg
        $tcExpected["source.coffee.embedded"] = $fg
        # JSON/object keys
        foreach ($s in @("meta.object-literal.key","support.type.property-name.json",
            "meta.structure.dictionary.key.python")) { $tcExpected[$s] = $scheme.yellow }
        # Decorators
        foreach ($s in @("meta.decorator","entity.name.decorator","punctuation.decorator",
            "punctuation.definition.decorator","punctuation.definition.annotation",
            "meta.attribute")) { $tcExpected[$s] = $scheme.yellow }
        # Rust lifetimes
        foreach ($s in @("entity.name.type.lifetime","punctuation.definition.lifetime")) { $tcExpected[$s] = $orange }
        # Preprocessor
        $tcExpected["meta.preprocessor"] = $scheme.red
        # Resets
        foreach ($s in @("meta.embedded","source.groovy.embedded","meta.template.expression",
            "entity.name.label","storage.modifier.import.java","storage.modifier.package.java")) { $tcExpected[$s] = $fg }
        # Misc
        $tcExpected["meta.diff.header"] = $scheme.yellow
        foreach ($s in @("punctuation.definition.quote.begin.markdown","entity.other.document.begin",
            "entity.other.document.end")) { $tcExpected[$s] = $fgMuted }
        $tcExpected["header"] = $scheme.yellow
        $tcExpected["invalid"] = $scheme.red
        # Markup
        $tcExpected["markup.heading"] = $scheme.yellow
        foreach ($s in @("markup.bold","markup.italic")) { $tcExpected[$s] = $fg }
        $tcExpected["markup.inserted"] = $scheme.green
        $tcExpected["markup.deleted"] = $scheme.red
        $tcExpected["markup.changed"] = $scheme.yellow
        $tcExpected["markup.inline.raw"] = $scheme.brightGreen
        foreach ($s in @("markup.underline.link","markup.link")) { $tcExpected[$s] = $scheme.blue }
        $tcExpected["punctuation.definition.to-file.diff"] = $scheme.green
        $tcExpected["punctuation.definition.from-file.diff"] = $scheme.red
        $tcExpected["text"] = $fg

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
        $orange = $scheme.brightRed
        $semExpected = [ordered]@{
            "keyword" = $scheme.red
            "function" = $scheme.yellow
            "method" = $scheme.yellow
            "function.defaultLibrary" = $scheme.yellow
            "method.defaultLibrary" = $scheme.yellow
            "variable" = $fg
            "parameter" = $fg
            "property" = $fg
            "class" = $scheme.green
            "interface" = $scheme.green
            "struct" = $scheme.green
            "enum" = $scheme.green
            "type" = $scheme.green
            "typeAlias" = $scheme.green
            "class.defaultLibrary" = $scheme.green
            "interface.defaultLibrary" = $scheme.green
            "struct.defaultLibrary" = $scheme.green
            "enum.defaultLibrary" = $scheme.green
            "type.defaultLibrary" = $scheme.green
            "builtinType" = $scheme.green
            "typeParameter" = $scheme.green
            "string" = $scheme.brightGreen
            "number" = $scheme.purple
            "boolean" = $scheme.purple
            "enumMember" = $scheme.purple
            "const" = $scheme.purple
            "operator" = $orange
            "punctuation" = $bracket
            "comment" = $fgMuted
            "newOperator" = $scheme.red
            "stringLiteral" = $scheme.brightGreen
            "customLiteral" = $scheme.yellow
            "numberLiteral" = $scheme.purple
            "label" = $fg
            "namespace" = $fg
            "decorator" = $scheme.yellow
            "macro" = $scheme.yellow
        }
        foreach ($k in $semExpected.Keys) {
            $actual = $stc.rules.$k
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
    @{ Name = "Edge";    Policy = "HKCU:\SOFTWARE\Policies\Microsoft\Edge";  Exe = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") }
    @{ Name = "Vivaldi"; Policy = "HKCU:\SOFTWARE\Policies\Vivaldi";  Exe = @("$env:LOCALAPPDATA\Vivaldi\Application\vivaldi.exe") }
)

foreach ($b in $browsers) {
    $installed = $b.Exe | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($installed) {
        if (Test-Path $b.Policy) {
            $regColor = (Get-ItemProperty -Path $b.Policy -Name "BrowserThemeColor" -ErrorAction SilentlyContinue).BrowserThemeColor
            if ($regColor) {
                _Check "$($b.Name) BrowserThemeColor" $scheme.background $regColor
            } else {
                _Skip "$($b.Name)" "BrowserThemeColor not set"
            }
        } else {
            _Skip "$($b.Name)" "policy key not found"
        }
    }
}
if ($script:passCount -eq $prePass -and $script:failCount -eq $preFail) {
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

# Color prevalence (accent on taskbar)
$colorPrev = (Get-ItemProperty $personalizePath -Name "ColorPrevalence" -ErrorAction SilentlyContinue).ColorPrevalence
if ($null -ne $colorPrev) { _Check "ColorPrevalence" 1 $colorPrev }
$dwmPrev = (Get-ItemProperty $dwmPath -Name "ColorPrevalence" -ErrorAction SilentlyContinue).ColorPrevalence
if ($null -ne $dwmPrev) { _Check "DWM ColorPrevalence" 1 $dwmPrev }

# Accent color (ABGR format)
$expectedABGR = Convert-HexToABGR $scheme.background
$actualAccent = (Get-ItemProperty $dwmPath -Name "AccentColor" -ErrorAction SilentlyContinue).AccentColor
if ($null -ne $actualAccent) {
    # Compare as unsigned — registry stores as signed Int32
    $expectedU = [Convert]::ToUInt32($expectedABGR -band 0xFFFFFFFF)
    $actualU = [Convert]::ToUInt32([int64]$actualAccent -band 0xFFFFFFFF)
    if ($expectedU -eq $actualU) {
        $script:passCount++
    } else {
        $script:failCount++
        Write-Host "  $($c.red)MISMATCH$($c.reset) AccentColor"
        Write-Host "           expected: $($c.dim)0x$($expectedU.ToString('X8'))$($c.reset)  got: $($c.dim)0x$($actualU.ToString('X8'))$($c.reset)"
    }
}

$actualMenu = (Get-ItemProperty $accentPath -Name "AccentColorMenu" -ErrorAction SilentlyContinue).AccentColorMenu
if ($null -ne $actualMenu) {
    $expectedU = [Convert]::ToUInt32($expectedABGR -band 0xFFFFFFFF)
    $actualU = [Convert]::ToUInt32([int64]$actualMenu -band 0xFFFFFFFF)
    if ($expectedU -eq $actualU) {
        $script:passCount++
    } else {
        $script:failCount++
        Write-Host "  $($c.red)MISMATCH$($c.reset) AccentColorMenu"
        Write-Host "           expected: $($c.dim)0x$($expectedU.ToString('X8'))$($c.reset)  got: $($c.dim)0x$($actualU.ToString('X8'))$($c.reset)"
    }
}

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

$lutgenMap = $script:LutgenPalettes
$lutgenName = $lutgenMap[$themeName]

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
