# VSCode Workbench Color Customization Targets - Complete Reference

Source: https://code.visualstudio.com/api/references/theme-color (April 2026)
Color format: `#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA` (alpha defaults to `ff` / opaque)

---

## 1. Contrast Colors

| Key | Description |
|-----|-------------|
| `contrastActiveBorder` | Extra border around active elements for greater contrast |
| `contrastBorder` | Extra border around elements for greater contrast |

## 2. Base Colors

| Key | Description |
|-----|-------------|
| `focusBorder` | Overall border color for focused elements |
| `foreground` | Overall foreground color |
| `disabledForeground` | Overall foreground for disabled elements |
| `widget.border` | Border color of widgets (e.g. Find/Replace inside editor) |
| `widget.shadow` | Shadow color of widgets |
| `selection.background` | Background color of text selections in the workbench |
| `descriptionForeground` | Foreground for description text providing additional info |
| `errorForeground` | Overall foreground color for error messages |
| `icon.foreground` | Default color for icons in the workbench |
| `sash.hoverBorder` | Hover border color for draggable sashes |

## 3. Window Border

| Key | Description |
|-----|-------------|
| `window.activeBorder` | Border color for the active (focused) window |
| `window.inactiveBorder` | Border color for inactive (unfocused) windows |

## 4. Text Colors

| Key | Description |
|-----|-------------|
| `textBlockQuote.background` | Background for block quotes in text |
| `textBlockQuote.border` | Border for block quotes in text |
| `textCodeBlock.background` | Background for code blocks in text |
| `textLink.activeForeground` | Foreground for links when clicked/hovered |
| `textLink.foreground` | Foreground for links in text |
| `textPreformat.foreground` | Foreground for preformatted text segments |
| `textPreformat.background` | Background for preformatted text segments |
| `textPreformat.border` | Border for preformatted text segments |
| `textSeparator.foreground` | Color for text separators |

## 5. Action Colors

| Key | Description |
|-----|-------------|
| `toolbar.hoverBackground` | Toolbar background when hovering over actions |
| `toolbar.hoverOutline` | Toolbar outline when hovering over actions |
| `toolbar.activeBackground` | Toolbar background when holding mouse over actions |
| `editorActionList.background` | Action List background color |
| `editorActionList.foreground` | Action List foreground color |
| `editorActionList.focusForeground` | Action List foreground for focused item |
| `editorActionList.focusBackground` | Action List background for focused item |

## 6. Button Control

| Key | Description |
|-----|-------------|
| `button.background` | Button background color |
| `button.foreground` | Button foreground color |
| `button.border` | Button border color |
| `button.separator` | Button separator color |
| `button.hoverBackground` | Button background when hovering |
| `button.secondaryForeground` | Secondary button foreground |
| `button.secondaryBackground` | Secondary button background |
| `button.secondaryHoverBackground` | Secondary button background when hovering |
| `button.secondaryBorder` | Secondary button border |
| `checkbox.background` | Checkbox widget background |
| `checkbox.foreground` | Checkbox widget foreground |
| `checkbox.disabled.background` | Disabled checkbox background |
| `checkbox.disabled.foreground` | Disabled checkbox foreground |
| `checkbox.border` | Checkbox widget border |
| `checkbox.selectBackground` | Checkbox background when selected |
| `checkbox.selectBorder` | Checkbox border when selected |
| `radio.activeForeground` | Active radio option foreground |
| `radio.activeBackground` | Active radio option background |
| `radio.activeBorder` | Active radio option border |
| `radio.inactiveForeground` | Inactive radio option foreground |
| `radio.inactiveBackground` | Inactive radio option background |
| `radio.inactiveBorder` | Inactive radio option border |
| `radio.inactiveHoverBackground` | Inactive radio option hover background |

## 7. Dropdown Control

| Key | Description |
|-----|-------------|
| `dropdown.background` | Dropdown background |
| `dropdown.listBackground` | Dropdown list background |
| `dropdown.border` | Dropdown border |
| `dropdown.foreground` | Dropdown foreground |

## 8. Input Control

| Key | Description |
|-----|-------------|
| `input.background` | Input box background |
| `input.border` | Input box border |
| `input.foreground` | Input box foreground |
| `input.placeholderForeground` | Input box placeholder text foreground |
| `inputOption.activeBackground` | Background of activated options in input fields |
| `inputOption.activeBorder` | Border of activated options in input fields |
| `inputOption.activeForeground` | Foreground of activated options in input fields |
| `inputOption.hoverBackground` | Hover background of options in input fields |
| `inputValidation.errorBackground` | Input validation background for error |
| `inputValidation.errorForeground` | Input validation foreground for error |
| `inputValidation.errorBorder` | Input validation border for error |
| `inputValidation.infoBackground` | Input validation background for info |
| `inputValidation.infoForeground` | Input validation foreground for info |
| `inputValidation.infoBorder` | Input validation border for info |
| `inputValidation.warningBackground` | Input validation background for warning |
| `inputValidation.warningForeground` | Input validation foreground for warning |
| `inputValidation.warningBorder` | Input validation border for warning |

## 9. Scrollbar Control

| Key | Description |
|-----|-------------|
| `scrollbar.background` | Scrollbar track background |
| `scrollbar.shadow` | Scrollbar shadow indicating view is scrolled |
| `scrollbarSlider.activeBackground` | Scrollbar slider background when clicked |
| `scrollbarSlider.background` | Scrollbar slider background |
| `scrollbarSlider.hoverBackground` | Scrollbar slider background when hovering |

## 10. Badge

| Key | Description |
|-----|-------------|
| `badge.foreground` | Badge foreground color |
| `badge.background` | Badge background color |

## 11. Progress Bar

| Key | Description |
|-----|-------------|
| `progressBar.background` | Background of progress bar for long running operations |

## 12. Lists and Trees

| Key | Description |
|-----|-------------|
| `list.activeSelectionBackground` | Background for selected item when list is active |
| `list.activeSelectionForeground` | Foreground for selected item when list is active |
| `list.activeSelectionIconForeground` | Icon foreground for selected item when active |
| `list.dropBackground` | Drag and drop background |
| `list.focusBackground` | Background for focused item when active |
| `list.focusForeground` | Foreground for focused item when active |
| `list.focusHighlightForeground` | Match highlight foreground on actively focused items |
| `list.focusOutline` | Outline for focused item when active |
| `list.focusAndSelectionOutline` | Outline for focused and selected item |
| `list.highlightForeground` | Match highlight foreground when searching |
| `list.hoverBackground` | Background when hovering |
| `list.hoverForeground` | Foreground when hovering |
| `list.inactiveSelectionBackground` | Background for selected item when inactive |
| `list.inactiveSelectionForeground` | Foreground for selected item when inactive |
| `list.inactiveSelectionIconForeground` | Icon foreground for selected item when inactive |
| `list.inactiveFocusBackground` | Background for focused item when inactive |
| `list.inactiveFocusOutline` | Outline for focused item when inactive |
| `list.invalidItemForeground` | Foreground for invalid items |
| `list.errorForeground` | Foreground for items containing errors |
| `list.warningForeground` | Foreground for items containing warnings |
| `listFilterWidget.background` | Filter widget background for typed text |
| `listFilterWidget.outline` | Filter widget outline |
| `listFilterWidget.noMatchesOutline` | Filter widget outline when no match found |
| `listFilterWidget.shadow` | Shadow of the type filter widget |
| `list.filterMatchBackground` | Background of filtered matches |
| `list.filterMatchBorder` | Border of filtered matches |
| `list.deemphasizedForeground` | Foreground for deemphasized items |
| `list.dropBetweenBackground` | Drag and drop border between items |
| `tree.indentGuidesStroke` | Stroke for indent guides |
| `tree.inactiveIndentGuidesStroke` | Stroke for inactive indent guides |
| `tree.tableColumnsBorder` | Table columns border |
| `tree.tableOddRowsBackground` | Background for odd table rows |

## 13. Activity Bar

