---
name: keymap-validation
description: Validate ZMK keymap with keymap-drawer. Parse .keymap → YAML, draw SVG, check for errors.
---

# Keymap Validation

```sh
python3 -m venv /tmp/kv
/tmp/kv/bin/pip install keymap-drawer
/tmp/kv/bin/keymap parse -z config/totem.keymap -c keymap_drawer.config.yaml -o /tmp/keymap.yaml
/tmp/kv/bin/keymap draw /tmp/keymap.yaml -c keymap_drawer.config.yaml -o docs/totem/images/keymap.svg
```

No output = valid. Any error = fix the keymap.

Common errors:
- Missing `#binding-cells` on custom behaviors
- Wrong number of bindings in a row (must match matrix column count)
- Referencing undefined combos or behaviors
- Nested `()` in key positions (use separate lines)

## Keymap Config

`keymap_drawer.config.yaml` maps ZMK keycodes to display labels:
- Raw codes → Unicode symbols (e.g., `LEFT_SHIFT` → "⇧")
- Modifier formatting (e.g., `&kp LS(EXCL)` → "!")
- Custom macro labels (e.g., `&leq` → "≤")

## CI

Docs workflow (`docs.yml`) auto-generates SVG and deploys to GH Pages.
