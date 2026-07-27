# MxNM Viewer HWND 层级兼容性调查

日期：2026-07-27
状态：诊断已收敛，production 修改暂缓；等待可分发诊断版本后的 Windows A/B

## 目的与边界

本文记录第二台 Windows 测试机上出现的 Viewer 自动化兼容性问题，并为后续实现与异步验收定义安全边界。

本轮只固化调查结论和下一步方案：

- 不修改 production 源码；
- 不修改 Vendor 配置；
- 不生成或发布新的 EXE；
- 不把测试机专用绝对坐标写入 production；
- 不以一次调用中逐层发送消息的方式猜测正确 HWND；
- 不降低现有 PID、进程路径、control ID、foreground、mouse、clipboard 和 popup 校验。

测试截图只用于瞬时几何比对，其中包含临床内容，因此不纳入仓库，也不记录其中的文字或图像内容。

## 测试环境

### 已确认环境

- Viewer：`MedExNMFusion.exe`
- Viewer file version：`1.0.0.4`
- Viewer product version：`1.0.0.4`
- Viewer 固定全屏运行于副屏，位置由 Vendor 配置决定，不能作为普通窗口移动
- 副屏分辨率：`1600×1200`
- 主屏与副屏 display scaling：均为 `100%`
- 多显示器环境
- 报告程序进程：`medexworkstations.exe`

### Vendor 配置

```ini
FramePosX=1000
FramePosY=0
FrameWidth=1000
FrameHeight=1000
ShowImagePosX=195
ShowImagePosY=56
ShowImageWidth=750
ShowImageHeight=938
SCBtnPadPosX=155
SCBtnPadPosY=360
```

配置中的 frame、image rectangle 和 tool pad 均通过现有 schema 校验。

## 已确认现象

### 权限层

- 普通权限启动麦旋风时，所有报告 hotstring 均无效。
- 以管理员权限启动麦旋风后，所有报告 hotstring 恢复正常。
- 这是 Windows integrity level 不一致导致的独立问题，不是 Viewer geometry 问题。

### Viewer 入口层

- Viewer 前台时，截图快捷键能够成功发送 F12，且 Viewer 完成实际截图动作。
- 这证明以下链路在管理员权限下正常：
  - Viewer 进程名识别；
  - Viewer foreground guard；
  - 快捷键注册与接收；
  - modifier release 后的按键发送。

### Viewer 工具按钮

- Arrow、Length 和 3D SUV 等需要 Vendor command/control 校验的工具快捷键均失败。
- 可见提示为：

```text
Viewer 工具按钮布局校验失败，未执行点击
```

- 该提示对应 `BUTTON_TARGET_INVALID` 或 `BUTTON_ID_MISMATCH`，当前 production UI 无法区分两者。
- 失败发生在消息派发前，未执行盲点点击。

### SUVMax 自动读取

- `;fzg` 已进入 hotstring handler。
- 自动读取阶段等待约 1–2 秒后返回获取失败。
- 触发期间 Viewer 完全没有出现右键菜单。
- 人工在图像区右键时，菜单中存在精确文字：

```text
复制SUVMax值
```

- 因此菜单文字没有变化；失败发生在菜单创建之前，而不是命令文字匹配或剪贴板解析阶段。

## 几何证据

测试截图以 `1200×900` 保存，是 `1600×1200` Viewer 的 `0.75` 比例图。

按当前 production 公式、以全屏 `1600×1200` runtime frame 计算：

```text
Mapped image rect:
  x = 195 × 1.6 = 312
  y = 56 × 1.2 ≈ 67
  right = (195 + 750) × 1.6 = 1512
  bottom = (56 + 938) × 1.2 ≈ 1193

Tool pad origin:
  x = 155 × 1.6 = 248
  y = 360 × 1.2 = 432
```

投影到 `1200×900` 截图后：

```text
Mapped image rect ≈ [234,50,1134,895]
Tool button column center ≈ 199
Arrow / Length / 3D SUV center Y ≈ 422 / 479 / 565
```

截图中的主图像边界和工具按钮列与这些预测值吻合。允许截图缩放、outer rect 边框和 JPEG 产生数像素误差，但不存在足以解释整体失败的区域偏移。

因此本轮结论修正为：

- `1600×1200`、4:3、副屏原点和独立 X/Y scaling 不是当前主要故障；
- Vendor 配置仍是有效的逻辑布局来源；
- production 计算点已落入视觉上正确的图像区和按钮区；
- 不应以改分辨率、移动 Viewer、写死新坐标或增加比例补偿作为修复。

## 当前实现中的兼容性假设

### Measurement context menu

现有链路为：

