# v0.5.x 临时共存与渐进迁移计划

## 目标运行模型

迁移期间同时运行两个独立进程：

1. 新的 v0.5.0 internal-test executable，负责已经完成并验证的新项目功能。
2. 清理后的 `legacy/medex_legacy_compat.ahk`，只负责新项目尚未覆盖的日常功能。

原始 `legacy/karabiner.ahk` 和 `legacy/string_change.ahk` 保持不变，作为行为参考和紧急回退来源。兼容脚本不是原文件的替换编辑。

## 激活规则

| Capability | Coexistence owner | Activation condition |
| --- | --- | --- |
| `;cmx` | 新项目 | 源码行为已对齐；Windows 回归通过 |
| `;red`、`;fzg`、`;fwj`、`;fjd` | 新项目 current mainline；legacy duplicate 必须停用 | Candidate G、template plan 与 MedEx-only entry guard 已实现；release smoke test 仍必需 |
| RAlt+H/J/K/L | 新项目 | 将 `GlobalHjklArrows` 设为 `true`；compatibility 不再注册这四个按键 |
| Legacy viewer/annotation hotkeys | compatibility | 用户确认仍需要，且未被新项目逐项验证替代 |
| Shift+Alt+R snapshot save | 原 legacy only，compatibility 不启用 | 只为旧 `red_not.clip` 流程服务；新项目验证后退役 |
| Ctrl+Alt+Esc / Ctrl+Alt+Q | 新项目 | 注意它们不控制 compatibility 进程 |

2026-07-16 Candidate G generated release 已在 baseline workstation 完成验证并成为 production mainline。v0.5.0 现已具备 portable package、Schema 2 configuration、Settings UI 和 MedEx-only hotstring guard；正式内测前仍需按 release checklist 完成 clean-build 与 coexistence smoke test。Legacy duplicate report hotstrings 必须保持停用。

## 进程与启动顺序

建议内测启动顺序：

1. 退出原始 `karabiner.ahk` 和 `string_change.ahk` 的运行实例。
2. 启动 v0.5.0 internal-test executable。
3. 确认新项目启动提示和版本。
4. 启动 `medex_legacy_compat.ahk`。
5. 在无患者信息的测试区域执行 release checklist。

禁止同时运行原始 legacy scripts 和 compatibility script。这样做会重新引入重复 hotstrings、重复 hotkeys 和不可辨识的 tray 进程。

## 冲突控制

### Hotstrings

同一个 trigger 只能由一个进程注册。Compatibility 中不注册 `;red`、`;fzg`、`;fwj`、`;fjd`、`;cmx`。如需临时改回人工或 legacy workflow，必须先退出新项目实例，不能让两套同名 triggers 并行注册。

### Hotkeys

Compatibility 已移除 RAlt+H/J/K/L；与 EXE 同时运行时，这四个方向键只由新项目注册。需要该功能时必须将 `GlobalHjklArrows=true`；保持 `false` 时两个进程都不会提供这四个方向键。该 navigation 保持 global；后续 MedEx/MxNMSoft 动作仍应增加 `#HotIf` 或等价窗口范围，并由外部 config 控制是否注册。

### Clipboard

当前两个进程没有跨进程 clipboard lock。临时操作规则：

- 新项目进行红字插入时，不触发 compatibility 的 Shift+Alt+S。
- compatibility 正在执行 Ctrl+C/Ctrl+V 传递时，不触发新项目 hotstrings。
- 新项目 color reset 不得延长或改变 `WithClipboardRestore()` 的 clipboard contract。

v0.5.x 应评估 named mutex 或轻量跨进程 busy marker，但只有在 compatibility 确实需要继续使用 clipboard workflow 时引入。

### Mouse and coordinates

Compatibility 保留的坐标动作仍是高风险 legacy behavior：固定 screen coordinates、缺少窗口校验，且部分流程不恢复鼠标位置。用户触发一个动作后必须等它结束，再触发另一个动作。不得在 geometry/window validation 失败后添加补偿性 blind click。

## Tray 与紧急停止

- 新项目的 `Ctrl+Alt+Esc` 只暂停新项目。
- 新项目的 `Ctrl+Alt+Q` 只退出新项目。
- Compatibility 需要从其独立 tray icon 退出；scaffold 使用不同的 tray tooltip 帮助辨认。
- 如果出现异常鼠标动作，应先停止输入并分别退出两个进程；不要假设暂停一个进程会停止另一个。

## 临床文字保护

每次所有权切换前，必须逐项记录和验证：

- replacement phrase 的每一个可见字符；
- 中文/英文括号形式；
- 红色范围；
- 光标最终位置；
- 后续输入颜色；
- paste failure 时的光标行为；
- 原剪贴板是否恢复。

仓库中没有 `red_not.clip` 内容，不能假设 legacy snapshot 与新 `CF_HTML` 输出完全一致。任何差异必须由用户确认，不能静默改变医疗报告文字。

## 逐版本缩减 compatibility

1. v0.5.0：新项目接管经过验证的报告 hotstrings；随后由新项目 `GlobalHjklArrows` 接管 RAlt+H/J/K/L，compatibility 只保留其余未迁移 viewer actions。
2. v0.5.x：逐项加入 window guard、DPI/layout validation、retry 和 diagnostics；每迁移并验证一个动作，就从下一版 compatibility 中禁用一个动作。
3. v0.6.0：测量读取采用 structured states；验证后才考虑替代相关 legacy measurement hotkeys。
4. Later：扩展 Settings 的占位页，评估更新支持及必要的 direct editor command；compatibility 清空后归档，不删除原始 legacy reference。

每次缩减必须在 Chinese maintainer/update notes 中写明：移除了哪个 compatibility capability、由哪个新模块接管、验证结果，以及出现问题时如何停止测试并恢复人工 workflow。

## 停止测试原则

- 同时退出新项目和 compatibility 进程。
- 不覆盖用户配置。
- 不删除原始 legacy scripts 或 `red_not.clip` 用户副本，直到用户明确确认不再需要。
- 应用不查找、备份、替换或恢复其他 EXE；是否保留历史文件不属于应用职责。

## 启用 compatibility scaffold 前的用户确认

需要继续确认或验证以下 legacy 行为的迁移条件：

- Shift+Alt+B/H/L 三组固定数值流程；
- Shift+Alt+S 快速标图；
- Ctrl+Win+Shift+S/M/A/C；
- SUV 3 秒复按与 Arrow 1 秒复按的“清除”语义是否必须原样保留。

XButton1 notification 是历史测试项，不属于正式 compatibility 功能；除非发现实际 hotkey conflict，否则忽略。
