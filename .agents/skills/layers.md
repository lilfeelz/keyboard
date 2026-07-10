---
name: layers
description: Layer reference for TOTEM root keymap. 5 active layers (BASE/NAV/SYM/MOO/fun) plus combo-only layer 5.
---

# Layer Reference

## BASE (0) — QWERTY

Left hand: Q W E R T, A S D F G, Y X C V B, SK_SHFT MO1 ESC
Right hand: Y U I O P, H J K L -, N M , . TAB, SPACE MO2 ENTER

Thumbs:
- Left thumb: tap = caps_word / hold = MOO(4). Hold-tap via `&lt_caps`.
- Right thumb: tap = backspace / hold = NAV(1). Hold-tap via `&sk_mo`.
- Space: both thumbs.
- SYM(2): right thumb hold.

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
Media play/pause, volume, previous/next.

## Delete Layer (5, combo-only)

Accessed via combo RC(0,2)+RC(1,2). Provides BACKSPACE, DELETE, ALT, navigation.
Combo times out after chord-time; holding combos for `require-prior-idle-ms` may activate the combo behavior on the BASE layer instead.
