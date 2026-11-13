<div align="center">

# powershell-profile

**A fast, good-looking PowerShell 7 profile for Windows, with every project one keystroke away.**

![PowerShell](https://img.shields.io/badge/PowerShell-7.2%2B-5391FE?style=flat&logo=powershell&logoColor=white)
![Windows 10 | 11](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D4)
![Zig](https://img.shields.io/badge/Zig-0.17-F7A41D?style=flat&logo=zig&logoColor=white)

</div>

![The same prompt in Gruvbox Dark, Catppuccin Mocha and Tokyo Night: git branch, eza listing and history predictions](docs/images/themes.png)

Turn a stock Windows terminal into a quick, keyboard-driven shell that works
the way bash and fish do. It opens in about 0.6 seconds, even with real-time
antivirus scanning on. Press <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>P</kbd> in any
app to jump into any project on your machine. Clone it once, and `git pull`
keeps it up to date.

## Features

| | Feature | What you get |
| :-: | --- | --- |
| ⚡ | Fast startup | A ready prompt in ~600 ms with Defender on, and under a second after a reboot. |
| 🗂️ | Project picker | <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>P</kbd> from any app lists every project on your machine; open one in your editor, a terminal or Explorer. |
| 🧭 | `z` jumps | `z api` jumps to a project by name with Tab completion; `zi` picks one with fzf. |
| 🎨 | One theme everywhere | `theme` recolors your terminals, VS Code, browsers, the Windows accent, the prompt and the picker at once, from 40 palettes. |
| 🔤 | Nerd Fonts | `font` switches the terminal font everywhere; `font --install` adds new ones. |
| 🐧 | Unix feel | Emacs keys, `grep`/`sed`/`awk`/`less`/`ssh`, `touch`, `mkcd`, `watch`, `time` and `sudo`. |
| 🔍 | Fuzzy everything | <kbd>Ctrl</kbd>+<kbd>R</kbd> history, <kbd>Ctrl</kbd>+<kbd>T</kbd> files, predictions as you type and a zsh-style Tab menu. |
| 🧰 | Guided setup | A checklist offers fzf, eza, bat, fd, ripgrep and more, and cleans up after older versions. |
| 🛡️ | Works on locked-down PCs | No keyboard hooks for endpoint protection to flag, and winget tools work where policy blocks winget's links. |
| 🔄 | Quiet updates | Checks for profile and PowerShell updates weekly in the background, never at startup. |

![The project picker](docs/images/project-picker.png)

## Install

You need Windows 10 or 11, [PowerShell 7.2+](https://github.com/PowerShell/PowerShell)
and [Git](https://git-scm.com/). Clone the profile into your PowerShell folder:

```powershell
git clone https://github.com/Nulifyer/powershell-profile.git "$HOME\Documents\PowerShell"
```

Open a new terminal. Setup runs once before the first prompt: tick the tools
you want and it does the rest, including building the project picker and
setting up its shortcut in [PowerToys](https://learn.microsoft.com/windows/powertoys/).
See [Getting started](docs/getting-started.md) for a walkthrough.

![The setup checklist](docs/images/setup.png)

To update, run `pu` (or `git pull` in the profile folder). The next terminal
asks only about what's new.

## Try it

```powershell
z api            # jump to the project named api (Tab completes names)
zi               # pick a project with fzf
theme gruvbox    # recolor terminals, editor, Windows and the prompt
font             # pick the terminal font
tools            # see which optional tools are installed
```

Press <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>P</kbd>, type a few letters of a
project, and press <kbd>Enter</kbd> to open it in your editor.
<kbd>Ctrl</kbd>+<kbd>E</kbd> opens a terminal there instead.

## Guides

- [Getting started](docs/getting-started.md): install, first-run setup, updating and uninstalling.
- [Commands](docs/commands.md): every command, alias and function.
- [Keybindings](docs/keybindings.md): shell and picker keys.
- [Project picker](docs/project-picker.md): <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>P</kbd>, `z`, `zi`, `zopen` and how the shortcut works.
- [Setup and tools](docs/setup.md): what `profile-setup` does, optional tools and winget on locked-down machines.
- [Themes and fonts](docs/themes.md): `theme`, `font` and `wallpaper`.
- [Performance](docs/performance.md): the numbers and how they were measured.
- [Troubleshooting](docs/troubleshooting.md): common problems, settings and where files live.

Want to change something? See [Working on the profile](docs/contributing.md).
