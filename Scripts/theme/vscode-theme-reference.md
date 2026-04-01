# VSCode Theme Reference — Nulifyer Color System

Quick reference for maintaining the VSCode theme in `TerminalConfig.ps1 → Update-VSCodeTheme()`.

---

## Color Palette (from terminal scheme)

Every theme provides a 16-color ANSI palette + cursor/selection. The theme engine derives
all VSCode colors from these sources:

| Variable     | Source              | Semantic Role                                    |
|--------------|---------------------|--------------------------------------------------|
| `$bgBase`    | `scheme.background` | Editor background                                |
| `$bgMid`     | bgBase ± 15         | Sidebar, panel, activity bar                     |
| `$bgDarkest` | bgBase ± 30         | Status bar, title bar, menus                     |
| `$bgSurface` | bgBase ± 8          | Hover widgets, suggestions, popups               |
| `$bgHover`   | fg + 15% alpha      | List/tree hover highlight                        |
| `$bgBorder`  | bgBase ± 12         | Borders, dividers, subtle separators             |
| `$fg`        | `scheme.foreground` | Editor text, bright foreground                   |
| `$fgDim`     | `scheme.white`      | UI text (sidebar, status bar, tabs, menus)       |
| `$fgMuted`   | `scheme.brightBlack` | Comments, line numbers, inactive elements        |
| `$cursor`    | `scheme.cursorColor` | Cursor                                           |
| `$accent`    | per-theme vscode role | Icons, badges, progress, buttons                |
| `$link`      | per-theme vscode role | Links, peek view title                          |
| `$match`     | per-theme vscode role | Search match highlight                          |
| `$find`      | per-theme vscode role | Find match highlight                            |
| `$bracket`   | per-theme vscode role | Bracket highlighting, punctuation               |
| `$orange`    | `scheme.brightRed`   | Operators, escapes, format placeholders          |

### ANSI → Syntax Color Map

| ANSI Color          | Token Role             |
|---------------------|------------------------|
| `scheme.red`        | Keywords, storage, control flow, `self`/`this` |
| `scheme.green`      | Types, classes, interfaces, structs             |
| `scheme.yellow`     | Functions, methods, tags, decorators            |
| `scheme.blue`       | Links, markup underline                         |
| `scheme.purple`     | Constants, numbers, booleans, enums             |
| `scheme.cyan`       | Regex patterns                                  |
| `scheme.brightRed`  | Operators, accessors (used as `$orange`)        |
| `scheme.brightGreen`| Strings, string interpolation                   |

---

## Workbench Color Keys

### Coverage Status

Our theme sets ~220 workbench color keys. A well-made theme like Catppuccin sets ~350+.
Below are all categories with what we set (✓) and what's missing (✗).

### Essential Keys (must set)

#### Editor Core ✓
```
editor.background                    editor.foreground
editorCursor.foreground              editor.selectionBackground
editor.selectionHighlightBackground  editor.inactiveSelectionBackground
editor.wordHighlightBackground       editor.wordHighlightStrongBackground
editor.findMatchBackground           editor.findMatchHighlightBackground
editor.findRangeHighlightBackground  editor.lineHighlightBackground
editor.lineHighlightBorder           editor.rangeHighlightBackground
editor.foldBackground                editorWhitespace.foreground
editorLineNumber.foreground          editorLineNumber.activeForeground
editorLink.activeForeground          editorOverviewRuler.border
editorCodeLens.foreground            editorGhostText.foreground
editorInlayHint.foreground           editorInlayHint.background
```

#### Editor Errors/Warnings ✓
```
editorError.foreground    editorError.background
editorWarning.foreground  editorWarning.background
editorInfo.foreground     editorInfo.background
editorHint.foreground
```

#### Editor Gutter ✓
```
editorGutter.background              editorGutter.addedBackground
editorGutter.modifiedBackground      editorGutter.deletedBackground
editorGutter.commentRangeForeground
```

#### Editor Brackets ✓
```
editorBracketHighlight.foreground1-6
editorBracketMatch.background        editorBracketMatch.border
```

