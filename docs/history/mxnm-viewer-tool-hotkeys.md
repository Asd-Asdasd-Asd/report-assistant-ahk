# MxNM Viewer 工具快捷键

更新：2026-09-06。本文描述当前源码；本次调整尚待 Windows EXE 现场验收。

## 当前命令与作用域

| 功能 | 原生命令 ID | 默认快捷键 |
| --- | ---: | --- |
| 箭头 | 21043 | Ctrl+Alt+1 |
| 长度测量 | 21048 | Ctrl+Alt+2 |
| 3D SUV 测量 | 21193 | Ctrl+Alt+3 |
| 截图 | F12 键盘消息 | Ctrl+Alt+4 |
| 清除全部标注 | 精确右键菜单命令 | Ctrl+Alt+5 |

Viewer 工具默认关闭。带修饰键的工具选择/清除支持 MedEx 报告程序及 Viewer 前台；无修饰字母/数字只在 Viewer 前台生效。截图始终限于 Viewer 前台。Win 修饰键通过设置页独立 checkbox 配置。

## 统一热键事务

所有五项热键进入 `RunMxNMViewerHotkey`，共享一个事务占用标记。每次调用最多派发一次，不补发 F12、不重复点击。

1. 记录动作与前台 HWND；检查当前作用域。
2. 等待主键及配置中声明的修饰键物理释放，最多 3000 ms。等待过程中前台变化立即取消；异常键名/读取错误进入失败诊断，不解释成“已释放”。
3. 在派发前复核前台；调用对应原生命令、F12 或清除链。
4. 在 finally 释放占用标记，并完成操作诊断。超时不派发，松键后可再次触发。

保留松键语义的原因：2026-07 现场曾确认 SUV 命令在 modifier 仍按下时会进入临时状态，并随 modifier 松开取消。本次不改变键盘 hook 安装策略，不把物理状态和逻辑状态视为同一件事；诊断同时记录两者的 modifier mask。

## 原生按钮定位

`MxNMViewerToolCommandProvider.ResolvePlan` 每次从运行中的 Viewer 获取进程路径，并从固定的三项命令定义建立原生计划。工具路径不读 vendor INI、不需要 frame size、面板位置或图像布局文件，不使用持久化路径缓存，也不启动后台 warmup。

运行时枚举同进程原生 `Button`，按直接父窗口分组，要求三个目标 ID 在同一面板内各唯一出现一次，控件可见且矩形位于父面板内。只接受唯一完整组；两组完整可见按钮、跨进程或身份歧义继续拒绝。

完整组签名用于区分工具面板；其他按钮的 enabled 状态不再否决当前工具。选中目标本身必须 enabled，否则返回 `BUTTON_DISABLED`。原生计划不以 vendor 行列顺序或第一列作为限制，按钮位置来自 live HWND。

向选中按钮的直接父窗口同步发送 `WM_COMMAND / BN_CLICKED`，超时上限为 250 ms。工具操作不移动鼠标，不激活 Viewer，也不自动重试。成功仅表示消息派发完成，不证明 Viewer 已进入测量模式。

旧 `BuildMxNMViewerToolCommandPlan`、配置解析和坐标映射 helper 暂留供历史 checkpoint/审计工具引用，不在生产 `ResolvePlan/Invoke` 路径；搬迁时需同步脚本提取边界。不要把历史 helper 的约束重新接回生产入口。

## F12 与白闪

松键后先解析白闪覆盖窗口，再在实际 Send 前复核原前台 HWND。只发送一次 F12。随后以 NoActivate、鼠标穿透的白色 overlay 闪烁约 90 ms，并 best-effort 排除 overlay 被截图。

白闪表示发送执行到了派发之后。当前没有可验证的截图产物接口，诊断明确写 `viewer.effectState=UNOBSERVABLE`；不得据白闪宣称截图成功。首次截图失败尚需比较物理 F12 与配置热键，以及图像焦点/窗口状态。

## 清除

清除复用 `MxNMAnnotationCleaner.DeleteAll` 和 context-session 图像目标，按精确菜单文字识别 `删除全部标注`，保持窗口身份与 confirmation 检测。独立快捷键使用 `COMMAND_ONLY`，不额外打开菜单复读；报告写入后的清除仍保留既有测量后置验证。

## 诊断与验收

F12、工具、清除分别以 `ViewerCapture`、`ViewerTool`、`ViewerClear` 写入现有 `automation-events.log`。每次完成一条精简摘要，失败/取消及临时详细模式保留阶段。字段限于固定动作、阶段、耗时、modifier mask、HWND、Control ID、候选数和派发状态；无患者信息、标题、图像或剪贴板内容。

关键结果：`KEY_RELEASE_TIMEOUT`、`FOREGROUND_CHANGED`、`WRONG_FOREGROUND`、`BUSY`、`BUTTON_DISABLED`、`DISPATCH_FAILED`、`DISPATCHED`。没有进入 AHK handler 的按键不可能由该日志记录，需现场核对实际键位和热键注册。

- `tests/windows/generated/viewer_state_regression_standalone.ahk`：从实际生产定义提取的状态与合成原生面板测试，不操作 MedEx。
- `tests/windows/mxnm_viewer_tool_command_field.ahk`：Ctrl+Alt+F9/F10/F11 provider 测试，等待松键，不替代生产入口验收。
- 当前正式入口：测试首次/连续调用、持键超过 3 秒、等待中切走前台、禁用其他工具、Viewer 重启及麦旋风重载。

Python 测试和生成一致性检查不能替代 Windows AHK 解析、EXE 编译和真实 Viewer 行为验收。
