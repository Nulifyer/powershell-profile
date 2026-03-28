# Theme System Plan

## Current State
- `theme.ps1` — palette picker with fzf preview, 30+ themes
- `$palettes` — 3 accent colors (pink/lavender/blue) + bg + os per theme
- `$wtSchemes` — full 16 ANSI color schemes per theme
- `TerminalConfig.ps1` — updates Windows Terminal and WezTerm on theme switch

## Dependencies
| Tool | Purpose | Install |
|------|---------|---------|
| `fzf` | Interactive picker with preview | `winget install junegunn.fzf` |
| `lutgen` | Remap wallpaper colors to theme palette | `cargo install lutgen-cli` |
| `chafa` | Image preview in terminal | `winget install hpjansson.Chafa` |

## VS Code Theming

### Goal
Create a local VS Code extension with our own named theme. Set VS Code to use it once.
On theme switch, regenerate the theme JSON — VS Code watches the file and reloads automatically.
No colorCustomizations, no third-party extensions.

### Extension structure
```
~/.vscode/extensions/nulifyer-theme/
  package.json          # extension manifest, contributes one theme
  themes/
    nulifyer.json        # the theme file we regenerate on switch
```

`package.json` — static, created once:
```json
{
  "name": "nulifyer-theme",
  "displayName": "Nulifyer",
  "version": "1.0.0",
  "engines": { "vscode": "^1.70.0" },
  "categories": ["Themes"],
  "contributes": {
    "themes": [{
      "label": "Nulifyer",
      "uiTheme": "vs-dark",
      "path": "./themes/nulifyer.json"
    }]
  }
}
```

`nulifyer.json` — regenerated on every theme switch with full `colors` + `tokenColors`.

VS Code setting (one-time): `"workbench.colorTheme": "Nulifyer"`

### Design

**3-tier background** (derived by darkening `$wtSchemes[x].background`):

| Tier     | VS Code targets                        | Derivation       |
|----------|----------------------------------------|------------------|
| darkest  | titleBar, statusBar, menu              | bg darkened ~30% |
| mid      | sideBar, panel                         | bg darkened ~15% |
| base     | editor, tabs                           | bg as-is         |
| surface  | hover, widgets, suggestions, peek      | bg lightened ~8%  |

**Borders** — match parent background (no visible dividers), following Evergruv pattern.

**Color mapping from ANSI scheme data:**

| Scheme key    | VS Code role                                    |
|---------------|--------------------------------------------------|
| red           | errors, git deleted, problems                    |
| green         | git added, success, test passed, links           |
| yellow        | warnings, git untracked, accents, badges         |
| blue          | info, git modified, debug                        |
| purple        | hints, git conflicts, booleans                   |
| cyan          | constants, secondary accents                     |
| brightBlack   | comments, line numbers, muted UI, inlay hints    |
| foreground    | main text, active tab, list selections            |
| All 16 ANSI   | terminal.ansi* tokens directly                   |

**Reference theme:** Evergruv (georglauterbach.evergruv) — clean borderless look, ~200 tokens.

### Implementation
- Add `Update-VSCodeTheme` function to `TerminalConfig.ps1`
- Create extension scaffold (`package.json`) on first run if missing
- Regenerate `nulifyer.json` from `$wtSchemes` data + `Adjust-HexBrightness` for bg tiers
- VS Code reloads the theme file automatically — no settings.json editing needed

## Windows System Theming

### Goal
Sync Windows dark/light mode and accent colors to match the active theme.

### Shared Helpers
- `Convert-HexToABGR` — converts `#RRGGBB` → `0xFFBBGGRR` DWORD for registry
  - Single source of truth: all theme colors stay as `#RRGGBB` hex
  - Only converted at the point of registry write
- `Adjust-HexBrightness` — darken/lighten a hex color by percentage (shared with VS Code tier generation)

### Dark/Light Mode
- Flag light themes (catppuccin_latte, gruvbox_light, everforest_light, tokyonight_light, rose_pine_dawn, ayu_light)
- Registry path: `HKCU:\...\Themes\Personalize`
  - `AppsUseLightTheme` — 0=dark, 1=light
  - `SystemUsesLightTheme` — 0=dark, 1=light
