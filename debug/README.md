# MedEx 颜色复位 Windows 现场调试

`medex_color_reset_field_debug.ahk` 是现场验证脚本，不是生产入口。它不会粘贴报告文字，也不会修改正常用户配置；它会尝试打开颜色菜单并对 Name=`000000` 的 UIA `Hyperlink` 执行 `Invoke()`。

## UIA 依赖

本实现 pin Descolada UIA-v2 v1.1.3。production 和 field debug 共用：

```text
src\Lib\UIA.ahk
debug\medex_color_reset_field_debug.ahk
```

Field script 使用 explicit relative include，production source 使用 `src/Lib` standard library lookup。目标工作站无需系统级安装 UIA-v2，也不要同时 include 另一份 global library。

- Repository: `https://github.com/Descolada/UIA-v2`
- Pinned release: `v1.1.3`

如果 repository-pinned dependency 缺失，AHK 会在启动时明确报告 include failure；不要把缺失依赖降级成 optional include。运行中 UIA 初始化失败仍返回：

```text
COLOR_RESET_UIA_UNAVAILABLE
```

不得为了绕过该结果而加入 blind clicks。

## Dedicated hotkey

```text
Ctrl+Alt+F12
```

脚本不会显示 MsgBox、ToolTip 或 TrayTip。它自动把完整结果复制到 clipboard，并默认追加写入：

```text
%TEMP%\MedExAHK\medex_color_reset_field_debug.txt
```

最小 development log 写入：

```text
%TEMP%\MedExAHK\medex_color_reset_field_debug.log
```

两者都不得包含 patient information、report text、clipboard text 或 pasted phrase。

`AUTOMATION_CHAIN_OK` 只表示 candidate selection、menu click、black-item lookup 和 Invoke 自动化链路完成。输出仍为 `FINAL_COLOR_PENDING_VISUAL_VALIDATION`；只有操作者随后输入无害字符并确认黑色，才能单独记录最终视觉验证成功。

## 可调 field-test overrides

只编辑脚本顶部以下 constants：

- `DEBUG_COLOR_ARROW_OFFSET_X`
- `DEBUG_COLOR_ARROW_OFFSET_Y`
- `DEBUG_MENU_OPEN_TIMEOUT_MS`
- `DEBUG_MENU_POLL_INTERVAL_MS`
- `DEBUG_MAX_TRIGGER_ATTEMPTS`
- `DEBUG_ALLOW_PROVISIONAL_PROCESS`
- `DEBUG_CONFIRMED_PROCESS_NAME`

`DEBUG_MAX_TRIGGER_ATTEMPTS` 在 adapter 内始终限制为 1–2，不能通过 debug override 形成无限或重复 blind clicks。

## Minor layout recalibration

在 MedEx 小版本只改变工具栏局部间距时，先用 Accessibility Insights 记录目标字号 `Text` rectangle，再用 Window Spy/现场观察记录颜色箭头目标点。计算：

```text
ColorArrowOffsetX = targetScreenX - fontRect.r
ColorArrowOffsetY = targetScreenY - Round((fontRect.t + fontRect.b) / 2)
```

只修改 field-debug 顶部两个 override 并在 non-clinical context 复测。验证通过后，再把相同值写入 `MedExColorResetLayoutProfile` 的新 profile/release；不要改 resolver，也不要加入 absolute-coordinate fallback。

## 安全限制

- 不在 finalized patient report 中测试。
- 使用经过批准的 non-clinical test context。
- Diagnostic hotkey 不插入 test text；颜色复位完成后，由用户手工输入一个无害字符检查颜色。
- 如果鼠标移动、窗口失焦或菜单行为异常，立即停止重复测试并退出脚本。
