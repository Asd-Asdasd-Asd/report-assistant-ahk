# Legacy 与新项目功能清单

更新日期：2026-07-13

本清单依据原始 legacy scripts、新项目源码以及 `debug/legacy-automation-survey-2026-07-13/` 的现场记录编写。名称相似不代表功能等价；业务语义已由现场记录确认时单独注明，实现可靠性仍需逐项验证。

## 状态定义

- 已迁移：新项目存在完整实现，且行为边界与 legacy 一致；仍可能需要 Windows validation。
- 部分迁移：已有新实现，但关键行为不同、缺失或尚未验证。
- 未迁移：新项目只有 placeholder 或完全没有对应实现。
- Legacy support：共存期由兼容脚本继续提供。

## 功能对照

| Feature | Legacy location | New-project location | Migration status | User dependency | Conflict risk | Recommended action | Target version |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 红色 `（见图）` 插入：`;red` | `legacy/string_change.ahk:4-12` → `InsertRedText()` → `red_not.clip`；随后点击固定坐标恢复黑色 | `src/hotstrings.ahk:1-4` → `InsertRedFigureTextAndRestoreState()` → dynamic `CF_HTML` → validated Color Reset V1 | 已迁移到 production source；2026-07-15 baseline workstation 已验证，仍待 packaged coexistence smoke test | 高 | 两个脚本注册同名热字符串，会重复触发或争抢触发；两种剪贴板路径也可能重叠 | internal-alpha coexistence 时禁用 legacy duplicate，只启用新实现；保留旧组合用于 rollback | v0.5.0 |
| 增高短语：`;fzg` | `legacy/string_change.ahk:15-22`；固定短语 + `InsertRedText()` + 50 ms + Left 4 | `src/hotstrings.ahk:6-11`；相同固定短语 + `PasteRedFigureText()` 成功后 Left 4 | 部分迁移：文本和光标位移相同；富文本来源、sleep 和成功条件不同 | 高 | 同名热字符串直接冲突 | 保留新实现作为目标；Windows 验证红字、光标位置和失败分支后停用 legacy | v0.5.0 |
| 未见明显增高短语：`;fwj` | `legacy/string_change.ahk:25-31` | `src/hotstrings.ahk:13-17` | 部分迁移：可见固定短语相同；富文本来源不同 | 高 | 同名热字符串直接冲突 | 完成 MedEx color reset 后验证完整输出，只保留新实现 | v0.5.0 |
| 摄取降低短语：`;fjd` | `legacy/string_change.ahk:34-40` | `src/hotstrings.ahk:19-23` | 部分迁移：可见固定短语相同；富文本来源不同 | 高 | 同名热字符串直接冲突 | 完成 MedEx color reset 后验证完整输出，只保留新实现 | v0.5.0 |
| 尺寸模板：`;cmx` | `legacy/string_change.ahk:43-48`；`cm×cm` + Left 2 | `src/hotstrings.ahk:25-29`；`cm×cm` + Left 2 | 已迁移（源码行为一致；仍需目标环境回归） | 高 | 同名热字符串直接冲突 | 共存时禁用 legacy 版本，只保留新实现 | v0.5.0 |
| Legacy clipboard snapshot 载入 | `legacy/string_change.ahk:51-67`，读取 `D:\AutoHotKey\red_not.clip` | `src/clipboard_html.ahk` 动态构造 `CF_HTML` | 已被替代，但现场等价性未完全验证 | 旧流程可能依赖 | 同时运行会争用系统剪贴板；legacy 恢复紧接 `Send("^v")`，没有显式 paste completion wait | v0.5.0 验证后不纳入兼容脚本；原文件继续保留作参考 | v0.5.0 |
| 保存 `red_not.clip`：Shift+Alt+R | `legacy/karabiner.ahk:198-204` | 无；新项目不需要 snapshot | 不迁移，目标架构已弃用 | 仅旧红字流程需要 | 固定路径删除/覆盖；与新 clipboard transaction 并行时可能保存临时 payload | 不放入目标兼容脚本；在新 color reset 验证前，不删除用户现有旧流程 | v0.5.0 后退役 |
| RAlt+H/J/K/L 方向移动 | `legacy/karabiner.ahk:3-6` | 无 | 未迁移 | 高；已确认是全局 HHKB navigation | 无新项目同键冲突；全局生效 | compatibility 保留；M2 迁入独立 navigation module，不加 MedEx `#HotIf` | v0.5.0 M2 |
| Shift+Alt+B Body montage | `legacy/karabiner.ahk:40-62` | `src/viewer_actions.ahk` 只有 placeholder | 未迁移 | 高；参数已确认 | 固定 screen coordinates、无 window guard、无 mouse restore | compatibility 暂留；未来参数化，Body=`8.5/8/0.8` | M4 |
| Shift+Alt+H Head montage | `legacy/karabiner.ahk:64-86` | placeholder only | 未迁移 | 高；参数已确认 | 同上 | compatibility 暂留；Head=`4/11/1.2` | M4 |
| Shift+Alt+L Lung montage | `legacy/karabiner.ahk:88-112` | placeholder only | 未迁移 | 高；参数及 lung-window reset 已确认 | 同上；遗漏 window reset 会改变报告图表现 | compatibility 暂留；Lung=`7.5/23/0.9` 并显式恢复 lung window | M4 |
| Shift+Alt+S caption + advance | `legacy/karabiner.ahk:114-124`；Ctrl+C → caption → Ctrl+V → MouseMove → WheelDown | 无 | 未迁移 | 高；无需额外 click 已确认 | 不保存/恢复剪贴板；可能与 CF_HTML transaction 冲突 | compatibility 保留；迁移时验证 empty copy、commit semantics、WheelDown equivalence 和 mouse restore | M4 |
| Viewer screenshot | `legacy/karabiner.ahk:126-132` | 无 | 未迁移 | 高频；官方 F12 已确认可靠 | command sent 不等于截图成功 | compatibility 保留；M3 使用 F12，反馈只能表示 command sent | M3 |
| Ctrl+Win+Shift+M SUV activate/clear | `legacy/karabiner.ahk:134-156` | 无 | 未迁移 | 高频；3000 ms repeat semantics 已确认 | local timing state 可与应用状态失同步 | compatibility 保留；M3 保留 distinct tab/clear control，失败、超时、window/process change 时清 state | M3 |
| Ctrl+Win+Shift+A Arrow activate/clear | `legacy/karabiner.ahk:158-180` | 无 | 未迁移 | 高频；1000 ms repeat semantics 已确认 | 同上 | compatibility 保留；不得与 SUV clear control 合并 | M3 |
| Ctrl+Win+Shift+C cover images | `legacy/karabiner.ahk:182-196` | 无 | 未迁移 | 高价值；左 MIP/右 coronal sectional/fusion 已确认 | 多个固定坐标、无 window guard；中途失败仍继续 | compatibility 保留；保持独立于 montage，M4 逐步校验并 fail closed | M4 |
| Copy SUVMax | 现场 context menu Name=`复制SUVMax值` | 仅调查文档 | 未迁移 | 计划功能 | `SUVMax: 0.000` 仍会更新 clipboard，不能当作 meaningful ROI | M3 使用 named Button/Invoke 和 sentinel；区分 zero value 与 automation failure | M3 |
| Copy line measurements | 现场 context menu Name=`复制直线测量值` | 仅调查文档 | 未迁移 | 计划功能 | no-line 可能不更新 clipboard；第四条及以后忽略 | M3 保持创建顺序，区分 no update、valid、unexpected 和 invoke failure | M3 |
| 紧急暂停/恢复 | 无 | `src/main.ahk:14-23`，Ctrl+Alt+Esc，`#SuspendExempt` | 新项目新增 | 高 | legacy 脚本是独立进程；暂停新项目不会暂停 legacy compatibility | 共存文档明确两个进程的边界；兼容脚本暂不新增冲突热键 | v0.5.0 |
| 紧急退出 | 无 | `src/main.ahk:25-28`，Ctrl+Alt+Q | 新项目新增 | 高 | 只退出新项目，不会退出 legacy compatibility | 用户文档必须说明需从 tray 单独退出兼容脚本 | v0.5.0 |
| 窗口校验 | legacy 坐标动作无校验 | `src/window_guard.ahk` 可激活配置的进程，但当前 viewer placeholder 未调用实际动作 | 部分基础设施 | 高 | legacy 可在错误窗口 blind click；新旧并行不会共享 guard | compatibility 暂保留但标红风险；迁移每个动作时加入专用 guard | v0.5.x |
| 鼠标位置恢复 | 多数 legacy 动作手工保存/恢复；Shift+Alt+B/H/L 不恢复；颜色复位固定坐标后恢复 | `WithMouseRestore()` 可恢复，但尚未用于实际 viewer workflow | 部分基础设施 | 中 | 两脚本同时移动鼠标时最终位置不可预测 | 禁止并发触发；迁移时统一 transaction boundary | v0.5.x |
| 用户配置 | 通过直接改 legacy 源码中的坐标、数值和热键 | `config.example.ahk` + optional `config.local.ahk`，但 hotkeys/hotstrings 仍硬编码，若干 config keys 未被消费 | 部分基础设施 | 高 | 两个进程各自有配置和硬编码状态，无法统一禁用冲突项 | v0.5.0 引入 centralized normalized config；compatibility 使用显式 feature switches | v0.5.0 |
| MedEx process name | Legacy report hotstrings 不校验进程 | `src/config.example.ahk` 当前为 `medexworkstation.exe`；调查确认目标为 `medexworkstations.exe` | 配置不一致 | 高 | 单数/复数不一致会让 guard 或 color reset 错误拒绝目标窗口；模糊匹配又可能误认进程 | V1 使用确切、normalized foreground process match，并在 Windows 上确认实际 executable name 后更新默认配置 | v0.5.0 |
| 启动与单实例 | 两个 legacy 文件均无 `#SingleInstance`，也无启动提示 | 新项目 `#SingleInstance Force`，启动时 Tooltip | 部分迁移 | 中 | 可同时产生多个 legacy 进程；新项目只约束自身同名实例 | compat scaffold 使用 `#SingleInstance Force`；启动时明确脚本身份 | v0.5.0 |
| Tray/menu | legacy 使用 AHK 默认 tray；无自定义 menu | 新项目也使用 AHK 默认 tray；无自定义 menu | 未定制 | 中 | 同时运行会出现多个相似 AHK tray icons，用户可能退出错误进程 | compat scaffold 设置不同 tray tooltip；v0.5.x 考虑清晰 menu/status | v0.5.x |
| Diagnostic logging | 无 | 无；只有 Tooltip/Beep | 未实现 | 高（内测定位问题需要） | 无日志时难以区分新项目失败还是 legacy 点击失败 | 只记录非临床元数据和结构化 result code | v0.5.0 |

