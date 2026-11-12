# Load into the shell under test:  . .\bench\keys\keyprobe.ps1
# F9 records PSReadLine's line, cursor, selection and the clipboard to the
# probe log, then clears the line for the next case.
$global:_ktLog = if ($env:KEYTEST_LOG) { $env:KEYTEST_LOG } else { [IO.Path]::Combine([IO.Path]::GetTempPath(), 'keytest-probe.log') }
[IO.File]::WriteAllText($global:_ktLog, '')
[Microsoft.PowerShell.PSConsoleReadLine]::AddToHistory('echo kt-history-marker')
Set-PSReadLineKeyHandler -Key F9 -ScriptBlock {
    $line = $null; $cur = $null; $ss = $null; $sl = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cur)
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$ss, [ref]$sl)
    $clip = try { Get-Clipboard -Raw } catch { '<error>' }
    $o = [ordered]@{ line = $line; cursor = $cur; selStart = $ss; selLen = $sl; clip = $clip }
    [IO.File]::AppendAllText($global:_ktLog, ($o | ConvertTo-Json -Compress) + "`n")
    # RevertLine alone sometimes leaves text behind; clear whatever is left
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    $line = $null; [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cur)
    if ($line.Length) { [Microsoft.PowerShell.PSConsoleReadLine]::Delete(0, $line.Length) }
}
$info = [ordered]@{ ready = $true; ps = $PSVersionTable.PSVersion.ToString(); psreadline = (Get-Module PSReadLine).Version.ToString()
    term = "$env:TERM_PROGRAM $env:TERM_PROGRAM_VERSION".Trim(); wt = [bool]$env:WT_SESSION }
[IO.File]::AppendAllText($global:_ktLog, ($info | ConvertTo-Json -Compress) + "`n")
Clear-Host
