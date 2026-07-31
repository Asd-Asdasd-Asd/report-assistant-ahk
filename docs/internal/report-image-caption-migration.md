# 报告图像 caption + advance 迁移设计

## 当前语义

Legacy `Shift+Alt+S` 跨两个同进程窗口完成一个高频循环：

1. 在 MedEx 报告编辑窗口复制当前选中的报告文字；
2. 点击另一个报告图像窗口下方的图像描述输入区域并粘贴；
3. 在该目标窗口上方图像区域发送一次 `WheelDown`；
4. 恢复原鼠标位置；foreground 与 legacy 一样停留在目标窗口。

Legacy 还包含一个需要保留的业务语义：首次粘贴后，系统 clipboard 继续保留
该 caption。此时编辑器选区已经消失，用户无需重新选择文字，仍可在图像窗口
再次触发快捷键，把同一句 caption 连续写入多张图片。这是 feature，不是复制
失败后的偶然行为。

旧实现的 `2821,1363` 与 `2884,704` 是虚拟桌面绝对坐标。它们来自窗口位于
右侧副屏时的既定布局，不能作为新实现的身份或几何依据。

## 目标架构

正式功能拆成四层：

1. **Source/target window model**：触发时前台 HWND 是 source；从 caption point
   或经过结构验证的同 PID 顶层窗口解析 target。复制前要求 source 保持前台，
   点击后则要求 target 成为前台。两个窗口分别记录 class、PID、root owner、
   client rect、DPI 和 monitor。
2. **Caption capture/reuse state**：从已验证 source 窗口触发时发送一次
   `Ctrl+C`，要求 clipboard sequence/内容确实更新，并用完整 clipboard
   payload 替换内存 caption cache；从已经绑定的 target HWND 触发时不再发送
   `Ctrl+C`，而是复用 cache。caption 有意留在系统 clipboard，不恢复触发前
   clipboard。
3. **Caption target resolver**：优先使用唯一、visible/enabled、矩形合理的
   `Edit`/TextEdit/Value element；若供应商只暴露自绘区域，则使用固定静态锚点
   与 target client rect 推导区域内点，不使用屏幕绝对坐标。
4. **Image advance resolver**：从同一窗口中定位图像 viewport，验证点属于同
   PID/root-owner/client bounds 后只发送一次 `WheelDown`，最后恢复鼠标。

热键在 `S` key-down 时立即进入 transaction，不等待 Shift/Alt 松开。transaction
结束后只等待 `S` 抬起以阻止主键自动重复；用户可以一直按住 Shift+Alt，逐次
按下 `S` 连续标图。

主屏或副屏不进入算法。monitor、分辨率、DPI 和 scaling 只用于解释现场差异及
拒绝未验证布局。

## 失败边界

- source 前台触发但 copy 未更新 clipboard：不复用旧 cache，不点击、不粘贴、
  不滚轮；
- target 前台触发但不是 cache 已绑定且重新验证通过的精确 HWND/PID/root-owner：
  不复用；
- cache 不存在、已显式清除，或其 source/target binding 已失效：不复用；
- copy 前 source window、PID 或 foreground 改变：立即停止；
- caption click 后 target 未成为前台，或 target PID/root-owner 改变：立即停止；
- caption target 缺失、重复、disabled、offscreen 或越界：立即停止；
- image target 缺失、重复或不属于同一 owner family：不滚轮；
- paste 成功但 advance 失败：保留已粘贴 caption，明确报告部分成功；
- 禁止 blind retry、第二 transport、自动点击“保存”或自动提交报告；
- `feat/report-image-caption-0.7.0` 已把 ownership 移交给 production module，
  并从 compatibility 删除重复入口；工作机验收通过后版本提升为 `0.7.0`，
  tag 仍等待发布后的多机器验证。

## 一次性现场诊断

如果目标机器没有安装 AutoHotkey，先在 Windows 源代码目录运行：

`tools\field-testing\Build Report Image Caption Diagnostic EXE.cmd`

生成文件位于仓库同级构建目录：

`..\report-assistant-build\report-image-caption-diagnostic\publish\MedEx-Report-Image-Caption-Diagnostic.exe`

将该 EXE 单独复制到目标机器即可运行；它不依赖目标机器安装 AutoHotkey，也不
进入正式 release/publish。

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

image point 不依赖大型 focusable Document。右侧报告预览 sidebar 折叠后，
Chromium UIA tree 不再暴露展开态中用于定位图像区的 Document，但底部 caption
Pane 会随可用图像区域同步扩展。统一规则取 caption Pane 的横向中心，以及
target client 顶部到 `图像描述` anchor 之间的纵向中心。重新验证
PID/root-owner/client bounds 后只发送一次 `WheelDown`，不回退到旧绝对坐标。

2026-07-31 的折叠态 field evidence：target client rect 为
`1920,23,4480,1440`，caption Pane 为 `2140,1322,4429,1438`，
`图像描述` 为 `2145,1297,2201,1313`，`保存` 为
`4328,1398,4408,1430`。此时 target 仅暴露两个无关 focusable Document，
原 Document 规则得到零个 target；统一 Pane 规则计算 image point 约为
`3285,660`。同一规则在展开态计算约为 `2939,640`。

