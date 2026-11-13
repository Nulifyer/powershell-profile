# Keybindings

## In the shell

The prompt uses emacs-style editing (as in bash and zsh), plus the Windows selection and clipboard keys. The keys work the same in Windows Terminal and in VS Code's terminal (after [setup](setup.md#vs-code-terminal-keys)).

### Search and completion

| Key | Action |
|-----|--------|
| <kbd>Ctrl</kbd>+<kbd>R</kbd> | Fuzzy-search your history, newest first, without duplicates *(fzf)* |
| <kbd>Ctrl</kbd>+<kbd>T</kbd> | Fuzzy-pick a file below the current folder and insert its path *(fzf; uses fd when installed)* |
| <kbd>Tab</kbd> | Completion menu; arrow keys move, <kbd>Enter</kbd> picks |
| <kbd>↑</kbd> / <kbd>↓</kbd> | Previous / next command, or move through the suggestion list |
| <kbd>Alt</kbd>+<kbd>.</kbd> | Insert the last argument of the previous command |

While you type, matching commands from your history appear in a list under the prompt. Use <kbd>↑</kbd>/<kbd>↓</kbd> to choose one.

### Moving

| Key | Action |
|-----|--------|
| <kbd>Home</kbd> / <kbd>End</kbd>, <kbd>Ctrl</kbd>+<kbd>A</kbd> / <kbd>Ctrl</kbd>+<kbd>E</kbd> | Start / end of line |
| <kbd>←</kbd> / <kbd>→</kbd> | One character |
| <kbd>Ctrl</kbd>+<kbd>←</kbd> / <kbd>Ctrl</kbd>+<kbd>→</kbd>, <kbd>Alt</kbd>+<kbd>B</kbd> / <kbd>Alt</kbd>+<kbd>F</kbd> | Start of the previous word / end of the next word |

### Editing

| Key | Action |
|-----|--------|
| <kbd>Ctrl</kbd>+<kbd>W</kbd>, <kbd>Ctrl</kbd>+<kbd>Backspace</kbd>, <kbd>Alt</kbd>+<kbd>Backspace</kbd> | Delete the word before the cursor |
| <kbd>Ctrl</kbd>+<kbd>Delete</kbd>, <kbd>Alt</kbd>+<kbd>D</kbd> | Delete to the end of the word |
| <kbd>Ctrl</kbd>+<kbd>U</kbd> | Delete everything before the cursor |
| <kbd>Ctrl</kbd>+<kbd>K</kbd> | Delete everything after the cursor |
| <kbd>Ctrl</kbd>+<kbd>Y</kbd> | Put back the text deleted last |
| <kbd>Ctrl</kbd>+<kbd>Z</kbd> | Undo |

### Selection and clipboard

| Key | Action |
|-----|--------|
| <kbd>Shift</kbd>+<kbd>←</kbd>/<kbd>→</kbd>, <kbd>Shift</kbd>+<kbd>Home</kbd>/<kbd>End</kbd> | Select characters / to the start or end of the line |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>←</kbd>/<kbd>→</kbd> | Select a word |
| <kbd>Ctrl</kbd>+<kbd>C</kbd>, <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>C</kbd>, <kbd>Ctrl</kbd>+<kbd>Insert</kbd> | Copy the selection. With nothing selected, <kbd>Ctrl</kbd>+<kbd>C</kbd> cancels the line |
| <kbd>Ctrl</kbd>+<kbd>X</kbd>, <kbd>Shift</kbd>+<kbd>Delete</kbd> | Cut the selection |
| <kbd>Ctrl</kbd>+<kbd>V</kbd>, <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>V</kbd>, <kbd>Shift</kbd>+<kbd>Insert</kbd> | Paste. A multi-line paste stays in the prompt until you press <kbd>Enter</kbd> |

Typing or pasting over a selection replaces it. Text selected with the mouse is the terminal's own selection: copy it with <kbd>Ctrl</kbd>+<kbd>C</kbd> or <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>C</kbd>.

Windows Terminal asks before pasting more than one line. Choosing *Paste anyway* is safe here: the lines stay in the prompt for you to check and run.

### Other

| Key | Action |
|-----|--------|
| <kbd>Enter</kbd> | Run the line. The prompt above it collapses to `❯` to keep scrollback tidy |
| <kbd>Ctrl</kbd>+<kbd>L</kbd> | Clear the screen |
| <kbd>Ctrl</kbd>+<kbd>D</kbd> | Delete the character under the cursor, or exit on an empty line |

## Project picker

<kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>P</kbd> from any app shows the picker; press it again, or <kbd>Esc</kbd>, to hide it. Clicking anywhere else also hides it.

| Key | Action |
|-----|--------|
| type | Filter (fuzzy, by name first, then by path) |
| <kbd>↑</kbd>/<kbd>↓</kbd>, <kbd>Ctrl</kbd>+<kbd>P</kbd>/<kbd>Ctrl</kbd>+<kbd>N</kbd>, <kbd>Ctrl</kbd>+<kbd>K</kbd>/<kbd>Ctrl</kbd>+<kbd>J</kbd> | Move the selection |
| <kbd>Tab</kbd> / <kbd>Shift</kbd>+<kbd>Tab</kbd> | Move the selection down / up |
| <kbd>PgUp</kbd> / <kbd>PgDn</kbd>, <kbd>Home</kbd> / <kbd>End</kbd> | Jump a page / to the first or last match |
| <kbd>Enter</kbd>, double-click | Open in your editor |
| <kbd>Ctrl</kbd>+<kbd>E</kbd>, <kbd>Ctrl</kbd>+<kbd>Enter</kbd> | Open a terminal in the project |
| <kbd>Ctrl</kbd>+<kbd>O</kbd> | Open the folder in your file manager |
| <kbd>Ctrl</kbd>+<kbd>Y</kbd>, <kbd>Ctrl</kbd>+<kbd>C</kbd> | Copy the project path |
| <kbd>Backspace</kbd> | Delete a character |
| <kbd>Ctrl</kbd>+<kbd>W</kbd>, <kbd>Ctrl</kbd>+<kbd>Backspace</kbd> | Delete a word |
| <kbd>Ctrl</kbd>+<kbd>U</kbd> | Clear the search |
| <kbd>Ctrl</kbd>+<kbd>V</kbd> | Paste into the search |
| <kbd>Ctrl</kbd>+<kbd>R</kbd> | Rescan for projects now |
| <kbd>Esc</kbd> | Close |
| mouse wheel | Scroll |

To use a different shortcut, see [How the shortcut works](project-picker.md#how-the-shortcut-works).
