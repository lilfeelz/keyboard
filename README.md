[![Build](https://github.com/lilfeelz/zmk/actions/workflows/build.yml/badge.svg)](https://github.com/lilfeelz/zmk/actions/workflows/build.yml)
[![Docs](https://github.com/lilfeelz/zmk/actions/workflows/docs.yml/badge.svg)](https://lilfeelz.github.io/zmk/)
[![GH Pages](https://img.shields.io/badge/docs-lilfeelz.github.io/zmk-9ee7ff?logo=github&labelColor=0b0d10)](https://lilfeelz.github.io/zmk/)

# TOTEM ZMK Configuration

36-key split column-staggered keyboard firmware for the [TOTEM](https://github.com/GEIGEIGEIST/TOTEM), powered by Seeed XIAO BLE (nRF52840). Built with ZMK.

## Quickstart

### Edit keymap

```sh
# Edit root keymap (this overrides shield built-in)
$EDITOR config/totem.keymap
```

### Validate

```sh
python3 -m venv /tmp/kv
/tmp/kv/bin/pip install keymap-drawer
/tmp/kv/bin/keymap parse -z config/totem.keymap -o /tmp/keymap.yaml
/tmp/kv/bin/keymap draw /tmp/keymap.yaml -o /tmp/keymap.svg
# No errors = valid
```

### Build

Requires ZMK SDK (`west`). CI builds on push.

```sh
west build -b xiao_ble -d build/left -s zmk/app -- -DSHIELD=totem_left
west build -b xiao_ble -d build/right -s zmk/app -- -DSHIELD=totem_right
```

### Docs preview

```sh
npm install honkit
npx honkit serve
# opens http://localhost:4000
```

## Layout

### Matrix (4 rows × 10 cols)

```
   ┌────┬────┬────┬────┬────┐ ┌────┬────┬────┬────┬────┐
   │ SW0│ SW1│ SW2│ SW3│ SW4│ │ SW5│ SW6│ SW7│ SW8│ SW9│  ← row 0
   ├────┼────┼────┼────┼────┤ ├────┼────┼────┼────┼────┤
   │ SW0│ SW1│ SW2│ SW3│ SW4│ │ SW5│ SW6│ SW7│ SW8│ SW9│  ← row 1
┌──╆━━━━╈━━━━╈━━━━╈━━━━╈━━━━┤ ├━━━━╈━━━━╈━━━━╈━━━━╈━━━━╅──┐
│    │ SW0│ SW1│ SW2│ SW3│ SW4│ │ SW5│ SW6│ SW7│ SW8│ SW9│    │ ← row 2 (12 cols)
└──┄┄┄┄╆━━━━╈━━━━╈━━━━┤ ├━━━━╈━━━━╈━━━━╅┄┄┄┄┄┄┘
         │ SW2│ SW3│ SW4│ │ SW5│ SW6│ SW7│      ← row 3 (6 thumbs)
         └────┴────┴────┘ └────┴────┴────┘
```

### Layers and thumb keys

Four layers (BASE, NAV, SYM, FUN). The layer table, thumb bindings and combos live in one place:
[`docs/totem/keymap.md`](docs/totem/keymap.md) (published at
[lilfeelz.github.io/zmk](https://lilfeelz.github.io/zmk/totem/keymap.html)).

## Key Features

- **Homerow mods** via custom `mt_left`/`mt_right` hold-tap (250ms, balanced, hold-trigger-on-release)
- **Caps word**: `&caps_word` with continuation list (underscore, backspace, delete, arrows, etc.)
- **5 combos**: see [`docs/totem/keymap.md`](docs/totem/keymap.md#combos)
- **5 mod-morphs**: comma↔semicolon, period↔colon, cmd+tab↔F21, cmd+shift+tab↔F22, shift+caps
- **5 macros**: ≤, ≥, ←, →, := and vim-style yank-line, yank-inner-word
- **Sticky keys**: one-shot shift on the outer thumb keys; `sk_mo` thumb (hold NAV, tap Backspace)

## Build Targets

| Shield | Board |
|--------|-------|
| `totem_left` | `xiao_ble//zmk` |
| `totem_right` | `xiao_ble//zmk` |
| `settings_reset` | `xiao_ble//zmk` |

## CI/CD

- **build.yml**: Builds firmware on push/PR touching `config/**` or `boards/**`
- **docs.yml**: Generates keymap SVG + honkit docs site, deploys to GH Pages
- **release.yml**: Release-Please on successful build (tag + release notes)

## Structure

```
zmk/
├── config/
│   ├── totem.keymap          # Root keymap (primary, overrides shield)
│   ├── totem.conf            # Board config (sleep, BT, idle)
│   ├── west.yml              # West manifest (ZMK revision: main — FLOATING)
│   └── boards/shields/totem/ # Shield definition (dtsi, overlay, Kconfig)
├── .github/workflows/        # 3 workflows: build, docs, release
├── docs/                     # Honkit documentation site
├── keymap_drawer.config.yaml # SVG rendering config
└── .agents/                  # Agent rules for this repo
```

## Known Issues

- Shield keymap at `config/boards/shields/totem/totem.keymap` is dead code
- `west.yml` pins ZMK to `revision: main` (floating — should pin to commit)
- 3 empty `.conf` files in shield dir
- `boards/shields/.gitkeep` confusing/wrong location
