# MxNM Viewer 工具快捷键

本文档固化 v0.6.1 的箭头、长度测量和 3D SUV 测量快捷键实现，以及 2026-07-26 Windows 现场验证中得到的结论。

## 已验证范围

当前工作站已验证三个命令：

| 功能 | Vendor command ID | Vendor 配置位置 | 现场按钮位置 |
| --- | ---: | --- | --- |
| 箭头 | `21043` | `Row1` | 第 4 个 |
| 长度测量 | `21048` | `Row3` | 第 6 个 |
| 3D SUV 测量 | `21193` | `Row6` | 第 9 个 |

默认快捷键为 `Ctrl+Alt+1/2/3`，三项首次升级均保持关闭。快捷键只在配置的 MedEx 报告程序或 Viewer 位于前台时注册为有效动作；其他程序中的相同按键继续交给原程序。

## 配置与运行时模型

`MxNMViewerToolCommandProvider` 在应用启动时尽量复用已经验证的 Viewer process path cache，并从固定相对路径读取 Vendor 配置。静态 plan 缓存：

- Viewer process path；
- `FrameWidth` / `FrameHeight`；
- `SCBtnPadPosX` / `SCBtnPadPosY`；
- `[SCBtnPadSetting]` 中三个 command ID 的行列；
- 主配置 hash。

这一路径不使用 UIA，不注册 shell hook，不运行后台 timer，也没有周期轮询。Viewer 尚未运行且没有可用 path cache 时，首次调用按既有 config discovery 流程建立 plan；成功后在本进程内复用。

每次按键只做以下工作：

1. 找到唯一的 runtime Viewer frame，并读取当前 window rect。
2. 将配置中的按钮面板原点按 logical frame → runtime frame 比例映射。
3. 加上固定按钮内部偏移，得到目标按钮中心。
4. 使用 `WindowFromPoint` 获取该点的 native HWND。
5. 校验目标 root/client rect、Viewer PID、直接父窗口 PID 和 `GetDlgCtrlID`。
6. 向按钮的直接父窗口发送带 250 ms 上限的同步 `WM_COMMAND / BN_CLICKED`。

正常路径不移动鼠标、不切换前台窗口，也不需要 hover。250 ms 是窗口失去响应时的等待上限，不是固定延迟；正常投递会立即返回。

## 坐标换算

当前 Vendor 按钮为固定 34 px 控件，中心偏移为 `(17,17)`，垂直 pitch 为 38 px。配置面板之前还有 3 个内置按钮，因此配置第 `row` 行的中心偏移为：

```text
x = 17
y = (3 + row - 1) * 38 + 17
```

只缩放 `SCBtnPadPosX/Y` 定义的面板原点；按钮尺寸和按钮间距保持 runtime 像素，不随整个 frame 比例再次缩放：

```text
padScreenX = windowX + round(SCBtnPadPosX * windowWidth / FrameWidth)
padScreenY = windowY + round(SCBtnPadPosY * windowHeight / FrameHeight)
buttonPoint = padScreenPoint + fixedButtonOffset
```

现场 frame 下三个中心约为：

- 箭头：`(2468,649)`；
- 长度测量：`(2468,725)`；
- 3D SUV 测量：`(2468,839)`。

## 本轮发现

### UIA 名称不能作为按钮身份

按钮默认不稳定暴露 UIA，hover 后出现的名称也可能描述当前作用而不是 Vendor 命令。父 Pane 可以被观察到，但不能可靠解决三个按钮的身份与点击问题。因此 production 路径完全移除 UIA，按钮身份以 Vendor command ID 和 native control ID 为准。

### `WM_COMMAND` 必须发给按钮的直接父窗口

最初将 command ID 发给 Viewer main frame 没有效果。native button 的 `BN_CLICKED` 接收者是直接父窗口；现场确认按钮父窗口可能同时也是独立 root，不应假设它等于 runtime main frame。

### 根 HWND 不相等不代表目标错误

MxNM Viewer 使用同一进程中的多个顶层或浮动窗口。要求 `button root == runtime frame HWND` 会误拒绝正确按钮。最终边界改为同一 PID、点位属于目标 root client rect，并继续核对 native control ID。

### 面板原点与按钮偏移不能采用同一种缩放

缩放整个 logical point 会把箭头算到 `(2483,707)`；完全不缩放会算到 `(2216,490)`。现场证明正确模型是缩放配置面板原点，再加固定像素按钮偏移。

### 非活动父窗口上的 `BM_CLICK` 不可靠

异步 `BM_CLICK` 在从报告窗口切换焦点后会出现第一次无效、第二次成功。最终改为向已经验证的直接父窗口同步发送 `WM_COMMAND / BN_CLICKED`，既避免激活 Viewer，也消除首次点击失效。

### 嵌套循环不能直接复用 `A_Index`

初版解析 `[SCBtnPadSetting]` 时，在外层 `loop` 内又进入 `for`，对象创建时读取的 `A_Index` 已被内层枚举覆盖。由于当前配置每行只有一个 command，三个命令全部被错误保存为 `row=1`，Length 和 SUV 因而都映射到箭头。解析器现在进入内层循环前保存显式 `rowIndex`，Windows 现场确认 Length 为 `row=3`、SUV 为 `row=6`。

## Fail-closed 边界

以下任一情况都拒绝投递：

- Vendor 配置或 frame geometry 不可用；
- 三个 command ID 不唯一、行列格式异常或不在第一列；
- Viewer frame 缺失或不唯一；
- `WindowFromPoint` 目标不存在；
- root/parent 与 Viewer PID 不一致；
- 目标点不在 root client rect；
- runtime control ID 与 Vendor command ID 不一致；
- 父窗口消息超时或发送失败。

配置变化不会通过猜测、UIA Name 或重复点击自动绕过。其他工作站、分辨率、缩放和 Vendor 版本仍须逐机验证后再启用。

## 验证入口

- 纯配置/映射回归：`tests/windows/mxnm_viewer_tool_command_regression.ahk`
- 现场单按钮测试：`tests/windows/mxnm_viewer_tool_command_field.ahk`
  - `Ctrl+Alt+F9`：箭头
  - `Ctrl+Alt+F10`：长度测量
  - `Ctrl+Alt+F11`：3D SUV 测量
- Python structural coverage：`tests/test_viewer_tool_hotkeys.py`

现场已确认三个按钮均可从 Viewer 或报告窗口前台一次触发成功，且 `ForegroundUnchanged=true`、`MouseUnchanged=true`。