```text
config-derived screen point
-> WindowFromPoint
-> GetAncestor(pointHwnd, GA_ROOT)
-> return root HWND as action/viewer HWND
-> screen point to root client point
-> PostMessage(WM_RBUTTONDOWN/WM_RBUTTONUP) to root HWND
-> wait for a new #32768 popup
```

该实现隐含假设：图像点所属的 root HWND 能够直接处理图像区右键消息。

测试机上的证据更符合以下解释：

```text
正确图像点
-> WindowFromPoint 找到图像 child/descendant HWND
-> GA_ROOT 上升到 Viewer shell/root HWND
-> PostMessage 对有效 root HWND 返回成功
-> root 不处理该图像区右键
-> 没有 popup
-> 等待超时
```

这是实现推断，不应在没有 HWND chain 证据时直接升级为 production 事实。

### Viewer tool buttons

现有链路在计算按钮中心后：

```text
WindowFromPoint
-> root/parent PID validation
-> root client-rect containment
-> GetDlgCtrlID(pointHwnd) == expected Vendor command ID
-> SendMessageTimeout(WM_COMMAND/BN_CLICKED) to direct parent
```

测试机上的正确视觉点仍可能出现：

- `WindowFromPoint` 返回按钮内部 child，而 command ID 位于某一级 ancestor；
- `WindowFromPoint` 返回装饰、图标或 overlay HWND；
- point HWND 的 parent/root 层级与原工作站不同；
- expected control ID 存在于同点 ancestor chain，但不在 deepest HWND；
- root/client containment 或 parent PID 判据在新的合法层级上返回 false。

当前统一错误提示不足以区分以上分支。

## 为什么暂不直接修改 production

将 measurement 目标从 root HWND 直接改为 deepest point HWND 仍有风险：

- deepest child 不一定处理右键；
- 正确 receiver 可能是 point HWND 的某一级 ancestor；
- 不同布局可能在同一 Viewer 版本中产生不同层级；
- 如果一次调用逐级尝试，会创建多个菜单或重复执行命令；
- popup 出现后继续 fallback 可能把第二条消息投给错误窗口；
- 原工作站已经验证的 root-based 行为可能回归。

将工具按钮校验改为忽略 control ID 或直接向配置 command ID 发送 `WM_COMMAND` 同样不可接受：

- 会失去按钮身份的 runtime 证据；
- 配置与实际控件不一致时可能触发错误命令；
- 不能证明消息接收者是正确的直接父窗口。

因此下一步必须先收集有界、无患者内容的 HWND hierarchy 证据。

## 下一步：诊断版本

### Step A：只读 HWND chain probe

新增独立 field harness，不接入 production hotstring 或快捷键。对以下计算点分别采集：

- config-derived image point；
- Arrow center；
- Length center；
- 3D SUV center。

从 `WindowFromPoint` 返回的 HWND 开始，沿 `GetParent` 和 `GetAncestor(GA_ROOT)` 记录有界 chain。每一级只记录：

- chain index；
- HWND 的临时十六进制值；
- window class；
- `GetDlgCtrlID`；
- PID；
- 是否与 Viewer PID 一致；
- window rect 与 client rect；
- point 是否位于该级 client rect；
- visible/enabled 状态；
- parent HWND 和 root HWND。

禁止记录：

- window text、UIA Name/Text/Value；
- patient/study/report 内容；
- Vendor 配置原文；
- clipboard 内容；
- 绝对安装路径；
- 屏幕截图。

输出写入：

```text
%TEMP%\MedExAHK\mxnm_hwnd_hierarchy_probe.txt
```

Step A 不发送鼠标、键盘、`WM_COMMAND` 或右键消息，不改变 foreground、mouse 或 clipboard。

### Step B：单候选右键 A/B

只有 Step A 确认有多个同 PID、包含目标点的合法候选 HWND 后，才创建 field-only A/B。

每个 hotkey 必须：

1. 明确绑定一个 chain index/selection policy；
2. 一次只向一个候选 HWND 发送一组 right-down/right-up；
3. 使用相对于该候选 HWND 重新计算的 client point；
4. 只等待一次 popup；
5. popup 出现或超时后立即结束；
6. 不在同一次调用中 fallback 到下一 candidate；
7. 不自动执行菜单命令。

每个候选由操作者单独触发并报告：

- `MessageDispatchSucceeded`
- `PopupCreated`
- `PopupPidMatches`
- `ForegroundUnchanged`
- `MouseUnchanged`
- `ClipboardUnchanged`

只有唯一 candidate 在重复测试中稳定创建正确菜单，才能成为 production receiver policy。

### Step C：工具按钮只读身份解析

