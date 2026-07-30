# Changelog

All notable changes to this private project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows manual internal versioning.

## [Unreleased]

## [0.6.3] - 2026-07-30

### Added

- Added a privacy-safe Viewer context receiver diagnostic that compares manual
  and automatic image points, probes bounded same-process HWND candidates
  without invoking a menu command, and copies its report to the clipboard.
- Added a separate `Package Release.cmd` workflow that reads generated version
  metadata, packages an exact five-file allowlist into a visible
  `麦旋风-v<version>.zip`, validates ZIP contents and CRC, writes SHA256, and
  transactionally retires only older managed distribution artifacts.

### Changed

- Viewer measurement targeting now keeps strict config geometry as the primary
  path and uses a shared owner-family image-surface resolver only when the
  primary path cannot identify one runtime frame.
- The runtime fallback prefers a structurally valid foreground image window or
  a unique significantly largest image client, while excluding the native tool
  panel, action root, buttons, small windows, and ambiguous large surfaces.

### Fixed

- Fixed `POPUP_NOT_CREATED` and “未找到可清除的对象” on Viewer installations
  where the prior tool-anchor fallback mapped the configured image point into
  the narrow native button panel instead of the actual image window.
- Fixed the standalone diagnostic builder so it waits for GUI-based Ahk2Exe
  completion and surfaces validation/compiler output.

## [0.6.2] - 2026-07-27

### Changed

- Viewer tool selection now discovers the live native command controls and resolves their shared owner hierarchy instead of assuming one workstation's button spacing or frame offsets.
- Viewer hotkeys now accept one Ctrl, Alt, Shift, or Win modifier. A single unmodified letter or digit is also supported and is automatically scoped to the Viewer foreground.
- Arrow and length hotkeys now wait for complete key release and dispatch once, preventing repeat-trigger behavior for unmodified keys.
- Formal and checkpoint builds now write only to the sibling `report-assistant-build` directory; the checkpoint launcher moved under `tools/field-testing`.

### Fixed

- Fixed adjacent-command activation on Viewer layouts whose native button sizes and vertical spacing differ from the original workstation.
- Fixed Viewer image resolution after the main image area creates or exposes additional same-process top-level windows.
- Fixed clear-annotation ambiguity by ranking image owner families and accepting only a unique best Viewer family.
- Reused the validated measurement client point across target resolution and command transport, avoiding a second inconsistent frame lookup.

## [0.6.1] - 2026-07-26

### Added

- Added configurable, default-disabled hotkeys for the MxNM Viewer arrow, length-measurement, and 3D SUV tools.
- Added a configurable, Viewer-only screenshot mapping that sends MedEx F12 and shows a brief non-text dispatch pulse.
- Added Win-key support through an explicit Settings modifier, bypassing the native Windows Hotkey control limitation.
- Added config-derived Vendor command discovery and Windows field harnesses for all three Viewer tools.

### Changed

- Viewer tool invocation now maps the Vendor button-pad origin into the current runtime frame, validates the native control and process boundary, and sends a bounded synchronous `WM_COMMAND / BN_CLICKED` to the button's direct parent.
- 3D SUV now dispatches once after the complete shortcut chord is released, avoiding Vendor modifier-dependent temporary state; screenshot feedback uses a fast, full-Viewer translucent flash after pure F12 dispatch.
- Removed UIA, mouse movement, focus switching, background polling, and hover dependencies from the Viewer tool hotkey path.

### Fixed

- Fixed inactive-parent `BM_CLICK` behavior that could discard the first tool selection after focus changed.
- Fixed overly strict root-HWND validation for same-process MxNM floating windows.
- Fixed logical/runtime coordinate mapping by scaling the configured panel origin while retaining fixed native button offsets.
- Fixed nested AHK `A_Index` reuse that incorrectly mapped every configured command to the arrow row.

### Documentation

- Documented the validated command IDs, coordinate model, native-window dispatch boundary, fail-closed checks, and Windows findings.
- Updated physician-facing hotkey and release guidance for the three optional Viewer tools.

