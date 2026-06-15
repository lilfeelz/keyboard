# Workflow

## Edit

Edit `config/totem.keymap` (root keymap overrides shield built-in).

Layers: BASE(0), left/NAV(1), right/SYM(2), middle/MOO(3), fun(4).

Matrix: row 0-1 (10 cols), row 2 (12 cols — extra pinky flanking), row 3 (6 — thumbs).

Hold-tap `/` hold-tap config in `&mt {};` block. Custom behaviors (`mt_left`, `mt_right`, `lt_caps`, etc.) defined in `/behaviors {};`.

## Validate

```sh
python3 -m venv /tmp/keymap-venv
/tmp/keymap-venv/bin/pip install keymap-drawer
/tmp/keymap-venv/bin/keymap parse -z config/totem.keymap -o /tmp/keymap.yaml
/tmp/keymap-venv/bin/keymap draw /tmp/keymap.yaml -o /tmp/keymap.svg
```
No errors → valid.

## Build (needs ZMK SDK)

```sh
west build -b xiao_ble -d build/left -s zmk/app -- -DSHIELD=totem_left
west build -b xiao_ble -d build/right -s zmk/app -- -DSHIELD=totem_right
```

CI builds via GitHub Actions on push (`.github/workflows/build.yml`).

## Docs preview

```sh
npm install honkit
npx honkit serve
```
Opens local server at `http://localhost:4000`.

Docs deploy: CI on push to `main` touching `docs/**` or `book.json` (`.github/workflows/docs.yml`).

Keymap SVG auto-generated in CI by `keymap-drawer`. To regenerate locally:

```sh
/tmp/keymap-venv/bin/keymap parse -z config/totem.keymap -o /tmp/keymap.yaml
/tmp/keymap-venv/bin/keymap draw /tmp/keymap.yaml -o docs/totem/images/keymap.svg
```
