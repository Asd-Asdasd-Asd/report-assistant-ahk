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
