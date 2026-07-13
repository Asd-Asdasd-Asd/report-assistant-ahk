# Changelog

All notable changes to this private project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows manual internal versioning.

## [Unreleased]

### v0.5.0 规划基础

- 新增正式的 MedEx 富文本颜色复位 Technical Investigation。
- 批准 fail-closed V1 路线：UIA anchors、比例 trigger 定位和对 `000000` 执行 UIA Invoke。
- 将原 v0.5/v0.6 规划调整为 Internal Test Foundation、Stabilization 和 Measurement Capture。
- 新增完整的 legacy-versus-new 功能清单和共存计划。
- 新增 v0.5.0 centralized external INI configuration architecture。
- 新增 structured color-reset result codes 和 privacy-safe diagnostic fields。
- 新增 living project status 和下一项精确编码任务。
- 新增尚不可正式部署的 `legacy/medex_legacy_compat.ahk` scaffold，并保留两份原始 legacy scripts。
- 记录 legacy 与新项目同时启用时存在 5 个 report hotstring conflicts。
- 本次文档阶段未实现 MedEx UIA runtime、configuration runtime、executable packaging 或 measurement automation。

### v0.5.0 MedEx color-reset runtime

- Added structured MedEx color-reset result codes and pure geometry validation.
- Added provisional dual process candidates while keeping production fail-closed until the target process name is confirmed.
- Added window-scoped UIA-v2 Document/anchor/color-item lookup and explicit InvokePattern use.
- Added bounded trigger interaction with one optional retry and mouse restoration.
- Added report-editor orchestration that reports paste/reset partial failure without deleting pasted text.
- Added minimal privacy-safe development logging under `%TEMP%\MedExAHK\`.
- Added a Ctrl+Alt+F12 Windows field-debug script with clipboard result export and editable debug overrides.
- Added platform-independent color-reset reference tests; Windows UIA runtime remains unverified.
- Did not implement configuration runtime, measurement capture, packaging, or additional legacy migration.

### v0.4.2

- Replaced the active RTF path with dynamic CF_HTML red figure-text insertion.
- Added UTF-8 byte-offset generation for CF_HTML headers and platform-independent structural tests.
- Added deterministic HTML clipboard writing and save/restore transaction handling.
- Removed `CF_UNICODETEXT` fallback from red figure-text insertion.
- Changed `;fzg` cursor movement to run only after paste dispatch succeeds.
- Added staged Windows tests for Notepad, Word, Chromium contenteditable, and the MedEx report editor.
- CF_HTML rendering and post-paste text color still require Windows workstation validation.

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
