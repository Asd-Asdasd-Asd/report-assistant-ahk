# 项目状态与交接

更新时间：2026-07-13（MedEx color-reset runtime implementation pass）

## 当前阶段

项目已进入 `v0.5.0 — Internal Test Foundation`。MedEx color-reset runtime、report-editor orchestration、minimal development diagnostics、field-debug script 和 pure-logic reference tests 已实现；尚未在 Windows/MedEx 上验证，也没有生成或发布 internal-test executable。

## 本次实现

- 新增 `src/adapters/medex_report_editor.ahk`，集中处理 foreground process、UIA、geometry、trigger click、menu lookup 和 `InvokePattern`。
- 新增 centralized `ColorResetCode`，覆盖完整 structured failure states。
- Production 默认要求 confirmed process name。由于目标工作站尚未确认，正常运行会返回 `COLOR_RESET_PROCESS_NAME_UNCONFIRMED`，不点击。
- Field-debug 通过 explicit override 临时允许 `medexworkstation.exe` 和 `medexworkstations.exe` 两个 provisional candidates，并记录实际进程名。
- `report_editor.ahk` 现在区分 paste failed、paste+reset succeeded、paste succeeded but reset failed，以及 clipboard restore failed。
- Reset failure 不会自动删除或 undo 已插入文字。
- `clipboard_html.ahk` 仍只负责 generic CF_HTML/clipboard transaction，没有引入 MedEx UIA logic。
- Minimal logs 写入 `%TEMP%\MedExAHK\`，不建立最终 user-data/config architecture。
- 选择 Descolada UIA-v2 v1.1.3；该依赖没有 vendored，Windows field machine 必须通过 standard `<UIA>` library path 提供。
- 新增 `debug/medex_color_reset_field_debug.ahk`，dedicated hotkey 为 Ctrl+Alt+F12。

## 今日确认

- Dynamic `CF_HTML` 已经可以在 MedEx report editor 中插入红色文字。
- 剩余问题是 MedEx 继承最后插入字符颜色，后续用户输入保持红色。
- MedEx 是 Electron/Chromium application，主窗口为 `ahk_class Chrome_WidgetWin_1`，report editor 暴露为 `Document`。
- 当前版本无法通过 F12、Ctrl+Shift+I、remote-debugging port 或 pipe 直接连接 DevTools。
- Editor `Document` 支持 `TextPattern`、`ValuePattern` 和 `LegacyAccessiblePattern`。
- Color trigger 本身没有可直接查询的 UIA node。
- Color menu 打开后，各颜色项暴露为支持 `InvokePattern` 的 `Hyperlink`；Name 为 `000000` 的 item 可以把当前 insertion color 改成 black。
- `16px` 和 `①` 的 UIA `BoundingRectangle` 可作为可靠相对 anchors。
- 原始 legacy 两个文件共包含 5 个报告 hotstrings，以及多组键盘、鼠标、阅片标注、测量/清除、封面图和 clipboard snapshot 行为。
- 新项目与 `legacy/string_change.ahk` 存在 5 个直接 hotstring collisions；新项目尚未迁移任何实际 legacy viewer action。

## 仍属 experimental

- 基于 anchors 的 `0.337` 水平比例只在当前观察 geometry 上成立，必须在目标工作站验证 DPI、缩放、窗口宽度和 MedEx layout variation。
- Color trigger 仍需一个经过校验的 proportional coordinate click。
- Menu appearance detection 和 retry policy 已进入源码，但仍未经过 Windows field validation。
- `executeJavaScript()`、Electron IPC 和 embedded editor direct command 尚未证明可用。
- Legacy `red_not.clip` 不在仓库内，无法确认其 visible text/format 与新项目完全等价。
- UIA-v2 在目标 MedEx Electron version 上的 `ElementFromHandle`/`ElementFromChromium` tree shape 尚未验证。
- 尚未确认 color menu 是否作为 foreground window subtree 的动态 `Hyperlink` 出现。
- 尚未确认 `WinGetClientPos` screen origin 与 UIA `BoundingRectangle` 在目标 DPI awareness context 中保持一致。
- Menu timeout 600 ms、poll interval 40 ms、最多 2 次 trigger attempts 都是 provisional field-test values。

## Approved V1 color-reset route

```text
PasteRedFigureText()
→ report_editor workflow
→ ResetMedExInsertionColor()
   → verify foreground process
   → find 16px and ① anchors
   → validate geometry
   → calculate proportional trigger point
   → click trigger
   → wait for menu
   → find Hyperlink Name=000000
   → Invoke()
   → return structured result