## 热键与热字符串冲突结论

### 已确认的直接冲突

以下 5 个 hotstrings 在 `legacy/string_change.ahk` 和新项目中完全同名，不能在共存模式中同时保持启用：

```text
;red
;fzg
;fwj
;fjd
;cmx
```

当前新项目 hotkeys `Ctrl+Alt+Esc` 和 `Ctrl+Alt+Q` 与 `legacy/karabiner.ahk` 中的 active hotkeys 没有字面冲突。

Legacy 中的 XButton1 notification 是历史测试项，不属于正式功能、用户依赖或迁移范围。除非后续发现它与实际 hotkey 注册冲突，否则不建立模块、测试或迁移任务。

### 行为差异，不得静默处理

- Legacy 红字内容来自仓库外的 `D:\AutoHotKey\red_not.clip`。该 binary snapshot 不在仓库内，因此仅凭源码不能证明其可见文字、括号形式、字体属性与新项目的 `（见图）` 完全相同。
- Legacy 只有 `;red` handler 在粘贴后执行固定坐标黑色复位；`;fzg`、`;fwj`、`;fjd` 自身没有调用该复位点击。
- Legacy `;fzg` 固定等待 50 ms 后总是 Left 4；新项目只在 paste dispatch 返回成功后 Left 4。
- 新 clipboard transaction 在 paste 后等待并恢复 `ClipboardAll()`；legacy 在发送 paste 后立即恢复，时序契约不同。
- Legacy Shift+Alt+S 使用 Ctrl+C/Ctrl+V 传递当前选择，但不恢复此前剪贴板；新 clipboard module 会保存和恢复剪贴板。

