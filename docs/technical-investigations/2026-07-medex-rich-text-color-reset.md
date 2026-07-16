# MedEx 富文本插入后颜色复位技术调查

日期：2026-07；最后修订：2026-07-15 production baseline validation

本文是 Technical Investigation。V1 是可替换的现场自动化方案，不是永久架构。

## Objective

`CF_HTML` 已确认可在 MedEx 报告编辑器插入红色文字。剩余问题是 MedEx 继承最后插入字符的颜色，导致后续输入仍为红色。目标是恢复黑色插入状态，同时：

- 不修改可见报告文字；
- 不插入零宽或隐藏字符；
- 不污染医疗报告；
- 不依赖 Word COM；
- 不改变 clipboard restoration contract。

## Rejected approaches

1. 红色 span 后的空黑色 HTML span：Word 忽略，MedEx 不恢复颜色；Rejected。
2. 黑色零宽字符：污染报告，删除和光标行为不可预测；Rejected。
3. Word COM：`Selection.Font.Color = 0` 只证明 Word 行为，MedEx 不是 Word；Rejected。
4. 键盘格式快捷键：`Ctrl+B` 可控制 bold，但 `Ctrl+Shift+C`、`Ctrl+Space`、`Alt` 组合等均不能可靠复位字体颜色；Rejected。

## Confirmed application architecture

MedEx 是 Electron/Chromium 应用，证据包括 `LICENSE.electron.txt`、`resources/app`、`dist`、`node_modules`，以及 renderer、gpu-process、network、audio 等 Chromium processes。主窗口为 `ahk_class Chrome_WidgetWin_1`，报告编辑器暴露为 `Document`，运行于 Chromium renderer。

## DevTools investigation

`F12` 和 `Ctrl+Shift+I` 均不打开 DevTools；未发现 `--remote-debugging-port` 或 `--remote-debugging-pipe`。因此当前版本不能直接附加 DevTools。Console inspection、`executeJavaScript()` 和 embedded-editor JavaScript command 是 deferred investigation，不是永久 rejected。

## UI Automation findings

Window Spy 只报告 `Intermediate D3D Window1`，不能识别 formatting toolbar；Accessibility Insights 可检查相关 nodes，二者并不等价。报告 `Document` 支持 `TextPattern`、`ValuePattern` 和 `LegacyAccessiblePattern`。

颜色 trigger 本身没有可用 UIA node。菜单打开后，每个颜色项暴露为 `Hyperlink`，Name 包括 `000000`、`ff0000`、`95b3d7`，并支持 `InvokePattern`。对 exact Name=`000000` 调用 `Invoke()` 与点击黑色项具有相同自动化效果。这仍是调查中最重要的 confirmed finding。

普通暂存、保存、打印按钮暴露为支持 InvokePattern 的 `Button`；bold、italic、color 中间 formatting group 没有直接可选 node，hit testing 只落到周围 `Document`，不能使用 `FindElement("颜色")`。

## Evidence classification

### Verified behavior

- UIA `BoundingRectangle` 可用于 toolbar Text anchors，即使 pointer hit testing 失败。
- 2026-07-13 现场存在病史信息、检查所见、检查结论三组同构 toolbar。
- 旧模型能打开颜色菜单并 Invoke black item，但曾选择错误 toolbar。
- 2026-07-14 旧模型正确选择 index 2 后，又因 UIA root `[-8,-8,1928,1048]` 不完全位于 client area 而 fail closed，未发送 click。
- `检查所见`：Text，`[296,289,352,305]`。
- 字号当前值：Text；`14px` 与 `16px` 均观察为 `[502,290,529,304]`。

### User observation

- `①` 是用户可配置的快捷符号内容，可改名、重排或移除。
- 字号 leaf 的 Name 随当前字号改变。
- completion notification 会干扰焦点和后续颜色验证。

### Implementation inference

- `检查所见` 比候选行序号更适合定位目标语义行。
- 同行动态字号 Text 是距离 color trigger 较近的局部几何基准。
- 当前 supported layout profile 假设字号值与颜色 control 之间的局部水平布局稳定。

### Deferred investigation

- 不同 DPI、缩放、窗口宽度和 MedEx 版本的 layout profiles。
- 是否存在更稳定的报告区域父容器。
- Electron renderer、IPC 或 embedded editor API 的直接命令。

## Invalidated anchor assumptions

以下仅保留为历史证据，不得用于 production resolver：

- exact `Name="①"`：它是用户可配置内容，不是稳定 anchor。
- exact `Name="16px"`：它是当前字号值；`14px` 等同样合法。
- `16px + ①` pairs 按 Y 排序后取第二组：插入其他 toolbar 或用户定制会破坏该假设。
- 整个 UIA root 必须包含于 client area：Windows invisible resize frame 会产生合法负边界。
- 旧 `0.337` 双锚点比例及 `fontSizeTop + 1` Y 公式：被新的 local-offset profile 取代。

## Approved V1 anchor model

`MedExColorResetLayoutProfile` 集中定义：

```text
ProfileName=medex-0.0.1-baseline
RegionAnchorName=检查所见
FontSizeNamePattern=^\d+(?:\.\d+)?px$
OptionalRightAnchorName=rAI
ColorArrowOffsetX=143
ColorArrowOffsetY=0
MinVerticalOverlapRatio=0.5
```

Required `RegionAnchor` 是 exact Text Name=`检查所见`，用于唯一定位目标行。Required `FontSizeAnchor` 是其右侧、垂直有效重叠、Name 匹配集中 pattern 的唯一 Text。`rAI` 只用于 diagnostics/layout fingerprint；缺失、改名或歧义均不阻塞。

