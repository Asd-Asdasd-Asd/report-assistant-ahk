# Manual Test Checklist

Use this checklist on a Windows workstation with AutoHotkey v2 installed.

- [ ] Script launches.
- [ ] Ctrl+Alt+Esc suspends hotkeys and hotstrings.
- [ ] Ctrl+Alt+Q exits the script.
- [ ] `;cmx` inserts `cm×cm` and moves the cursor left 2.
- [ ] `;red` does not destroy clipboard contents.
- [ ] `;red` inserts red `（见图）`.
- [ ] After `;red`, newly typed characters continue in black.
- [ ] `;fzg` inserts the expected phrase and figure marker.
- [ ] `;fzg` inserts the phrase plus red `（见图）`, and cursor movement remains correct.
- [ ] Original clipboard content is restored after `;red`.
- [ ] If red insertion fails, no silent black fallback hides the issue.
- [ ] Report editor remains usable after hotstring expansion.
- [ ] Viewer coordinate actions are disabled or placeholder only.
- [ ] No automatic final submission occurs.

## v0.4.2 CF_HTML staged tests

### Notepad

- [ ] `;red`, `;fzg`, `;fwj`, and `;fjd` trigger immediately.
- [ ] Unsupported HTML produces no insertion or a visible failure; it never inserts black `（见图）` as a fallback.
- [ ] The original clipboard is restored after the attempt.
- [ ] If `;fzg` paste dispatch fails, the cursor does not move left.

### Microsoft Word

- [ ] `;red` inserts red `（见图）`.
- [ ] Typing `abc` immediately after the insertion produces black text.
- [ ] The original clipboard is restored after insertion.
- [ ] `;fzg`, `;fwj`, and `;fjd` preserve their existing phrases.
- [ ] `;fzg` moves the cursor left 4 only after paste dispatch succeeds.

### Edge or Chrome contenteditable

- [ ] `;red` inserts red `（见图）` in a contenteditable field.
- [ ] Typing `abc` immediately afterward produces black text.
- [ ] No hidden or visible boundary character is added.
- [ ] The original clipboard is restored after insertion.

### MedEx report editor

- [ ] The editor accepts the CF_HTML payload and renders `（见图）` in red.
- [ ] Typing `abc` immediately afterward produces black text.
- [ ] Paste timing is reliable during normal and repeated report entry.
- [ ] The original clipboard is restored after success and failure.
- [ ] Failure never inserts black `（见图）` as a fallback.
- [ ] `;fzg` leaves the cursor in the expected position after successful paste dispatch.
- [ ] Report input remains usable after a failed insertion.
