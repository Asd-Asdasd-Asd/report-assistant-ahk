# 报告图像 caption + advance 迁移设计

## 当前语义

Legacy `Shift+Alt+S` 跨两个同进程窗口完成一个高频循环：

1. 在 MedEx 报告编辑窗口复制当前选中的报告文字；
2. 点击另一个报告图像窗口下方的图像描述输入区域并粘贴；
3. 在该目标窗口上方图像区域发送一次 `WheelDown`；
4. 恢复原鼠标位置；foreground 与 legacy 一样停留在目标窗口。

旧实现的 `2821,1363` 与 `2884,704` 是虚拟桌面绝对坐标。它们来自窗口位于
右侧副屏时的既定布局，不能作为新实现的身份或几何依据。

## 目标架构

正式功能拆成四层：

1. **Source/target window model**：触发时前台 HWND 是 source；从 caption point
   或经过结构验证的同 PID 顶层窗口解析 target。复制前要求 source 保持前台，
   点击后则要求 target 成为前台。两个窗口分别记录 class、PID、root owner、
   client rect、DPI 和 monitor。
2. **Source selection capture**：只在已验证目标窗口发送一次 `Ctrl+C`，要求
   clipboard sequence/内容确实更新；使用共享 clipboard transaction，完成
   paste 后恢复用户原 clipboard。
3. **Caption target resolver**：优先使用唯一、visible/enabled、矩形合理的
   `Edit`/TextEdit/Value element；若供应商只暴露自绘区域，则使用固定静态锚点
   与 target client rect 推导区域内点，不使用屏幕绝对坐标。
4. **Image advance resolver**：从同一窗口中定位图像 viewport，验证点属于同
   PID/root-owner/client bounds 后只发送一次 `WheelDown`，最后恢复鼠标。

主屏或副屏不进入算法。monitor、分辨率、DPI 和 scaling 只用于解释现场差异及
拒绝未验证布局。

## 失败边界

- source copy 未更新 clipboard：不点击、不粘贴、不滚轮；
- copy 前 source window、PID 或 foreground 改变：立即停止；
- caption click 后 target 未成为前台，或 target PID/root-owner 改变：立即停止；
- caption target 缺失、重复、disabled、offscreen 或越界：立即停止；
- image target 缺失、重复或不属于同一 owner family：不滚轮；
- paste 成功但 advance 失败：保留已粘贴 caption，明确报告部分成功；
- 禁止 blind retry、第二 transport、自动点击“保存”或自动提交报告；
- 迁移验证完成前，ownership 继续属于
  `legacy/medex_legacy_compat.ahk`。

## 一次性现场诊断

运行
`tests/windows/report_image_caption_migration_diagnostic.ahk`。该脚本不点击、
不粘贴、不滚轮，也不输出选中文字、窗口标题、accessible Name/Value、URL 或
患者信息。

1. 打开报告图像窗口，选中一段非临床测试文字。
2. 按 `Ctrl+Alt+Shift+F8`。脚本仅验证一次 `Ctrl+C` 是否产生新 clipboard，
   记录长度后立即丢弃 payload 并恢复原 clipboard。
3. 把鼠标停在图像描述输入框中央，再按同一快捷键。
4. 把鼠标停在上方实际接收滚轮的图像区域中央，再按同一快捷键。
5. 完整诊断结果会写入 clipboard；回传该文本。
6. 任意阶段按 `Ctrl+Alt+Shift+F7` 可重置。

诊断同时收集 source 与同 PID 顶层窗口集合，并从两个鼠标 point 分别反查
target root-owner、monitor、DPI、client-relative point/ratio、native HWND
parent chain、UIA smallest-element parent chain、target 结构候选及精确静态锚点
`图像描述`/`保存` 的数量与矩形。现场数据足够后再选择 semantic control、
window-relative geometry 或二者组合，不提前把 fallback 写入 production。

## 2026-07-30 现场结论