| Key | Description |
|-----|-------------|
| `activityBar.background` | Activity Bar background |
| `activityBar.dropBorder` | Drag and drop feedback for activity bar items |
| `activityBar.foreground` | Activity Bar foreground (active icon) |
| `activityBar.inactiveForeground` | Activity Bar item foreground when inactive |
| `activityBar.border` | Activity Bar border with Side Bar |
| `activityBarBadge.background` | Activity notification badge background |
| `activityBarBadge.foreground` | Activity notification badge foreground |
| `activityBar.activeBorder` | Active indicator border |
| `activityBar.activeBackground` | Optional background for the active element |
| `activityBar.activeFocusBorder` | Focus border for the active item |
| `activityBarTop.foreground` | Active foreground when Activity Bar is on top |
| `activityBarTop.activeBorder` | Focus border for active item when on top |
| `activityBarTop.inactiveForeground` | Inactive foreground when on top |
| `activityBarTop.dropBorder` | Drag and drop feedback when on top |
| `activityBarTop.background` | Background when set to top/bottom |
| `activityBarTop.activeBackground` | Active item background when on top/bottom |
| `activityWarningBadge.foreground` | Warning activity badge foreground |
| `activityWarningBadge.background` | Warning activity badge background |
| `activityErrorBadge.foreground` | Error activity badge foreground |
| `activityErrorBadge.background` | Error activity badge background |

## 14. Profiles

| Key | Description |
|-----|-------------|
| `profileBadge.background` | Profile badge background |
| `profileBadge.foreground` | Profile badge foreground |
| `profiles.sashBorder` | Profiles editor splitview sash border |

## 15. Side Bar

| Key | Description |
|-----|-------------|
| `sideBar.background` | Side Bar background |
| `sideBar.foreground` | Side Bar foreground |
| `sideBar.border` | Side Bar border on the side separating editor |
| `sideBar.dropBackground` | Drag and drop feedback for side bar sections |
| `sideBarTitle.foreground` | Side Bar title foreground |
| `sideBarTitle.background` | Side Bar title background |
| `sideBarTitle.border` | Side Bar title border on bottom |
| `sideBarSectionHeader.background` | Section header background |
| `sideBarSectionHeader.foreground` | Section header foreground |
| `sideBarSectionHeader.border` | Section header border |
| `sideBarActivityBarTop.border` | Border between activity bar at top/bottom and views |
| `sideBarStickyScroll.background` | Sticky scroll background in side bar |
| `sideBarStickyScroll.border` | Sticky scroll border in side bar |
| `sideBarStickyScroll.shadow` | Sticky scroll shadow in side bar |

## 16. Minimap

| Key | Description |
|-----|-------------|
| `minimap.findMatchHighlight` | Highlight for search matches |
| `minimap.selectionHighlight` | Highlight for editor selection |
| `minimap.errorHighlight` | Highlight for errors |
| `minimap.warningHighlight` | Highlight for warnings |
| `minimap.background` | Minimap background |
| `minimap.selectionOccurrenceHighlight` | Marker for repeating editor selections |
| `minimap.foregroundOpacity` | Opacity of foreground elements |
| `minimap.infoHighlight` | Marker for infos |
| `minimap.chatEditHighlight` | Color of pending edit regions |
| `minimapSlider.background` | Slider background |
| `minimapSlider.hoverBackground` | Slider background when hovering |
| `minimapSlider.activeBackground` | Slider background when clicked |
| `minimapGutter.addedBackground` | Gutter color for added content |
| `minimapGutter.modifiedBackground` | Gutter color for modified content |
| `minimapGutter.deletedBackground` | Gutter color for deleted content |
| `editorMinimap.inlineChatInserted` | Marker for inline chat inserted content |

## 17. Editor Groups and Tabs

| Key | Description |
|-----|-------------|
| `editorGroup.border` | Separator between multiple editor groups |
| `editorGroup.dropBackground` | Background when dragging editors |
| `editorGroupHeader.noTabsBackground` | Title header background when using single tab |
| `editorGroupHeader.tabsBackground` | Tabs container background |
| `editorGroupHeader.tabsBorder` | Border below editor tabs control |
| `editorGroupHeader.border` | Border between editor group header and editor |
| `editorGroup.emptyBackground` | Background of empty editor group |
| `editorGroup.focusedEmptyBorder` | Border of focused empty editor group |
| `editorGroup.dropIntoPromptForeground` | Foreground of text shown when dragging files |
| `editorGroup.dropIntoPromptBackground` | Background of text shown when dragging files |
| `editorGroup.dropIntoPromptBorder` | Border of text shown when dragging files |
| `tab.activeBackground` | Active tab background in active group |
| `tab.unfocusedActiveBackground` | Active tab background in inactive group |
| `tab.activeForeground` | Active tab foreground in active group |
| `tab.border` | Border to separate tabs |
| `tab.activeBorder` | Bottom border for active tab |
| `tab.selectedBorderTop` | Top border of selected tab |
| `tab.selectedBackground` | Background of selected tab |
| `tab.selectedForeground` | Foreground of selected tab |
| `tab.dragAndDropBorder` | Border between tabs during drag |
| `tab.unfocusedActiveBorder` | Bottom border for active tab in inactive group |
| `tab.activeBorderTop` | Top border for active tab |
| `tab.unfocusedActiveBorderTop` | Top border for active tab in inactive group |
| `tab.lastPinnedBorder` | Border on right of last pinned editor |
| `tab.inactiveBackground` | Inactive tab background |
| `tab.unfocusedInactiveBackground` | Inactive tab background in unfocused group |
| `tab.inactiveForeground` | Inactive tab foreground in active group |
| `tab.unfocusedActiveForeground` | Active tab foreground in inactive group |
| `tab.unfocusedInactiveForeground` | Inactive tab foreground in inactive group |
| `tab.hoverBackground` | Tab background when hovering |
| `tab.unfocusedHoverBackground` | Tab background in unfocused group when hovering |
| `tab.hoverForeground` | Tab foreground when hovering |
| `tab.unfocusedHoverForeground` | Tab foreground in unfocused group when hovering |
| `tab.hoverBorder` | Border to highlight tabs when hovering |
| `tab.unfocusedHoverBorder` | Border in unfocused group when hovering |
| `tab.activeModifiedBorder` | Top border on modified active tabs in active group |
| `tab.inactiveModifiedBorder` | Top border on modified inactive tabs in active group |
| `tab.unfocusedActiveModifiedBorder` | Top border on modified active tabs in unfocused group |
| `tab.unfocusedInactiveModifiedBorder` | Top border on modified inactive tabs in unfocused group |
| `editorPane.background` | Editor pane background (left/right side) |
| `sideBySideEditor.horizontalBorder` | Horizontal separator between side-by-side editors |
| `sideBySideEditor.verticalBorder` | Vertical separator between side-by-side editors |

## 18. Editor Colors

### Core Editor
| Key | Description |
|-----|-------------|
| `editor.background` | Editor background |
| `editor.foreground` | Editor default foreground |
| `editorLineNumber.foreground` | Line number color |
| `editorLineNumber.activeForeground` | Active line number color |
| `editorLineNumber.dimmedForeground` | Final line number when renderFinalNewline is dimmed |
| `editorCursor.background` | Cursor background |
| `editorCursor.foreground` | Cursor color |
| `editorMultiCursor.primary.foreground` | Primary cursor foreground (multi-cursor) |
| `editorMultiCursor.primary.background` | Primary cursor background (multi-cursor) |
| `editorMultiCursor.secondary.foreground` | Secondary cursor foreground (multi-cursor) |
| `editorMultiCursor.secondary.background` | Secondary cursor background (multi-cursor) |
| `editor.placeholder.foreground` | Placeholder text foreground |
| `editor.compositionBorder` | IME composition border |

### Selection
| Key | Description |
|-----|-------------|
| `editor.selectionBackground` | Selection background |
| `editor.selectionForeground` | Selected text foreground (high contrast) |
| `editor.inactiveSelectionBackground` | Selection in inactive editor |
| `editor.selectionHighlightBackground` | Regions with same content as selection |
| `editor.selectionHighlightBorder` | Border for regions matching selection |

### Word Highlight
| Key | Description |
|-----|-------------|
| `editor.wordHighlightBackground` | Symbol background during read-access |
| `editor.wordHighlightBorder` | Symbol border during read-access |
| `editor.wordHighlightStrongBackground` | Symbol background during write-access |
| `editor.wordHighlightStrongBorder` | Symbol border during write-access |
| `editor.wordHighlightTextBackground` | Textual occurrence background for a symbol |
| `editor.wordHighlightTextBorder` | Textual occurrence border for a symbol |

