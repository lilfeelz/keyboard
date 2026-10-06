# Build System

ZMK firmware builds via `west` (Zephyr's meta-build tool) and GitHub Actions.

## Local Build

Requires the ZMK SDK (Zephyr + toolchain). Set up once:

```sh
west init -l config
west update
west zephyr-export
pip install -r zephyr/scripts/requirements.txt
```

Then build:

```sh
# Left half
west build -b xiao_ble -d build/left -s zmk/app -- -DSHIELD=totem_left

# Right half
west build -b xiao_ble -d build/right -s zmk/app -- -DSHIELD=totem_right

# Settings reset (BT pairings, etc.)
west build -b xiao_ble -d build/reset -s zmk/app -- -DSHIELD=settings_reset
```

Firmware `.uf2` files land in `build/<side>/zephyr/zmk.uf2`. Flash by copying to the XIAO BLE's mass storage device (double-tap reset to enter bootloader).

## CI Build

`../.github/workflows/zmk-build.yml` (repo root) triggers on:
- Push to `main` touching `config/**`, `zmk/boards/**`, `zmk/build.yaml`, `zmk/zephyr/**`
- PRs with same path filters
- Manual trigger via `workflow_dispatch`

Same steps as `zmkfirmware/zmk/.github/workflows/build-user-config.yml` (the official ZMK build
action), with the config at the root and build.yaml, boards and the zephyr module in `zmk/`.

## CI Docs

`../.github/workflows/zmk-docs.yml`:
- Generates `keymap.svg` via `keymap-drawer` with `keymap_drawer.config.yaml` for symbol rendering
- Builds honkit documentation site from `docs/` directory
- Deploys to GH Pages via `peaceiris/actions-gh-pages` (https://lilfeelz.github.io/keyboard/)

## West Manifest

`config/west.yml` pins dependencies:

```yaml
projects:
  - name: zmk
    remote: zmkfirmware
    revision: main   # FLOATING — should pin to specific commit
```

**Known issue:** `revision: main` pulls latest ZMK on every `west update`. Pin to a specific commit or tag for reproducible builds.