`DiagnosticVersion=1.1` 在 1920×1080 主屏加 2560×1440 右侧副屏、DPI 96、
100% scaling 环境完成一次三阶段采集：

- source 是主屏前台 `Chrome_WidgetWin_1`，selection copy 更新为 10 个字符，
  foreground/mouse 不变，原 clipboard 已恢复；
- 同一 `medexworkstations.exe` PID 下存在三个 visible top-level window，
  因此不能用 PID、title length、monitor 或“排除 source 后取第一个”选择 target；
- caption 与 image point 均反查到同一个 target root-owner，位于副屏，client
  rect 为 `1920,23,4480,1400`；
- caption point 的 client ratio 为约 `0.353125,0.954248`，命中
  `Pane 2140,1282,3739,1398`；该 Pane 没有 Text/TextEdit/Value Pattern；
- target 内 exact `图像描述` Text 恰好一个，rect 为
  `2145,1257,2201,1273`；exact `保存` Button 恰好一个，rect 为
  `3638,1358,3718,1390`；
- target 的唯一 `Edit` 位于窗口左上方，与 caption 无关；
- image point 的 client ratio 为约 `0.396484,0.467683`，UIA hit testing
  只返回 outer `Document`；但 target 内存在一个包含该点的大型 focusable
  `Document 2743,142,3739,938`，另有右侧报告预览 Document。

以上是单机 field evidence，不代表其他分辨率或布局已经通过。它足以确定
实现方向，不再需要同机重复诊断。

## 建议 resolver

### Target window

1. 从 source 前台 HWND/PID 枚举同 PID、visible、root-owner=self 的
   `Chrome_WidgetWin_1`，排除 source。
2. 对每个候选只执行固定 exact-query，不读取或记录任意 Name/Value：
   - `图像描述` Text 恰好一个；
   - `保存` Button 恰好一个；
   - 两者处于窗口下部且横向顺序合理；
   - 存在位于两锚点上方、面积显著的 image Document；
   - caption、image 和 anchors 均在 candidate client bounds 内。
3. 只有一个候选通过完整签名时才继续；零个或多个均 fail closed。不得用
   z-order、monitor、title length 或旧坐标打破歧义。

### Caption point

caption 不能通过 Value/TextEdit 写入。由 exact `图像描述` 与 `保存` rect
构造二者之间、位于 caption Pane 内的 client-relative click point，并要求：

- `WindowFromPoint` 回到 target PID/root-owner；
- smallest UIA element 是 visible/enabled Pane；
- Pane 位于 anchors 下方、宽度和高度达到最低阈值；
- click 前 source 仍前台；click 后 target 必须成为前台。

随后只粘贴一次。无需也不得自动点击“保存”。

### Image point

从 target 中选择唯一满足以下条件的大型 focusable Document：

- 位于 caption anchors 上方；
- 不属于最右侧报告预览栏；
- 面积达到 target client 的最低比例；
- 与 caption Pane 横向区域有合理重叠。

使用该 Document 中心附近的内部点，重新验证 PID/root-owner/client bounds 后
只发送一次 `WheelDown`。若不能唯一识别 image Document，则停止，不回退到
旧绝对坐标。

### Transaction

完整顺序固定为：

1. 保存 mouse 与完整 clipboard；
2. source 前台下发送一次 `Ctrl+C`，要求 fresh non-empty clipboard；
3. 解析唯一 target 和 caption/image points；
4. 点击 caption point，验证 target 成为前台；
5. 粘贴一次并等待最小安全 settle；
6. 移到 image point，发送一次 `WheelDown`；
7. `finally` 恢复 mouse 和原 clipboard。

paste 已发送后若 wheel 失败，返回 partial success，不重贴、不补偿滚轮，也不
撤销 caption。只有 Windows field harness 对 source copy、target ambiguity、
foreground switch、paste、wheel、clipboard restore 和 mouse restore 全部验收
后，才把 `Shift+Alt+S` ownership 从 compatibility 移交给麦旋风。
