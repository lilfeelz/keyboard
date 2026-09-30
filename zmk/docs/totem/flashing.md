# Building & Flashing

## Local Build

```sh
west build -b xiao_ble -d build/left  -s zmk/app -- -DSHIELD=totem_left
west build -b xiao_ble -d build/right -s zmk/app -- -DSHIELD=totem_right
```

## GitHub Actions

This repo uses the [ZMK Build Action](https://github.com/zmkfirmware/zmk-build-action). Push to `main` to trigger a build. Firmware artifacts available under [Actions](https://github.com/lilfeelz/zmk/actions/workflows/build.yml).

## Flashing

1. Enter bootloader (double-tap reset on XIAO BLE)
2. Copy the `.uf2` file to the mounted mass-storage device
3. Device resets automatically

### First flash

Left half must be flashed first. Label controllers before soldering.