- VS Code `window.autoDetectColorScheme` follows this automatically

### Accent Color (taskbar, Start menu, title bars, window borders)

**Registry keys** (all written together on theme switch):

| Path | Key | Type | Value |
|------|-----|------|-------|
| `HKCU:\...\DWM` | `AccentColor` | DWORD | `Convert-HexToABGR $scheme.background` |
| `HKCU:\...\DWM` | `ColorizationColor` | DWORD | `Convert-HexToABGR $scheme.background` |
| `HKCU:\...\DWM` | `ColorizationAfterglow` | DWORD | `Convert-HexToABGR $scheme.background` |
| `HKCU:\...\DWM` | `ColorPrevalence` | DWORD | 1 (show accent on title bars) |
| `HKCU:\...\Explorer\Accent` | `AccentColorMenu` | DWORD | `Convert-HexToABGR $scheme.background` |
| `HKCU:\...\Explorer\Accent` | `StartColorMenu` | DWORD | `Convert-HexToABGR $scheme.background` |
| `HKCU:\...\Explorer\Accent` | `AccentPalette` | BINARY | 32 bytes — 8 shades generated from bg |
| `HKCU:\...\Themes\Personalize` | `ColorPrevalence` | DWORD | 1 (show accent on Start/taskbar) |

**Accent color source:** Use `$wtSchemes[x].background` so title bars blend with the terminal/editor.

**AccentPalette generation:** 8 shades from the bg color (lightest → darkest), each 4 bytes in BBGGRRAA format.

**Refresh:** Broadcast `WM_SETTINGCHANGE` with `"ImmersiveColorSet"` via P/Invoke to apply without restarting Explorer.

### Notes
- "Automatic accent from wallpaper" must be off (we set explicit accent)

## Wallpaper

### Goal
Set a theme-matched wallpaper on theme switch. Must support 3840x1600 ultrawide (primary) + 3440x1440 (secondary).

### Approach: lutgen color remapping
Rather than curating wallpapers per theme (30+ themes × finding ultrawide images = painful),
use [lutgen](https://github.com/ozwaldorf/lutgen-rs) to remap any wallpaper's colors to match the active theme.

**How it works:**
1. User puts a few high-res ultrawide base wallpapers in `~/.config/wallpapers/originals/`
2. On theme switch, lutgen remaps the selected wallpaper to the theme's palette
3. Cached output goes to `~/.config/wallpapers/cache/{theme}_{wallpaper}.png`
4. Set via `SystemParametersInfo` P/Invoke (instant, no restart)

**lutgen palette input:** Feed it the colors from `$wtSchemes` — background, foreground, and all 16 ANSI colors.

**Caching:** Only regenerate if the cached file doesn't exist. Theme switch stays fast after first use.

**Base wallpapers:** User-chosen. Can include some defaults from:
- [42Willow/wallpapers](https://github.com/42Willow/wallpapers) (curated for high-res)
- [r4chl/Wallpapers](https://github.com/r4chl/Wallpapers) (organized by theme)
- [Axenide/Wallpapers](https://github.com/Axenide/Wallpapers) (428 images, sorted by theme)

### Set wallpaper (P/Invoke)
```powershell
Add-Type -TypeDefinition 'using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}'
[Wallpaper]::SystemParametersInfo(0x0014, 0, $path, 0x01 -bor 0x02)
```

### fzf wallpaper picker
- List wallpapers from originals folder
- Preview pane: `chafa --format sixel --size ${cols}x${lines} {file}` — actual image in terminal
- Enter to select, lutgen remaps to active theme, sets wallpaper

### Prerequisites
- `lutgen` and `chafa` on PATH (see Dependencies)
- At least one base wallpaper in the originals folder

## Order of Operations (theme switch)
1. Save theme choice to config
2. Set Windows dark/light mode (registry)
3. Set Windows accent color (registry + broadcast)
4. Update Windows Terminal colors
5. Update WezTerm colors
6. Update VS Code colorCustomizations
7. Generate/cache theme wallpaper (lutgen) and set it
8. Print confirmation