生产流程：

1. 验证 foreground MedEx hwnd/process。
2. 从 foreground window root 或已确认的报告区域父容器枚举 Text elements。
3. 找到 client area 内唯一有效的 `检查所见`。
4. 找到该行右侧唯一动态字号 Text。
5. 验证 rectangles、vertical overlap、relative order 和 client coordinate space。
6. 以 local offsets 计算 color trigger。
7. 点击前再次验证 foreground hwnd/process。
8. 发送一次 validated click；只有菜单未出现且 foreground 不变时允许一次 bounded retry。
9. 查找 exact Name=`000000` 的 `Hyperlink`，确认 InvokePattern 后调用 `Invoke()`。
10. 输出 automation-chain result，等待人工最终颜色验证。

失败时不点击或停止后续动作：region 缺失/歧义、font anchor 缺失/歧义、invalid rectangle/geometry/coordinate space、foreground 改变、菜单未打开、black item 缺失、Invoke 不可用/失败。没有 guessed black-coordinate fallback，也没有 absolute screen-coordinate fallback。

## Click-point calculation

V1 使用：

```text
arrowX = fontRect.r + ColorArrowOffsetX
arrowY = Round((fontRect.t + fontRect.b) / 2) + ColorArrowOffsetY
```

baseline 为 `529 + 143 = 672`、`Round((290 + 304) / 2) + 0 = 297`。工具栏整体沿 Y 移动时，font rectangle 与 click point 同步移动相同 delta。位置校准只有 `ColorArrowOffsetX/Y` 两个集中值，不需要重写 resolver。

## Recalibration procedure

MedEx 小版本改变局部布局后：

1. 在 approved non-clinical context 记录字号 Text rectangle。
2. 记录 color-arrow 目标 screen point。
3. 计算 `ColorArrowOffsetX = targetX - fontRect.r`。
4. 计算 `ColorArrowOffsetY = targetY - Round((fontRect.t + fontRect.b) / 2)`。
5. 仅在 field-debug overrides 中试验新值。
6. Windows 人工验证通过后，为新 MedEx layout 新增/更新 profile 并发布；不要改 core resolver。

## Structured results and diagnostics

核心新增失败码为 `COLOR_RESET_REGION_ANCHOR_NOT_FOUND`、`COLOR_RESET_REGION_ANCHOR_AMBIGUOUS`、`COLOR_RESET_FONT_SIZE_ANCHOR_NOT_FOUND`、`COLOR_RESET_FONT_SIZE_ANCHOR_AMBIGUOUS`。既有 process/UIA/rectangle/geometry/coordinate/click/menu/black-item/invoke/unexpected failure codes 保持。

Diagnostics 记录 profile、region/font/optional anchor names 和 rectangles、font candidate count、offsets、screen/client point、selection/geometry/coordinate/foreground reasons、timing/retry、process/window 和 UIA metadata；不得记录患者信息、报告文字或 clipboard payload。

自动化输出分别包含 `ColorMenuClickSent`、`BlackItemFound`、`BlackItemInvokeSucceeded` 和 `FinalInsertionColorVisuallyValidated`。`AUTOMATION_CHAIN_OK` 只表示 Invoke 链路未失败，同时必须保持 `FINAL_COLOR_PENDING_VISUAL_VALIDATION`。最终字段只能由 Windows 操作者在非临床测试环境手工输入无害字符后确认。Field debug 不显示 `MsgBox`、`ToolTip` 或 `TrayTip`，只写 clipboard/log/file。

## Architecture boundary

- `clipboard_html.ahk` 只负责 generic CF_HTML、clipboard writing、paste 和 restoration。
- `report_editor.ahk` 负责 formatted-text workflow orchestration 和 partial-failure contract。
- `medex_report_editor.ahk` 负责 MedEx process/UIA/menu interaction。
- `medex_color_reset_logic.ahk` 负责可测试的 profile、selection 和 geometry。

未来 Word、browser editor 或其他 HIS 必须使用独立 adapter，不能把 MedEx UIA 混入 generic clipboard module。

## Future investigation

继续检查 `resources/app`，识别 TinyMCE、Vue、其他 editor framework 或 Electron IPC，并调查 direct renderer/editor command。概念路线 `executeJavaScript() → editor.setColor("#000000")` 只表示方向，不声明该 API 当前存在。

Candidate G 已完成 G1/G2、caret-order A/B 和 generated-release Windows 验证并提升为 production mainline：UIA 仅定位 semantic `检查所见` toolbar row，arrow/black interaction 使用经过 profile 校准的相对鼠标位置，并在 black click 前执行四点 popup signature guard。详见 `2026-07-medex-color-reset-candidate-g.md`。

## Investigation conclusion

- Current control implementation: `uiaInvoke`, retained for comparison/rollback only
- Current production route: Candidate G semantic UIA localization + pixel-validated relative mouse interaction
- Known limitation: The color dropdown trigger itself is not exposed as a usable UIA element.
- Future replacement candidate: Direct editor command through Electron renderer, IPC, or the embedded editor API.
- Candidate G status: promoted on the supported profile; `uiaInvoke` is explicit comparison/rollback only, with no automatic fallback.

2026-07-15 baseline validation 在 MedEx 0.0.1.0、1920×1080、100% scaling、DPI 96 环境获得三次连续 `AUTOMATION_CHAIN_OK`，并由用户人工确认后续输入为黑色。观察到的 process 是 provisional `medexworkstations.exe`。其他 DPI、resolution、multi-monitor/per-monitor DPI、MedEx version 和用户布局仍待验证。

Status: Investigation complete; Color Reset V1 production baseline field-validated.
