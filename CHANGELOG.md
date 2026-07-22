# Changelog

All notable changes to this private project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows manual internal versioning.

## [Unreleased]

### Added

- Added a stable `Local\MedExReportAssistant.Singleton` mutex before configuration initialization. Conflicting policy-aware versions now show a Chinese message and exit without terminating or reloading the existing process.
- Added startup metadata logging under `%LOCALAPPDATA%\MedExReportAssistant\logs\startup.log`, including application version, source revision, executable path, and configuration path.
- Added Ahk2Exe version metadata derived from the canonical `AppMetadata.Version` and Git source-revision stamping for generated release builds.
- Added a root-level one-click Windows build workflow that compiles through a validated temporary EXE, transactionally replaces the last-known-good artifact, and outputs `publish/麦旋风.exe`.
- Added recursive overlay synchronization for static release resources under `assets/publish/`, including separate Chinese first-use and configuration guides.

### Documentation

- Defined the initial portable single-EXE update model, local ZIP extraction requirement, arbitrary executable location, and explicit exclusion of installer/updater/rollback/old-EXE management behavior.
- Synchronized project state with `2369b68` / `v0.6.0-candidate-g`, including the promoted `relativeMousePixelValidated` default, field-confirmed `medexworkstations.exe`, phrase-specific no-reset `;fzg`, and recorded `75 tests passed` promotion baseline.
- Added the ordered critical-path optimization checkpoints, timing schema, clipboard minimum-interval safety contract, MedEx-only hotstring scope plan, Windows result continuation rules, and deferred per-machine calibration design.

### Fixed

- Restored the field-validated CF_HTML clipboard timing (`200 ms` paste settle, `100 ms` before restore, `100 ms` after restore) after Windows testing exposed a 50 ms race that could insert the user's restored clipboard content.
- Added Candidate G1 calibration-only toolbar-row selection, relative geometry measurement, and privacy-safe pixel probes. The harness may click the validated arrow once but cannot click black or query popup UIA.
- Added `relativeMousePixelValidated` using the field-calibrated `(320,0)` arrow offset, `(6,83)` black offset, four-point popup signature, one passive retry, and at-most-once arrow/black clicks. After controlled Windows G2 validation, it is now the production default; `uiaInvoke` remains an explicit comparison/rollback strategy and there is no automatic fallback.
- Recorded successful final Windows validation of the generated Candidate G release and promoted this implementation as the production mainline for the supported MedEx 0.0.1.0, 1920×1080, 100%, DPI 96 profile.
- Restored the field-validated phrase-specific `;fzg` order: paste the red marker, restore the clipboard, wait 50 ms, and send `Left 4` without running Color Reset. A six-run Windows A/B confirmed this fixes the caret while retaining the current CF_HTML payload; standalone `;red` continues to own black-color reset.
- Deferred the remaining small post-insertion delay until after final release validation; the validated clipboard transaction waits and legacy 50 ms caret settle remain unchanged for this promotion.
- Removed production hotstring registration from the field-debug process; F11 now calls the shared `RunFzgInsertion()` workflow directly, avoiding duplicate `;red`/`;fzg` handlers when comparing release and debug paths.
- Recorded 2026-07-16 evidence that semantic localization is usable while popup UIA traversal is too slow and unreliable for the preferred production route; `uiaInvoke` remains a comparison/rollback strategy.
- Recorded the earlier reconciliation control and its disabled diagnostic experiments; it was superseded as production default by the validated Candidate G promotion.
- Hoisted required AutoHotkey directives to the beginning of the generated self-contained release while preserving BOM-safe generation.
- Stripped only the leading UTF-8 BOM from each release component before merging, preventing embedded U+FEFF parser errors in the self-contained AHK release.
- Added a zero-U+FEFF build guard and BOM regression coverage while preserving the original source content beyond its first character.
- Recorded and then superseded an attempted 50 ms clipboard settle; Windows exposed a wrong-paste race, so the promoted baseline retains the field-validated `200/100/100 ms` timing.
- Preserved the fixed-attempt lookup implementation only as an explicit diagnostic experiment; it is not the production default.
- Restored the legacy `;fzg` 50 ms caret-settle interval while retaining phrase-specific `Left 4` behavior.
- Added an explicit full-production timing diagnostic hotkey and stage timestamps without enabling heavy diagnostics on the normal success path.

