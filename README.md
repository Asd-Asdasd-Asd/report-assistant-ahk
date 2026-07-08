# Report Assistant AHK

Report Assistant AHK is a private AutoHotkey v2 project for Windows clinical report-writing and viewer automation workflows. The first milestone is a maintainable project skeleton, clear safety boundaries, and a minimal runnable entrypoint.

## Current Status

This is an early personal prototype. It is not ready for department-wide use, unattended use, or use on uncalibrated workstations.

The legacy scripts are preserved as historical source material in `legacy/`. They have not been fully refactored into the new project structure.

## Requirements

- Windows
- AutoHotkey v2
- Target report-writing workstation
- Local calibration for any coordinate-based viewer actions

## Safety Principles

- No database access.
- No permission bypass.
- No automatic final submission by default.
- Clipboard contents must be restored after scripted paste actions.
- Coordinate-based actions require local calibration.
- Do not commit patient data, hospital identifiers, credentials, screenshots, or sensitive logs.

## Repository Layout

```text
legacy/   Historical AutoHotkey scripts kept unchanged.
src/      AutoHotkey v2 source modules.
docs/     Installation, usage, safety, calibration, and release notes.
scripts/  Development helper scripts.
release/  Generated single-file release script.
tests/    Manual workstation test checklist.
```

## Quick Start

1. Install AutoHotkey v2 on the Windows workstation.
2. Copy `src/config.example.ahk` to `src/config.local.ahk`.
3. Adjust local executable names and coordinates in `src/config.local.ahk`.
4. Run `src/main.ahk` with AutoHotkey v2 for development, or run `python scripts/build_release.py` to generate `release/report_assistant.ahk`.
5. Test the generated script using `tests/manual-test-checklist.md` before using it in a real workflow.
