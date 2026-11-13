param([string]$FontName)
$FontName = $FontName.Trim().TrimStart('*').Trim()

# Determine font variant info
$variant = "Standard"
$description = "Full Nerd Font with ligatures and icons"
if ($FontName -match 'Mono$' -or $FontName -match 'NFM$') {
    $variant = "Mono"
    $description = "Monospaced glyphs only — icons won't overlap adjacent characters"
} elseif ($FontName -match 'Propo$' -or $FontName -match 'NFP$') {
    $variant = "Proportional"
    $description = "Proportional width icons — may cause alignment issues in TUI apps"
}

$hasLigatures = $FontName -match 'Code|Cove' -and $FontName -notmatch 'Mono'

Write-Host ""
Write-Host "  $FontName" -ForegroundColor Cyan
Write-Host "  $([string][char]0x2500 * 40)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Variant:    $variant" -ForegroundColor White
Write-Host "  Ligatures:  $(if ($hasLigatures) { 'Yes' } else { 'No' })" -ForegroundColor White
Write-Host ""
Write-Host "  $description" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Variants:" -ForegroundColor White
Write-Host "    NF / Nerd Font       Standard (recommended)" -ForegroundColor DarkGray
Write-Host "    NFM / Mono           Fixed-width icons" -ForegroundColor DarkGray
Write-Host "    NFP / Propo          Variable-width icons" -ForegroundColor DarkGray
