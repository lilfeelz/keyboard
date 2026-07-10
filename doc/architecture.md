# Firmware Architecture

## Shield vs Root Keymap

ZMK supports two levels of keymap definition:

### Shield keymap (DEAD CODE)

`config/boards/shields/totem/totem.keymap` was the original keymap bundled with the shield definition. It uses:
- Different layout: QWERTY but with different key positions (e.g., F on left ring, P on left index)
- Different layers: BASE/NAV/SYM/ADJ (vs root's BASE/NAV/SYM/MOO/fun)
- A `gif` macro not bound to any key

**This keymap is not used.** ZMK convention: when `config/<shield>.keymap` exists (root keymap), it completely overrides the shield-level keymap.

Should be removed or kept as a reference only.

### Root keymap (ACTIVE)

`config/totem.keymap` is the source of truth. It defines:

**Matrix:** 10 columns × 4 rows, mapped via `totem.dtsi`:
```
map = <
  RC(0,0) RC(0,1) RC(0,2) RC(0,3) RC(0,4)    RC(0,5) RC(0,6) RC(0,7) RC(0,8) RC(0,9)
  RC(1,0) RC(1,1) RC(1,2) RC(1,3) RC(1,4)    RC(1,5) RC(1,6) RC(1,7) RC(1,8) RC(1,9)
  RC(3,0) RC(2,0) RC(2,1) RC(2,2) RC(2,3) RC(2,4)    RC(2,5) RC(2,6) RC(2,7) RC(2,8) RC(2,9) RC(3,9)
                        RC(3,2) RC(3,3) RC(3,4)    RC(3,5) RC(3,6) RC(3,7)
>;
```

Note: Row 3 has mixed positions — RC(3,0) is the left pinky column, RC(3,2-7) are thumbs, RC(3,9) is right pinky column.

## Behavior Architecture

### Hold-Tap

Two variants (`mt_left`, `mt_right`) differ only in `hold-trigger-key-positions` — which keys trigger the hold action. This enables:
- Left-hand mods activate when the other hand's keys are pressed (right-hand roll)
- Right-hand mods activate when the left hand's keys are pressed

`quick-tap-ms=150` allows rapid tapping to act as repeated keypresses.

### Combos

Defined in the `combos` node. All on BASE layer. Key positions reference the 38-key physical layout (10+10+12+6).

### Macros

Standard `zmk,behavior-macro` for multi-key output. Used for:
- Symbol shortcuts (≤, ≥, ←, →, :=)
- Vim yank operations (escape+y+i+w, escape+V+Y+I)

### Mod-Morphs

`zmk,behavior-mod-morph` changes output based on modifier state. For example:
- `&caps`: `&caps_word` normally, `&kp CAPSLOCK` when shift is held
- `&cmd_tab`: `&kp TAB` normally, `&kp F21` when GUI is held

## Shield Hardware

### GPIO Mapping (Left)

| Column | GPIO |
|--------|------|
| COL0 | xiao_d 4 |
| COL1 | xiao_d 5 |
| COL2 | xiao_d 10 |
| COL3 | xiao_d 9 |
| COL4 | xiao_d 8 |

### GPIO Mapping (Right)

Columns shifted by 5 (`col-offset = <5>`). GPIO order reversed (mirrored).

| Column | GPIO |
|--------|------|
| COL5 | xiao_d 8 |
| COL6 | xiao_d 9 |
| COL7 | xiao_d 10 |
| COL8 | xiao_d 5 |
| COL9 | xiao_d 4 |

### Rows (both halves)

| Row | GPIO |
|-----|------|
| 0 | xiao_d 0 |
| 1 | xiao_d 1 |
| 2 | xiao_d 2 |
| 3 | xiao_d 3 |

Diode direction: `col2row`, pull-down enabled.

## Board Config

`config/totem.conf`:
```
CONFIG_ZMK_SLEEP=y
CONFIG_ZMK_IDLE_TIMEOUT=30000     # 30s to idle
CONFIG_ZMK_IDLE_SLEEP_TIMEOUT=60000  # 60s to sleep
CONFIG_BT_MAX_CONN=6
CONFIG_BT_MAX_PAIRED=6
```
