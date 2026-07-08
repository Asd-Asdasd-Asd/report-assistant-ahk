# Safety

This project is intended to assist local report-writing workflows without bypassing clinical system controls.

## Boundaries

- No database access.
- No permission bypass.
- No automatic final submission by default.
- Viewer actions remain disabled or placeholder-only until calibrated and tested.
- Clipboard contents must be restored after scripted paste actions.

## Clipboard Protection

Clipboard paste helpers save the current clipboard, perform the scripted paste, and restore the previous clipboard in a `finally` block.

## Window Guard

Window guard helpers validate and activate expected windows before future sensitive actions are added.

## Emergency Controls

- Ctrl+Alt+Esc suspends hotkeys and hotstrings.
- Ctrl+Alt+Q exits the script.
