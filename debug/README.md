# MedEx 颜色复位 Windows 现场调试

`medex_color_reset_field_debug.ahk` 是现场验证脚本，不是生产入口，也不注册 `;red`、`;fzg` 或其他 production hotstrings。F12 不粘贴报告文字并保留显式 `uiaInvoke` comparison；F11 调用与 production `;red` 相同的 `RunRedInsertion()`，显式使用 `relativeMousePixelValidated` 并输出 Step 1 critical-path timing。两者都不修改正常用户配置。

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

## Dedicated hotkeys

```text
Ctrl+Alt+F12
Ctrl+Alt+F11
```

Step 3 另提供 `Ctrl+Alt+F10` fast-failure test。它会先发送同一 red CF_HTML paste，再用故意不匹配的 process allowlist 让 Candidate G 在任何 coordinate click 前 fail closed。F10 不把 diagnostic 写回 clipboard，以便操作者验证原 sentinel 已恢复；完整结果只追加到 `%TEMP%\MedExAHK\medex_production_timing_debug.txt`。

脚本不会显示 MsgBox、ToolTip 或 TrayTip。F12/F11 自动把完整结果复制到 clipboard；F10 保留 restored clipboard。结果默认追加写入：

```text
%TEMP%\MedExAHK\medex_color_reset_field_debug.txt
```

最小 development log 写入：

```text
%TEMP%\MedExAHK\medex_color_reset_field_debug.log
```

两者都不得包含 patient information、report text、clipboard text 或 pasted phrase。

`AUTOMATION_CHAIN_OK` 只表示 candidate selection、menu click、black-item lookup 和 Invoke 自动化链路完成。输出仍为 `FINAL_COLOR_PENDING_VISUAL_VALIDATION`；只有操作者随后输入无害字符并确认黑色，才能单独记录最终视觉验证成功。

F12 是 reset-only field diagnostic；F11 是完整 Candidate G `;red` success timing；F10 是 Step 3 controlled fast failure。测试时不得同时运行 generated release 与本 debug script。

## 可调 field-test overrides

只编辑脚本顶部以下 constants：

- `DEBUG_COLOR_ARROW_OFFSET_X`
- `DEBUG_COLOR_ARROW_OFFSET_Y`
- `DEBUG_COLOR_RESET_STRATEGY`
- `DEBUG_MENU_LOOKUP_STRATEGY`
- `DEBUG_MENU_OPEN_TIMEOUT_MS`
- `DEBUG_MENU_POLL_INTERVAL_MS`
- `DEBUG_USE_CACHED_ANCHOR_SNAPSHOT`
- `DEBUG_ENABLE_FONT_ANCHOR_RETRY`
- `DEBUG_ALLOW_PROVISIONAL_PROCESS`
- `DEBUG_CONFIRMED_PROCESS_NAME`

现有 `medex_color_reset_field_debug.ahk` 继续固定测试 `uiaInvoke`，作为 comparison/rollback。Candidate G 使用独立 `medex_candidate_g_calibration.ahk`：F8–F11 用于 G1 calibration，F12 经 production dispatcher 显式调用 `relativeMousePixelValidated`。Windows G2、caret-order A/B 与最终 generated-release 验证通过后，正常 release 的颜色复位默认 strategy 已提升为后续 production mainline；两种 strategy 之间没有 automatic fallback。

Candidate G2 F12 只在 MedEx 0.0.1.0、1920×1080、100%、DPI 96 profile 匹配、toolbar row 唯一、arrow/black points 有效、foreground 未变化且 popup 四点 signature 匹配时发送一次 black click。结果复制到 clipboard 并写入 `%TEMP%\MedExAHK\candidate_g_calibration.txt`；不显示 modal 或 non-modal UI。

同一脚本的 F7 是 closed-popup safety gate：它故意不点击 arrow，只验证关闭状态 signature 必须失败且 black click 不可达。F7 只用于现场安全验证，不是 production fallback 或 interaction strategy。

`medex_candidate_g2_test.ahk` 是独立 G2 production-path test build，注册 `;red`、`;fzg` 和 reset-only F12，并为每次操作追加 privacy-safe 行到 `%TEMP%\MedExAHK\candidate_g2_test.txt`。它必须单独运行；不得同时运行 generated release、calibration harness 或 legacy script。

同一 test build 保留历史 `Ctrl+Alt+F8` G2 reset-path，并提供 Step 4 单变量 A/B：`Ctrl+Alt+F9` 为 no-reset、50 ms、`Left 4` control；`Ctrl+Alt+F10` 为 no-reset、0 ms、`Left 4` candidate。F9/F10 只改变 `SettleDelayMs`，结果写入 `%TEMP%\MedExAHK\candidate_g2_test.txt`；不得使用 `Left 5`。

2026-07-16 历史 A/B 结果确认 F9 50 ms control 连续 6 次正确，production 因而采用 no-reset caret-relocation workflow；F8 继续保留为历史对照。2026-07-20 Step 4 在同一 editor state 完成五组 F9/F10：50 ms 与 0 ms 均保持正确 caret、clipboard 和黑色输入，随后 generated release 也通过；`medex_color_reset_field_debug.ahk` 不用于本轮 `;fzg` caret validation。

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
- F12 不插入 test text；F11 会运行真实 `;red` shared workflow 并插入红色 marker。两者都只能在 approved non-clinical context 使用。
- 如果鼠标移动、窗口失焦或菜单行为异常，立即停止重复测试并退出脚本。

## Candidate G1 calibration

`medex_candidate_g_calibration.ahk` 是独立 calibration harness。不要与 generated release、legacy 或 `medex_color_reset_field_debug.ahk` 同时运行。

- `F8`：鼠标置于实际 color arrow center，记录 arrow offset。
- `F9`：手工打开 popup、鼠标置于 black swatch center，记录 black offset；脚本不会点击。
- `F10`：popup closed 状态读取 pixel probe grid。
- `F11`：解析并验证 toolbar row，最多点击 arrow 一次，在 0/20/40/80 ms 读取 probe grid。

F11 不执行 popup UIA lookup、`000000` search、Invoke 或 black click。estimated `(320,0)` 和 `(6,83)` 只用于 supported baseline 的 G1 measurement，不是 production constants。

输出位置：

```text
%TEMP%\MedExAHK\candidate_g_calibration.txt
```

脚本不显示 `MsgBox`、`ToolTip` 或 `TrayTip`，不保存 screenshot、报告文字或 clipboard content。
