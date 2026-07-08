# Changelog

All notable changes to this private project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows manual internal versioning.

## [Unreleased]

### Added

- Refactored core report hotstrings into `src/hotstrings.ahk`.
- Added safer clipboard save/restore helpers.
- Removed dependency on external `red_not.clip` in the new code path.
- Documented long-term release strategy.
- Noted that red formatted insertion remains a planned compatibility task.
- Added Chinese documentation structure for maintainers and end users.
- Added internal architecture, roadmap, decisions, maintenance, and release checklist documents.
- Added user-facing quick start, hotkey guide, update guide, troubleshooting, and emergency stop documents.
- Initial maintainable project structure.
- Minimal AutoHotkey v2 entrypoint.
- Safety-focused module placeholders.
- Manual workstation test checklist.

## [0.2.0] - Planned

### Planned

- Maintain Chinese documentation layers for internal maintainers and non-technical users.
- Review early English technical drafts and decide whether to migrate or archive them.
- Align release workflow with the new internal checklist.

## [0.3.0] - Planned

### Planned

- Continue validating report hotstrings on Windows.
- Test clipboard restore behavior in the target report editor.
- Design true RTF / HTML red text insertion after compatibility testing.

## [0.1.0] - Planned

### Planned

- Calibrated report editor actions.
- Calibrated viewer actions.
- Safer rich-text clipboard insertion.
- Documented release package for internal testing.
