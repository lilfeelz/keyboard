# Local validation

```sh
python3 -m venv /tmp/keymap-venv
/tmp/keymap-venv/bin/pip install keymap-drawer
/tmp/keymap-venv/bin/keymap parse -z config/totem.keymap -o /tmp/keymap.yaml
/tmp/keymap-venv/bin/keymap draw /tmp/keymap.yaml -o /tmp/keymap.svg
```
No errors → valid.