### Find/Search
| Key | Description |
|-----|-------------|
| `editor.findMatchBackground` | Current search match background |
| `editor.findMatchForeground` | Current search match text color |
| `editor.findMatchHighlightForeground` | Other search matches foreground |
| `editor.findMatchHighlightBackground` | Other search matches background |
| `editor.findRangeHighlightBackground` | Range limiting the search |
| `editor.findMatchBorder` | Current search match border |
| `editor.findMatchHighlightBorder` | Other search matches border |
| `editor.findRangeHighlightBorder` | Border of range limiting the search |

### Line Highlights
| Key | Description |
|-----|-------------|
| `editor.hoverHighlightBackground` | Highlight below word for hover |
| `editor.lineHighlightBackground` | Current line highlight background |
| `editor.inactiveLineHighlightBackground` | Line highlight when editor not focused |
| `editor.lineHighlightBorder` | Border around current line |
| `editor.rangeHighlightBackground` | Highlighted ranges background |
| `editor.rangeHighlightBorder` | Highlighted ranges border |
| `editor.symbolHighlightBackground` | Highlighted symbol background |
| `editor.symbolHighlightBorder` | Highlighted symbol border |

### Unicode Highlight
| Key | Description |
|-----|-------------|
| `editorUnicodeHighlight.border` | Border for unicode characters |
| `editorUnicodeHighlight.background` | Background for unicode characters |

### Links
| Key | Description |
|-----|-------------|
| `editorLink.activeForeground` | Active links color |

### Whitespace and Indentation
| Key | Description |
|-----|-------------|
| `editorWhitespace.foreground` | Whitespace characters color |
| `editorIndentGuide.background` | Indentation guides color |
| `editorIndentGuide.background1` | Indentation guides color (1) |
| `editorIndentGuide.background2` | Indentation guides color (2) |
| `editorIndentGuide.background3` | Indentation guides color (3) |
| `editorIndentGuide.background4` | Indentation guides color (4) |
| `editorIndentGuide.background5` | Indentation guides color (5) |
| `editorIndentGuide.background6` | Indentation guides color (6) |
| `editorIndentGuide.activeBackground` | Active indentation guide color |
| `editorIndentGuide.activeBackground1` | Active indentation guide color (1) |
| `editorIndentGuide.activeBackground2` | Active indentation guide color (2) |
| `editorIndentGuide.activeBackground3` | Active indentation guide color (3) |
| `editorIndentGuide.activeBackground4` | Active indentation guide color (4) |
| `editorIndentGuide.activeBackground5` | Active indentation guide color (5) |
| `editorIndentGuide.activeBackground6` | Active indentation guide color (6) |

### Inlay Hints
| Key | Description |
|-----|-------------|
| `editorInlayHint.background` | Inline hints background |
| `editorInlayHint.foreground` | Inline hints foreground |
| `editorInlayHint.typeForeground` | Type inline hints foreground |
| `editorInlayHint.typeBackground` | Type inline hints background |
| `editorInlayHint.parameterForeground` | Parameter inline hints foreground |
| `editorInlayHint.parameterBackground` | Parameter inline hints background |

### Rulers and CodeLens
| Key | Description |
|-----|-------------|
| `editorRuler.foreground` | Editor rulers color |
| `editorCodeLens.foreground` | CodeLens foreground |

### Linked Editing
| Key | Description |
|-----|-------------|
| `editor.linkedEditingBackground` | Background in linked editing mode |

### Light Bulb
| Key | Description |
|-----|-------------|
| `editorLightBulb.foreground` | Lightbulb actions icon color |
| `editorLightBulbAutoFix.foreground` | Lightbulb auto fix icon color |
| `editorLightBulbAi.foreground` | Lightbulb AI icon color |

### Bracket Matching
| Key | Description |
|-----|-------------|
| `editorBracketMatch.background` | Background behind matching brackets |
| `editorBracketMatch.border` | Border for matching brackets |
| `editorBracketMatch.foreground` | Foreground for matching brackets |

### Bracket Pair Colorization
| Key | Description |
|-----|-------------|
| `editorBracketHighlight.foreground1` | Bracket foreground (1) |
| `editorBracketHighlight.foreground2` | Bracket foreground (2) |
| `editorBracketHighlight.foreground3` | Bracket foreground (3) |
| `editorBracketHighlight.foreground4` | Bracket foreground (4) |
| `editorBracketHighlight.foreground5` | Bracket foreground (5) |
| `editorBracketHighlight.foreground6` | Bracket foreground (6) |
| `editorBracketHighlight.unexpectedBracket.foreground` | Unexpected bracket foreground |

### Bracket Pair Guides
| Key | Description |
|-----|-------------|
| `editorBracketPairGuide.activeBackground1` | Active bracket pair guide (1) |
| `editorBracketPairGuide.activeBackground2` | Active bracket pair guide (2) |
| `editorBracketPairGuide.activeBackground3` | Active bracket pair guide (3) |
| `editorBracketPairGuide.activeBackground4` | Active bracket pair guide (4) |
| `editorBracketPairGuide.activeBackground5` | Active bracket pair guide (5) |
| `editorBracketPairGuide.activeBackground6` | Active bracket pair guide (6) |
| `editorBracketPairGuide.background1` | Inactive bracket pair guide (1) |
| `editorBracketPairGuide.background2` | Inactive bracket pair guide (2) |
| `editorBracketPairGuide.background3` | Inactive bracket pair guide (3) |
| `editorBracketPairGuide.background4` | Inactive bracket pair guide (4) |
| `editorBracketPairGuide.background5` | Inactive bracket pair guide (5) |
| `editorBracketPairGuide.background6` | Inactive bracket pair guide (6) |

### Folding
| Key | Description |
|-----|-------------|
| `editor.foldBackground` | Folded ranges background |
| `editor.foldPlaceholderForeground` | Collapsed text color after first line |

### Overview Ruler
| Key | Description |
|-----|-------------|
| `editorOverviewRuler.background` | Overview ruler background |
| `editorOverviewRuler.border` | Overview ruler border |
| `editorOverviewRuler.findMatchForeground` | Find matches marker |
| `editorOverviewRuler.rangeHighlightForeground` | Highlighted ranges marker |
| `editorOverviewRuler.selectionHighlightForeground` | Selection highlights marker |
| `editorOverviewRuler.wordHighlightForeground` | Symbol highlights marker |
| `editorOverviewRuler.wordHighlightStrongForeground` | Write-access symbol highlights marker |
| `editorOverviewRuler.wordHighlightTextForeground` | Textual occurrence marker |
| `editorOverviewRuler.modifiedForeground` | Modified content marker |
| `editorOverviewRuler.addedForeground` | Added content marker |
| `editorOverviewRuler.deletedForeground` | Deleted content marker |
| `editorOverviewRuler.errorForeground` | Errors marker |
| `editorOverviewRuler.warningForeground` | Warnings marker |
| `editorOverviewRuler.infoForeground` | Infos marker |
| `editorOverviewRuler.bracketMatchForeground` | Matching brackets marker |
| `editorOverviewRuler.inlineChatInserted` | Inline chat inserted content marker |
| `editorOverviewRuler.inlineChatRemoved` | Inline chat removed content marker |
| `editorOverviewRuler.commentDraftForeground` | Comment threads with draft comments |

### Errors, Warnings, Info
| Key | Description |
|-----|-------------|
| `editorError.foreground` | Error squiggles foreground |
| `editorError.border` | Error boxes border |
| `editorError.background` | Error text background |
| `editorWarning.foreground` | Warning squiggles foreground |
| `editorWarning.border` | Warning boxes border |
| `editorWarning.background` | Warning text background |
| `editorInfo.foreground` | Info squiggles foreground |
| `editorInfo.border` | Info boxes border |
| `editorInfo.background` | Info text background |
| `editorHint.foreground` | Hints foreground |
| `editorHint.border` | Hint boxes border |
| `problemsErrorIcon.foreground` | Problems error icon |
| `problemsWarningIcon.foreground` | Problems warning icon |
| `problemsInfoIcon.foreground` | Problems info icon |

### Unused Code
| Key | Description |
|-----|-------------|
| `editorUnnecessaryCode.border` | Unused source code border |
| `editorUnnecessaryCode.opacity` | Unused source code opacity |