## 共享状态与并行运行风险

- 两个 AHK 进程不共享 `LastPressSUVTime`、`LastPressArrowTime`、suspend state 或配置对象。
- 所有 active legacy hotkeys/hotstrings 都是 global；没有 `#HotIf` window scoping。
- 系统剪贴板和鼠标是跨进程共享资源，但当前没有 mutex、busy flag 或跨进程 lock。
- 新项目 `Ctrl+Alt+Esc` 只暂停新项目。兼容脚本仍可响应热键并执行固定坐标动作。
- 当前 sample config 的 `medexworkstation.exe` 与调查确认的 `medexworkstations.exe` 不一致；不能在实现时静默忽略。
- 默认 AHK tray icons 外观相似。没有明确 tooltip/menu 时容易误判哪个进程仍在运行。
- Legacy 的定时行为依赖 `A_TickCount`：SUV 复按阈值为 3000 ms，Arrow 复按阈值为 1000 ms。迁移时不能把它们当作普通单击动作。

## 当前迁移结论

新项目已覆盖 5 个报告文本入口，但除 `;cmx` 外，其他 4 个仍依赖尚未实现的 MedEx insertion-color reset 才能视为完整迁移。所有 active `legacy/karabiner.ahk` 阅片/键盘行为在新项目中均未迁移。

在用户确认各 legacy 功能的真实日常依赖之前，兼容脚本应保守保留 `legacy/karabiner.ahk` 的 active behavior；只移除已经确认与新项目重复的 5 个 hotstrings，以及仅服务于已弃用 clipboard snapshot 路径的 Shift+Alt+R。
