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

$bg = hex2rgb $f[1]; $os = hex2rgb $f[2]; $bl = hex2rgb $f[3]; $pk = hex2rgb $f[4]; $lv = hex2rgb $f[5]
$bgOn = "`e[48;2;${bg}m"; $off = "`e[0m"

# Use a wide fill + erase-to-end-of-line to cover the full preview pane
$eol = "`e[K"
$bgLine = "$bgOn$eol"

# Helper: print a line with bg filling to end of line
function wl([string]$content) {
    Write-Host "${bgOn}${content}${eol}${off}"
}

wl ""
wl "  `e[1;38;2;${os}m$($f[0])"
wl ""
wl "  `e[38;2;${os}m `e[38;2;${bl}m${User}@${Host_} `e[38;2;${pk}m~/Projects/my-app `e[38;2;${lv}m main `e[38;2;${os}m"
wl ""
wl "  `e[38;2;${bg}m████`e[38;2;${os}m  bg        $($f[1])"
wl "  `e[38;2;${os}m████`e[38;2;${os}m  os        $($f[2])   (prompt char)"
wl "  `e[38;2;${bl}m████`e[38;2;${os}m  blue      $($f[3])   (user@host)"
wl "  `e[38;2;${pk}m████`e[38;2;${os}m  pink      $($f[4])   (path)"
wl "  `e[38;2;${lv}m████`e[38;2;${os}m  lavender  $($f[5])   (git branch)"
wl ""
