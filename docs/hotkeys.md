# Hotkeys and Hotstrings

## Global Hotkeys

| Shortcut | Action |
| --- | --- |
| Ctrl+Alt+Esc | Suspend AutoHotkey hotkeys and hotstrings |
| Ctrl+Alt+Q | Exit the script |

Optional global navigation, enabled with `GlobalHjklArrows=true` in the
`[Features]` section of `config.ini`:

| Shortcut | Action |
| --- | --- |
| RAlt+H | Left |
| RAlt+J | Down |
| RAlt+K | Up |
| RAlt+L | Right |

## Hotstrings

| Hotstring | Action |
| --- | --- |
| `;red` | Render the explicit red `（见图）` element and restore black insertion color |
| `;fzg` | Insert `放射性摄取增高，SUVmax约为（见图）` and place the caret before the red suffix |
| `;fwj` | Insert `放射性摄取未见明显增高（见图）` with an explicit red suffix |
| `;fjd` | Insert `放射性摄取降低（见图）` with an explicit red suffix |
| `;cmx` | Insert `cm×cm` and place the caret between the two units |

The active Schema 2 model derives caret movement and color restoration from
`{{cursor}}`, `{{date}}`, and `{{red:（见图）}}`. Plain literal `（见图）`
remains black.
