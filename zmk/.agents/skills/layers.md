---
name: layers
description: Layer reference for TOTEM root keymap. 4 layers (BASE/NAV/SYM/FUN).
---

# Layer Reference

Layer triggers, thumb bindings and combos: `docs/totem/keymap.md`. That page
is the only hand-written table; the notes below are a summary of layer
contents. Source of truth is `config/totem.keymap`.

## BASE (0): QWERTY

QWERTY alphas. See `docs/totem/keymap.md` for thumbs and the outer keys.

## NAV (1) — Numbers + Shortcuts

Numbers 1-0 on the top row. Cmd+A/S/D/F on the left home row as hold-taps (hold Globe, Alt, Ctrl, Cmd).
`cmd_tab`/`cmd_stb` (F21/F22 with Cmd held) for app switching.
Arrows on the right home row. Home/PgDn/PgUp/End on the bottom row.

## SYM (2) — Symbols

Shifted symbols (!@#$%^&* etc.). Braces and brackets, `=`, and `` ` `` `"` `'` `~` hold-taps on the right home row.
Pipe, angle brackets and parens on the left bottom row; Cmd+N/M/,/./slash on the right.

## FUN (3) — F-Keys + Bluetooth + Media

Held from either outer pinky. F1-F12. BT_SEL 0-3 (left-right mirrored for both-hand reach), BT clear.
Brightness down/up, volume down/up, mute, output toggle.
