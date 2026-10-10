# ZMK — TOTEM Firmware

ZMK user config for TOTEM 38-key split keyboard. Seeed XIAO BLE (nRF52840).

Edit `config/totem.keymap`; the root keymap overrides the shield built-in.
Matrix: 38 keys. Rows 0-1 have 10 columns, row 2 has 12 (extra pinky
flanking), row 3 has 6 (thumbs). The flanking pinkies (positions 20 and 31) are
wired on electrical row 3, `RC(3,0)` and `RC(3,9)`. Hold-tap defaults live in
the `&mt {};` block, custom behaviors in `/behaviors {};`.

## Structure

```
config/
  totem.keymap              # Root keymap — THIS IS THE SOURCE OF TRUTH
  totem.conf                # Board-level config (sleep, idle, BT)
  west.yml                  # West manifest (ZMK revision, pinned to a main commit)
  boards/shields/totem/     # Shield definitions (dtsi, overlay, Kconfig)
    totem_left.overlay      # Left half column GPIOs
    totem_right.overlay     # Right half (col-offset=5) + column GPIOs
    totem.dtsi              # Matrix transform (10 cols, 4 rows) + kscan definition
```

## Layers

Layer table, thumb bindings and combos: `docs/totem/keymap.md` (the only
hand-written copy; it is published by the docs site). Update it in the same
commit as any layer, thumb or combo change to `config/totem.keymap`. Do not
repeat the table here.

## Custom Behaviors

### Hold-taps

- `mt_left` (balanced, 250ms, hold-trigger-on-release, require-prior-idle=100)
  - Trigger positions (22): right hand 5-9, 15-19, 26-31 and all six thumbs 32-37
- `mt_right` (balanced, 250ms, hold-trigger-on-release, require-prior-idle=100)
  - Trigger positions (22): left hand 0-4, 10-14, 20-25 and all six thumbs 32-37
- `lt_caps` (150ms tap): `&lt` on hold, caps-word on tap
- `sk_mo` (150ms tap): `&mo` on hold, `&sk` on tap

### Mod-morphs (6)

`comma_semicolon`, `period_colon`, `cmd_tab` (TAB→F21 with GUI), `cmd_stb` (LS(TAB)→F22 with GUI), `bwd_dwd`, `caps` (caps_word→CAPSLOCK with shift).

### Combos (2)

`enter` (16 17) and `bs_df` (12 13), both BASE only. See
`docs/totem/keymap.md#combos`.

## Validate

```sh
python3 -m venv /tmp/kv && /tmp/kv/bin/pip install keymap-drawer
/tmp/kv/bin/keymap parse -z config/totem.keymap -o /tmp/keymap.yaml
/tmp/kv/bin/keymap draw /tmp/keymap.yaml -o /tmp/keymap.svg
```

## Build (needs ZMK SDK)

```sh
west build -b xiao_ble//zmk -d build/left -s zmk/app -- -DSHIELD=totem_left
west build -b xiao_ble//zmk -d build/right -s zmk/app -- -DSHIELD=totem_right
```

CI builds via `../.github/workflows/zmk-build.yml`. Parse without errors means the
keymap is valid.

## Docs preview

```sh
npm install honkit
npx honkit serve          # http://localhost:4000
```

Docs deploy on push to `main` touching `docs/**` or `book.json`
(`../.github/workflows/zmk-docs.yml`). The keymap SVG is generated in CI by
keymap-drawer. To regenerate it locally into the docs tree:

```sh
/tmp/kv/bin/keymap parse -z config/totem.keymap -o /tmp/keymap.yaml
/tmp/kv/bin/keymap draw /tmp/keymap.yaml -o docs/totem/images/keymap.svg
```

## Known Issues

- Shield keymap (`config/boards/shields/totem/totem.keymap`) is dead code
- 3 empty .conf files in shield dir
- `boards/shields/.gitkeep` is confusing/wrong
