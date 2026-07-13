# MedEx 富文本插入后颜色复位技术调查

日期：2026-07

本文记录一次已经完成的 Technical Investigation。当前结论批准一个可实施的 V1 方案，但不把该方案描述为永久架构。

## Objective

`CF_HTML` 已确认可以在 MedEx 报告编辑器中正确插入红色文字。剩余问题是 MedEx 会继承最后一个已插入字符的颜色，导致用户随后键入的内容继续保持红色。

目标是在不改变以下契约的前提下，将当前插入颜色恢复为黑色：

- 不修改报告中可见文字；
- 不插入零宽字符或隐藏字符；
- 不污染医疗报告内容；
- 不依赖 Word COM；
- 不改变现有剪贴板恢复契约。

## Rejected approaches

### 1. 在红色 span 后放置空的黑色 HTML span

- Word 会忽略空 span。
- MedEx 不会因此恢复插入颜色。
- 结论：Rejected。

### 2. 插入黑色零宽字符

- 会污染报告内容。
- 删除行为和光标行为不可预测。
- 医疗报告中不接受隐藏字符。
- 结论：Rejected。

### 3. Word COM

- `Selection.Font.Color = 0` 在 Word 中有效。
- MedEx 不是 Word，不能依赖 Word 对象模型。
- 结论：Rejected。

### 4. 键盘格式快捷键

- `Ctrl+B` 可以控制粗体格式。
- 没有找到可靠的字体颜色复位快捷键。
- `Ctrl+Shift+C`、`Ctrl+Space`、`Alt` 组合及类似尝试均未形成可用方案。
- 结论：Rejected。

## Confirmed application architecture

MedEx 已确认是 Electron/Chromium 应用。证据包括：

- `LICENSE.electron.txt`；
- `resources/app`；
- `dist`；
- `node_modules`；
- Chromium 进程类型，包括 renderer、gpu-process、network 和 audio。

主窗口使用：

```text
ahk_class Chrome_WidgetWin_1
```

报告编辑器暴露为：

```text
Document
```

因此，报告编辑器运行在 Chromium renderer 内。

## DevTools investigation

已确认：

- `F12` 不会打开 DevTools；
- `Ctrl+Shift+I` 不会打开 DevTools；
- 未发现 `--remote-debugging-port` 参数；
- 未发现 `--remote-debugging-pipe` 参数。

因此，当前应用版本不能直接附加 Chromium DevTools。以下路线是 deferred，而不是永久 rejected：

- Console inspection；
- `executeJavaScript()`；
- 直接调用嵌入式编辑器 JavaScript 命令。

## UI Automation findings

- Window Spy 报告 `Intermediate D3D Window1`，无法识别工具栏控件。
- Accessibility Insights 可以检查相关 accessibility nodes。
- Window Spy 与 Microsoft UI Automation 不是等价的检查机制。

报告编辑器 `Document` 支持：

- `TextPattern`；
- `ValuePattern`；
- `LegacyAccessiblePattern`。

因此，报告编辑器已经通过 UIA 暴露。

## Color menu findings

颜色触发按钮本身没有独立且可用的 UIA node。

颜色菜单打开后，每个颜色项暴露为：

- Control type：`Hyperlink`；
- Name 示例：`000000`、`ff0000`、`95b3d7`；
- 支持 `InvokePattern`。

已确认行为：

- 对颜色项调用 `Invoke()` 与鼠标点击该颜色具有相同功能效果；
- 调用 Name 为 `000000` 的项目会把当前插入颜色改为黑色。

**这是本次调查中最重要的已确认发现。**

## Toolbar findings

普通工具栏按钮，例如暂存、保存和打印，暴露为：

- `Button`；
- 支持 `InvokePattern`。

中间格式组中的粗体、斜体和颜色没有暴露对应的、可直接选择的 UIA nodes。鼠标 hover 和 hit testing 只能解析到周围的 `Document`。

因此，当前不能使用以下直接查询定位颜色触发器：

```text
FindElement("颜色")
```

## BoundingRectangle findings

accessibility tree 为以下 anchors 暴露了可靠矩形：

| Anchor | Observed rectangle values |
| --- | --- |
| `检查所见` | `l=296, r=352` |
| `宋体` | `l=425, r=449` |
| `16px` | `l=502, r=529` |
| `①` | `l=953, r=967` |

这说明即使 pointer hit testing 失败，UIA `BoundingRectangle` 数据仍然可用。

## Color arrow positioning

Window Spy 观察到的 client coordinates：

```text
x=672
y=291
```

使用：

```text
fontSizeRight = 529
numberButtonLeft = 953
```

估算水平比例约为：

```text
0.337
```

V1 临时公式：

```text
arrowX = fontSizeRight + 0.337 * (numberButtonLeft - fontSizeRight)
arrowY = fontSizeTop + 1
```