### Transaction

实现维护一个仅存在于当前进程内存的 caption cache。它不得写入日志、配置或
磁盘，也不得输出 payload；新 source capture 覆盖旧 cache。退出/重载、显式
结束本轮快速标图，或绑定的 source/target 失效时必须清除 cache。正式功能需
提供一个明确的“清除快速标图 caption”入口，防止同一窗口跨检查继续复用旧句子。

从 source 窗口首次触发时，顺序固定为：

1. 保存 mouse；记录当前 source HWND/PID；
2. source 前台下发送一次 `Ctrl+C`，要求 fresh non-empty clipboard；
3. 将新的完整 clipboard payload 写入内存 cache，并绑定 source 与唯一 target；
4. 解析 caption/image points；
5. 显式激活唯一 target，重新验证 caption point 后点击并等待 15 ms，使
   Chromium 在首次激活与连续复用时都完成 caption 焦点切换；
6. 从 cache 写回 clipboard，先 `Ctrl+A` 全选当前 caption，再粘贴一次；
7. 等待 20 ms 后翻页；这是已通过工作机验收的短 settle，不假定延长等待
   能代替 MedEx 自身的 caption 提交流程；
8. 移到 image point，发送一次 `WheelDown`；
9. `finally` 只恢复 mouse；系统 clipboard 有意保留当前 caption。

从已绑定 target 窗口连续触发时，顺序固定为：

1. 不发送 `Ctrl+C`，重新验证前台正是 cache 绑定的 target
   HWND/PID/root-owner，client rect 未变化且两个缓存点仍属于该 target；
2. 从 cache 写回 clipboard，避免用户中途复制的其他内容被误粘贴；
3. 复核缓存的 caption/image points，点击、粘贴一次并 `WheelDown` 一次；
4. `finally` 只恢复 mouse；系统 clipboard 继续保留当前 caption。

首次完整 UIA signature 解析后，同时缓存 target client rect 与 caption/image
points。只要 source/target binding 和 client rect 未变化，从 target 连续复用，
以及回到同一 source 复制新 caption，都走轻量验证，不重复扫描整个 UIA tree。
任何窗口尺寸或 binding 变化都会使缓存失效；source 捕获新文字时可重新执行
完整 resolver，target 前台复用时则 fail closed 并要求重新选择。

在 source 窗口触发时，无论是否已有 cache，fresh copy 失败都必须 fail closed，
不得偷偷降级为 reuse。其他窗口触发同样不得复用。这样既保留“一句话连续标多张
图片”，又不会把真正的复制失败当成用户意图。

paste 已发送后若 wheel 失败，返回 partial success，不重贴、不补偿滚轮，也不
撤销 caption。工作机已验收新 capture、同 caption 连续 reuse、key-down 触发、
保持修饰键连续操作、paste、wheel、clipboard retention 和 mouse restore，
因此版本提升为 `0.7.0`。发布后继续验证多机器 target resolution、cache 失效
和 Viewer 右键链；全部通过后再创建正式 tag。

2026-07-31 DevTools 证据确认，MedEx 的 `flipImage()` 只在首次操作或距离上次
翻页超过 500 ms 时调用 `saveDescriptionByMouse()`；500 ms 内仍会切换图片但
跳过保存。快速连续触发时“caption 可见但未保存”由此产生，不能用调整 20/80 ms
粘贴 settle 根治。

production 现改为从同一套 UIA signature 中同时解析唯一“保存”按钮：粘贴后先
复核并点击 save point，等待 200 ms，再向 image point 发送一次 `WheelDown`。
save point 与 caption/image points 一起缓存并逐次校验 target PID、client rect 和
root-owner；保存入口失效时返回 `SAVE_DISPATCH_FAILED`，不继续翻页。这样通过页面
原有按钮触发已确认的 `saveDescription()` 业务链，不再把 500 ms 条件保存当作正常
路径。

无界面直调 `editorInstance`、`saveDescription()`、`nextImg()` 仍缺少经过验证的
renderer transport，留给独立 experiment。当前 DevTools 已确认图片窗口没有
`opener`，不包含主编辑 renderer，并且只注册 Electron remote 内部回调事件；不得
猜测 `ipcRenderer.sendTo` 的目标、channel 或 payload。完整分析见
`docs/technical-investigations/2026-07-medex-devtools-runtime.md`。

保存点击派发后，production 在既有 200 ms settle 内启动非激活、鼠标穿透的视觉
反馈：一张带三条文字线的轻量卡片从 source 选区附近（鼠标不在 source 时退回
source client 中心）沿二次曲线缓入缓出，接近 caption point 时缩小并淡出；同一
时间 caption 输入区域执行一次低透明度高亮。overlay 使用 token 取代旧动画，
不进入 clipboard、保存、翻页或结果判断逻辑；其含义仅为“保存点击已经派发”，
不声称后端保存成功。