#### Editor Widgets ✓
```
editorWidget.background/foreground/border
editorSuggestWidget.background/border/foreground/highlightForeground/selectedBackground
editorHoverWidget.background/border
```

#### Tabs ✓
```
tab.activeBackground/activeForeground/activeBorder
tab.inactiveBackground/inactiveForeground
tab.border  tab.hoverBackground/hoverForeground
tab.lastPinnedBorder  tab.unfocused*
```

#### Sidebar ✓
```
sideBar.background/foreground
sideBarTitle.foreground
sideBarSectionHeader.background/foreground
```

#### Activity Bar ✓
```
activityBar.background/foreground/inactiveForeground
activityBar.border/activeBorder
activityBarBadge.background/foreground
```

#### Panel ✓
```
panel.background/border
panelTitle.activeForeground/activeBorder/inactiveForeground
panelInput.border  panelSection.border
panelSectionHeader.background/foreground/border
panelStickyScroll.background/border
```

#### Status Bar ✓
```
statusBar.background/foreground/border
statusBar.debuggingBackground/debuggingForeground
statusBar.noFolderBackground/noFolderForeground/noFolderBorder
statusBarItem.hoverBackground/activeBackground
statusBarItem.errorBackground/errorForeground
statusBarItem.warningBackground/warningForeground
statusBarItem.remoteBackground/remoteForeground
```

#### Title Bar ✓
```
titleBar.activeBackground/activeForeground
titleBar.inactiveBackground/inactiveForeground
titleBar.border
```

#### Terminal ✓
```
terminal.background/foreground/border
terminal.ansi{Black,Red,Green,Yellow,Blue,Magenta,Cyan,White}
terminal.ansiBright{Black,Red,Green,Yellow,Blue,Magenta,Cyan,White}
terminal.tab.activeBorder
terminalCursor.foreground
terminalCommandDecoration.{default,success,error}Background
```

#### Git Decorations ✓
```
gitDecoration.addedResourceForeground     gitDecoration.modifiedResourceForeground
gitDecoration.deletedResourceForeground   gitDecoration.untrackedResourceForeground
gitDecoration.ignoredResourceForeground   gitDecoration.conflictingResourceForeground
gitDecoration.stageModifiedResourceForeground  gitDecoration.stageDeletedResourceForeground
gitDecoration.submoduleResourceForeground
```

#### Lists/Trees ✓
```
list.activeSelectionBackground/Foreground  list.focusBackground/Foreground
list.focusOutline  list.focusAndSelectionOutline
list.inactiveSelectionBackground/Foreground
list.hoverBackground/hoverForeground  list.highlightForeground
list.errorForeground  list.warningForeground
tree.indentGuidesStroke
```

#### Input/Button/Dropdown ✓
```
input.background/border/foreground/placeholderForeground
inputOption.activeBorder/activeForeground
inputValidation.{error,warning,info}{Background,Border,Foreground}
button.background/foreground/hoverBackground
button.secondaryBackground/secondaryForeground/secondaryHoverBackground
dropdown.background/border/foreground
```

### Remaining Optional Keys (not yet set)

These are lower-priority keys — set if specific visual issues arise:

```
editor.selectionForeground             — selection text color (rarely needed)
terminalCursor.background              — block cursor background
terminalStickyScroll.background        — terminal sticky scroll
list.filterMatchBackground             — filter match highlight
notebook.* (20+ keys)                 — Jupyter notebook colors
symbolIcon.* (25+ keys)              — Symbol icons in autocomplete/outline
editorBracketPairGuide.* (12 keys)   — bracket pair indent guides
mergeEditor.* (10+ keys)             — 3-way merge editor
```

---

## Token Colors — Semantic Groups

All `_tc()` rules in the `$tokenColors` array are organized by semantic role, not by language.
Language-specific scopes go under the appropriate group with a `# lang-specific` comment.

