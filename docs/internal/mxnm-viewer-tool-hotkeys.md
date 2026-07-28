# MxNM Viewer 工具快捷键

本文档固化 v0.6.1–v0.6.2 的箭头、长度测量、3D SUV、截图和清除全部标注快捷键实现，以及 2026-07-26 至 2026-07-27 Windows 多机验证中得到的结论。

## 已验证范围

当前工作站已验证三个命令：

| 功能 | Vendor command ID | Vendor 配置位置 | 现场按钮位置 |
| --- | ---: | --- | --- |
| 箭头 | `21043` | `Row1` | 第 4 个 |
| 长度测量 | `21048` | `Row3` | 第 6 个 |
| 3D SUV 测量 | `21193` | `Row6` | 第 9 个 |

默认快捷键为 `Ctrl+Alt+1/2/3`，三项首次升级均保持关闭。快捷键只在配置的 MedEx 报告程序或 Viewer 位于前台时注册为有效动作；其他程序中的相同按键继续交给原程序。

## Win 修饰键

AHK 动态 `Hotkey()` 原生支持 `#` 表示 Win，但 Windows common-control `Hotkey` 输入框没有 Win modifier flag，只能采集 Ctrl、Alt 和 Shift。设置页因此在每一行提供独立的 Win checkbox：加载时从 canonical chord 拆出 `#`，保存时再与 native Hotkey 值合并。

Ctrl、Alt、Shift、Win 中任意一个修饰键即可与主键组成快捷键。无修饰时只接受单个字母或数字，并自动缩窄为仅在 Viewer 前台注册；报告编辑器和其他程序不会拦截该单键。箭头和长度也在完整松键后单次执行，避免无修饰单键长按产生键盘重复。归一化继续使用统一顺序 `^!+#`，并与 emergency/reserved 及其他已启用快捷键做不区分大小写的冲突检查。

## F12 截图映射

第四项默认快捷键为 `Ctrl+Alt+4`，保存键位后只在 `MedExNMFusion.exe` Viewer 位于前台时注册。handler 保存 foreground HWND，等待主键及全部声明 modifier 物理释放，再复核仍是同一个 Viewer 后发送纯 F12，避免 MedEx 收到 Ctrl/Alt/Win+F12；报告窗口或其他程序前台时既不触发，也不吞掉相同按键。

F12 派发成功后，以约 23% opacity 的白色 overlay 覆盖 Viewer outer rect 约 90 ms。pulse 使用 `NoActivate`、click-through tool window，不包含文字，不改变焦点；显示前 best-effort 设置 `WDA_EXCLUDEFROMCAPTURE`，降低 overlay 进入截图的风险。它只表示麦旋风在正确 Viewer context 中接受快捷键并执行 F12 send，不验证 MedEx 的截图文件、剪贴板或保存结果。

## 3D SUV release-then-dispatch semantics

现场确认 `21193` 在快捷键 modifier 仍物理按下时投递，会进入由 modifier 维持的临时状态：抬起主键后仍可测量，但释放 modifier 就会自动取消。这不是期望的产品交互，也不表示 Vendor command 必须持续重复。

production 因此在 hotkey key-down 后等待主键及所有声明 modifier 完全物理释放，再复核 foreground HWND 未变化，最后只执行一次完整 config、geometry、HWND、PID、control-ID 校验和 command 投递。静态 `active` guard 屏蔽等待期间的操作系统重复 hotkey thread。这样 Vendor 收到 `21193` 时不再带着 Ctrl、Alt、Shift 或 Win 的物理按下状态，目标交互与箭头、长度一致：按下并松开一次完成选择，选择后无需继续按住快捷键。

## 清除全部标注

第五项默认快捷键为 `Ctrl+Alt+5`，默认关闭，作用域与三个工具选择快捷键相同。handler 等待完整 chord 物理释放并复核 foreground HWND 未变化后，调用既有 `MxNMAnnotationCleaner.DeleteAll()`；它不使用标注工具面板上的 `21081`，也不增加任何工具面板坐标。

