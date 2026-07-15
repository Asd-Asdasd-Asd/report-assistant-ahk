# Windows 手动测试清单

本清单在安装 AutoHotkey v2 的 Windows 目标工作站执行。不得使用真实患者报告作为测试样本。

- [ ] Script 正常启动。
- [ ] Ctrl+Alt+Esc 可以暂停和恢复 new-project hotkeys/hotstrings。
- [ ] Ctrl+Alt+Q 可以退出新项目。
- [ ] 明确确认上述两个快捷键不会停止 compatibility process。
- [ ] `;cmx` 插入 `cm×cm` 并将光标左移 2。
- [ ] `;red` 不破坏原剪贴板内容。
- [ ] `;red` 插入红色 `（见图）`。
- [ ] `;red` 后立即输入的字符为黑色。
- [ ] `;fzg` 插入预期短语和红色 figure marker。
- [ ] `;fzg` 的光标最终位置正确。
- [ ] `;fwj` 和 `;fjd` 的每一个可见字符、红色范围和光标位置正确。
- [ ] Red insertion 失败时不静默 fallback 成黑色 `（见图）`。
- [ ] Hotstring expansion 后 report editor 仍可正常使用。
- [ ] 未经批准的 viewer coordinate actions 保持 disabled/placeholder-only。
- [ ] 没有发生 automatic final submission。

## v0.4.2 CF_HTML staged tests

### Notepad

- [ ] `;red`、`;fzg`、`;fwj`、`;fjd` 立即触发。
- [ ] 不支持 HTML 时不插入内容或给出 visible failure；不静默插入黑色 `（见图）`。
- [ ] 尝试后恢复原剪贴板。
- [ ] `;fzg` paste dispatch 失败时不移动光标。

### Microsoft Word

- [ ] `;red` 插入红色 `（见图）`。
- [ ] 紧接着输入 `abc` 时文字为黑色。
- [ ] 插入后恢复原剪贴板。
- [ ] `;fzg`、`;fwj`、`;fjd` 保持现有可见短语。
- [ ] `;fzg` 只在 paste dispatch 成功后 Left 4。

### Edge 或 Chrome contenteditable

- [ ] `;red` 在 contenteditable field 中插入红色 `（见图）`。
- [ ] 紧接着输入 `abc` 时文字为黑色。
- [ ] 没有插入 hidden/visible boundary character。
- [ ] 插入后恢复原剪贴板。

### MedEx report editor

- [ ] Editor 接受 `CF_HTML` 并把 `（见图）` 渲染为红色。
- [ ] Color reset 后输入 `abc` 为黑色。
- [ ] 正常和重复输入时 paste timing 可靠。
- [ ] 成功和失败后均恢复原剪贴板。
- [ ] 失败不会 fallback 成黑色 `（见图）`。
- [ ] `;fzg` paste 成功后光标位置正确。
- [ ] 插入失败后 report input 仍可使用。

## v0.5.0 MedEx color reset staged tests

### Field-debug 准备与执行

Prerequisite：[ ] AutoHotkey v2 可用，field-debug 目录包含 pinned `debug/Lib/UIA.ahk` v1.1.3，并已准备 approved non-clinical test context。UIA-v2 不需要系统级安装，不要同时提供另一份全局版本。

1. [ ] 启动 MedEx。
2. [ ] Focus report editor。
3. [ ] 记录 actual process name，不从 sample config 推断。
4. [ ] 记录 MedEx version；无法可靠读取时记录 `UNKNOWN`。
5. [ ] 记录 Windows resolution。
6. [ ] 记录 display scaling。
7. [ ] 启动 `debug/medex_color_reset_field_debug.ahk` 并按 Ctrl+Alt+F12 运行 diagnostic hotkey。
8. [ ] 确认 exact Text Name=`检查所见` 被唯一选为 region anchor。
9. [ ] 确认同行右侧动态字号 Text（如 `14px`/`16px`）被唯一选为 local anchor。
10. [ ] 确认 calculated screen point 与 color arrow 对齐；baseline evidence 期望 `(672,297)`。
11. [ ] 确认 color menu 是否打开，以及 Name=`000000` 的 black item 是否被 Invoke。
12. [ ] 确认全过程没有 `MsgBox`、`ToolTip`、`TrayTip` 或其他 focus-stealing feedback，MedEx editor focus 未改变。
13. [ ] 在 approved non-clinical test context 手工输入一个 harmless test character，并确认它是 black；只有此步骤可将 `FinalInsertionColorVisuallyValidated` 记为 true。
14. [ ] 将自动复制的完整 diagnostic result 带回 Mac development environment。
15. [ ] 记录任何 mouse movement、focus loss、menu delay 或 unexpected side effect。

严禁在 finalized patient report 中执行本测试。Diagnostic hotkey 不插入 test text，也不得记录 clinical content。

