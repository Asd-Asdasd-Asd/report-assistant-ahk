# 路线图

版本号用于内部沟通和发布节奏，不代表已经适合科室范围推广。

## 长期发布策略

源码继续采用模块化 AHK v2，并保留可生成的单文件 `.ahk` 作为调试产物。这样便于审查 diff、定位问题，也便于在 Windows 工作站上快速验证。

v0.5.0 内测阶段开始增加 internal-test executable，降低普通用户的安装门槛；`.ahk` release 继续作为维护和诊断产物，不作为普通用户配置入口。

用户配置从 v0.5.0 起放在应用二进制和 source release 之外，并在更新时保留。每次 internal release 必须同时提供简单中文用户说明和中文维护/更新说明。

后续产品化阶段可以再加入完整 tray menu、version display、calibration mode、diagnostics export 和更容易远程支持的工具。

Executable 只改变交付形式，不改变源代码真相来源、配置保存位置或回滚要求。

## v0.1.0 项目初始化

目标：建立可维护的项目骨架。

范围：

- 创建 `src/`、`legacy/`、`docs/`、`scripts/`、`release/`、`tests/`。
- 保留 legacy 脚本。
- 建立最小可运行入口和安全热键。

不做：

- 不完整迁移 legacy 行为。
- 不启用自动提交类动作。
- 不做科室范围发布。

## v0.2.0 文档分层和项目治理

目标：建立维护者文档和普通用户文档。

范围：

- 增加 `docs/internal/`。
- 增加 `docs/user/`。
- 记录架构、路线图、决策、维护流程和发布检查。
- 编写面向普通用户的启动、热键、更新、故障处理和紧急停止说明。

不做：

- 不修改 AHK 功能逻辑。
- 不迁移坐标动作。
- 不改变 release 机制。

## v0.3.0 hotstrings 模块重构

目标：整理文本扩展逻辑，让短语维护更清晰。

范围：

- 梳理 legacy 中稳定、低风险的热字符串。
- 统一命名和组织方式。
- 增加必要的手动测试记录。

不做：

- 不处理复杂富文本。
- 不引入数据库或外部服务。
- 不迁移高风险窗口动作。

## v0.4.0 红色 RTF 剪贴板插入

目标：实现动态 RTF 剪贴板构造，用于插入红色 `（见图）`。

范围：

- 建立剪贴板保存、写入、粘贴、恢复事务。
- 使用 Windows Clipboard API 写入 `Rich Text Format`。
- 同时写入 `CF_UNICODETEXT` 作为兼容格式。
- 替代对固定本地 `.clip` 文件的依赖。
- 失败时明确提示，不静默降级成黑色文本。

不做：

- 不提交真实患者文本样例。
- 不保存敏感剪贴板日志。
- 不自动最终提交报告。
- 不实现 HTML clipboard。

## v0.4.1 调查记录和路线校正

目标：记录 Windows 红字剪贴板测试和 MxNMSoft 现场调查，修正后续路线。

范围：

- 记录 RTF 语法问题和手工最小修复。
- 记录 RTF + `CF_UNICODETEXT` 与 RTF only 的现场行为。
- 将 RTF 红字插入重新分类为 experimental/reference。
- 记录 HTML Clipboard / `CF_HTML` 作为下一步主路径。
- 记录 line measurement 和 SUVMax 的 context-menu 读取发现。
- 明确 SUV 策略从 log-first 改为 current-image context-menu first。

不做：

- 不修改 `src/` 功能代码。
- 不实现 HTML clipboard。
- 不实现 `ContextMeasurementProvider`。
- 不重建 release。

## v0.4.2 HTML Clipboard 红字插入

目标：实现 HTML Clipboard / `CF_HTML` 红色 `（见图）` 插入。

范围：

- 动态构造 `CF_HTML` payload。
- 保留 clipboard save/restore transaction。
- 验证目标报告编辑器是否接受 HTML Clipboard。
- 验证后续输入恢复黑色。
- 增加 UTF-8 byte offset 的平台无关结构测试。
- 移除 RTF 实现的活动运行路径。

不做：

- 不静默 fallback 成黑色文本。
- 不依赖 `red_not.clip`。
- 不加入隐藏格式边界字符或编辑器专用格式重置。
- 不实现测量提取、ZMQ 或 `window.nodeApi` 集成。

## v0.5.0 — Internal Test Foundation

目标：建立能够开始小范围内部测试的安全基础，同时保留 legacy compatibility 作为未迁移功能的临时来源。

Required scope：

1. `CF_HTML` red-text insertion。
2. MedEx insertion-color reset to black。
3. 用户配置独立存放，不与 application binary 或 source release 混合。
4. Configurable hotkeys。
5. Configurable trigger strings for built-in hotstrings。
6. Configurable replacement text for built-in hotstrings。
7. 独立的 fully user-defined hotstrings 区域。
8. 配置缺失或无效时使用 safe defaults。
9. 应用更新不得覆盖 user configuration。
10. Diagnostic logging 足以说明 color reset 或 automation 失败原因，且不记录报告内容。
11. 打包 internal-test executable。
12. 提供简单中文 internal-test user documentation。
13. 每个 internal release 提供中文 maintainer/update notes。

Explicitly deferred，除非已经实现且稳定：

- automatic SUVmax extraction；
- automatic long-axis and short-axis extraction；
- complete settings GUI；
- Electron JavaScript injection；
- automatic updater；
- multi-editor support。

v0.5.0 的 MedEx color reset 采用已批准 V1：UIA anchors + proportional coordinate positioning + UIA Invoke。该方案属于可替换 adapter，不进入 generic clipboard module。

## v0.5.x — Stabilization

目标：处理内测暴露出的环境差异和可靠性问题。

计划范围：

- DPI and display-scaling compatibility；
- resolution and layout variation；
- MedEx version variation；
- timing/retry improvements；
- configuration migration；
- improved diagnostics and failure logging。

每个 stabilizing release 都应缩小 compatibility script，但只有在对应新实现完成并通过工作站验证后才能移除 legacy capability。

## v0.6.0 — Measurement Capture

目标：安全获取当前 annotation 对应的 measurement，不复用旧值，不把 automation failure 当成未标注。

计划范围：

- 从 image-window context menu 自动获取 SUVmax；
- 自动获取 long-axis 和 short-axis；
- annotation 存在时自动使用测量值；
- annotation 不存在时 fallback 到 manual-input hotstrings；
- 结果必须严格区分：
  - `FOUND`；
  - `NOT_ANNOTATED`；
  - `AUTOMATION_FAILED`。

技术自动化失败不等同于“无标注”。`AUTOMATION_FAILED` 不得触发静默的空值或旧值 fallback。

## Later versions

计划范围：

- simple configuration GUI；
- import/export of user configuration；
- automatic update support；
- possible replacement of coordinate interaction with a direct Electron/editor command；
- workstation profiles and calibration；
- 经过逐项验证的其他 viewer actions。

Direct editor command 仍是未来调查方向，当前不声称存在可调用的 embedded editor API。

## 长期安全边界

- 不对外发布未经验证的临床工作流自动化。
- 不替代人工审核和临床判断。
- 不自动最终提交、审核或发送报告。
- 不把患者信息或报告正文写入 diagnostics。