| Group                        | Color          | Description                           |
|------------------------------|----------------|---------------------------------------|
| **Comments**                 | `$fgMuted`     | All comment scopes                    |
| **Strings**                  | `$brightGreen` | All string scopes (regexp → `$cyan`)  |
| **Constants**                | `$purple`      | Numbers, booleans, language constants |
| **Format/Escapes**           | `$orange`      | Placeholders, escape sequences        |
| **Keywords & Storage**       | `$red`         | Control flow, modifiers, declarations |
| **Storage Type**             | `$green`       | `storage.type` — type keywords        |
| **Word-like Operators**      | `$red`         | `new`, `delete`, `typeof`, `sizeof`   |
| **Symbolic Operators**       | `$orange`      | `+`, `=`, `->`, `.`, `::`, `|>`      |
| **Regex**                    | mixed          | Groups→green, classes→red, ops→yellow |
| **Functions**                | `$yellow`      | Names, support, builtins (bold)       |
| **Brackets**                 | `$bracket`     | All bracket/brace/paren punctuation   |
| **Types**                    | `$green`       | Classes, interfaces, enums, structs   |
| **Variables**                | `$fg`          | All variable scopes                   |
| **variable.language**        | `$red`         | `self`, `this`, `super`, `arguments`  |
| **Tags**                     | `$yellow`      | HTML/XML/JSX tag names                |
| **Tag Attributes**           | `$orange`      | HTML/CSS attribute names              |
| **Tag Punctuation**          | `$fgMuted`     | `<`, `>`, `</`, `/>`                  |
| **CSS Properties**           | `$yellow`      | Property names, vendored names        |
| **CSS Values**               | `$brightGreen` | Property values, font names, media    |
| **JSON/Object Keys**         | `$yellow`      | Object keys, dict keys, TOML keys    |
| **Decorators**               | `$yellow`      | `@decorator`, annotations, attributes |
| **Resets**                   | `$fg`          | Embedded sources, labels, imports     |
| **Markup**                   | mixed          | Headings→yellow, bold/italic→fg, links→blue |
| **Text**                     | `$fg`          | Base text color                       |

### Semantic Token Rules

These override TextMate scopes when LSP provides semantic info:

| Token Type             | Color          |
|------------------------|----------------|
| `keyword`              | `$red`         |
| `function`, `method`   | `$yellow`      |
| `*.defaultLibrary`     | same as base   |
| `variable`, `parameter`, `property` | `$fg` |
| `class`, `interface`, `struct`, `enum`, `type` | `$green` |
| `typeAlias`, `typeParameter`, `builtinType`, `generic` | `$green` |
| `string`               | `$brightGreen` |
| `number`, `boolean`, `enumMember`, `const` | `$purple` |
| `operator`             | `$orange`      |
| `punctuation`          | `$bracket`     |
| `comment`              | `$fgMuted`     |
| `namespace`, `label`   | `$fg`          |
| `decorator`, `macro`   | `$yellow`      |
| `lifetime`             | `$orange`      |
| `selfKeyword`, `selfTypeKeyword` | `$red` |
| `escapeSequence`, `formatSpecifier` | `$orange` |
| `newOperator`          | `$red`         |

---

## Languages Covered

Scopes exist for all of these (grouped into the semantic sections above):

**Web:** HTML, CSS, SCSS, Less, JS, TS, JSX/TSX, JSON, Vue, Handlebars, Razor
**Systems:** C, C++, C#, Go, Rust, Swift, Zig, Objective-C, Assembly
**Scripting:** Python, PowerShell, Shell/Bash, Perl, Ruby, Lua, PHP
**Data/Config:** XML, YAML, TOML, INI, .env, Dockerfile, Makefile
**Query:** SQL, GraphQL
**Markup:** Markdown, LaTeX
**JVM:** Java, Groovy, Clojure, F#
**Other:** R, Dart, Visual Basic, Fortran, Ada, MATLAB, Delphi/Pascal

---

## Adding a New Language

1. Open the language's `.tmLanguage.json` grammar (find via VSCode extension source)
2. Identify scopes for: keywords, types, functions, variables, strings, constants
3. Add each scope to the correct **semantic group** in `$tokenColors` with a `# lang-specific` comment
4. Do NOT create a separate per-language block — keep scopes in their semantic groups
