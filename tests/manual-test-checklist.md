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