### Gutter
| Key | Description |
|-----|-------------|
| `editorGutter.background` | Gutter background |
| `editorGutter.modifiedBackground` | Modified lines background |
| `editorGutter.modifiedSecondaryBackground` | Modified lines secondary background |
| `editorGutter.addedBackground` | Added lines background |
| `editorGutter.addedSecondaryBackground` | Added lines secondary background |
| `editorGutter.deletedBackground` | Deleted lines background |
| `editorGutter.deletedSecondaryBackground` | Deleted lines secondary background |
| `editorGutter.commentRangeForeground` | Commenting ranges decoration |
| `editorGutter.commentGlyphForeground` | Commenting glyphs decoration |
| `editorGutter.commentUnresolvedGlyphForeground` | Unresolved comment thread glyphs |
| `editorGutter.foldingControlForeground` | Folding control color |
| `editorGutter.itemGlyphForeground` | Gutter item glyphs |
| `editorGutter.itemBackground` | Gutter item background |
| `editorGutter.commentDraftGlyphForeground` | Draft comment glyphs |

### Editor Comments Widget
| Key | Description |
|-----|-------------|
| `editorCommentsWidget.resolvedBorder` | Resolved comments borders and arrow |
| `editorCommentsWidget.unresolvedBorder` | Unresolved comments borders and arrow |
| `editorCommentsWidget.rangeBackground` | Comment ranges background |
| `editorCommentsWidget.rangeActiveBackground` | Selected/hovered comment range background |
| `editorCommentsWidget.replyInputBackground` | Comment reply input box background |

### Inline Edits (Copilot)
| Key | Description |
|-----|-------------|
| `inlineEdit.gutterIndicator.primaryBorder` | Primary inline edit gutter indicator border |
| `inlineEdit.gutterIndicator.primaryForeground` | Primary inline edit gutter indicator foreground |
| `inlineEdit.gutterIndicator.primaryBackground` | Primary inline edit gutter indicator background |
| `inlineEdit.gutterIndicator.secondaryBorder` | Secondary inline edit gutter indicator border |
| `inlineEdit.gutterIndicator.secondaryForeground` | Secondary inline edit gutter indicator foreground |
| `inlineEdit.gutterIndicator.secondaryBackground` | Secondary inline edit gutter indicator background |
| `inlineEdit.gutterIndicator.successfulBorder` | Successful inline edit gutter indicator border |
| `inlineEdit.gutterIndicator.successfulForeground` | Successful inline edit gutter indicator foreground |
| `inlineEdit.gutterIndicator.successfulBackground` | Successful inline edit gutter indicator background |
| `inlineEdit.gutterIndicator.background` | Inline edit gutter indicator background |
| `inlineEdit.originalBackground` | Original text background |
| `inlineEdit.modifiedBackground` | Modified text background |
| `inlineEdit.originalChangedLineBackground` | Changed lines in original text background |
| `inlineEdit.originalChangedTextBackground` | Changed text in original overlay |
| `inlineEdit.modifiedChangedLineBackground` | Changed lines in modified text background |
| `inlineEdit.modifiedChangedTextBackground` | Changed text in modified overlay |
| `inlineEdit.originalBorder` | Original text border |
| `inlineEdit.modifiedBorder` | Modified text border |
| `inlineEdit.tabWillAcceptModifiedBorder` | Modified border when tab will accept |
| `inlineEdit.tabWillAcceptOriginalBorder` | Original border when tab will accept |

## 19. Diff Editor

| Key | Description |
|-----|-------------|
| `diffEditor.insertedTextBackground` | Inserted text background |
| `diffEditor.insertedTextBorder` | Inserted text outline |
| `diffEditor.removedTextBackground` | Removed text background |
| `diffEditor.removedTextBorder` | Removed text outline |
| `diffEditor.border` | Border between two text editors |
| `diffEditor.diagonalFill` | Diagonal fill in side-by-side views |
| `diffEditor.insertedLineBackground` | Inserted lines background |
| `diffEditor.removedLineBackground` | Removed lines background |
| `diffEditorGutter.insertedLineBackground` | Margin background for inserted lines |
| `diffEditorGutter.removedLineBackground` | Margin background for removed lines |
| `diffEditorOverview.insertedForeground` | Overview ruler foreground for inserted content |
| `diffEditorOverview.removedForeground` | Overview ruler foreground for removed content |
| `diffEditor.unchangedRegionBackground` | Unchanged blocks background |
| `diffEditor.unchangedRegionForeground` | Unchanged blocks foreground |
| `diffEditor.unchangedRegionShadow` | Shadow around unchanged region widgets |
| `diffEditor.unchangedCodeBackground` | Unchanged code background |
| `diffEditor.move.border` | Moved text border |
| `diffEditor.moveActive.border` | Active moved text border |
| `multiDiffEditor.headerBackground` | Multi diff editor header background |
| `multiDiffEditor.background` | Multi diff editor background |
| `multiDiffEditor.border` | Multi diff editor border |

## 20. Chat Colors

| Key | Description |
|-----|-------------|
| `chat.requestBorder` | Chat request border |
| `chat.requestBackground` | Chat request background |
| `chat.slashCommandBackground` | Slash command background |
| `chat.slashCommandForeground` | Slash command foreground |
| `chat.avatarBackground` | Chat avatar background |
| `chat.avatarForeground` | Chat avatar foreground |
| `chat.editedFileForeground` | Edited file foreground in file list |
| `chat.linesAddedForeground` | Lines added in code block pill |
| `chat.linesRemovedForeground` | Lines removed in code block pill |
| `chat.requestCodeBorder` | Code blocks border within request bubble |
| `chat.requestBubbleBackground` | Request bubble background |
| `chat.requestBubbleHoverBackground` | Request bubble background on hover |
| `chat.checkpointSeparator` | Checkpoint separator color |
| `chat.thinkingShimmer` | Shimmer for thinking/working labels |
| `chatManagement.sashBorder` | Chat Management editor splitview sash border |

## 21. Inline Chat

| Key | Description |
|-----|-------------|
| `inlineChat.background` | Interactive editor widget background |
| `inlineChat.foreground` | Interactive editor widget foreground |
| `inlineChat.border` | Interactive editor widget border |
| `inlineChat.shadow` | Interactive editor widget shadow |
| `inlineChatInput.border` | Interactive editor input border |
| `inlineChatInput.focusBorder` | Interactive editor input focus border |
| `inlineChatInput.placeholderForeground` | Interactive editor input placeholder |
| `inlineChatInput.background` | Interactive editor input background |
| `inlineChatDiff.inserted` | Inserted text background in inline chat |
| `inlineChatDiff.removed` | Removed text background in inline chat |

## 22. Panel Chat

| Key | Description |
|-----|-------------|
| `interactive.activeCodeBorder` | Border for current interactive code cell (focused) |
| `interactive.inactiveCodeBorder` | Border for current interactive code cell (unfocused) |

## 23. Editor Widget Colors

| Key | Description |
|-----|-------------|
| `editorWidget.foreground` | Widget foreground (e.g. Find/Replace) |
| `editorWidget.background` | Widget background |
| `editorWidget.border` | Widget border |
| `editorWidget.resizeBorder` | Widget resize bar border |
| `editorSuggestWidget.background` | Suggestion widget background |
| `editorSuggestWidget.border` | Suggestion widget border |
| `editorSuggestWidget.foreground` | Suggestion widget foreground |
| `editorSuggestWidget.focusHighlightForeground` | Match highlights when item focused |
| `editorSuggestWidget.highlightForeground` | Match highlights in suggestions |
| `editorSuggestWidget.selectedBackground` | Selected entry background |
| `editorSuggestWidget.selectedForeground` | Selected entry foreground |
| `editorSuggestWidget.selectedIconForeground` | Selected entry icon foreground |
| `editorSuggestWidgetStatus.foreground` | Suggest widget status foreground |
| `editorHoverWidget.foreground` | Hover foreground |
| `editorHoverWidget.background` | Hover background |
| `editorHoverWidget.border` | Hover border |
| `editorHoverWidget.highlightForeground` | Active item in parameter hint |
| `editorHoverWidget.statusBarBackground` | Hover status bar background |
| `editorGhostText.border` | Ghost text border (inline completions) |
| `editorGhostText.background` | Ghost text background |
| `editorGhostText.foreground` | Ghost text foreground |
| `editorStickyScroll.background` | Sticky scroll background |
| `editorStickyScroll.border` | Sticky scroll border |
| `editorStickyScroll.shadow` | Sticky scroll shadow |
| `editorStickyScrollGutter.background` | Sticky scroll gutter background |
| `editorStickyScrollHover.background` | Sticky scroll hover background |
| `debugExceptionWidget.background` | Exception widget background |
| `debugExceptionWidget.border` | Exception widget border |
| `editorMarkerNavigation.background` | Marker navigation background |
| `editorMarkerNavigationError.background` | Marker navigation error color |
| `editorMarkerNavigationWarning.background` | Marker navigation warning color |
| `editorMarkerNavigationInfo.background` | Marker navigation info color |
| `editorMarkerNavigationError.headerBackground` | Marker navigation error heading background |
| `editorMarkerNavigationWarning.headerBackground` | Marker navigation warning heading background |
| `editorMarkerNavigationInfo.headerBackground` | Marker navigation info heading background |