### v0.5.0-alpha.0 — Field-validated production baseline

- Integrated the validated semantic-anchor Color Reset V1 into the normal hotstring/report-editor call chain.
- Accepted the exact provisional MedEx process allowlist in production while retaining `ProcessNameConfirmed=false`.
- Added `COLOR_RESET_FOREGROUND_CHANGED` without renaming established result codes.
- Split default failure-only production diagnostics from explicit full field diagnostics; both use the same adapter/resolver.
- Removed ToolTip feedback from the red-paste/color-reset production path.
- Centralized application version metadata and promoted pinned UIA-v2 v1.1.3 to a shared production/build dependency.
- Generated a self-contained single-file AHK release and added production integration/path tests.
- Recorded three successful automation runs and user-confirmed final black insertion color for the MedEx 0.0.1.0, 1920×1080, 100% baseline.
- Did not implement full configuration, EXE packaging, GUI, updater, M2, or additional legacy migration.

### M1 — Semantic region/local-anchor redesign

- Removed production dependency on user-configurable shortcut Name=`①`.
- Replaced exact Name=`16px` with centralized dynamic font-size pattern matching.
- Replaced second-sorted-toolbar selection with exact Text Name=`检查所见` row selection.
- Added `MedExColorResetLayoutProfile` with centralized anchor rules and `ColorArrowOffsetX/Y` calibration.
- Changed click calculation to local font-anchor offsets; baseline point is `(672,297)`.
- Added optional non-blocking `rAI` layout diagnostics.
- Removed entire-UIA-root-inside-client validation that rejected maximized Windows resize frames.
- Added semantic-anchor failure codes, profile diagnostics, recalibration documentation, and pure-logic coverage.
- Preserved exact black-item Invoke, bounded retry, foreground guards, and no-modal field debugging.
- Did not modify legacy behavior or enter M2.

### M1 — Color Reset V1 Mac-side implementation

- Replaced first-match anchor lookup with foreground-window-root enumeration of all `16px` and `①` elements.
- Added unique one-to-one toolbar pairing, geometry validation, stable center-Y sorting, and V1 selection of candidate index 2 without requiring exactly three candidates.
- Added fail-closed results for missing second candidate, pairing ambiguity, and sorting ambiguity.
- Revalidated foreground hwnd and process before trigger click and before black-item Invoke.
- Changed automated completion to `AUTOMATION_CHAIN_OK` with `FINAL_COLOR_PENDING_VISUAL_VALIDATION`; Invoke success no longer claims final insertion-color success.
- Added explicit candidate, selected rectangles, click, Invoke, process-confirmation, pinned UIA metadata, and manual-validation diagnostic fields.
- Removed all field-debug startup/completion UI; validation output is clipboard and log/file only.
- Expanded platform-independent color-reset tests. Windows workstation visual validation remains required.
- Did not modify legacy behavior or begin M2.

### M0 — 2026-07-13 现场证据固化

- 固化 Windows 工作站 color-reset 与 legacy automation survey 证据，并保留原始 debug artifacts 不变。
- 确认现有自动化链路打开了错误的第一组 toolbar；既有 `COLOR_RESET_OK` 不能代表目标编辑器最终颜色已恢复。
- 将 V1 修订为从 foreground MedEx root/报告区域父容器枚举唯一 anchor pairs，至少两个候选并选择 Y 排序后的第二个。
- 明确 automation chain success 与人工 `FinalInsertionColorVisuallyValidated` 是两个不同结果。
- 记录 field debug 默认只写 clipboard/log，禁止 focus-stealing completion feedback。
- 更新首次有限内测门槛：M3/M4 可由稳定 compatibility 暂时承接，不必自动阻塞首个内测。
- 本次只更新文档；未修复 Color Reset V1、未修改 legacy、未开始 configuration 或 packaging。

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
- Added platform-independent color-reset reference tests; at implementation time Windows UIA runtime was unverified. The later 2026-07-13 field evidence now establishes partial automation-chain validation only.
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
