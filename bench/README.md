# pbench

Measures shell startup and hotkey responsiveness on Windows. It is how the
numbers in the main README were produced.

Build (from any OS):

```sh
GOOS=windows GOARCH=amd64 go build -o pbench.exe .
```

Run it from an interactive desktop session (not over SSH: services and SSH
sessions have no visible desktop, so PSReadLine and hotkeys behave differently).

## Shell startup

```powershell
.\pbench.exe shell -runs 10 -think 800ms -cwd $HOME\Projects\some-repo -out shell.json
```

Starts `pwsh -NoLogo` inside a ConPTY (the pseudo console Windows Terminal
uses) and records, per launch:

- `prompt_ms`: process creation to the prompt marker (`-marker`, default the
  prompt's `` glyph) appearing in the output
- `first_key_echo_ms`: a keystroke sent right after the prompt until the
  console redraws
- `enter_prompt_ms`: `-command` (default `cd .`) plus Enter until the next
  prompt. `-think` pauses first, like a person reading the prompt.

`-cmd` changes the shell command line, for example
`-cmd '"C:\Program Files\PowerShell\7\pwsh.exe" -NoLogo -NoProfile' -marker 'repo>'`.

## Hotkey

```powershell
.\pbench.exe hotkey -runs 50 -type proj -high -out hotkey.json
```

Presses the hotkey (`-combo`, default `ctrl+alt+p`) with `SendInput`, then
polls until the window (`-class`, or `-title`) is visible and in the
foreground. It then types `-type` one character at a time and waits until the
window title shows the query (projpick publishes `projpick [query] count selected` in
its title for this), and finally presses Esc.

- `-high` runs the harness at high priority so CPU load measures the target,
  not the harness.
- `-focus TEXT` puts a window whose title contains TEXT in the foreground
  before each summon (run elevated to test elevated windows).
- `pbench burn -threads 8 -for 60s` in another process loads the CPU.

All timings use QueryPerformanceCounter.

## Typing

```powershell
.\pbench.exe type -focus KEYTEST -delay 60ms -text "echo hi{combo:ctrl+left}{wait:300}\r"
```

Types into the window whose title contains `-focus`, with `SendInput` like a
physical keyboard. In `-text`, `\r` is Enter, `\e` is Esc, `{wait:MS}` pauses,
`{focus}` brings the window forward again, and `{combo:KEYS}` presses a
combination such as `ctrl+shift+left`, `alt+bs`, `shift+ins` or `f9`. Key
names: `ctrl alt shift win`, `left right up down home end pgup pgdn`,
`ins del bs tab enter esc space`, `f1`–`f12`, `backtick period comma`, and
single letters or digits.

## Key handling

`keys\` checks that editing keys do the same thing in every terminal, such as
Windows Terminal and VS Code's terminal. Each case types some text, presses
keys, then presses <kbd>F9</kbd>, which records the line, cursor, selection and
clipboard. The test then compares those with the expected result.

1. Open the terminal under test, with the profile loaded, and give it a title
   you can find, for example `wt --title KEYTEST`. In it, run
   `. .\bench\keys\keyprobe.ps1` from the profile folder.
2. From another console, run:

   ```powershell
   .\bench\keys\keytest.ps1 -Title KEYTEST -Target wt      # Windows Terminal
   .\bench\keys\keytest.ps1 -Title "Visual Studio Code" -Target code
   ```

Don't touch the keyboard or mouse while it runs (about 3 minutes). It sets the
clipboard for the paste cases. `-Only "ctrl+x,paste ctrl+v"` runs some cases,
and `-Out results.json` saves the details. `cases.json` lists the cases, and
`only` marks the ones for one terminal: for example, Windows Terminal asks
before a multi-line paste and VS Code doesn't.
