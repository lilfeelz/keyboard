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
| `TotemKit/Sources/TotemCore/default.kbd` | bundled config: `~/.config/kanata/kanata.kbd` on the TOTEM grid |

## Config

Same syntax as kanata: `defcfg defvar defalias defsrc deflayer defchordsv2`. `defsrc` describes
the touch grid: one line per row, `gap:w` leaves space, `name:w` sets a key's width. Supported
actions: keys with `S- C- A- M-` prefixes, modifiers, `tap-hold(-press|-release)`, `one-shot*`,
`layer-while-held`/`layer-toggle`/`layer-switch`, `fork`, `unshift`, `multi`, `macro`,
`unicode`, `caps-word*`, `switch` (`and or not layer base-layer`, plus `mode text|terminal`), `rpt`. Extras: `nextkbd`,
`dismiss`, `term`, `copy`, `cut`, `paste`, `(text "...")`, and the swipe wrappers
`(swipe-delete a)` / `(swipe-cursor a)`: `a` on tap and hold, but a drag deletes characters
(previewed by moving the cursor back, applied on lift) or moves the cursor (vertical drag moves
by lines). The default puts them on the backspace and esc thumbs.

Edit it in the app (checked as you type, errors carry line:col) and save; the keyboard reloads
it each time it appears. The keyboard reads the app group only with Full Access, otherwise it
runs the bundled default.

## What iOS allows

A keyboard extension can insert text, delete backward and move the cursor. So:

* word/line delete (`A-bspc`, `M-bspc`, `A-del`), arrows, `A-`/`M-`arrows, home/end are emulated
  from the text around the cursor
* `M-c M-x M-v` copy, cut, paste (Full Access)
* `M-z` / `M-S-z` undo and redo this keyboard's own edits (typing by word, deletes, swipes,
  cursor moves); the host app's undo stack is out of reach. In terminal mode `M-z` sends `^_`.
* the `>_` key switches to terminal mode: `C-x`, `A-x`, esc, arrows, F1-F12 go out as control
  codes and xterm sequences (Blink, SSH apps). Other Cmd chords go out as kitty keyboard
  protocol sequences with the super bit (`M-p` is `ESC[112;9u`, `M-left` `ESC[1;9D`), which
  attach (lilfeelz/workspaces, attach/) takes as its own hotkeys
* in text mode, other Cmd shortcuts, selection (`S-`arrows), media keys: impossible, drawn dimmed. iOS
  gives keyboards no selection API and no way to reach the app's commands (select all, save,
  find). In the bundled config the nav layer's ⌘A ⌘S ⌘D ⌘F slots are sticky ⇧ ⌥ ⌃ ⌘ (tap, then the next
  key gets it; with the arrows that is word and line jumps), `M-g` is `rpt`, the esc thumb hides
  the keyboard in text mode, and the sym layer's `fn` slot is `?`
* not shown in secure fields or while a hardware keyboard is attached

## Build

```bash
make test         # core unit tests + UI test on the "Totem iPad Air 11-inch (M4)" simulator
make device DEVICE=<devicectl id>
```

Then Settings > General > Keyboard > Keyboards > Add New Keyboard > Totem, and Allow Full Access.

CI (`../.github/workflows/kanata-ios.yml`) runs the same from the repo root through
`JakobMelchard/.github` xcode.yml with `working-directory: kanata-ios`.
