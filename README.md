# Digilog

A minimal macOS menu bar task list, inspired by [Ugmonk Analog](https://ugmonk.com/en-de/pages/analog).

Three tabs — **Today**, **Next**, **Someday** — each with 10 fixed rows. Today resets at 4 AM local time. State lives as plain markdown files in `~/Documents/Digilog/`.

See [SPEC.md](SPEC.md) for the full behavioral spec.

## Use

Click the checklist icon in the menu bar. Type into any row, check off items as you go. That's it.

Files are written to `~/Documents/Digilog/` as you type:

```
~/Documents/Digilog/
├── 2026-05-22.md   # Today, keyed by logical date (now − 4h)
├── NEXT.md
└── SOMEDAY.md
```

You can edit those files in any text editor — changes show up next time you open the popover.