## [0.6.0] - 2026-07-24

### Release summary

- Added production SUVMax acquisition through `{{suvmax}}`, including strict parsing, automatic target resolution, manual-input fallback, visual failure feedback, and post-write annotation cleanup.
- Added production 1–3 axis acquisition through `{{size}}`, including fresh-empty detection, descending numeric formatting with `×`, manual `;cmx` fallback, and cleanup verification.
- Reused one config/UIA target resolver, context-menu transport, clipboard transaction, report transaction, and cleanup boundary for both measurement types.
- Preserved fail-closed behavior: stale clipboard content is never reused, automation failure is distinct from no annotation, and cleanup failure never rolls back written report content.
- Added non-technical Chinese v0.6.0 first-use, configuration, and update guidance.

### Added

- Added a stable `Local\MedExReportAssistant.Singleton` mutex before configuration initialization. Conflicting policy-aware versions now show a Chinese message and exit without terminating or reloading the existing process.
- Added startup metadata logging under `%LOCALAPPDATA%\MedExReportAssistant\logs\startup.log`, including application version, source revision, executable path, and configuration path.
- Added Ahk2Exe version metadata derived from the canonical `AppMetadata.Version` and Git source-revision stamping for generated release builds.
- Added a root-level one-click Windows build workflow that compiles through a validated temporary EXE, transactionally replaces the last-known-good artifact, and outputs `publish/麦旋风.exe`.
- Added recursive overlay synchronization for static release resources under `assets/publish/`, including separate Chinese first-use and configuration guides.
- Added Schema 2 templates with `{{cursor}}`, `{{date}}`, and the exact red suffix `{{red:（见图）}}`; plain literal `（见图）` remains black.
- Added one-time, audited Schema 1 → 2 configuration migration with backup, temporary-file validation, and fail-closed recovery.
- Added a native Settings UI for creating, editing, enabling, disabling, sorting, and deleting custom report templates, including a compact template-element insertion control.
- Added tray “设置…” and “重新加载配置” actions; double-clicking the tray icon opens the single Settings window.
- Added the original SVG, deterministic multi-size PNG/ICO generation pipeline, and Ahk2Exe icon integration.
- Added the initial v0.6.0 measurement foundation: structured SUVMax states, strict parsing, an independent sentinel/sequence-based clipboard capture transaction, and a no-focus-switch context-menu provider that remains disconnected from production hotstrings pending Windows validation.
- Added non-focus-stealing visual feedback to the Windows measurement field harness for workstations without audio devices.
- Added a spec-driven measurement acquisition core with an unchanged SUVMax wrapper, reserved `line_axes` type, and optional structured components for later line-measurement support.
- Added a read-only MxNM config geometry schema audit that derives the two vendor INI paths from the running viewer executable, hashes both files, and exports only whitelisted numeric geometry entries.
- Added a privacy-safe MxNM UIA image-region audit that cross-checks unnamed Pane rectangles against the config-derived runtime image rectangle without reading UIA text.
- Added a field-only automatic MxNM measurement target resolver that selects a maximin point inside every declared layout and validates its UIA/action-window ownership before SUVMax testing.

### Documentation

- Defined the initial portable single-EXE update model, local ZIP extraction requirement, arbitrary executable location, and explicit exclusion of installer/updater/rollback/old-EXE management behavior.
- Updated v0.5.0 architecture, configuration, build, validation, migration, release, and non-technical user documentation to match the current mainline.
- Added `assets/publish/更新说明.md` for the v0.5.0 internal release and synchronized first-use/update guidance around full-folder replacement.
- Recorded the deferred first-run color-menu limitation: black may be selected while the popup remains open once after recompilation; subsequent attempts are normally unaffected.

### Fixed

- Resolved SUVMax viewer ambiguity by using the validated image screen point to identify its owning `MedExNMFusion.exe` window, while retaining fail-closed unique-window resolution when no point is available.

- Wait for the GUI-based Ahk2Exe process to exit before checking its output, capture compiler diagnostics, retry temporary-file cleanup, and verify every overlaid static publish asset.
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
