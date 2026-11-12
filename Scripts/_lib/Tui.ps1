# Minimal terminal UI helpers in plain PowerShell (no fzf or modules), so they
# work on a fresh Windows 11 machine.
#
# Show-Checklist renders a scrolling checkbox list:
#   Up/Down (or j/k) move, Space toggles, a = all, n = none,
#   Enter confirms, Esc cancels (returns $null).

function Show-Checklist {
    param(
        [Parameter(Mandatory)][string]$Title,
        [string]$Hint = 'Up/Down move   Space toggle   a all   n none   Enter continue   Esc skip',
        # Each item: @{ Key; Label; Detail; Checked = $bool; Header = $bool; Disabled = $bool }
        [Parameter(Mandatory)][System.Collections.IList]$Items
    )

    $e = [char]27
    $selectable = @(for ($i = 0; $i -lt $Items.Count; $i++) { if (-not $Items[$i].Header -and -not $Items[$i].Disabled) { $i } })
    if ($selectable.Count -eq 0) { return @() }
    $cursor = 0
    $labelWidth = [Math]::Min(28, (($Items | ForEach-Object { "$($_.Label)".Length } | Measure-Object -Maximum).Maximum + 2))

    $render = {
        $width = [Math]::Max(40, [Console]::WindowWidth - 1)
        $height = [Math]::Max(8, [Console]::WindowHeight - 6)
        $rows = [Math]::Min($Items.Count, $height)
        $focus = $selectable[$cursor]
        $top = [Math]::Max(0, [Math]::Min($focus - [int]($rows / 2), $Items.Count - $rows))
        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.Append("$e[1m $Title$e[0m$e[K`n")
        [void]$sb.Append("$e[90m $Hint$e[0m$e[K`n")
        for ($r = 0; $r -lt $rows; $r++) {
            $i = $top + $r
            $it = $Items[$i]
            if ($it.Header) {
                [void]$sb.Append("$e[36m $($it.Label)$e[0m$e[K`n")
                continue
            }
            $pointer = if ($i -eq $focus) { "$e[36m>$e[0m" } else { ' ' }
            $box = if ($it.Disabled) { "$e[90m[-]" } elseif ($it.Checked) { "$e[32m[x]" } else { "$e[0m[ ]" }
            $label = "$($it.Label)".PadRight($labelWidth)
            $detail = "$($it.Detail)"
            $max = $width - $labelWidth - 9
            if ($detail.Length -gt $max) { $detail = $detail.Substring(0, [Math]::Max(0, $max - 1)) + '…' }
            $style = if ($it.Disabled) { "$e[90m" } elseif ($i -eq $focus) { "$e[1m" } else { '' }
            [void]$sb.Append(" $pointer $box$e[0m $style$label$e[0m$e[90m$detail$e[0m$e[K`n")
        }
        $count = @($Items | Where-Object { $_.Checked -and -not $_.Header -and -not $_.Disabled }).Count
        [void]$sb.Append("$e[90m $count selected$(if ($Items.Count -gt $rows) { "   ($($top + 1)-$($top + $rows) of $($Items.Count))" })$e[0m$e[K")
        $script:_tuiLines = $rows + 3
        [Console]::Write($sb.ToString())
    }

    $oldCursor = $true
    try { $oldCursor = [Console]::CursorVisible } catch {}
    try {
        [Console]::CursorVisible = $false
        & $render
        while ($true) {
            $k = [Console]::ReadKey($true)
            $item = $Items[$selectable[$cursor]]
            $done = $false
            switch ($k.Key) {
                'UpArrow' { if ($cursor -gt 0) { $cursor-- } }
                'DownArrow' { if ($cursor -lt $selectable.Count - 1) { $cursor++ } }
                'K' { if ($cursor -gt 0) { $cursor-- } }
                'J' { if ($cursor -lt $selectable.Count - 1) { $cursor++ } }
                'Home' { $cursor = 0 }
                'End' { $cursor = $selectable.Count - 1 }
                'Spacebar' { $item.Checked = -not $item.Checked }
                'A' { foreach ($i in $selectable) { $Items[$i].Checked = $true } }
                'N' { foreach ($i in $selectable) { $Items[$i].Checked = $false } }
                'Enter' { $done = $true }
                'Escape' {
                    [Console]::Write("`r$e[$($script:_tuiLines - 1)A$e[0J")
                    return $null
                }
            }
            if ($done) { break }
            # move back to the top of the block and redraw in place
            [Console]::Write("`r$e[$($script:_tuiLines - 1)A")
            & $render
        }
        # Collapse the list into a one-line summary of the choice.
        $chosen = @($Items | Where-Object { $_.Checked -and -not $_.Header -and -not $_.Disabled })
        [Console]::Write("`r$e[$($script:_tuiLines - 1)A$e[0J")
        $names = if ($chosen.Count) { ($chosen | ForEach-Object { $_.Label }) -join ', ' } else { 'nothing' }
        [Console]::WriteLine("$e[1m $Title$e[0m$e[90m: $names$e[0m")
        return @($chosen | ForEach-Object { $_.Key })
    } finally {
        try { [Console]::CursorVisible = $oldCursor } catch {}
    }
}

# A one-line status helper used by setup steps:  "  ok    Rebuilt profile cache"
function Write-Step {
    param([ValidateSet('ok', 'skip', 'fail', 'run', 'info')][string]$State, [string]$Text)
    $e = [char]27
    $tag = switch ($State) {
        'ok' { "$e[32m  ok  $e[0m" }
        'skip' { "$e[90m  --  $e[0m" }
        'fail' { "$e[31m fail $e[0m" }
        'run' { "$e[36m  ..  $e[0m" }
        'info' { "$e[90m      $e[0m" }
    }
    [Console]::WriteLine("$tag $Text")
}