清除继续复用 production context-menu transport：从 config-only measurement target 取得当前图像点，向 Viewer 投递右键消息，按精确可见文字找到 `删除全部标注`，核验 popup PID 和运行时 control ID，异步执行命令并检测意外 confirmation。独立清除快捷键使用 `COMMAND_ONLY` mode，命令成功投递后不再通过 SUVMax 和直线测量菜单复读结果，因此整个动作只创建一次右键菜单。报告写入后的既有清除仍复核本次使用的 measurement type。失败时只显示短暂视觉提示；不移动鼠标、不切换前台窗口，也不因清除失败改变报告内容。

清除同样等待主键及所有声明 modifier 完全物理释放，并在 foreground HWND 未变化时只执行一次。等待期间保持 `active` guard，避免长按触发键盘重复而多次发送清除命令；释放后再运行 context-menu transport，也避免把 Ctrl、Alt、Shift 或 Win 的物理按下状态带入 Vendor 菜单处理。

## 配置与运行时模型

`MxNMViewerToolCommandProvider` 在应用启动时尽量复用已经验证的 Viewer process path cache，并从固定相对路径读取 Vendor 配置。静态 plan 缓存：

- Viewer process path；
- `FrameWidth` / `FrameHeight`；
- `SCBtnPadPosX` / `SCBtnPadPosY`；
- `[SCBtnPadSetting]` 中三个 command ID 的行列；
- 主配置 hash。

这一路径不使用 UIA，不注册 shell hook，不运行后台 timer，也没有周期轮询。Viewer 尚未运行且没有可用 path cache 时，首次调用按既有 config discovery 流程建立 plan；成功后在本进程内复用。

每次按键只做以下工作：

1. 枚举 Viewer 同进程中的 native child controls，只保留目标 command ID、
   visible/enabled 且 class 为 `Button` 的候选。
2. 按直接父窗口分组，要求三个目标 ID 在同一面板内各唯一出现一次，实际
   控件顺序与 Vendor row/column 顺序一致。
3. 从候选父面板沿 `GA_ROOTOWNER` 取得 outer Viewer。优先复用已验证进程
   窗口集合中的 rect；若 owner 不在可见窗口 snapshot 中，则要求它仍是
   同一已验证 Viewer PID 的真正 root owner，并经同 PID 可见窗口再次核对
   进程名和完整路径后，直接读取该 owner 的 window/client rect。
4. 将 Vendor 按钮面板原点按 logical frame → outer Viewer 比例映射，校验
   父面板实际左上角与 `SCBtnPadPos` 映射
   一致。
5. 向按钮的直接父窗口发送带 250 ms 上限的同步 `WM_COMMAND / BN_CLICKED`。

正常路径不移动鼠标、不切换前台窗口，也不需要 hover。250 ms 是窗口失去响应时的等待上限，不是固定延迟；正常投递会立即返回。

2026-07-28 当前工作站回归发现，三个目标按钮组成的主面板可以同时满足唯一
ID、可见/启用、顺序和面板原点校验，但其 `GA_ROOTOWNER` 不出现在
`WinGetList` 的可见 Viewer snapshot 中。旧 resolver 因
`frameFound=false` 错误淘汰该合法组。当前实现不再把 snapshot membership
当作 owner 身份本身；direct fallback 仍要求 HWND 有效、owner PID 与已验证
Viewer PID 相同、该 HWND 自身确为 root owner、进程名和完整路径匹配，并且
window/client rect 均有效。跨进程 owner、错误路径和无有效几何继续 fail
closed。

## 面板映射与实际控件

只缩放 `SCBtnPadPosX/Y` 定义的面板原点：

```text
padScreenX = windowX + round(SCBtnPadPosX * windowWidth / FrameWidth)
padScreenY = windowY + round(SCBtnPadPosY * windowHeight / FrameHeight)
```

该点只用于识别工具面板，不再生成按钮点击坐标。按钮中心来自运行时
`GetWindowRect`，用于诊断；命令直接投递给实际 HWND，不移动或点击鼠标。

2026-07-27 的第二台机器表明：相同 Viewer frame、相同面板原点下，箭头和
长度按钮分别从首台机器的 `y=632..666`、`708..742` 变为
`y=600..637`、`682..719`。旧固定 pitch 算法分别误中 `21044` 和
`21078`，因此固定首行、尺寸、中心和 `38 px` pitch 均只保留在
Checkpoint 1 审计回归中，不属于 production resolver。