这是基于 UIA anchors 的比例坐标计算，不是固定 absolute-pixel coordinate。

## Approved V1 implementation direction

推荐调用流：

```text
PasteRedFigureText()
→ ResetMedExInsertionColor()
```

`ResetMedExInsertionColor()` 内部流程：

1. 验证前台进程是 `medexworkstations.exe`。
2. 使用 UIA 定位 `16px`。
3. 使用 UIA 定位 `①`。
4. 校验两个矩形及其相对几何关系。
5. 使用 anchor rectangles 和比例公式计算颜色箭头位置。
6. 点击计算得到的 trigger position。
7. 等待颜色菜单出现。
8. 查找 Name 为 `000000` 的 `Hyperlink`。
9. 调用该元素的 `Invoke()`。
10. 返回结构化成功或失败结果。

失败行为必须 fail-closed：

- 前台进程错误时立即返回；
- 任一 anchor 缺失时立即返回；
- 几何关系无效时立即返回；
- 菜单未出现时停止；
- 未找到 `000000` 时停止；
- 绝不在校验失败后继续 blind clicks。

## Structured diagnostic results

颜色复位不能只返回无信息量的 Boolean。V1 至少应返回以下 result codes：

| Result code | Meaning |
| --- | --- |
| `COLOR_RESET_OK` | 黑色项目已成功 Invoke |
| `COLOR_RESET_WRONG_PROCESS` | 前台进程不是目标 MedEx 进程 |
| `COLOR_RESET_PROCESS_NAME_UNCONFIRMED` | 命中 provisional candidate，但 target workstation 尚未确认 production process name |
| `COLOR_RESET_UIA_UNAVAILABLE` | UIA-v2 未安装或无法初始化 |
| `COLOR_RESET_DOCUMENT_NOT_FOUND` | foreground MedEx window 内未找到 report `Document` |
| `COLOR_RESET_ANCHOR_FONT_SIZE_NOT_FOUND` | 未找到 `16px` anchor |
| `COLOR_RESET_ANCHOR_NUMBER_BUTTON_NOT_FOUND` | 未找到 `①` anchor |
| `COLOR_RESET_INVALID_RECTANGLE` | UIA/window rectangle 非有限数值或没有正 width/height |
| `COLOR_RESET_INVALID_GEOMETRY` | anchor 矩形或相对位置无效 |
| `COLOR_RESET_INVALID_COORDINATE_SPACE` | UIA screen coordinates 与 foreground window/client coordinate space 不一致 |
| `COLOR_RESET_TRIGGER_CLICK_FAILED` | validated trigger click 抛出错误 |
| `COLOR_RESET_MENU_NOT_OPENED` | 点击 trigger 后未检测到颜色菜单 |
| `COLOR_RESET_BLACK_ITEM_NOT_FOUND` | 菜单中未找到 Name 为 `000000` 的项目 |
| `COLOR_RESET_INVOKE_UNAVAILABLE` | Black item 不支持 InvokePattern |
| `COLOR_RESET_INVOKE_FAILED` | 找到黑色项目但 `Invoke()` 失败 |
| `COLOR_RESET_UNEXPECTED_ERROR` | 未预期异常被 adapter boundary 捕获 |

日志可包含：timestamp、action name、result code、executable/process name、anchor rectangles、calculated click coordinates、elapsed timing、retry count，以及在可安全检测时记录的 MedEx version。

日志不得包含患者信息、报告文字或剪贴板内容。

## Architecture boundary

必须保留以下职责分离：

- `clipboard_html.ahk`
  - 只负责通用 `CF_HTML` 构造、剪贴板写入、paste execution 和 clipboard restoration；
- `report_editor.ahk`
  - 负责 editor-level operations，例如插入格式化报告文字和恢复 insertion state；
- MedEx-specific logic
  - 放入专用 MedEx adapter/module，不得混入通用 clipboard module。

该边界必须保留未来对 Word、browser editors 或其他 HIS applications 的支持空间。

## Future investigation

当前 V1 足以进入实现，但以下路线仍是未来 replacement candidate：

- 检查 `resources/app`；
- 确认使用 TinyMCE、Vue、其他 editor framework，还是 Electron IPC；
- 找到最终改变 font color 的 JavaScript command；
- 调查 direct renderer/editor command 能否替代 coordinate clicking。

未来概念路线示例：

```text
executeJavaScript()
→ editor.setColor("#000000")
```

这只是调查方向，不表示 `editor.setColor()` API 当前存在。

## Investigation conclusion

- Current implementation direction: UIA anchors + proportional coordinate positioning + UIA Invoke
- Known limitation: The color dropdown trigger itself is not exposed as a usable UIA element.
- Future replacement candidate: Direct editor command through Electron renderer, IPC, or the embedded editor API.

Status: Investigation complete; V1 implementation approved.
