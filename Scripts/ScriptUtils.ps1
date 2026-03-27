# Shared utilities for scripts — dot-source this at the top of any script.
# Usage: . "$PSScriptRoot\..\ScriptUtils.ps1"  (or adjust path as needed)

<#
.SYNOPSIS
    Parse unix-style arguments (-f, --flag, --key=value, --key value, positional args).

.PARAMETER RawArgs
    The raw $args array from the calling script.

.PARAMETER FlagDefs
    Hashtable defining flags. Keys are flag names, values are hashtables with:
      - Aliases: string[] of short/long names (e.g. @('r', 'raw'))
      - Type: 'switch' (default) or 'value'
      - Default: default value (switches default to $false, values to $null)

.OUTPUTS
    Hashtable with parsed flag values + a '_positional' key containing positional args.

.EXAMPLE
    $parsed = Parse-Args $args @{
        Raw     = @{ Aliases = @('r', 'raw') }
        NoColor = @{ Aliases = @('nc', 'no-color') }
        Distro  = @{ Aliases = @('d', 'distro'); Type = 'value'; Default = 'alpine' }
    }
    $parsed.Raw        # $true / $false
    $parsed.Distro     # 'alpine' or whatever was passed
    $parsed._positional # @('arg1', 'arg2', ...)
    $parsed._help      # $true if -h or --help was passed
#>
function Parse-Args {
    param(
        [object[]]$RawArgs,
        [hashtable]$FlagDefs = @{}
    )

    # Build lookup: alias -> flag name
    $aliasMap = @{}
    $result = @{ _positional = @(); _help = $false }

    # Always include help
    $aliasMap['h'] = '_help'
    $aliasMap['help'] = '_help'
    $result['_help'] = $false

    foreach ($name in $FlagDefs.Keys) {
        $def = $FlagDefs[$name]
        $type = if ($def.Type) { $def.Type } else { 'switch' }
        $default = if ($def.ContainsKey('Default')) { $def.Default } elseif ($type -eq 'switch') { $false } else { $null }
        $result[$name] = $default

        foreach ($alias in $def.Aliases) {
            $aliasMap[$alias] = $name
        }
    }

    for ($i = 0; $i -lt $RawArgs.Count; $i++) {
        $arg = $RawArgs[$i]
        if ($arg -eq '--') {
            # Everything after -- is positional
            for ($j = $i + 1; $j -lt $RawArgs.Count; $j++) {
                $result._positional += $RawArgs[$j]
            }
            break
        }
        elseif ($arg -match '^--?(?<flag>[^=]+)(=(?<val>.*))?$') {
            $flag = $Matches.flag
            $inlineVal = $Matches.val

            if (-not $aliasMap.ContainsKey($flag)) {
                Write-Error "Unknown option: $arg"
                exit 1
            }

            $name = $aliasMap[$flag]
            $def = $FlagDefs[$name]
            $type = if ($def.Type) { $def.Type } else { 'switch' }

            if ($name -eq '_help') {
                $result._help = $true
            }
            elseif ($type -eq 'switch') {
                $result[$name] = $true
            }
            else {
                if ($null -ne $inlineVal) {
                    $result[$name] = $inlineVal
                }
                elseif ($i + 1 -lt $RawArgs.Count) {
                    $result[$name] = $RawArgs[++$i]
                }
                else {
                    Write-Error "Option --$flag requires a value"
                    exit 1
                }
            }
        }
        else {
            $result._positional += $arg
        }
    }

    return $result
}

<#
.SYNOPSIS
    Get ANSI color variables. Returns a hashtable of escape sequences.

.PARAMETER Disabled
    If true, returns empty strings (for -NoColor / piping).

.EXAMPLE
    $c = Get-Colors
    Write-Host "$($c.bold)$($c.cyan)Hello$($c.reset)"
#>
function Get-Colors {
    param([switch]$Disabled)

    if ($Disabled) {
        return @{
            reset = ''; bold = ''; dim = ''; italic = ''; underline = ''
            black = ''; red = ''; green = ''; yellow = ''
            blue = ''; magenta = ''; cyan = ''; white = ''
            brBlack = ''; brRed = ''; brGreen = ''; brYellow = ''
            brBlue = ''; brMagenta = ''; brCyan = ''; brWhite = ''
        }
    }

    # Uses terminal palette colors (0-15) — automatically matches your theme
    $e = [char]27
    return @{
        reset     = "$e[0m"
        bold      = "$e[1m"
        dim       = "$e[2m"
        italic    = "$e[3m"
        underline = "$e[4m"
        # Normal (from terminal colors 0-7)
        black     = "$e[30m"
        red       = "$e[31m"
        green     = "$e[32m"
        yellow    = "$e[33m"
        blue      = "$e[34m"
        magenta   = "$e[35m"
        cyan      = "$e[36m"
        white     = "$e[37m"
        # Bright (from terminal colors 8-15)
        brBlack   = "$e[90m"
        brRed     = "$e[91m"
        brGreen   = "$e[92m"
        brYellow  = "$e[93m"
        brBlue    = "$e[94m"
        brMagenta = "$e[95m"
        brCyan    = "$e[96m"
        brWhite   = "$e[97m"
    }
}

<#
.SYNOPSIS
    Display formatted help text for a script.

.PARAMETER Name
    Script name (auto-detected if not provided).

.PARAMETER Usage
    Usage string (e.g. "<Path> [Filter] [-r|--raw]")

.PARAMETER Description
    One-line description.

.PARAMETER Arguments
    Ordered hashtable of argument names to descriptions.

.PARAMETER Options
    Ordered hashtable of option strings to descriptions.

.PARAMETER Examples
    String array of example commands.

.EXAMPLE
    Show-ScriptHelp -Usage "<Username> [-g] [-r]" -Description "Get AD user info." `
        -Arguments ([ordered]@{ Username = "The user's samAccountName" }) `
        -Options ([ordered]@{ "-g, --groups" = "Show group memberships"; "-r, --raw" = "CSV output" }) `
        -Examples @("adui jdoe", "adui jdoe -g")
#>
function Show-ScriptHelp {
    param(
        [string]$Name,
        [string]$Usage,
        [string]$Description,
        [System.Collections.Specialized.OrderedDictionary]$Arguments,
        [System.Collections.Specialized.OrderedDictionary]$Options,
        [string[]]$Examples
    )

    if (-not $Name) {
        $Name = [System.IO.Path]::GetFileNameWithoutExtension(
            (Get-PSCallStack)[1].Command
        )
    }

    Write-Host "Usage: $Name $Usage" -ForegroundColor Cyan
    Write-Host ""
    if ($Description) { Write-Host $Description; Write-Host "" }

    if ($Arguments -and $Arguments.Count -gt 0) {
        Write-Host "Arguments:"
        $maxLen = ($Arguments.Keys | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
        $maxLen = [Math]::Max($maxLen, 8)
        foreach ($key in $Arguments.Keys) {
            Write-Host "  $($key.PadRight($maxLen + 2))$($Arguments[$key])"
        }
        Write-Host ""
    }

    if ($Options -and $Options.Count -gt 0) {
        Write-Host "Options:"
        $maxLen = ($Options.Keys | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
        $maxLen = [Math]::Max($maxLen, 8)
        foreach ($key in $Options.Keys) {
            Write-Host "  $($key.PadRight($maxLen + 2))$($Options[$key])"
        }
        Write-Host ""
    }

    if ($Examples -and $Examples.Count -gt 0) {
        Write-Host "Examples:"
        foreach ($ex in $Examples) {
            Write-Host "  $ex"
        }
        Write-Host ""
    }
}