先在 point HWND 的有界 ancestor chain 中寻找 expected control ID：

- expected ID 必须恰好出现一次；
- candidate、direct parent 与 root 必须属于 Viewer PID；
- point 必须位于 candidate 或其已验证 client/root boundary；
- 不得通过 UIA Name、hover text 或位置序号替代 control ID；
- Step C 只解析并输出 candidate，不发送 `WM_COMMAND`。

如果 expected ID 不在 ancestor chain，停止并重新调查；不得扩大为全 Viewer 无界枚举后猜测最近控件。

### Step D：单命令 dispatch A/B

在 Step C 得到唯一 candidate 后，field harness 才允许：

- 等待全部 hotkey modifiers 释放；
- 复核 foreground HWND 未变化；
- 向 candidate 的已验证直接父窗口发送一次 `WM_COMMAND/BN_CLICKED`；
- 记录 command ID、receiver relation、返回状态；
- 人工确认只进入预期工具且无需重复触发。

Arrow、Length 和 3D SUV 分开验收，不因一个 command 通过而推断其他 command 通过。

## 候选 production 修复

以下设计仅在 Step A–D 产生证据后实施。

### Measurement receiver resolver

新增一个明确的 receiver resolution result，至少包含：

```text
ok
code
pointHwnd
receiverHwnd
rootHwnd
pid
screenPoint
receiverClientPoint
selectionPolicy
```

安全条件：

- receiver 必须来自 `WindowFromPoint` 的有界 parent chain；
- receiver、root 和 runtime frame 必须属于同一 Viewer PID 与已验证 process path；
- screen point 必须位于 receiver client rect；
- candidate 必须唯一；
- production 一次只向 resolved receiver 发送一组右键消息；
- popup 缺失时直接 fail closed，不尝试第二 receiver；
- foreground、mouse 和 clipboard invariants 保持不变。

原工作站若继续要求 root receiver，应由相同 resolver 根据其 hierarchy 证据选择 root，而不是删除旧路径。

### Tool control resolver

新增 point-chain control resolver：

```text
screen point
-> bounded WindowFromPoint parent chain
-> unique same-PID HWND with expected control ID
-> validate direct parent PID and candidate/root client bounds
-> dispatch once to validated direct parent
```

保留：

- Vendor config 中 command ID 的唯一性和行列校验；
- config-derived point；
- expected runtime control ID；
- direct-parent `WM_COMMAND/BN_CLICKED`；
- 250 ms bounded timeout；
- foreground/release semantics；
- 无 mouse move、无 focus activation、无 hover 依赖。

不得加入：

- 忽略 control ID 的 direct command；
- root HWND 广播；
- 多 ancestor 连续发送；
- BM_CLICK fallback；
- UIA Name fallback；
- 固定屏幕坐标 fallback。

## 回归与异步验收矩阵

### 静态与纯逻辑

- parent chain 有界且可终止；
- cycle/duplicate HWND 被拒绝；
- zero/invalid HWND 被拒绝；
- PID/path 不一致被拒绝；
- expected control ID 缺失或重复被拒绝；
- screen-to-client 使用最终 receiver HWND；
- popup failure 不触发第二次 right-click；
- tool dispatch failure 不触发第二次 command；
- 现有 config/schema/parser tests 保持通过；
- generated release 与 source include 顺序正确。

### 原工作站

- F12 screenshot 保持正常；
- Arrow、Length、3D SUV 各连续通过；
- positive SUVMax、zero/not-annotated、line axes 各通过；
- annotation cleanup 只创建一次菜单；
- foreground、mouse、clipboard 均保持；
- 原有 tool/control ID 和 root/parent 关系仍被接受；
- 不出现额外菜单闪烁或重复命令。

### 1600×1200 测试机

- 普通 hotstring 在管理员权限下保持正常；
- F12 保持正常；
- Step A 输出能够解释旧 production 的具体失败 code；
- image receiver A/B 仅有一个 candidate 稳定创建菜单；
- production candidate 的 `;fzg` 能创建一次菜单并读取当前值；
- Arrow、Length、3D SUV 各自命中唯一 expected control ID；
- 不修改 Vendor 配置、不移动 Viewer、不改变分辨率；
- 无 blind click、无 mouse move、无 focus activation；
- 错误环境继续 fail closed。

## 实施停止点

返回工作机后，先实现并审查 Step A 的诊断 harness。没有 Step A 的 Windows hierarchy 输出，不进入 production resolver 修改。

Step A 输出明确后，再单独决定是否进入 Step B/C；measurement receiver 与 tool control resolver 应分开提交和验收，不能在同一未经验证的改动中同时推广。