## 24. Peek View

| Key | Description |
|-----|-------------|
| `peekView.border` | Peek view borders and arrow |
| `peekViewEditor.background` | Peek view editor background |
| `peekViewEditorGutter.background` | Peek view editor gutter background |
| `peekViewEditor.matchHighlightBackground` | Search match highlight in peek editor |
| `peekViewEditor.matchHighlightBorder` | Search match highlight border in peek editor |
| `peekViewResult.background` | Result list background |
| `peekViewResult.fileForeground` | File nodes foreground in result list |
| `peekViewResult.lineForeground` | Line nodes foreground in result list |
| `peekViewResult.matchHighlightBackground` | Match highlight in result list |
| `peekViewResult.selectionBackground` | Selected entry background in result list |
| `peekViewResult.selectionForeground` | Selected entry foreground in result list |
| `peekViewTitle.background` | Title area background |
| `peekViewTitleDescription.foreground` | Title info (description) color |
| `peekViewTitleLabel.foreground` | Title label color |
| `peekViewEditorStickyScroll.background` | Sticky scroll background in peek editor |
| `peekViewEditorStickyScrollGutter.background` | Sticky scroll gutter in peek editor |

## 25. Merge Conflicts

| Key | Description |
|-----|-------------|
| `merge.currentHeaderBackground` | Current header background in inline conflicts |
| `merge.currentContentBackground` | Current content background in inline conflicts |
| `merge.incomingHeaderBackground` | Incoming header background in inline conflicts |
| `merge.incomingContentBackground` | Incoming content background in inline conflicts |
| `merge.border` | Border on headers and splitter |
| `merge.commonContentBackground` | Common ancestor content background |
| `merge.commonHeaderBackground` | Common ancestor header background |
| `editorOverviewRuler.currentContentForeground` | Current content overview ruler marker |
| `editorOverviewRuler.incomingContentForeground` | Incoming content overview ruler marker |
| `editorOverviewRuler.commonContentForeground` | Common content overview ruler marker |
| `editorOverviewRuler.commentForeground` | Resolved comments overview ruler marker |
| `editorOverviewRuler.commentUnresolvedForeground` | Unresolved comments overview ruler marker |
| `mergeEditor.change.background` | Changes background |
| `mergeEditor.change.word.background` | Word changes background |
| `mergeEditor.conflict.unhandledUnfocused.border` | Unhandled unfocused conflict border |
| `mergeEditor.conflict.unhandledFocused.border` | Unhandled focused conflict border |
| `mergeEditor.conflict.handledUnfocused.border` | Handled unfocused conflict border |
| `mergeEditor.conflict.handledFocused.border` | Handled focused conflict border |
| `mergeEditor.conflict.handled.minimapOverViewRuler` | Minimap color for handled conflicts |
| `mergeEditor.conflict.unhandled.minimapOverViewRuler` | Minimap color for unhandled conflicts |
| `mergeEditor.conflictingLines.background` | "Conflicting Lines" text background |
| `mergeEditor.changeBase.background` | Base version changes background |
| `mergeEditor.changeBase.word.background` | Base version word changes background |
| `mergeEditor.conflict.input1.background` | Input 1 decorations background |
| `mergeEditor.conflict.input2.background` | Input 2 decorations background |

## 26. Panel Colors

| Key | Description |
|-----|-------------|
| `panel.background` | Panel background |
| `panel.border` | Panel border separating from editor |
| `panel.dropBorder` | Drag and drop feedback for panel titles |
| `panelTitle.activeBorder` | Active panel title border |
| `panelTitle.activeForeground` | Active panel title foreground |
| `panelTitle.inactiveForeground` | Inactive panel title foreground |
| `panelTitle.border` | Panel title bottom border |
| `panelTitleBadge.background` | Panel title badge background |
| `panelTitleBadge.foreground` | Panel title badge foreground |
| `panelInput.border` | Panel input box border |
| `panelSection.border` | Border between horizontally stacked panel views |
| `panelSection.dropBackground` | Drag and drop feedback for panel sections |
| `panelSectionHeader.background` | Section header background |
| `panelSectionHeader.foreground` | Section header foreground |
| `panelSectionHeader.border` | Section header border (vertical stacking) |
| `panelStickyScroll.background` | Sticky scroll background in panel |
| `panelStickyScroll.border` | Sticky scroll border in panel |
| `panelStickyScroll.shadow` | Sticky scroll shadow in panel |
| `outputView.background` | Output view background |
| `outputViewStickyScroll.background` | Output view sticky scroll background |

## 27. Status Bar

| Key | Description |
|-----|-------------|
| `statusBar.background` | Standard status bar background |
| `statusBar.foreground` | Status bar foreground |
| `statusBar.border` | Status bar border |
| `statusBar.debuggingBackground` | Background when debugging |
| `statusBar.debuggingForeground` | Foreground when debugging |
| `statusBar.debuggingBorder` | Border when debugging |
| `statusBar.noFolderForeground` | Foreground when no folder open |
| `statusBar.noFolderBackground` | Background when no folder open |
| `statusBar.noFolderBorder` | Border when no folder open |
| `statusBar.focusBorder` | Border when keyboard focused |
| `statusBarItem.activeBackground` | Item background when clicking |
| `statusBarItem.hoverForeground` | Item foreground on hover |
| `statusBarItem.hoverBackground` | Item background on hover |
| `statusBarItem.prominentForeground` | Prominent items foreground |
| `statusBarItem.prominentBackground` | Prominent items background |
| `statusBarItem.prominentHoverForeground` | Prominent items foreground on hover |
| `statusBarItem.prominentHoverBackground` | Prominent items background on hover |
| `statusBarItem.remoteBackground` | Remote indicator background |
| `statusBarItem.remoteForeground` | Remote indicator foreground |
| `statusBarItem.remoteHoverBackground` | Remote indicator background on hover |
| `statusBarItem.remoteHoverForeground` | Remote indicator foreground on hover |
| `statusBarItem.errorBackground` | Error items background |
| `statusBarItem.errorForeground` | Error items foreground |
| `statusBarItem.errorHoverBackground` | Error items background on hover |
| `statusBarItem.errorHoverForeground` | Error items foreground on hover |
| `statusBarItem.warningBackground` | Warning items background |
| `statusBarItem.warningForeground` | Warning items foreground |
| `statusBarItem.warningHoverBackground` | Warning items background on hover |
| `statusBarItem.warningHoverForeground` | Warning items foreground on hover |
| `statusBarItem.compactHoverBackground` | Background for dual-hover items |
| `statusBarItem.focusBorder` | Border when keyboard focused |
| `statusBarItem.offlineBackground` | Background when workbench offline |
| `statusBarItem.offlineForeground` | Foreground when workbench offline |
| `statusBarItem.offlineHoverForeground` | Foreground on hover when offline |
| `statusBarItem.offlineHoverBackground` | Background on hover when offline |

## 28. Title Bar

| Key | Description |
|-----|-------------|
| `titleBar.activeBackground` | Background when window is active |
| `titleBar.activeForeground` | Foreground when window is active |
| `titleBar.inactiveBackground` | Background when window is inactive |
| `titleBar.inactiveForeground` | Foreground when window is inactive |
| `titleBar.border` | Title bar border |

## 29. Menu Bar

| Key | Description |
|-----|-------------|
| `menubar.selectionForeground` | Selected menu item foreground in menubar |
| `menubar.selectionBackground` | Selected menu item background in menubar |
| `menubar.selectionBorder` | Selected menu item border in menubar |
| `menu.foreground` | Menu items foreground |
| `menu.background` | Menu items background |
| `menu.selectionForeground` | Selected menu item foreground in dropdowns |
| `menu.selectionBackground` | Selected menu item background in dropdowns |
| `menu.selectionBorder` | Selected menu item border in dropdowns |
| `menu.separatorBackground` | Separator color in menus |
| `menu.border` | Menu border |

## 30. Command Center

