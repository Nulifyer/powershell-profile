param([string]$Query, [string]$DataFile, [string]$User, [string]$Host_)

$Query = $Query.Trim()
$d = Get-Content $DataFile | Where-Object { $_ -match "^$([regex]::Escape($Query))\|" } | Select-Object -First 1
if (-not $d) { Write-Host "No preview"; exit }
$f = $d.Split('|')

function hex2rgb([string]$h) {
    $rv = [Convert]::ToInt32($h.Substring(1,2),16)
    $gv = [Convert]::ToInt32($h.Substring(3,2),16)
    $bv = [Convert]::ToInt32($h.Substring(5,2),16)
    return "$rv;$gv;$bv"
}

$bg = hex2rgb $f[1]; $mu = hex2rgb $f[2]; $uh = hex2rgb $f[3]; $pa = hex2rgb $f[4]; $gi = hex2rgb $f[5]
$bgOn = "`e[48;2;${bg}m"; $off = "`e[0m"

$eol = "`e[K"

function wl([string]$content) {
    Write-Host "${bgOn}${content}${eol}${off}"
}

wl ""
wl "  `e[1;38;2;${mu}m$($f[0])"
wl ""
wl "  `e[38;2;${mu}m `e[38;2;${uh}m${User}@${Host_} `e[38;2;${pa}m~/Projects/my-app `e[38;2;${gi}m main `e[38;2;${mu}m"
wl ""

# Palette colors (prompt accent colors)
$palBlocks = ""
foreach ($i in 1..5) {
    $rgb = hex2rgb $f[$i]
    $palBlocks += "`e[48;2;${rgb}m  `e[0m${bgOn}"
}
wl "  `e[38;2;${mu}mpalette  ${palBlocks}"

# ANSI 16 colors (if present)
if ($f.Count -ge 22) {
    $normalBlocks = ""
    for ($i = 6; $i -le 13; $i++) {
        $rgb = hex2rgb $f[$i]
        $normalBlocks += "`e[48;2;${rgb}m  `e[0m${bgOn}"
    }
    $brightBlocks = ""
    for ($i = 14; $i -le 21; $i++) {
        $rgb = hex2rgb $f[$i]
        $brightBlocks += "`e[48;2;${rgb}m  `e[0m${bgOn}"
    }
    wl "  `e[38;2;${mu}mansi     ${normalBlocks}"
    wl "  `e[38;2;${mu}m         ${brightBlocks}"
}
wl ""
