---
name: layers
description: Layer reference for TOTEM root keymap. 5 active layers (BASE/NAV/SYM/MOO/fun) plus combo-only layer 5.
---

# Layer Reference

Layer triggers, thumb bindings and combos: `docs/totem/keymap.md`. That page
is the only hand-written table; the notes below are a summary of layer
contents. Source of truth is `config/totem.keymap`.

## BASE (0): QWERTY

QWERTY alphas. See `docs/totem/keymap.md` for thumbs and the outer keys.

## NAV (1) — Numbers + Shortcuts

Numbers 1-0 on homerow. Mod-shortcuts (Cmd+A, Cmd+S, etc.) via hold-tap.
F21/F22 for app switching (WezTerm intercepts for alt-tab).
Arrows on home row. Home/PgDn/PgUp/End on bottom row.

## SYM (2) — Symbols

Shifted symbols (!@#$%^&* etc.). Brackets. Equal sign with mod-morphs for ≤, ≥, ←, →.
Colon/semicolon, period/comma mod-morphs reversed.

## MOO (3) — F-Keys + Sticky Mods

F1-F20 on homerow. Sticky modifiers (GUI, Ctrl, Alt, Shift) on both left and right hand.

## FUN (4) — Bluetooth + Media

BT0-BT4 select (left-right mirrored for both-hand reach). Brightness up/down.
Mute, volume down/up. BT clear, output toggle.

## Delete Layer (5, combo-only)

Meant to be held via the `del` combo on positions 12+13 (D+F), but `bs_df` on the
same positions is defined first and always wins, so the layer is unreachable.
Alt, Delete, Backspace on the left home row; Shift+arrows on the right.
Combo times out after chord-time; holding combos for `require-prior-idle-ms` may activate the combo behavior on the BASE layer instead.