| Key | Description |
|-----|-------------|
| `commandCenter.foreground` | Default foreground |
| `commandCenter.activeForeground` | Active foreground |
| `commandCenter.background` | Default background |
| `commandCenter.activeBackground` | Active background |
| `commandCenter.border` | Border |
| `commandCenter.inactiveForeground` | Foreground when window unfocused |
| `commandCenter.inactiveBorder` | Border when window unfocused |
| `commandCenter.activeBorder` | Active border |
| `commandCenter.debuggingBackground` | Background when debugging |

## 31. Notifications

| Key | Description |
|-----|-------------|
| `notificationCenter.border` | Notification Center border |
| `notificationCenterHeader.foreground` | Header foreground |
| `notificationCenterHeader.background` | Header background |
| `notificationToast.border` | Toast border |
| `notifications.foreground` | Notification foreground |
| `notifications.background` | Notification background |
| `notifications.border` | Notification border (between notifications) |
| `notificationLink.foreground` | Notification link foreground |
| `notificationsErrorIcon.foreground` | Error icon color |
| `notificationsWarningIcon.foreground` | Warning icon color |
| `notificationsInfoIcon.foreground` | Info icon color |

## 32. Banner

| Key | Description |
|-----|-------------|
| `banner.background` | Banner background |
| `banner.foreground` | Banner foreground |
| `banner.iconForeground` | Banner icon color |

## 33. Extensions

| Key | Description |
|-----|-------------|
| `extensionButton.prominentForeground` | Extension view button foreground (e.g. Install) |
| `extensionButton.prominentBackground` | Extension view button background |
| `extensionButton.prominentHoverBackground` | Extension view button hover background |
| `extensionButton.background` | Button background for extension actions |
| `extensionButton.foreground` | Button foreground for extension actions |
| `extensionButton.hoverBackground` | Button hover background for extension actions |
| `extensionButton.separator` | Button separator for extension actions |
| `extensionButton.border` | Button border for extension actions |
| `extensionBadge.remoteBackground` | Remote badge background |
| `extensionBadge.remoteForeground` | Remote badge foreground |
| `extensionIcon.starForeground` | Extension ratings icon |
| `extensionIcon.verifiedForeground` | Verified publisher icon |
| `extensionIcon.preReleaseForeground` | Pre-release extension icon |
| `extensionIcon.sponsorForeground` | Sponsored extension icon |
| `extensionIcon.privateForeground` | Private extension icon |
| `mcpIcon.starForeground` | MCP starred icon |

## 34. Quick Picker

| Key | Description |
|-----|-------------|
| `pickerGroup.border` | Quick Open grouping border |
| `pickerGroup.foreground` | Quick Open grouping label |
| `quickInput.background` | Quick input background |
| `quickInput.foreground` | Quick input foreground |
| `quickInputList.focusBackground` | Focused item background |
| `quickInputList.focusForeground` | Focused item foreground |
| `quickInputList.focusIconForeground` | Focused item icon foreground |
| `quickInputTitle.background` | Title background |

## 35. Keybinding Label

| Key | Description |
|-----|-------------|
| `keybindingLabel.background` | Label background |
| `keybindingLabel.foreground` | Label foreground |
| `keybindingLabel.border` | Label border |
| `keybindingLabel.bottomBorder` | Label bottom border |

## 36. Keyboard Shortcut Table

| Key | Description |
|-----|-------------|
| `keybindingTable.headerBackground` | Table header background |
| `keybindingTable.rowsBackground` | Table alternating rows background |

## 37. Integrated Terminal

### Core Terminal
| Key | Description |
|-----|-------------|
| `terminal.background` | Terminal viewport background |
| `terminal.border` | Border separating split panes |
| `terminal.foreground` | Terminal default foreground |
| `terminal.selectionBackground` | Selection background |
| `terminal.selectionForeground` | Selection foreground |
| `terminal.inactiveSelectionBackground` | Selection background when unfocused |
| `terminal.findMatchBackground` | Current search match |
| `terminal.findMatchBorder` | Current search match border |
| `terminal.findMatchHighlightBackground` | Other search matches |
| `terminal.findMatchHighlightBorder` | Other search matches border |
| `terminal.hoverHighlightBackground` | Link hover highlight |
| `terminalCursor.background` | Cursor background |
| `terminalCursor.foreground` | Cursor foreground |
| `terminal.dropBackground` | Background when dragging on terminals |
| `terminal.tab.activeBorder` | Active terminal tab side border |
| `terminal.initialHintForeground` | Initial hint foreground |

### ANSI Colors
| Key | Description |
|-----|-------------|
| `terminal.ansiBlack` | Black ANSI color |
| `terminal.ansiRed` | Red ANSI color |
| `terminal.ansiGreen` | Green ANSI color |
| `terminal.ansiYellow` | Yellow ANSI color |
| `terminal.ansiBlue` | Blue ANSI color |
| `terminal.ansiMagenta` | Magenta ANSI color |
| `terminal.ansiCyan` | Cyan ANSI color |
| `terminal.ansiWhite` | White ANSI color |
| `terminal.ansiBrightBlack` | Bright black ANSI color |
| `terminal.ansiBrightRed` | Bright red ANSI color |
| `terminal.ansiBrightGreen` | Bright green ANSI color |
| `terminal.ansiBrightYellow` | Bright yellow ANSI color |
| `terminal.ansiBrightBlue` | Bright blue ANSI color |
| `terminal.ansiBrightMagenta` | Bright magenta ANSI color |
| `terminal.ansiBrightCyan` | Bright cyan ANSI color |
| `terminal.ansiBrightWhite` | Bright white ANSI color |

### Terminal Command Decorations
| Key | Description |
|-----|-------------|
| `terminalCommandDecoration.defaultBackground` | Default command decoration |
| `terminalCommandDecoration.successBackground` | Successful command decoration |
| `terminalCommandDecoration.errorBackground` | Error command decoration |

### Terminal Overview Ruler
| Key | Description |
|-----|-------------|
| `terminalOverviewRuler.cursorForeground` | Cursor marker |
| `terminalOverviewRuler.findMatchForeground` | Find match marker |
| `terminalOverviewRuler.border` | Overview ruler left-side border |

### Terminal Sticky Scroll
| Key | Description |
|-----|-------------|
| `terminalStickyScroll.background` | Sticky scroll background |
| `terminalStickyScroll.border` | Sticky scroll border |
| `terminalStickyScrollHover.background` | Sticky scroll hover background |

### Terminal Command Guide
| Key | Description |
|-----|-------------|
| `terminalCommandGuide.foreground` | Command guide foreground (left of command output on hover) |

### Terminal Symbol Icons
| Key | Description |
|-----|-------------|
| `terminalSymbolIcon.aliasForeground` | Alias icon in terminal suggestions |
| `terminalSymbolIcon.branchForeground` | Branch icon in terminal suggestions |
| `terminalSymbolIcon.commitForeground` | Commit icon in terminal suggestions |
| `terminalSymbolIcon.flagForeground` | Flag icon in terminal suggestions |
| `terminalSymbolIcon.optionForeground` | Option icon in terminal suggestions |
| `terminalSymbolIcon.optionValueForeground` | Enum member icon in terminal suggestions |
| `terminalSymbolIcon.methodForeground` | Method icon in terminal suggestions |
| `terminalSymbolIcon.argumentForeground` | Argument icon in terminal suggestions |
| `terminalSymbolIcon.inlineSuggestionForeground` | Inline suggestion icon |
| `terminalSymbolIcon.fileForeground` | File icon in terminal suggestions |
| `terminalSymbolIcon.folderForeground` | Folder icon in terminal suggestions |
| `terminalSymbolIcon.pullRequestDoneForeground` | Completed PR icon |
| `terminalSymbolIcon.pullRequestForeground` | PR icon in terminal suggestions |
| `terminalSymbolIcon.remoteForeground` | Remote icon in terminal suggestions |
| `terminalSymbolIcon.stashForeground` | Stash icon in terminal suggestions |
| `terminalSymbolIcon.symbolText` | Plaintext suggestion foreground |
| `terminalSymbolIcon.symbolicLinkFileForeground` | Symbolic link file icon |
| `terminalSymbolIcon.symbolicLinkFolderForeground` | Symbolic link folder icon |
| `terminalSymbolIcon.tagForeground` | Tag icon in terminal suggestions |

## 38. Debug Colors