```

所有失败分支 fail-closed，不执行 blind follow-up clicks。详细证据和 rejected approaches 见 `docs/technical-investigations/2026-07-medex-rich-text-color-reset.md`。

## Legacy coexistence requirement

v0.5.0 内测期仍需同时运行新 executable 和 cleaned compatibility script。新 build 只接管完整、稳定且验证过的 capabilities；compatibility 只保留缺失功能。原始 legacy scripts 不修改、不删除。

当前 `legacy/medex_legacy_compat.ahk` 是预备 scaffold，不应在 color reset 完成前被当成用户现有工作流的完整替代，因为它有意不注册 5 个重复 report hotstrings。正式切换和回滚规则见 `docs/migration/coexistence-plan.md`。

## v0.5.0 next implementation order

1. Finish and validate MedEx color reset.
2. Introduce centralized user configuration.
3. Migrate existing new-project hotkeys and hotstrings to configuration.
4. Add user-defined hotstring support.
5. Add structured diagnostics and logging.
6. Inventory legacy functionality.
7. Produce a non-conflicting legacy compatibility script.
8. Package the v0.5.0 internal-test executable.
9. Write/update simple Chinese internal-test instructions.
10. Begin internal testing.
11. Only after stabilization, begin SUVmax and long/short-axis automation.

第 6 项已在本轮建立初版 inventory，第 7 项已创建预备 scaffold；在第 1–5 项实现完成后仍需重新核对它们，不能因此跳过顺序中的验证关卡。

## 当前 exact next task

下一项任务不是继续扩展代码，而是在目标 Windows 工作站执行 field-debug procedure，回传完整 diagnostic result，并据实际结果确认 process name、UIA tree、geometry、timing 和 Invoke behavior。

Field test 成功后，下一次精确代码变更为：

1. 将确认的 executable name 写入 `MedExColorResetDefaults.ConfirmedProcessName`。
2. 根据 diagnostic evidence 调整 ratio/timing/geometry ranges；没有证据不改。
3. 在正常 report hotstrings 上完成 harmless non-clinical end-to-end validation。
4. 只有 color reset 稳定后，才开始 centralized user configuration runtime。

## 当前实现文件

- `src/medex_color_reset_logic.ahk`
- `src/diagnostics.ahk`
- `src/adapters/medex_report_editor.ahk`
- `src/report_editor.ahk`
- `src/clipboard_html.ahk`
- `src/hotstrings.ahk`
- `debug/medex_color_reset_field_debug.ahk`
- `tests/test_medex_color_reset_logic.py`

## Pure-logic test status

macOS 上运行 `python3 -m unittest discover -s tests -p 'test_*.py'`：13 tests passed。覆盖 CF_HTML 既有 tests，以及 ratio、valid geometry、reversed anchors、zero-width rectangle、invalid coordinate range、point outside target window、screen-to-client conversion、structured result construction 和 required result codes。

这不代表 Windows UIA、MedEx、mouse click 或 Invoke runtime 已测试。

## Windows field-debug procedure

Prerequisite：安装 AutoHotkey v2 和 pinned UIA-v2 v1.1.3，使 `#Include <UIA>` 可用；准备 approved non-clinical test context。

1. 启动 MedEx。
2. Focus report editor。
3. 用 Task Manager 或 Window Spy 记录 actual process name。
4. 记录 MedEx version；不可见时写 `UNKNOWN`。
5. 记录 Windows resolution。
6. 记录 display scaling。
7. 启动 `debug/medex_color_reset_field_debug.ahk`，按 Ctrl+Alt+F12 运行 diagnostic hotkey。
8. 确认 color menu 是否打开。
9. 确认 black item 是否被 Invoke。
10. 手工输入一个 harmless test character，确认它是 black。
11. 将自动复制的 diagnostic result 带回 Mac development environment。
12. 记录 mouse movement、focus loss、menu delay 或任何 unexpected side effect。

