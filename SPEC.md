# Digilog — Spec

A macOS menu bar task list inspired by [Ugmonk Analog](https://ugmonk.com/pages/analog).

## Behavior

- Three tabs: **Today**, **Next**, **Someday**.
- Each tab is **always 10 fixed rows**. Empty rows are valid both in the view and on disk.
- Each row is a checkbox + an inline-editable text field.
- Editing happens directly in the row. Clearing a row's text is how you "delete" a task.
- Checked rows render with strikethrough and secondary color.
- No counter, no add button, no quit button, no settings.

## 4 AM reset

Today is keyed by a **logical date** = `now − 4h` (local time).

- 03:59 → file is yesterday's date.
- 04:00 → file flips to today's date.

Yesterday's file is left on disk untouched. There are no timers and no wake-from-sleep handling. Each time the popover appears it recomputes the logical date and re-reads from disk.

## Storage

Files live in `~/Documents/Digilog/`:

| File              | Purpose                          |
|-------------------|----------------------------------|
| `YYYY-MM-DD.md`   | Today list, keyed by logical date |
| `NEXT.md`         | Next list                         |
| `SOMEDAY.md`      | Someday list                      |

Each file contains exactly 10 GFM checkbox lines:

```markdown
- [x] write spec
- [x] merge PR
- [ ] ship digilog
- [ ]
- [ ]
- [ ]
- [ ]
- [ ]
- [ ]
- [ ]
```

### Read rules

- Parse the file line-by-line.
- Recognize lines matching `- [ ] …` (todo) and `- [x] …` / `- [X] …` (done).
- Non-checkbox lines are skipped.
- If the file has fewer than 10 checkbox lines, pad with empty rows.
- If it has more than 10, truncate to the first 10.

### Write rules

- On every mutation (text edit, checkbox toggle), the entire 10-row file is rewritten.
- Format: `- [ ] text` or `- [x] text`. Empty rows are written as `- [ ]` (no trailing space).
- Files are created on first write. The `~/Documents/Digilog/` directory is created on app launch if missing.

## UI

```
┌──────────────────────────────┐
│  [ Today ] [ Next ] [Someday]│
├──────────────────────────────┤
│  ☐ write spec                │
│  ☑ ship PR                   │
│  ☐ call dentist              │
│  ☐                           │
│  ☐                           │
│  ☐                           │
│  ☐                           │
│  ☐                           │
│  ☐                           │
│  ☐                           │
└──────────────────────────────┘
```

- Width 320pt, height 380pt.
- Tabs are a `.segmented` `Picker`.
- Menu bar icon: SF Symbol `checklist`.

## Tech

- SwiftUI `MenuBarExtra` with `.window` style.
- macOS 13.0+.
- `LSUIElement = YES` (no Dock icon).
- Single Swift file: `Digilog/DigilogApp.swift`.

## Out of scope

- Drag to reorder
- More than two task states (in-progress, delegated, etc.)
- Search, archive, undo
- Reset for Next/Someday
- Hotkeys
- Settings UI
- Sync, auth
