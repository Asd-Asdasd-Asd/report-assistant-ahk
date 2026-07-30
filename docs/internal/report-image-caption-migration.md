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
