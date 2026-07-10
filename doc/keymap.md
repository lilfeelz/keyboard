# Keymap Details

## Behavior Reference

### Hold-Tap: `mt_left` / `mt_right`

Custom hold-tap behaviors with left/right-aware trigger positions.

```dts
mt_left: mt_left {
    compatible = "zmk,behavior-hold-tap";
    bindings = <&kp>, <&kp>;
    flavor = "balanced";
    hold-trigger-on-release;
    hold-trigger-key-positions = <5 6 7 8 9 15 16 17 18 19 26 27 28 29 30 31 32 33 34 35 37 36>;
    require-prior-idle-ms = <100>;
    tapping-term-ms = <250>;
    quick-tap-ms = <150>;
};
```

`mt_left` triggers hold only when the right hand's keys are pressed (positions 5-9, 15-19, 26-35, 37-36). Left-hand key + left-hand mod = tap (not hold), enabling fast rolling on the same hand.

`mt_right` mirrors: triggers hold only when left-hand keys are pressed.

### Hold-Tap: `lt_caps` / `sk_mo`

- `lt_caps` (150ms): `&lt` on hold, caps-word on tap
- `sk_mo` (150ms): `&mo` on hold, sticky key on tap

### Mod-Morph: `&caps`

```dts
caps: caps {
    compatible = "zmk,behavior-mod-morph";
    bindings = <&caps_word>, <&kp CAPSLOCK>;
    mods = <(MOD_LSFT|MOD_RSFT)>;
};
```

Tap = caps_word (auto-dismisses on non-continuation key). Shift+key = CAPSLOCK toggle.

### Mod-Morph: cmd_tab / cmd_stb

```dts
cmd_tab: cmd_tab {
    bindings = <&kp TAB>, <&kp F21>;
    mods = <(MOD_RGUI|MOD_LGUI)>;
    keep-mods = <(MOD_LSFT|MOD_RSFT)>;
};
```

Normal = TAB. With GUI (Cmd) held = F21. F21 is intercepted by WezTerm for alt-tab-like behavior. Shift is preserved for reverse-tab.

## Caps Word Configuration

```dts
&caps_word { continue-list = <UNDERSCORE BACKSPACE DELETE
    LEFT_ARROW DOWN_ARROW UP_ARROW RIGHT_ARROW
    HOME END PAGE_DOWN PAGE_UP
    MINUS LEFT_SHIFT RIGHT_SHIFT>; };
```

These keys don't dismiss caps_word. Shift keys within caps_word produce shifted versions of letters.

## Combos

All on BASE layer unless noted:

| Keys | Positions | Action | Notes |
|------|-----------|--------|-------|
| T+G | 16, 17 | Enter | Thumb-index roll |
| X+V | 12, 13 | LA(BACKSPACE) then LA(DEL) | Word back/delete with shift |
| Left+Right (NAV) | 15, 18 | Yank line macro | Escape, V, Y, I |
| Up+Down (NAV) | 16, 17 | Yank inner word | Escape, y, i, w, i |
| X+V | 12, 13 | Layer 5 backspace | Also triggers on BASE without shift |
| C+X+V | 11, 12, 13 | LA(BACKSPACE) | Triple combo for word back |

## Macros

| Macro | Output | Use case |
|-------|--------|----------|
| `leq` | `<` `=` | ≤ missing from keyboard |
| `geq` | `=` `>` | ≥ missing from keyboard |
| `left_arrow` | `<` `-` | ← |
| `right_arrow` | `-` `>` | → |
| `colon_equals` | `:` `=` | := assignment |
| `yank_inner_word` | `esc` `y` `i` `w` `i` | Vim: yank inside word |
| `yank_line` | `esc` `V` `Y` `I` | Vim: yank current line |
