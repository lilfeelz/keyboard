# totem

My [kanata](https://github.com/jtroo/kanata) layout as a custom iOS keyboard (SwiftUI keyboard
extension), configured in kanata's own lisp. Replaces `lilfeelz/keyman`: a Keyman keyboard can
only emit text, so tap-hold, chords, one-shot, caps-word and terminal keys were out of reach.

## Layout

| path | what |
| --- | --- |
| `TotemKit/Sources/TotemCore` | s-expression reader, config parser, key engine, edit translator (pure Swift, `swift test` on macOS) |
| `TotemKit/Sources/TotemUI` | SwiftUI keyboard view, multi-touch surface, controller, app-group config store |
| `Keyboard/` | the `UIInputViewController` extension |
| `App/` | container app: config editor, in-app keyboard to try it, setup notes |
| `TotemKit/Sources/TotemCore/DefaultConfig.swift` | bundled config: `~/.config/kanata/kanata.kbd` on the TOTEM grid |

## Config

Same syntax as kanata: `defcfg defvar defalias defsrc deflayer defchordsv2`. `defsrc` describes
the touch grid: one line per row, `gap:w` leaves space, `name:w` sets a key's width. Supported
actions: keys with `S- C- A- M-` prefixes, modifiers, `tap-hold(-press|-release)`, `one-shot*`,
`layer-while-held`/`layer-toggle`/`layer-switch`, `fork`, `unshift`, `multi`, `macro`,
`unicode`, `caps-word*`, `switch` (`and or not layer base-layer`), `rpt`. Extras: `nextkbd`,
`dismiss`, `term`, `copy`, `cut`, `paste`, `(text "...")`.

Edit it in the app (checked as you type, errors carry line:col) and save; the keyboard reloads
it each time it appears. The keyboard reads the app group only with Full Access, otherwise it
runs the bundled default.

## What iOS allows

A keyboard extension can insert text, delete backward and move the cursor. So:

* word/line delete (`A-bspc`, `M-bspc`, `A-del`), arrows, `A-`/`M-`arrows, home/end are emulated
  from the text around the cursor
* `M-c M-x M-v` copy, cut, paste (Full Access)
* the `>_` key switches to terminal mode: `C-x`, `A-x`, esc, arrows, F1-F12 go out as control
  codes and xterm sequences (Blink, SSH apps)
* other Cmd shortcuts, selection (`S-`arrows), media keys: impossible, drawn dimmed
* not shown in secure fields or while a hardware keyboard is attached

## Build

```bash
make test         # core unit tests + UI test on the "Totem iPad Air 11-inch (M4)" simulator
make device DEVICE=<devicectl id>
```

Then Settings > General > Keyboard > Keyboards > Add New Keyboard > Totem, and Allow Full Access.