严禁在 finalized patient report 中执行 field test。Diagnostic hotkey 自身不粘贴或记录 clinical content。

## Implemented code changes

1. 增加 `src/adapters/medex_report_editor.ahk`。
2. 在该模块定义 stable result codes 或 result factory，返回 `{ ok, code, context }`，不得只返回 Boolean。
3. 实现 `ResetMedExInsertionColor()`：
   - 读取 foreground process，不主动激活其他窗口；
   - 在 field-debug 中严格匹配两个 provisional candidates，production 在 confirmed name 缺失时 fail-closed；
   - 使用选定的 AHK v2 UIA library 查找 Name=`16px` 和 Name=`①`；
   - 提取并验证两个 `BoundingRectangle`；
   - 使用 `arrowX = fontSizeRight + 0.337 * (numberButtonLeft - fontSizeRight)` 和 `arrowY = fontSizeTop + 1`；
   - 将 screen/client coordinate conversion 作为显式步骤，不混用 coordinate spaces；
   - 点击一次 trigger 后轮询 menu；
   - 只对 ControlType=`Hyperlink` 且 Name=`000000` 的 element 调用 `Invoke()`；
   - 所有异常映射到 documented result codes。
4. 修改 `src/report_editor.ahk`，新增 editor-level workflow，例如 `InsertRedFigureTextAndRestoreState(text)`；它先调用 generic paste，再调用 MedEx adapter。
5. 修改 `src/hotstrings.ahk`，让 4 个 red-text workflows 调用 editor-level workflow；保持现有 visible phrases 和 cursor movement 不变。
6. 不在 `src/clipboard_html.ahk` 中加入任何 MedEx process、UIA、coordinate 或 menu code；只在需要时收紧其 generic transaction result contract。
7. 增加不含临床文字的 unit/reference tests：geometry calculation、invalid rectangles、result-code mapping。
8. 扩充 Windows manual checklist：wrong process、missing anchors、menu timeout、missing black item、Invoke failure、DPI/layout variation、clipboard restoration、cursor final position 和后续输入颜色。
9. 验证通过后再生成 `release/report_assistant.ahk`；未验证前不制作正式 internal-test executable。

## Known risks

- Color trigger 没有独立 UIA element，V1 仍包含一次 coordinate click。
- UIA accessible names `16px`、`①` 或 toolbar geometry 可能随 MedEx version、语言、DPI、窗口宽度变化。
- 新旧进程没有 shared clipboard/mouse mutex；并发触发可能互相干扰。
- Compatibility 中的 legacy coordinates 缺少 window guard，可能在错误窗口 blind click。
- 新项目的 suspend/exit hotkeys 不控制 compatibility process。
- 默认 AHK tray icons 相似，用户可能退出错误实例。
- 当前 config keys `RED_TEXT_COLOR`、`RED_TEXT_RESET_TO_BLACK` 和示例 coordinates 尚未形成 centralized validated runtime config。
- `src/config.example.ahk` 当前写的是 `medexworkstation.exe`，而调查确认的 V1 foreground process 是 `medexworkstations.exe`；实现前必须在目标工作站确认并统一，不能用 substring match 掩盖差异。

## Deferred work

- automatic SUVmax extraction；
- automatic long-axis and short-axis extraction；
- complete settings GUI；
- Electron JavaScript injection；
- automatic updater；
- multi-editor support；
- direct embedded-editor command；
- 未经逐项校准和验证的 legacy viewer action migration。

## Conservative migration decisions applied

- 所有 legacy hotkeys 和 viewer actions 暂时视为仍然需要。
- 保留 XButton1 notification。
- 保留三组 fixed-parameter annotation workflows。
- 原样保留 SUV 3000 ms 与 Arrow 1000 ms repeat-press clear semantics。
- 不假设 `red_not.clip` 与新 CF_HTML functionally equivalent。
- 本次没有删除或修改任何 additional legacy capability。

当前只需要 Windows field evidence：actual executable name、MedEx version、resolution、display scaling、diagnostic result 和 observed side effects。
