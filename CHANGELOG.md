# Changelog

All notable changes to this private project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows manual internal versioning.

## [Unreleased]

### Fixed

- Emergency hotkeys are exempt from suspension.
- Semicolon hotstrings restored to immediate-trigger legacy behavior.

### Added

- Documented Windows RTF clipboard test results.
- Recorded the temporary `BuildRedRtf()` syntax fix used during field testing.
- Reclassified RTF red-text insertion as experimental/reference.
- Added planned HTML Clipboard / CF_HTML implementation path.
- Documented MxNMSoft context-menu measurement reading for line axes and SUVMax.
- Updated SUV strategy from log-first to current-image context-menu first.
- Added the safety requirement to never reuse stale measurements and to fall back to manual input.
- Added dynamic RTF clipboard construction for red figure text.
- Added clipboard save/restore transaction around red text paste.
- Removed default dependency on saved `red_not.clip` snapshots.
- Red insertion requires Windows report editor compatibility testing.
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

## [0.3.1] - Planned

### Planned

- Validate emergency suspend/restore behavior on Windows.
- Validate immediate-trigger report hotstrings in the target report editor.

## [0.4.0] - Planned

### Planned

- Validate dynamic RTF red figure text insertion in the target Windows report editor.
- Confirm that text typed after red insertion continues in black.
- Keep HTML clipboard support as a future compatibility option if RTF is insufficient.

## [0.4.1] - Planned

### Planned

- Preserve Windows red-text and MxNMSoft field-test findings as internal documentation.
- Delete temporary diagnostic artifacts from the product repository.
- Prepare for a future CF_HTML implementation without changing runtime behavior in this step.

## [0.1.0] - Planned

### Planned

- Calibrated report editor actions.
- Calibrated viewer actions.
- Safer rich-text clipboard insertion.
- Documented release package for internal testing.