| Key | Description |
|-----|-------------|
| `debugToolBar.background` | Debug toolbar background |
| `debugToolBar.border` | Debug toolbar border |
| `editor.stackFrameHighlightBackground` | Top stack frame highlight |
| `editor.focusedStackFrameHighlightBackground` | Focused stack frame highlight |
| `editor.inlineValuesForeground` | Inline value text color |
| `editor.inlineValuesBackground` | Inline value background |
| `debugView.exceptionLabelForeground` | Exception label foreground (Call Stack) |
| `debugView.exceptionLabelBackground` | Exception label background (Call Stack) |
| `debugView.stateLabelForeground` | State label foreground (Call Stack) |
| `debugView.stateLabelBackground` | State label background (Call Stack) |
| `debugView.valueChangedHighlight` | Value change highlight in debug views |
| `debugTokenExpression.name` | Token name foreground in debug views |
| `debugTokenExpression.value` | Token value foreground |
| `debugTokenExpression.string` | String foreground in debug views |
| `debugTokenExpression.boolean` | Boolean foreground in debug views |
| `debugTokenExpression.number` | Number foreground in debug views |
| `debugTokenExpression.error` | Expression error foreground |
| `debugTokenExpression.type` | Token type foreground |

## 39. Testing

| Key | Description |
|-----|-------------|
| `testing.runAction` | Run icons in editor |
| `testing.iconErrored` | Errored icon in test explorer |
| `testing.iconFailed` | Failed icon in test explorer |
| `testing.iconPassed` | Passed icon in test explorer |
| `testing.iconQueued` | Queued icon in test explorer |
| `testing.iconUnset` | Unset icon in test explorer |
| `testing.iconSkipped` | Skipped icon in test explorer |
| `testing.iconErrored.retired` | Retired errored icon |
| `testing.iconFailed.retired` | Retired failed icon |
| `testing.iconPassed.retired` | Retired passed icon |
| `testing.iconQueued.retired` | Retired queued icon |
| `testing.iconUnset.retired` | Retired unset icon |
| `testing.iconSkipped.retired` | Retired skipped icon |
| `testing.peekBorder` | Peek view border and arrow |
| `testing.peekHeaderBackground` | Peek view header background |
| `testing.message.error.lineBackground` | Error message margin background |
| `testing.message.info.decorationForeground` | Info message text color |
| `testing.message.info.lineBackground` | Info message margin background |
| `testing.messagePeekBorder` | Logged message peek view border |
| `testing.messagePeekHeaderBackground` | Logged message peek view header |
| `testing.coveredBackground` | Covered text background |
| `testing.coveredBorder` | Covered text border |
| `testing.coveredGutterBackground` | Gutter for covered regions |
| `testing.uncoveredBranchBackground` | Uncovered branch widget background |
| `testing.uncoveredBackground` | Uncovered text background |
| `testing.uncoveredBorder` | Uncovered text border |
| `testing.uncoveredGutterBackground` | Gutter for uncovered regions |
| `testing.coverCountBadgeBackground` | Execution count badge background |
| `testing.coverCountBadgeForeground` | Execution count badge foreground |
| `testing.message.error.badgeBackground` | Error message badge background |
| `testing.message.error.badgeBorder` | Error message badge border |
| `testing.message.error.badgeForeground` | Error message badge foreground |

## 40. Welcome Page

| Key | Description |
|-----|-------------|
| `welcomePage.background` | Welcome page background |
| `welcomePage.progress.background` | Progress bar foreground (note: name is swapped in docs) |
| `welcomePage.progress.foreground` | Progress bar background (note: name is swapped in docs) |
| `welcomePage.tileBackground` | Tile background |
| `welcomePage.tileHoverBackground` | Tile hover background |
| `welcomePage.tileBorder` | Tile border |
| `walkThrough.embeddedEditorBackground` | Interactive Playground embedded editor background |
| `walkthrough.stepTitle.foreground` | Walkthrough step heading foreground |

## 41. Git Decoration

| Key | Description |
|-----|-------------|
| `gitDecoration.addedResourceForeground` | Added resource color |
| `gitDecoration.modifiedResourceForeground` | Modified resource color |
| `gitDecoration.deletedResourceForeground` | Deleted resource color |
| `gitDecoration.renamedResourceForeground` | Renamed/copied resource color |
| `gitDecoration.stageModifiedResourceForeground` | Staged modification color |
| `gitDecoration.stageDeletedResourceForeground` | Staged deletion color |
| `gitDecoration.untrackedResourceForeground` | Untracked resource color |
| `gitDecoration.ignoredResourceForeground` | Ignored resource color |
| `gitDecoration.conflictingResourceForeground` | Conflicting resource color |
| `gitDecoration.submoduleResourceForeground` | Submodule resource color |
| `git.blame.editorDecorationForeground` | Blame editor decoration color |

## 42. Source Control Graph

| Key | Description |
|-----|-------------|
| `scmGraph.historyItemHoverLabelForeground` | History item hover label foreground |
| `scmGraph.foreground1` | Graph foreground color (1) |
| `scmGraph.foreground2` | Graph foreground color (2) |
| `scmGraph.foreground3` | Graph foreground color (3) |
| `scmGraph.foreground4` | Graph foreground color (4) |
| `scmGraph.foreground5` | Graph foreground color (5) |
| `scmGraph.historyItemHoverAdditionsForeground` | History hover additions foreground |
| `scmGraph.historyItemHoverDeletionsForeground` | History hover deletions foreground |
| `scmGraph.historyItemRefColor` | History item reference color |
| `scmGraph.historyItemRemoteRefColor` | History item remote reference color |
| `scmGraph.historyItemBaseRefColor` | History item base reference color |
| `scmGraph.historyItemHoverDefaultLabelForeground` | History hover default label foreground |
| `scmGraph.historyItemHoverDefaultLabelBackground` | History hover default label background |

## 43. Settings Editor

| Key | Description |
|-----|-------------|
| `settings.headerForeground` | Section header or active title foreground |
| `settings.modifiedItemIndicator` | Modified setting indicator line |
| `settings.dropdownBackground` | Settings dropdown background |
| `settings.dropdownForeground` | Settings dropdown foreground |
| `settings.dropdownBorder` | Settings dropdown border |
| `settings.dropdownListBorder` | Settings dropdown list border |
| `settings.checkboxBackground` | Settings checkbox background |
| `settings.checkboxForeground` | Settings checkbox foreground |
| `settings.checkboxBorder` | Settings checkbox border |
| `settings.rowHoverBackground` | Settings row hover background |
| `settings.textInputBackground` | Text input background |
| `settings.textInputForeground` | Text input foreground |
| `settings.textInputBorder` | Text input border |
| `settings.numberInputBackground` | Number input background |
| `settings.numberInputForeground` | Number input foreground |
| `settings.numberInputBorder` | Number input border |
| `settings.focusedRowBackground` | Focused setting row background |
| `settings.focusedRowBorder` | Focused row top and bottom border |
| `settings.headerBorder` | Header container border |
| `settings.sashBorder` | Settings editor splitview sash border |
| `settings.settingsHeaderHoverForeground` | Section header or hovered title foreground |

## 44. Breadcrumbs

| Key | Description |
|-----|-------------|
| `breadcrumb.foreground` | Breadcrumb items color |
| `breadcrumb.background` | Breadcrumb items background |
| `breadcrumb.focusForeground` | Focused breadcrumb items color |
| `breadcrumb.activeSelectionForeground` | Selected breadcrumb items color |
| `breadcrumbPicker.background` | Breadcrumb item picker background |

## 45. Snippets

| Key | Description |
|-----|-------------|
| `editor.snippetTabstopHighlightBackground` | Tabstop highlight background |
| `editor.snippetTabstopHighlightBorder` | Tabstop highlight border |
| `editor.snippetFinalTabstopHighlightBackground` | Final tabstop highlight background |
| `editor.snippetFinalTabstopHighlightBorder` | Final tabstop highlight border |

## 46. Symbol Icons