- [ ] Foreground process 正确时进入 UIA lookup；错误时返回 `COLOR_RESET_WRONG_PROCESS` 且不点击。
- [ ] Production process name 未确认时返回 `COLOR_RESET_PROCESS_NAME_UNCONFIRMED` 且不点击。
- [ ] UIA-v2 缺失时返回 `COLOR_RESET_UIA_UNAVAILABLE` 且不点击。
- [ ] Anchor enumeration 以 foreground MedEx window root 或经确认的报告区域父容器为 scope，不要求 toolbar 是 focused `Document` descendant。
- [ ] 不使用 exact `16px` 或 shortcut `①` 作为 production lookup。
- [ ] Region anchor 缺失返回 `COLOR_RESET_REGION_ANCHOR_NOT_FOUND` 且不点击。
- [ ] 多个有效 `检查所见` 返回 `COLOR_RESET_REGION_ANCHOR_AMBIGUOUS` 且不点击。
- [ ] 同行没有匹配 `^\d+(?:\.\d+)?px$` 的字号 Text，返回 `COLOR_RESET_FONT_SIZE_ANCHOR_NOT_FOUND`。
- [ ] 同行存在多个匹配字号 Text，返回 `COLOR_RESET_FONT_SIZE_ANCHOR_AMBIGUOUS`。
- [ ] 其他 toolbar 全局存在多个字号 Text 时，只要目标行唯一，仍可正确选择。
- [ ] `①` 缺失、改名或出现多个 shortcut symbols 不影响 normal path。
- [ ] optional `rAI` 存在时输出 fingerprint；缺失、改名或歧义时不阻塞。
- [ ] Rectangles 无效或相对位置异常时返回 `COLOR_RESET_INVALID_GEOMETRY` 且不点击。
- [ ] Zero-width/non-finite rectangle 返回 `COLOR_RESET_INVALID_RECTANGLE`。
- [ ] Calculated point 位于 client area 和 local toolbar band；否则 fail closed。
- [ ] 不要求整个 UIA root rectangle 位于 client area。
- [ ] 字号 value 从 `16px` 改为 `14px`、rectangle 不变时，point 不变。
- [ ] 工具栏整体沿 Y 移动时，calculated Y 移动相同 delta。
- [ ] `ColorArrowOffsetX/Y` 改变时 point 按相同 delta 改变，不修改 resolver。
- [ ] Trigger click exception 返回 `COLOR_RESET_TRIGGER_CLICK_FAILED`。
- [ ] Click 前 foreground hwnd/process 改变时停止且不点击。
- [ ] Menu 未出现时返回 `COLOR_RESET_MENU_NOT_OPENED`，不继续 blind click。
- [ ] Menu 中没有 Name=`000000` 时返回 `COLOR_RESET_BLACK_ITEM_NOT_FOUND`。
- [ ] Black item 不支持 InvokePattern 时返回 `COLOR_RESET_INVOKE_UNAVAILABLE`。
- [ ] `Invoke()` 抛错或失败时返回 `COLOR_RESET_INVOKE_FAILED`。
- [ ] 未分类异常返回 `COLOR_RESET_UNEXPECTED_ERROR`，不继续点击。
- [ ] 自动化字段记录 region/font/optional anchor、active profile/offsets、`ColorMenuClickSent`、`BlackItemFound` 和 `BlackItemInvokeSucceeded`。
- [ ] Invoke 成功时只报告 `AUTOMATION_CHAIN_OK` / `FINAL_COLOR_PENDING_VISUAL_VALIDATION`，不得自动报告最终成功。
- [ ] `FinalInsertionColorVisuallyValidated` 初始为 false/unknown，人工确认无害字符为黑色后才单独记录 true。
- [ ] `RetryCount` 输出为整数 `0` 或 `1`，不得序列化为 Boolean。
- [ ] `ProcessNameConfirmed=false` 必须与 provisional candidate accepted 的含义分开记录。
- [ ] Field debug 默认只写 clipboard/log，不显示成功提示；任何可选提示必须先证明不改变 focus 和颜色状态。
- [ ] 最多执行一次 initial trigger click 和一次 bounded retry，不出现 repeated blind clicks。
- [ ] Mouse position 在 interaction 结束后恢复。
- [ ] 在目标 DPI、display scaling、resolution、window width 和 MedEx version 上重复测试。
- [ ] Logs 只包含 timestamp、action、result code、process、rectangles、point、timing、retry 和安全检测到的 version。
- [ ] Logs 不包含患者信息、report text、hotstring replacement 或 clipboard payload。
- [ ] Copied field result 包含 process、window handle、DPI/scaling、profile、region/font/optional rectangles、screen/client point、Invoke flags 和 elapsed timings。

## v0.5.0 configuration staged tests

- [ ] `config.ini` 不存在时使用 safe defaults。
- [ ] 单项 invalid value 只使对应项回退或禁用，不使整个应用崩溃。
- [ ] Higher unsupported `ConfigVersion` 不覆盖原配置，并明确提示 incompatibility。
- [ ] Built-in 与 user-defined trigger collision 被检测并 fail-safe。
- [ ] Configured hotkeys、built-in triggers/replacements 和 user-defined hotstrings 正确注册。
- [ ] User replacement 只作为 text data，不执行 AHK code。
- [ ] 更新 executable 后 `%LocalAppData%\MedExAHK\config.ini` 保持不变。

## Compatibility staged tests

- [ ] 原始 `karabiner.ahk` 和 `string_change.ahk` instances 均已退出。
- [ ] New executable 与 `medex_legacy_compat.ahk` 同时运行时没有重复 hotkeys/hotstrings。
- [ ] Compatibility tray tooltip 可与新项目区分。
- [ ] 每个保留的 legacy hotkey 在用户确认的工作站和窗口上逐项测试。
- [ ] Shift+Alt+S 与新 clipboard transaction 不并发触发。
- [ ] SUV 3000 ms 与 Arrow 1000 ms 复按行为保持用户确认的语义。
- [ ] 回滚时能够同时退出两个进程并启动上一版已知可用组合。
