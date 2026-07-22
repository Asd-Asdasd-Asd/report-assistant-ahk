# MxNMSoft 测量值读取调查记录

本文档记录 Windows 工作站上对 MxNMSoft / `MedExNMFusion.exe` 阅片窗口测量值读取的现场调查。当前只记录发现和计划，不实现自动化功能。

## Line measurement

观察到的菜单控件：

- Text: `复制直线测量值`
- Observed ClassNN: `Button10`
- Observed Control ID: `21877`

剪贴板输出示例：

```text
2.1cm×2.9cm (长径×短径)
```

已验证调用链：

```text
mouse located on image area containing the measurement
-> obtain MedExNMFusion.exe main-window HWND
-> convert screen coordinates to client coordinates
-> send WM_RBUTTONDOWN
-> send WM_RBUTTONUP
-> wait for a newly created #32770 popup
-> locate the popup containing visible text “复制直线测量值”
-> obtain the runtime control ID
-> send WM_COMMAND to the popup
-> read clipboard content
-> validate and parse the line measurement
```

重要负向发现：

- 如果尚未创建 popup context，直接向主窗口发送 `WM_COMMAND 21877` 无效。
- 现场测试中，单独发送 `WM_CONTEXTMENU` 没有创建 popup。
- 当前可靠路径需要 `WM_RBUTTONDOWN` + `WM_RBUTTONUP`。

## SUVMax

同一 context-menu 机制暴露：

- Text: `复制SUVMax值`
- Observed ClassNN: `Button11`

剪贴板输出示例：

```text
SUVMax: 3.599
```

解析 regex：

```regex
^\s*SUVMax\s*:\s*(\d+(?:\.\d+)?)\s*$
```

更新策略：

- SUV hotstrings 应优先读取当前图像 context-menu。
- 不应默认使用最后一条 Line 522 log record。
- logs 仍可用于诊断、study-transition 研究和未来严格校验后的 secondary source。
- 当前图像读取失败时，不应自动 fallback 到最后一个 SUV log 值。

## Shared architecture

计划抽象：

```text
ContextMeasurementProvider
├── open_context_popup()
├── invoke_copy_command(command_text)
├── read_line_measurement()
└── read_suvmax()
```

`open_context_popup()` 职责：

- 定位 `MedExNMFusion.exe` 主窗口；
- 将目标 screen coordinates 转为 client coordinates；
- 发送 `WM_RBUTTONDOWN` 和 `WM_RBUTTONUP`；
- 检测新创建的 `#32770` popup。

`invoke_copy_command(command_text)` 职责：

- 按 visible text 定位控件；
- 使用 `GetDlgCtrlID` 获取 runtime control ID；
- 向 popup 发送 `WM_COMMAND`；
- 等待剪贴板更新；
- 返回剪贴板文本。

`read_line_measurement()` 职责：

- command text: `复制直线测量值`；
- validate and parse line axes。

`read_suvmax()` 职责：

- command text: `复制SUVMax值`；
- validate and parse SUVMax。

## v0.6.0 first implementation contract

本节是 v0.6.0 首版实现的固定运行契约。后续 remote development 以本节为准；现场证据推翻某项假设时，先更新本节，再修改 production workflow。

### Product boundary and assumptions

- 用户在报告编辑时负责保证当前报告与阅片窗口中的检查对应。工具不读取患者姓名、检查号、窗口正文或其他临床内容，也不尝试纠正检查错配。
- 首版只要求存在可用的 `MedExNMFusion.exe` 阅片窗口，不实现 study identity matching。
- 阅片窗口由软件设置固定位置，不能由用户任意拖动。首版允许使用集中维护的 screen-coordinate profile 定位可靠图像区域。
- 图像位置只能由单一 profile/resolver 提供，不得把坐标散落在 hotstring、clipboard 或 report-editor modules 中。
- profile 至少校验 screen bounds 和目标 viewer window/client bounds。Windows 现场验收后，可在不改变调用方接口的前提下增加 UIA-relative resolver 或用户校验步骤。

### Preferred no-focus-switch transport

首版不得主动激活 `MedExNMFusion.exe`，不得移动鼠标，也不得为读取测量值切换报告编辑器焦点。优先直接向 viewer HWND 发送后台窗口消息：

```text
;fzg triggered in the report editor
-> capture originalReportHwnd and originalReportProcess
-> verify originalReportHwnd exists and process is in the report allowlist
-> locate MedExNMFusion.exe viewer HWND
-> resolve a profile-owned image screen point
-> validate the point against screen and viewer bounds
-> convert the screen point to viewer client coordinates
-> save ClipboardAll and clear the clipboard or install a unique sentinel
-> send WM_RBUTTONDOWN and WM_RBUTTONUP directly to the viewer HWND
-> wait for a newly created #32770 popup containing “复制SUVMax值”
-> obtain the command runtime control ID
-> send WM_COMMAND to that popup
-> wait for a new clipboard result
-> copy the returned text into a local value
-> close only the popup created by this operation if cleanup is required
-> restore the original ClipboardAll in finally
-> run zero-wait report-target guards
-> run the existing red-left4 insertion
-> insert the formatted value only when the measurement state is FOUND
```

The transport must not call `WinActivate`, `WinWaitActive`, `MouseMove`, `MouseClick`, `ControlClick`, or an equivalent focus-changing fallback. Required popup and clipboard waits must be bounded; the report-target guards themselves must not sleep or retry.