同一机器还证明，主图区激活会新增一个同进程顶层图像窗口，使“outer frame
必须包含全部 Viewer 顶层窗口”的通用规则得到零个候选。工具 resolver
因此不再使用该包含关系，而由已验证工具父面板的 `GA_ROOTOWNER` 唯一反查
outer Viewer。额外图像层不会参与按钮身份判断。

## 本轮发现

### UIA 名称不能作为按钮身份

按钮默认不稳定暴露 UIA，hover 后出现的名称也可能描述当前作用而不是 Vendor 命令。父 Pane 可以被观察到，但不能可靠解决三个按钮的身份与点击问题。因此 production 路径完全移除 UIA，按钮身份以 Vendor command ID 和 native control ID 为准。

### `WM_COMMAND` 必须发给按钮的直接父窗口

最初将 command ID 发给 Viewer main frame 没有效果。native button 的 `BN_CLICKED` 接收者是直接父窗口；现场确认按钮父窗口可能同时也是独立 root，不应假设它等于 runtime main frame。

### 根 HWND 不相等不代表目标错误

MxNM Viewer 使用同一进程中的多个顶层或浮动窗口。要求
`button root == runtime frame HWND` 会误拒绝正确按钮。最终边界改为同一
PID、同一直接父面板、父面板匹配 Vendor 原点，并继续核对 native control
ID、可见性、启用状态和几何顺序。

### 面板原点可以缩放，按钮位置必须实测

缩放整个 logical point 或完全不缩放都会得到错误目标。多机证据进一步证明
即使正确映射面板原点，固定像素按钮偏移仍不可迁移。production 只映射
Vendor 面板原点，按钮位置完全由 native HWND 实际矩形决定。

### 非活动父窗口上的 `BM_CLICK` 不可靠

异步 `BM_CLICK` 在从报告窗口切换焦点后会出现第一次无效、第二次成功。最终改为向已经验证的直接父窗口同步发送 `WM_COMMAND / BN_CLICKED`，既避免激活 Viewer，也消除首次点击失效。

### 嵌套循环不能直接复用 `A_Index`

初版解析 `[SCBtnPadSetting]` 时，在外层 `loop` 内又进入 `for`，对象创建时读取的 `A_Index` 已被内层枚举覆盖。由于当前配置每行只有一个 command，三个命令全部被错误保存为 `row=1`，Length 和 SUV 因而都映射到箭头。解析器现在进入内层循环前保存显式 `rowIndex`，Windows 现场确认 Length 为 `row=3`、SUV 为 `row=6`。

## Fail-closed 边界

以下任一情况都拒绝投递：

- Vendor 配置或 frame geometry 不可用；
- 三个 command ID 不唯一、行列格式异常或不在第一列；
- Viewer frame 缺失或不唯一；
- 同 PID 的可见、启用 native `Button` 候选缺失；
- 候选不在同一直接父面板，或面板原点与 Vendor 映射不一致；
- 任一目标 ID 在候选面板中不唯一；
- runtime control ID 或实际几何顺序与 Vendor command schema 不一致；
- 父窗口消息超时或发送失败。

配置变化不会通过猜测、UIA Name 或重复点击自动绕过。其他工作站、分辨率、缩放和 Vendor 版本仍须逐机验证后再启用。

## 验证入口

- 纯配置/映射回归：`tests/windows/mxnm_viewer_tool_command_regression.ahk`
- 现场单按钮测试：`tests/windows/mxnm_viewer_tool_command_field.ahk`
  - `Ctrl+Alt+F9`：箭头
  - `Ctrl+Alt+F10`：长度测量
  - `Ctrl+Alt+F11`：3D SUV 测量
- Python structural coverage：`tests/test_viewer_tool_hotkeys.py`

旧固定偏移路径仅在首台机器确认成功；第二台机器已证明其不可迁移。新的
native control-set resolver 仍需按 Checkpoint 2 在至少三台机器完成 EXE
现场验证后，才能标记跨机器通过。
