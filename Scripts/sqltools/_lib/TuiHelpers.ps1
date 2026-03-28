# TUI helpers — alt screen, resize, status bar, fzf wrappers

$script:e = [char]27

function Enter-AltScreen { Write-Host "$script:e[?1049h" -NoNewline }
function Exit-AltScreen  { Write-Host "$script:e[?1049l" -NoNewline }

function Get-TermSize {
    $sz = $Host.UI.RawUI.WindowSize
    return @{ Width = $sz.Width; Height = $sz.Height }
}

function Clear-Screen { Write-Host "$script:e[2J$script:e[H" -NoNewline }

function Write-StatusBar {
    param([string]$Left, [string]$Right = "")
    $sz = Get-TermSize
    $w = $sz.Width
    $pad = $w - $Left.Length - $Right.Length
    if ($pad -lt 1) { $pad = 1 }
    $bg = "${script:e}[47m"
    Write-Host "$($script:c.bold)$($script:c.black)${bg} $Left$(' ' * $pad)$Right $($script:c.reset)" -NoNewline
    Write-Host ""
}

function Invoke-Fzf {
    param(
        [string[]]$Items,
        [string]$Header,
        [string]$Prompt = "> ",
        [switch]$Multi,
        [string]$Preview,
        [int]$HeightPercent = 50
    )
    $fzfArgs = @('--border', '--reverse', "--height=${HeightPercent}%", "--prompt=$Prompt")
    if ($Header) { $fzfArgs += '--header'; $fzfArgs += $Header }
    if ($Multi) { $fzfArgs += '--multi'; $fzfArgs += '--bind'; $fzfArgs += 'ctrl-a:select-all,ctrl-d:deselect-all' }
    if ($Preview) { $fzfArgs += '--preview'; $fzfArgs += $Preview }
    $fzfArgs += '--no-info'
    $Items | fzf @fzfArgs
}

function Read-SqlInput {
    Write-Host ""
    Write-Host "  $($script:c.dim)Enter SQL (end with ; on its own line, or single line):$($script:c.reset)"
    Write-Host ""
    $queryLines = @()
    while ($true) {
        $line = Read-Host "  sql"
        if ($line -eq ';' -or ($queryLines.Count -eq 0 -and $line -match ';\s*$')) {
            if ($queryLines.Count -eq 0) { $queryLines += ($line -replace ';\s*$', '') }
            break
        }
        $queryLines += $line
    }
    return ($queryLines -join "`n").Trim()
}

function Require-Fzf {
    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
        Write-Host "fzf is required for interactive mode. Run 'tools --install' to install it." -ForegroundColor Red
        exit 1
    }
}
