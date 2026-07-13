# 项目状态与交接

更新时间：2026-07-13（M1 Color Reset V1 Mac-side implementation）

## 当前阶段

项目处于 `v0.5.0 — Internal Test Foundation` 的 M1 现场验证准备阶段。CF_HTML red-text insertion 已确认可用；Mac-side M1 已实现 window-root anchor enumeration、唯一 pairing、稳定排序和第二候选选择。Windows 尚未运行新版本，因此最终 insertion color 仍未完成有效人工验证。

本轮只修改 color-reset adapter、pure logic、diagnostics、field-debug、tests 和对应文档。没有修改 legacy scripts，没有进入 HHKB、viewer、montage、caption、cover、measurement、configuration 或 packaging。

## Repository 状态

- Branch：`main`，相对 `origin/main` ahead 2。
- 当前本地提交：`ff70bab`（pinned UIA-v2 field-debug dependency）和 `1d15a21`（color-reset runtime/field debug）。
- 两个未跟踪现场目录必须原样保留：
  - `debug/field-result-2026-07-13/`
  - `debug/legacy-automation-survey-2026-07-13/`
- 原始 evidence 不改写、不删除；durable conclusions 记录在 `docs/field-tests/2026-07-13-workstation-findings.md`。

## 2026-07-13 已确认事项

### Verified behavior

- MedEx 0.0.1.0 在 1920×1080、100% scaling、DPI 96 环境运行，现场进程名为 `medexworkstations.exe`。
- CF_HTML 可插入红色文字。
- ratio-derived click 可打开被选中 toolbar 的 color menu。
- Name=`000000` 的 `Hyperlink` 可找到，InvokePattern 可用且调用未抛错。
- 页面至少有病史信息、检查所见、检查结论三组同构 toolbar。
- 现有 adapter 使用 first-match lookup，实际选择第一组病史信息 toolbar；目标工作流主要需要第二组检查所见。

### User observation

- 操作者聚焦检查所见，但脚本打开病史信息 toolbar。
- black item Invoke 后，黑色激活看起来曾成功。
- completion notification 改变焦点并干扰后续颜色状态，因此最终结果无效。

### Implementation inference

- Proportional trigger click 与 UIA Invoke 路线可继续作为 V1 基础。
- 当前主要缺陷是 toolbar candidate selection 与 focus-interfering diagnostic feedback。
- 六次现有 `COLOR_RESET_OK` 只证明 automation chain 走到 Invoke，不证明目标 editor 最终颜色正确。

### Deferred investigation

- V1 第二候选策略对其他 DPI、缩放、窗口宽度、语言和 MedEx version 的适配性。
- focused editable `DocumentRect` 与最近上方 toolbar 的稳定关联；这是 V2。
- direct Electron renderer、IPC 或 embedded editor command。

## 关键矛盾和诊断缺陷

- `Process=medexworkstations.exe` 与 `ProcessNameConfirmed=false` 并不矛盾：进程命中了 provisional candidate，但 production confirmed name 仍为空。M1 必须分开输出这两个状态。
- `RetryCount=false` 是类型错误，M1 改为整数 `0`/`1`。
- `UIALibraryVersion=EXPECTED_1.1.3_NOT_RUNTIME_DETECTED` 是 build/dependency metadata，不是运行时检测。
- `COLOR_RESET_OK` 与用户最终观察冲突；M1 改用 automation/pending-visual-validation 双层语义。
- Survey 目录没有预期的 `screenshots/` 和 `uia_dumps/`，除一张 toolbar screenshot 外没有额外视觉材料。缺失证据不补写、不推测。

## Revised Color Reset V1

1. 验证 foreground MedEx process/window。
2. 从 foreground window root，或经证据确认的报告区域父容器，枚举所有 `16px` 和 `①`。
3. 不假设 anchors 是 focused `Document` descendants。
4. 按 vertical alignment、horizontal order 和 plausible gap 形成唯一 pairs。
5. 要求至少两个唯一有效候选，不要求总数严格等于三。
6. 按 Y 排序并选择第二个候选。
7. 缺少第二候选、pairing ambiguity、sorting ambiguity、invalid rectangle/geometry/coordinate space 时立即停止，不点击。
8. 使用选中 pair 与 provisional ratio `0.337` 计算 trigger，不使用 absolute final point。
9. Menu 打开后只对 exact Name=`000000` 且支持 InvokePattern 的 item 调用 Invoke。
10. 默认只写 clipboard/log，不显示任何 completion feedback。

V2 才通过 focused editable `DocumentRect` 选择最近上方的唯一 toolbar。

