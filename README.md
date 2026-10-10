[![zmk-build](https://github.com/lilfeelz/keyboard/actions/workflows/zmk-build.yml/badge.svg)](https://github.com/lilfeelz/keyboard/actions/workflows/zmk-build.yml)
[![zmk-docs](https://github.com/lilfeelz/keyboard/actions/workflows/zmk-docs.yml/badge.svg)](https://lilfeelz.github.io/keyboard/)
[![kanata-ios](https://github.com/lilfeelz/keyboard/actions/workflows/kanata-ios.yml/badge.svg)](https://github.com/lilfeelz/keyboard/actions/workflows/kanata-ios.yml)
[![hooks](https://github.com/lilfeelz/keyboard/actions/workflows/hooks.yml/badge.svg)](https://github.com/lilfeelz/keyboard/actions/workflows/hooks.yml)

# keyboard

One layout, the TOTEM 36-key split, kept in step across the places it runs:

| dir | what |
| --- | --- |
| [`zmk/`](zmk/) | ZMK firmware config for the TOTEM (Seeed XIAO BLE). Keymap, shield, honkit docs. |
| [`kanata-ios/`](kanata-ios/) | The same layout as an iOS keyboard extension (SwiftUI), configured in kanata's lisp. |

The third copy is `~/.config/kanata/kanata.kbd` (dotfiles), which drives kanata on the laptop
and is the bundled default config of the iOS keyboard. A layer, thumb or chord change lands in
`zmk/config/totem.keymap`, `kanata-ios/TotemKit/Sources/TotemCore/default.kbd` and the
dotfile together; that is why the two projects share a repo.

Docs for the firmware keymap: [lilfeelz.github.io/keyboard](https://lilfeelz.github.io/keyboard/).

## Working in a subproject

Each directory keeps its own README and tooling; run commands from inside it.

```sh
cd zmk && $EDITOR config/totem.keymap       # validate: see zmk/README.md
cd kanata-ios && make test-core             # TotemKit unit tests; make test adds the XCUITest
```

## CI

| workflow | runs | what |
| --- | --- | --- |
| `zmk-build` | changes under `zmk/` | west build per `zmk/build.yaml` entry, firmware as artifacts |
| `zmk-docs` | pushes to main touching `zmk/docs`, keymap | keymap SVG + honkit site to the `gh-pages` branch |
| `kanata-ios` | every PR and push to main | `JakobMelchard/.github` xcode.yml in `kanata-ios/`: swift-format lint, TotemKit tests, XCUITest |
| `hooks` | every PR and push to main | prek over all files with this repo's `.pre-commit-config.yaml` |

Hooks: `brew install prek && prek install` (gitleaks, conventional commit subjects, swift-format;
`xcodegen generate` on push). Renovate bumps the pinned hook revs.

History: `zmk/` and `kanata-ios/` were the repos `lilfeelz/zmk` and `lilfeelz/kanata-ios`,
merged with `git subtree add`, so their history is in `git log -- zmk` and `git log -- kanata-ios`.
