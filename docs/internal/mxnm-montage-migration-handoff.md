# MxNM montage 迁移交接

更新时间：2026-08-03

本文用于从已验证的 Lung 字段测试继续开发正式的 Body、Head、Lung montage
功能。运行时契约探测、Lung 单机字段验证和 production 的初版接入均已完成；
`Shift+Alt+B/H/L` 默认不注册，避免在仍启用 legacy compatibility 时发生快捷键抢占。

## 当前结论

`MxNMMontageLungFieldTest 0.7` 已在当前工作站完整执行 12/12 步，并由操作者确认
Viewer 最终表现正确。验证环境为：

- process：`MedExNMFusion.exe`；
- Viewer rect：`1920,0,4481,1440`；
- DPI：96；
- layout：5 行 × 4 列，执行目标为第 4 行第 4 列；
- Lung profile：层厚 `7.5`、当前层 `23`、放大倍数 `0.9`、窗宽 `lung`。

这是一台工作站、一个 Viewer 布局上的现场证据。它足以开始正式实现，但不代表
其他分辨率、DPI、显示器排列、MedEx 版本或工作站 profile 已经通过。

对应证据与工具：

- [控件探测](mxnm-montage-control-diagnostic.md)；
- [Lung 受控执行](mxnm-montage-lung-field-test.md)；
- 当前字段测试基线：commit `3cd41ad`，`FieldTestVersion=0.7`。

## 目前 production 接入

`src/mxnm_montage.ahk` 已复用字段测试 0.7 的 resolver 与 transport，并以一键方式
注册以下 profile：Body `Shift+Alt+B`、Head `Shift+Alt+H`、Lung `Shift+Alt+L`。三者
共用同一执行链；默认窗宽为 `default`，Lung 为 `lung`。

首次运行会在 `%LOCALAPPDATA%\MedExReportAssistant\config.ini` 补入：

```ini
[MontageHotkeys]
Enabled=false
LayoutRow=4
LayoutColumn=4
BodyThickness=8.5
BodySlice=8
BodyZoom=0.7
HeadThickness=4
HeadSlice=11
HeadZoom=1.2
LungThickness=8
LungSlice=23
LungZoom=0.85
```

明天 Windows 现场测试前，将 `Enabled=true`，重新加载脚本，然后在无患者隐私的
Viewer 检查中分别验证三个快捷键。数值可在这一段微调。配置的其他 layout 值会被
读取和校验，但 production 暂时只允许已验证的 `LayoutRow=4`、`LayoutColumn=4`
实际执行；其他值会提示并停止，不会发送半条点击链。

## 业务顺序

三种 profile 复用同一条执行链：

```text
选择布局行列
→ Tab 3
→ 四角图注选择 null
→ Tab 5
→ 选择窗宽 preset
→ 写入层厚
→ 调用层厚更改按钮
→ 写入当前层
→ 调用跳转按钮
→ Tab 4
→ 写入放大倍数
→ 聚焦放大倍数输入框并发送 Enter
```

Body、Head 也应显式选择 `default`，不能依赖 Viewer 启动时或上一次操作遗留的
窗宽状态。Lung 显式选择 `lung`。

## 参数边界

下表是正式开发的初始值，不应散落在执行器函数体中。用户计划在正式开发前后
微调数值，因此 profile 数据与执行逻辑必须分离。

| Profile | Hotkey | Window preset | Thickness | Current slice | Zoom | 状态 |
| --- | --- | --- | ---: | ---: | ---: | --- |
| Body | `Shift+Alt+B` | `default` | 8.5 | 8 | 0.7 | production 成品测试后微调值，待复验 |
| Head | `Shift+Alt+H` | `default` | 4 | 11 | 1.2 | legacy 初始值，待现场复验/微调 |
| Lung | `Shift+Alt+L` | `lung` | 8 | 23 | 0.85 | production 成品测试后微调值，待复验 |

布局配置的初始值为 `row=4`、`column=4`。允许范围暂定为 5 行 × 4 列，但只有
R4C4 完成了自动执行验证。第 5 行虽然被 Tab 遮住一部分，探测确认露出区域可命中；
在未做实际执行验收前，不能把所有 20 个格子标记为已支持。