## Diagnostic contract

M1 分别记录：

- `ToolbarCandidateSelected`
- `ColorMenuClickSent`
- `BlackItemFound`
- `BlackItemInvokeSucceeded`
- `FinalInsertionColorVisuallyValidated`

Automation 可报告 `AUTOMATION_CHAIN_OK`，但在人工验证前必须同时保持 `FINAL_COLOR_PENDING_VISUAL_VALIDATION`。只有 Windows 操作者在 approved non-clinical context 输入无害字符并确认黑色后，才能记录最终视觉验证成功。

Field debug 禁止 `MsgBox`。ToolTip、TrayTip 或其他提示也只有在目标工作站证明不改变 editor focus、不影响颜色状态后才允许启用；M1 默认完全不显示提示。

## UIA dependency

UIA-v2 v1.1.3 是当前 pinned、可复现版本，不表示其他版本严格不可用。Field debug 使用仓库内 `debug/Lib/UIA.ahk`，无需系统级安装，也不要同时放置另一份 global UIA library。未来 compiled EXE 把 pinned dependency 作为构建输入处理。

## Legacy coexistence

- 原始 legacy scripts 保持不变，compatibility 在对应新功能完成并通过现场验证前继续承接日常 viewer/report-image workflow。
- RAlt+H/J/K/L 是正式、全局 HHKB navigation，M2 迁移时不得放入 MedEx-only `#HotIf`。
- XButton1 notification 是历史测试项，不属于功能、用户依赖或迁移任务；仅在发现真实 hotkey conflict 时处理。
- Body/Head/Lung、caption、screenshot、SUV/Arrow、cover 和 measurement 的已确认业务语义见 migration inventory 与 field-test document。

## 首次有限内测硬门槛

硬门槛为 M0、M1、M2、最小 M5 和 M6。M3 高频 viewer 与 M4 报告图 workflow 在 cleaned compatibility 稳定、无冲突地继续提供相应功能时不阻塞首次有限内测；如果 compatibility 缺失、不稳定或冲突，对应功能重新成为 blocker。

## M1 Mac-side implementation status

已完成：

1. foreground UIA root anchor enumeration；
2. unique pairing、geometry validation、Y sorting、second-candidate selection；
3. candidate missing、pairing ambiguity 和 sorting ambiguity structured failures；
4. foreground revalidation、provisional ratio 和 bounded interaction；
5. 删除 focus-changing feedback，默认 clipboard/log only；
6. integer RetryCount 和 process acceptance/confirmation 分离；
7. automation fields 与 manual final-validation state；
8. pure-logic tests 和 Windows manual retest preparation。

Automation success code 现在是 `AUTOMATION_CHAIN_OK`，diagnostics 同时输出 `FINAL_COLOR_PENDING_VISUAL_VALIDATION`。现有 `COLOR_RESET_OK` 仅保留给内部 pure-geometry compatibility，不再作为 field-debug 最终结果。

M1 实际代码和测试文件：

- `src/adapters/medex_report_editor.ahk`
- `src/medex_color_reset_logic.ahk`
- `src/diagnostics.ahk`
- `debug/medex_color_reset_field_debug.ahk`
- `tests/test_medex_color_reset_logic.py`
- `tests/manual-test-checklist.md` 及 M1 状态文档

没有修改 `report_editor.ahk`；现有 `{ok, code, context}` contract 足以承载 automation/pending-validation 状态。

## Windows M1 验收

在 approved non-clinical context 聚焦检查所见，运行 diagnostic，确认第二组 toolbar 被选择、没有 focus-stealing feedback、`000000` Invoke 成功；随后手工输入一个无害字符并确认黑色。严禁在 finalized patient report 中测试。

## 当前风险

- Color trigger 没有 usable UIA element，V1 仍需一次经过校验的 relative/proportional click。
- 多组 toolbar 的 accessible names 相同，candidate pairing 和 ordering 必须 fail closed。
- 多显示器、DPI、缩放和 MedEx layout/version variation 尚未覆盖。
- 新旧进程没有 shared clipboard/mouse mutex；共存期不得并发触发相关动作。
- Compatibility legacy coordinates 缺少 window guard，需继续保持明确风险和回滚路径。

## 当前测试状态

macOS pure-logic suite 基线为 13 tests passed，覆盖 CF_HTML 和现有 geometry/result-code helpers。这不代表 Windows UIA、MedEx click/Invoke 或最终 insertion color 已通过测试。

下一步只是在 Windows 工作站执行 M1 验收。验收结果回传前不进入 M2，不 commit、不 push。
