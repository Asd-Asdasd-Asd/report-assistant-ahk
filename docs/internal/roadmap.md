# 路线图

版本号用于内部沟通和发布节奏，不代表已经适合科室范围推广。

## 长期发布策略

短期阶段继续采用模块化 AHK 源码加生成单文件 `.ahk` release 的方式。这样便于快速调试、审查 diff、定位问题，也便于在 Windows 工作站上直接验证。

内部试点阶段可以将 `.ahk` release 与离线 AutoHotkey v2 installer/runtime 一起分发，降低普通用户的安装门槛，同时仍保留脚本可读性和快速迭代能力。

稳定科室发布阶段再考虑 portable `.exe` package、外部配置文件和完整中文用户文档。`.exe` 有利于降低使用门槛，但会增加调试、回滚和问题定位成本。

后续产品化阶段可以再加入 tray menu、version display、calibration mode、logging、diagnostics export 和更容易远程支持的工具。

当前不应过早切换到 exe，因为调试和快速迭代仍然比包装形式更重要。

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

## later ContextMeasurementProvider core

目标：建立 MxNMSoft context-menu 测量读取 provider。

范围：

- 实现 popup 打开、命令查找、clipboard 读取和结果结构。
- 动态识别 popup 和控件，不硬编码 runtime HWND/PID。

## later line-axis context-command parser

目标：解析 `复制直线测量值` 的 clipboard 输出。

范围：

- 支持 `cm` / `mm`。
- 支持 `×`、`x`、`X`、`*`、`＊`。
- 输出 structured line axes。

## later SUVMax context-command parser

目标：解析 `复制SUVMax值` 的 clipboard 输出。

范围：

- 读取当前图像 context-menu 的 SUVMax。
- 格式化为报告需要的数值。
- 不自动使用最后一条 log 作为 fallback。

## later safe manual fallback

目标：自动读取失败时回到人工输入流程。

范围：

- 明确失败提示。
- 不插入旧值。
- 不要求用户重启 MxNMSoft。

## later centralized user-editable hotstrings and hotkeys

目标：集中管理可编辑 hotstrings 和 hotkeys。

范围：

- 设计外部配置格式。
- 保留安全默认值。
- 避免普通用户直接修改源码。

## later workstation profiles and calibration

目标：支持工作站 profile、coordinate/control calibration。

范围：

- 保存本机校准结果。
- 区分工作站差异。
- 避免跨机器误用坐标。

## v0.5.0 坐标表集中管理和窗口校验

目标：让坐标动作可配置、可校准、可测试。

范围：

- 集中管理 coordinate map。
- 加强 `window_guard.ahk`。
- 为每个坐标动作建立本机校准记录要求。

不做：

- 不默认启用未校准动作。
- 不假设不同工作站坐标一致。

## v0.6.0 阅片动作迁移

目标：逐步迁移低风险、高频阅片动作。

范围：

- 从 legacy 中选择单个动作迁移。
- 为每个动作增加窗口校验和失败提示。
- 在 Windows 工作站手动验证。

不做：

- 不一次性迁移全部点击序列。
- 不迁移可能造成不可逆操作的动作。

## v0.7.0 单文件 release 和 Windows 手动测试

目标：形成可重复发布和测试流程。

范围：

- 改进 `scripts/build_release.py`。
- 生成单文件 `release/report_assistant.ahk`。
- 完善 Windows 手动测试清单。

不做：

- 不制作安装器。
- 不自动更新用户工作站。

## v1.0.0 科室内测稳定版

目标：达到小范围内部试用的稳定度。

范围：

- 完成核心 hotstrings。
- 完成可靠的剪贴板富文本插入。
- 完成经过校准的少量阅片动作。
- 具备普通用户文档和维护者发布流程。

不做：

- 不对外发布。
- 不开放源码分发。
- 不替代人工审核和临床判断。
