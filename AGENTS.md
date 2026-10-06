# keyboard

Two projects, one layout. `zmk/` plus root `config/` is the TOTEM firmware config (`config/`
stays at the root because the keymap editor only reads `config/` there), `kanata-ios/` the iOS keyboard
extension configured in kanata lisp. The layout also lives in `~/.config/kanata/kanata.kbd`
(dotfiles), which is the source of the iOS keyboard's bundled default.

## Rules

- A layer, thumb, hold or chord change is a layout change: apply it to `config/totem.keymap`,
  `kanata-ios/TotemKit/Sources/TotemCore/DefaultConfig.swift` and the kanata dotfile in the same
  change, or say which copies were left behind and why.
- Work inside the subproject directory; its README and Makefile are the entry points.
  `zmk/AGENTS.md` and `zmk/.agents/skills/` hold the firmware rules (validation, layers).
- Root owns repo scaffolding: `.github/workflows`, `.pre-commit-config.yaml`, `renovate.json`,
  `LICENSE`. Do not add per-directory copies.
- Commits: conventional subjects, scope by directory when the change is local to one
  (`feat(zmk): ...`, `fix(kanata-ios): ...`). Hooks: `brew install prek && prek install`.
- No release-please: no manifests, no CHANGELOG bumps, no release workflow.

## zmk

Validate with keymap-drawer before pushing (see `zmk/AGENTS.md`). CI builds every
`zmk/build.yaml` entry on changes under `zmk/`; the docs site publishes from `zmk/docs` to the
`gh-pages` branch on pushes to main.

## kanata-ios

```sh
cd kanata-ios
make project      # xcodegen generate (Totem.xcodeproj is git-ignored)
make test-core    # cd TotemKit && swift test
make test         # core tests + XCUITest on the "Totem iPad Air 11-inch (M4)" simulator
make ipa          # build/Totem.ipa for SideStore
```

Format with `xcrun swift-format format --in-place --recursive .` from `kanata-ios/`; CI lints
with `--strict`. Config parsing and the key engine are pure Swift in `TotemKit/Sources/TotemCore`
and get unit tests; the SwiftUI view and the extension are covered by the UI test only.