If background `WM_RBUTTONDOWN` + `WM_RBUTTONUP` cannot open a usable popup on the Windows workstation, return `AUTOMATION_FAILED`. Do not silently switch to a focus-changing implementation. A future UIA caret capture/restore path is a separately reviewed fallback, not part of this first contract.

### Report-target guards

Capture the original report HWND before measurement acquisition. Immediately before any report insertion, perform only inexpensive synchronous checks:

1. `originalReportHwnd` still exists.
2. Its current process name remains in the existing report-process allowlist.
3. `originalReportHwnd` is still the active foreground window.

If any guard fails, do not send text, caret movement, paste commands, or measurement content. Return a structured failure and use only non-focus-stealing feedback. These guards protect against an unexpected foreground change during the short script-owned operation; they do not perform patient or study matching.

### `;fzg` orchestration

Measurement acquisition happens before the existing report insertion. The measurement text must be copied into a local value before the acquisition transaction restores the user's clipboard. The existing CF_HTML transaction then owns the report insertion independently.

```text
ReadCurrentSuvMaxWithoutFocusSwitch()
-> verify original report target
-> insert “放射性摄取增高，SUVmax约（见图）” through the existing workflow
-> restore the user's clipboard
-> send the existing Left 4
-> FOUND: insert the formatted numeric value at the current caret
-> NOT_ANNOTATED: insert nothing and leave the caret for manual input
-> AUTOMATION_FAILED: insert nothing, leave the caret for manual input,
   and emit explicit non-focus-stealing failure feedback
```

The existing `Left 4` is unconditional after a successful red-left4 insertion. Do not replace it with `Left 5`, calculate a new caret offset from the measurement text, or run Color Reset for `;fzg`.

This automatic behavior belongs to the builtin `;fzg` workflow. It must not be attached to every configurable `red-left4` template.

### SUVMax state mapping

For the first implementation:

- valid `SUVMax: N` where `N > 0` -> `FOUND`；
- valid `SUVMax: 0.000` or another exact numeric zero -> `NOT_ANNOTATED`；
- popup not created, command not found, invocation failed, clipboard did not produce a new result, or returned text did not match the expected format -> `AUTOMATION_FAILED`。

Only `FOUND` may insert a numeric value. `NOT_ANNOTATED` and `AUTOMATION_FAILED` both preserve the manual-input caret position, but `AUTOMATION_FAILED` must remain visibly or diagnostically distinguishable from a normal no-annotation result.

### Explicit exclusions

- no patient/study content matching；
- no screen OCR or measurement-text pixel recognition；
- no latest-log-value fallback；
- no old clipboard-value reuse；
- no automatic foreground switching；
- no UIA caret restoration in the first implementation；
- no automatic retry through a second transport strategy；
- no report submission, review, or final confirmation。

## Do not hard-code runtime identities

不要把以下内容当作稳定生产标识：

- `Button10`
- `Button11`
- popup HWND
- button HWND
- PID

应使用动态识别：

- `ahk_exe MedExNMFusion.exe`
- newly created `ahk_class #32770` popup
- visible command text
- runtime control ID obtained through `GetDlgCtrlID`

## Measurement output contract

未来统一返回结构：

```text
success
measurement_type
raw_value
formatted_value
source
timestamp
study_identity
failure_reason
```

示例：

```text
success = true
measurement_type = line_axes
raw_value = 2.1cm×2.9cm (长径×短径)
formatted_value = 2.1cm×2.9cm
source = mxnm_context_command
```

```text
success = true
measurement_type = suvmax
raw_value = SUVMax: 3.599
formatted_value = 3.6
source = mxnm_context_command
```

```text
success = false
measurement_type = suvmax
failure_reason = no_valid_current_measurement
```

## Safety principles

- prefer false negative over wrong-value insertion；
- never reuse the previous clipboard measurement；
- never insert an old measurement value after automatic reading failure；
- do not use the latest SUV log line as an automatic fallback；
- save `ClipboardAll` before invoking the copy command；
- clear the clipboard before invoking the command；
- verify that the clipboard changed and matches the expected format；
- restore the original `ClipboardAll` afterward；
- fall back to the existing manual input workflow；
- only clear SUV measurement state after successful report insertion；
- do not require users to restart MxNMSoft after an automation failure。

## Line measurement parser

期望输入：

```text
2.1cm×2.9cm (长径×短径)
```

建议 parser compatibility：

- `cm` or `mm`；
- `×`, `x`, `X`, `*`, or `＊`；
- integer or decimal values；
- optional spaces。

概念 regex：

```regex
^\s*\d+(?:\.\d+)?\s*(?:mm|cm)\s*[×xX＊*]\s*\d+(?:\.\d+)?\s*(?:mm|cm)
```

建议结构化结果：

```text
long_axis
short_axis
long_unit
short_unit
raw_text
```

如果单位不同，应先 normalize 再格式化。

## MFCGridCtrl1

- 结果 grid 暴露为 `MFCGridCtrl1`。
- 它是 custom MFC grid control。
- 常规 Window Spy 检查无法看到单元格。
- `Ctrl+C` 没有复制其内容。
- 第一版实现不应依赖该控件。

## Logs and privacy

保留之前的 log 发现作为 secondary diagnostic material。

- MxNMSoft logs 可能包含 patient names、patient IDs、study IDs、UIDs、DICOM paths 和其他受保护信息。
- 不要提交 raw logs。
- 不要上传完整 logs。
- 测试必须使用 synthetic and redacted fixtures。
- 只保留 minimal parsed state。
- debug output 默认不得包含 patient identifiers。