正式配置字段名称尚未冻结。无论最终放入 machine profile、feature config 还是独立
montage section，都必须满足：

- row、column 和三项数值由用户拥有，可修改且可回退；
- preset 只接受明确白名单 `default` / `lung`；
- 数值先规范化和校验，再传给执行器；
- 缺失、越界或无法解析时不启动半条链。

## 已验证的控件契约

Control ID 在字段验证中稳定，但 HWND 每次运行都会变化，绝不能持久化 HWND。

| 语义 | Control ID | Class/UIA type | 已验证 transport | 成功证据 |
| --- | ---: | --- | --- | --- |
| 布局矩阵 | 21112 | `Static` / Image | 动态矩形内真实鼠标单击 | R4C4 由操作者目视确认 |
| Tab 3/4/5 条带 | 21007 | `Static` / Image | 动态矩形内真实鼠标单击 | 页面特有控件出现 |
| 四角图注 | 21155 | `ComboBox` | UIA 展开、唯一定位，真实单击 ListItem | ComboBox 值和 Viewer 表现确认 |
| 窗宽 preset | 21014 | `ComboBox` | UIA 展开、唯一定位，真实单击 ListItem | `lung` 值和窗宽表现确认 |
| 层厚 | 21012 | `Edit` | UIA ValuePattern | 写入值回读一致 |
| 层厚更改 | 21015 | `Button` | UIA InvokePattern | dispatch 成功并由操作者确认结果 |
| 当前层 | 21201 | `Edit` | UIA ValuePattern | 写入值回读一致 |
| 跳转 | 21203 | `Button` | UIA InvokePattern | dispatch 成功并由操作者确认结果 |
| 放大倍数 | 21032 | `Edit` | UIA ValuePattern + focus + Enter | 值回读、焦点和 Enter dispatch 成功 |

控件解析必须保留字段测试已经验证的约束：

- 每一步重新解析，不缓存 HWND；
- 先限定当前前台 Viewer、process、PID 和 root owner；
- Win32 枚举与 UIA AutomationId 两条证据合并后仍须唯一；
- 当前机器上 Win32 子窗口枚举为 0、UIA 候选为 1，不能删除 UIA 路径；
- 控件必须可用、未 offscreen，且矩形位于当前 Viewer 内；
- 任一身份或几何证据不唯一时立即停止。

## 自绘区域点击

布局矩阵与 Tab 条带不响应 `PostMessage(WM_LBUTTONDOWN/UP)`。消息进入队列并不
等于 Viewer 执行了点击。正式实现应沿用字段测试 0.7 的方式：

1. 从唯一 UIA control 取得当前屏幕矩形；
2. 以经过验证的相对位置计算屏幕点；
3. 用 `WindowFromPoint` 确认命中同一 control HWND；
4. 保存鼠标位置，发送真实单击，立即恢复鼠标；
5. 再检查 Viewer 前台身份未变化。

字段测试脚本在自动执行区显式设置 `CoordMode "Mouse", "Screen"`。production 的每个
hotkey 线程也必须在真实点击前设置相同模式：控件矩形和 `WindowFromPoint` 都是屏幕
坐标，若沿用默认的活动窗口相对坐标，点击会落在错误位置并表现为 Tab 无反应。

production 只在布局点击后保留 350 ms 固定稳定时间，因为该控件没有公开“已选中”的
状态；其余步骤不采用全局固定等待。Tab 通过页面特有控件出现确认，下拉通过回读值
确认，Edit 使用最长 300 ms 的自适应回读，Button 只保留 60 ms 稳定时间，最终
Enter 发送后直接结束。

当前已验证 Tab 相对位置为：

| Tab | x ratio | y ratio | 后置观察 |
| --- | ---: | ---: | --- |
| Tab 3 | 0.479866 | 0.5 | ComboBox 21155 唯一出现 |
| Tab 4 | 0.681208 | 0.5 | Edit 21032 唯一出现 |
| Tab 5 | 0.869128 | 0.5 | ComboBox 21014 唯一出现 |