| Key | Description |
|-----|-------------|
| `symbolIcon.arrayForeground` | Array symbol |
| `symbolIcon.booleanForeground` | Boolean symbol |
| `symbolIcon.classForeground` | Class symbol |
| `symbolIcon.colorForeground` | Color symbol |
| `symbolIcon.constantForeground` | Constant symbol |
| `symbolIcon.constructorForeground` | Constructor symbol |
| `symbolIcon.enumeratorForeground` | Enumerator symbol |
| `symbolIcon.enumeratorMemberForeground` | Enumerator member symbol |
| `symbolIcon.eventForeground` | Event symbol |
| `symbolIcon.fieldForeground` | Field symbol |
| `symbolIcon.fileForeground` | File symbol |
| `symbolIcon.folderForeground` | Folder symbol |
| `symbolIcon.functionForeground` | Function symbol |
| `symbolIcon.interfaceForeground` | Interface symbol |
| `symbolIcon.keyForeground` | Key symbol |
| `symbolIcon.keywordForeground` | Keyword symbol |
| `symbolIcon.methodForeground` | Method symbol |
| `symbolIcon.moduleForeground` | Module symbol |
| `symbolIcon.namespaceForeground` | Namespace symbol |
| `symbolIcon.nullForeground` | Null symbol |
| `symbolIcon.numberForeground` | Number symbol |
| `symbolIcon.objectForeground` | Object symbol |
| `symbolIcon.operatorForeground` | Operator symbol |
| `symbolIcon.packageForeground` | Package symbol |
| `symbolIcon.propertyForeground` | Property symbol |
| `symbolIcon.referenceForeground` | Reference symbol |
| `symbolIcon.snippetForeground` | Snippet symbol |
| `symbolIcon.stringForeground` | String symbol |
| `symbolIcon.structForeground` | Struct symbol |
| `symbolIcon.textForeground` | Text symbol |
| `symbolIcon.typeParameterForeground` | Type parameter symbol |
| `symbolIcon.unitForeground` | Unit symbol |
| `symbolIcon.variableForeground` | Variable symbol |

## 47. Debug Icons

| Key | Description |
|-----|-------------|
| `debugIcon.breakpointForeground` | Breakpoint icon |
| `debugIcon.breakpointDisabledForeground` | Disabled breakpoint icon |
| `debugIcon.breakpointUnverifiedForeground` | Unverified breakpoint icon |
| `debugIcon.breakpointCurrentStackframeForeground` | Current breakpoint stack frame icon |
| `debugIcon.breakpointStackframeForeground` | All breakpoint stack frames icon |
| `debugIcon.startForeground` | Start debugging icon |
| `debugIcon.pauseForeground` | Pause icon |
| `debugIcon.stopForeground` | Stop icon |
| `debugIcon.disconnectForeground` | Disconnect icon |
| `debugIcon.restartForeground` | Restart icon |
| `debugIcon.stepOverForeground` | Step over icon |
| `debugIcon.stepIntoForeground` | Step into icon |
| `debugIcon.stepOutForeground` | Step out icon |
| `debugIcon.continueForeground` | Continue icon |
| `debugIcon.stepBackForeground` | Step back icon |
| `debugConsole.infoForeground` | Debug console info message foreground |
| `debugConsole.warningForeground` | Debug console warning message foreground |
| `debugConsole.errorForeground` | Debug console error message foreground |
| `debugConsole.sourceForeground` | Debug console source filename foreground |
| `debugConsoleInputIcon.foreground` | Debug console input marker icon |

## 48. Notebook

| Key | Description |
|-----|-------------|
| `notebook.editorBackground` | Notebook background |
| `notebook.cellBorderColor` | Cell border color |
| `notebook.cellHoverBackground` | Cell hover background |
| `notebook.cellInsertionIndicator` | Cell insertion indicator |
| `notebook.cellStatusBarItemHoverBackground` | Cell status bar item hover background |
| `notebook.cellToolbarSeparator` | Cell bottom toolbar separator |
| `notebook.cellEditorBackground` | Cell editor background |
| `notebook.focusedCellBackground` | Focused cell background |
| `notebook.focusedCellBorder` | Focused cell indicator borders |
| `notebook.focusedEditorBorder` | Cell editor border |
| `notebook.inactiveFocusedCellBorder` | Cell borders when focused but primary focus outside editor |
| `notebook.inactiveSelectedCellBorder` | Cell borders when multiple cells selected |
| `notebook.outputContainerBackgroundColor` | Output container background |
| `notebook.outputContainerBorderColor` | Output container border |
| `notebook.selectedCellBackground` | Selected cell background |
| `notebook.selectedCellBorder` | Selected but unfocused cell borders |
| `notebook.symbolHighlightBackground` | Highlighted cell background |
| `notebookScrollbarSlider.activeBackground` | Notebook scrollbar clicked background |
| `notebookScrollbarSlider.background` | Notebook scrollbar slider background |
| `notebookScrollbarSlider.hoverBackground` | Notebook scrollbar hover background |
| `notebookStatusErrorIcon.foreground` | Cell status bar error icon |
| `notebookStatusRunningIcon.foreground` | Cell status bar running icon |
| `notebookStatusSuccessIcon.foreground` | Cell status bar success icon |
| `notebookEditorOverviewRuler.runningCellForeground` | Running cell overview ruler color |

## 49. Chart Colors

| Key | Description |
|-----|-------------|
| `charts.foreground` | Chart text contrast color |
| `charts.lines` | Lines in charts |
| `charts.red` | Red elements in charts |
| `charts.blue` | Blue elements in charts |
| `charts.yellow` | Yellow elements in charts |
| `charts.orange` | Orange elements in charts |
| `charts.green` | Green elements in charts |
| `charts.purple` | Purple elements in charts |
| `chart.line` | Chart line color |
| `chart.axis` | Chart axis color |
| `chart.guide` | Chart guide line |

## 50. Ports

| Key | Description |
|-----|-------------|
| `ports.iconRunningProcessForeground` | Icon for port with running process |

## 51. Comments View

| Key | Description |
|-----|-------------|
| `commentsView.resolvedIcon` | Resolved comments icon |
| `commentsView.unresolvedIcon` | Unresolved comments icon |

## 52. Action Bar

| Key | Description |
|-----|-------------|
| `actionBar.toggledBackground` | Toggled action items background |

## 53. Simple Find Widget

| Key | Description |
|-----|-------------|
| `simpleFindWidget.sashBorder` | Sash border color |

## 54. Gauge

| Key | Description |
|-----|-------------|
| `gauge.background` | Gauge background |
| `gauge.foreground` | Gauge foreground |
| `gauge.border` | Gauge border |
| `gauge.warningBackground` | Gauge warning background |
| `gauge.warningForeground` | Gauge warning foreground |
| `gauge.errorBackground` | Gauge error background |
| `gauge.errorForeground` | Gauge error foreground |

## 55. Markdown Alerts

| Key | Description |
|-----|-------------|
| `markdownAlert.note.foreground` | Note alert foreground |
| `markdownAlert.tip.foreground` | Tip alert foreground |
| `markdownAlert.important.foreground` | Important alert foreground |
| `markdownAlert.warning.foreground` | Warning alert foreground |
| `markdownAlert.caution.foreground` | Caution alert foreground |

## 56. Agent Session

| Key | Description |
|-----|-------------|
| `agentSessionReadIndicator.foreground` | Read indicator foreground |
| `agentSessionSelectedBadge.border` | Selected item badge border |
| `agentSessionSelectedUnfocusedBadge.border` | Selected unfocused item badge border |
| `agentStatusIndicator.background` | Agent status indicator background in titlebar |
| `aiCustomizationManagement.sashBorder` | Chat Customization Management splitview sash border |

---

## Summary Statistics

Total unique color target keys: ~900+
Total UI area groups: 56

### Theme Engine Mapping Suggestions

For a palette-based theme engine, these are the logical color groups to map:

**High-impact (most visible):**
- editor.background/foreground
- activityBar.background/foreground
- sideBar.background/foreground
- titleBar.activeBackground/activeForeground
- statusBar.background/foreground
- tab.activeBackground/activeForeground/inactiveBackground
- panel.background + panelTitle colors
- terminal.background/foreground + ANSI colors
- editor line numbers, cursor, selection

**Semantic colors (map to palette accents):**
- Error colors (red): editorError.*, testing.iconFailed, etc.
- Warning colors (yellow/orange): editorWarning.*, testing.iconQueued, etc.
- Info colors (blue): editorInfo.*, notificationsInfoIcon, etc.
- Success colors (green): testing.iconPassed, terminalCommandDecoration.success, etc.
- Modified/Added/Deleted (git): gitDecoration.*, editorGutter.modified/added/deleted

**Widget/chrome colors (derive from base):**
- All widget backgrounds/borders can derive from editor.background
- All input/button/dropdown can share common base + accent
- Badge, progress bar, scrollbar derive from accent + surface colors
