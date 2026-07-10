# ZMK — TOTEM Firmware

ZMK user config for TOTEM 36-key split keyboard. Seeed XIAO BLE (nRF52840).

## Structure

```
config/
  totem.keymap              # Root keymap — THIS IS THE SOURCE OF TRUTH
  totem.conf                # Board-level config (sleep, idle, BT)
  west.yml                  # West manifest (ZMK revision — currently floating on main)
  boards/shields/totem/     # Shield definitions (dtsi, overlay, Kconfig)
    totem.keymap            # DEAD CODE — uses different layout than root
    totem_left.overlay      # Left half column GPIOs
    totem_right.overlay     # Right half (col-offset=5) + column GPIOs
    totem.dtsi              # Matrix transform (10 cols, 4 rows) + kscan definition
```

## Layers

Indexed 0-4 (BASE/NAV/SYM/MOO/fun). Layer 5 used by combos for del actions.

| Layer | Name | Column regions |
|-------|------|---------------|
| 0 | BASE | QWERTY + homerow mods + thumbs |
| 1 | left/NAV | Numbers + arrows + cmd shortcuts |
| 2 | right/SYM | Symbols + brackets + macros |
| 3 | middle/MOO | F-keys + sticky mods |
| 4 | fun | BT + media + brightness (mirrored for left/right reach) |

## Custom Behaviors

### Hold-taps

- `mt_left` (balanced, 250ms, hold-trigger-on-release, require-prior-idle=100)
  - Trigger positions (22): right-hand keys at RC(0,5..9), RC(1,5..9), RC(2,5..9), RC(3,5..7)
- `mt_right` (balanced, 250ms, hold-trigger-on-release, require-prior-idle=100)
  - Trigger positions (22): left-hand keys at RC(0,0..4), RC(1,0..4), RC(2,0..4), RC(3,0..4), RC(2,12-13)
- `lt_caps` (150ms tap): `&lt` on hold, caps-word on tap
- `sk_mo` (150ms tap): `&mo` on hold, `&sk` on tap

### Mod-morphs (6)

`comma_semicolon`, `period_colon`, `cmd_tab` (TAB→F21 with GUI), `cmd_stb` (LS(TAB)→F22 with GUI), `bwd_dwd`, `caps` (caps_word→CAPSLOCK with shift).

### Combos (6)

All on BASE layer unless noted:
- RC(0,4)+RC(1,4) = enter
- RC(0,2)+RC(1,2) = bwd_dwd (exit = shift+bwd → LA(DEL))
- RC(0,5)+RC(1,5) on NAV = yank_line macro
- RC(0,6)+RC(1,6) on NAV = yank_inner_word macro
- RC(0,2)+RC(1,2) = `&lt 5 BACKSPACE` (usually del key)
- RC(0,1)+RC(1,1)+RC(2,1) = LA(BACKSPACE)

## Macros (7)

Typing: leq, geq, left_arrow, right_arrow, colon_equals
Vim: yank_inner_word (esc y i w i), yank_line (esc V Y I)

## Validate

```sh
python3 -m venv /tmp/kv && /tmp/kv/bin/pip install keymap-drawer
/tmp/kv/bin/keymap parse -z config/totem.keymap -o /tmp/keymap.yaml
/tmp/kv/bin/keymap draw /tmp/keymap.yaml -o /tmp/keymap.svg
```

## Build

```sh
west build -b xiao_ble -d build/left -s zmk/app -- -DSHIELD=totem_left
west build -b xiao_ble -d build/right -s zmk/app -- -DSHIELD=totem_right
```

CI builds via `.github/workflows/build.yml`.

## Known Issues

- Shield keymap (`config/boards/shields/totem/totem.keymap`) is dead code
- `west.yml` uses `revision: main` (floating — pin to commit)
- 3 empty .conf files in shield dir
- `boards/shields/.gitkeep` is confusing/wrong