R4C4 在布局 control 中的字段测试位置为 `xRatio=0.881579`、
`yRatio=0.771014`。不要直接假设 `(column-0.5)/4`、`(row-0.5)/5` 就能覆盖全部
格子；应使用探测得到的首格中心和行列步距建立布局 profile，并逐格做边界检查。

## ComboBox 选项

下拉项不属于 Viewer root-owner 下的普通子窗口，而是桌面根下的 `ComboLBox`。
正确流程已经现场验证：

1. UIA `ExpandCollapsePattern.Expand()` 展开目标 ComboBox；
2. 从 desktop root 搜索 `ListItem`，名称使用忽略大小写的精确匹配；
3. 要求候选同 PID、可用、可见并支持 SelectionItem；
4. 沿 UIA RawView 父链确认候选回到刚展开的 ComboBox；
5. 用 ListItem 矩形中心计算点击点；
6. `WindowFromPoint` 必须命中同 PID 的 `ComboLBox`；
7. 发送真实单击、恢复鼠标，再回读 ComboBox 值。

不能只调用 `SelectionItemPattern.Select()`：现场证明确实会改变 ComboBox 值，但
不会可靠触发 MedEx 应用 `lung` 窗宽。ListItem 是虚拟 UIA 元素，
`NativeWindowHandle=0` 是合法现场结果；不能要求它等于 `ComboLBox` HWND。

## 正式实现建议

建议把实现拆成三层，避免把字段测试脚本整体复制进 production：

1. profile：Body/Head/Lung 的 preset、三项数值和 layout row/column；
2. resolver/transport：控件唯一解析、Tab/layout 点击、ComboBox 选择、Edit 写入、
   Button invoke 和 Enter commit；
3. orchestration：按统一顺序执行、busy guard、逐步失败即停止、结果反馈和热键注册。

执行器应返回结构化结果，至少区分：

- Viewer/foreground identity 变化；
- control not found/not unique；
- point HWND mismatch；
- Tab 点击后页面特有控件未出现；
- ComboBox option not unique、popup host mismatch、值未确认；
- Edit 值未确认；
- Button invoke 或最终 focus/Enter 失败。

不要在 production 保留字段测试的逐步 F10 操作方式；也不要删除字段测试。正式动作
需要一键执行，而字段测试继续作为现场诊断和回归工具。

## 开分支前检查

当前工作区可能包含用户维护的发布说明修改。开分支前先审计，不要用 `git clean`、
`git reset --hard` 或 checkout 覆盖未确认内容：

```text
git status --short
git diff -- assets/publish/更新说明.md
git log -4 --oneline
```

确认保留方式后，再从最新 main 建立功能分支，例如：

```text
git switch -c feature/mxnm-montage
```

## 分支开发顺序

1. 冻结 profile schema 和用户可调参数，不注册新 hotkey。
2. 从字段测试提取通用 resolver/transport，并为每个失败码补静态测试。
3. 先接 Lung profile，保留逐步 harness 与 production executor 的契约对照。
4. 在当前工作站做 Lung 一键端到端验证；确认鼠标恢复、窗宽实际应用和失败即停。
5. 接 Body/Head，并分别确认 `default` 窗宽和微调后的三个数值。
6. 更新 hotkey ownership：production 注册后，compatibility 不再注册同一组快捷键。
7. 生成 release source，跑完整测试，再在 Windows 编译产物上做三项 smoke test。

## 完成条件

只有同时满足以下条件，才能从 legacy compatibility 移除 montage：

- 三个 profile 的最终参数由用户确认；
- layout row/column 配置保存与读取通过；
- Body、Head、Lung 在目标工作站分别完成一键现场验证；
- 快捷键 ownership 回归证明不会重复注册；
- 任一步失败都会停止后续操作，并给出可理解反馈；
- release source/build integration 和完整自动测试通过；
- 用户文档只描述最终操作方法和必要限制，不暴露内部控件实现。
