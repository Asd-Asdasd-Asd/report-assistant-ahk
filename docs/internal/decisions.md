# 决策记录

本文档使用简化 ADR 风格记录关键工程决策。

## Decision 001: 使用 AHK v2 作为初始自动化层

状态：Accepted

背景：当前目标是辅助 Windows 报告书写和阅片窗口，不修改原系统，也不接入数据库。

决策：使用 AutoHotkey v2 作为初始自动化层。

原因：

- 能覆盖热字符串、快捷键、剪贴板、窗口激活和鼠标动作。
- 部署成本低，适合早期内部原型。
- 可以保持在本机辅助层，不绕过系统权限。

影响：

- 需要严格控制坐标动作风险。
- 复杂集成能力有限，未来可能需要重新评估插件或正式接口。

## Decision 002: 保留 legacy 脚本作为历史来源

状态：Accepted

背景：已有两个 legacy 脚本包含可参考的历史行为。

决策：将 legacy 脚本保留在 `legacy/`，不直接删除或覆盖。

原因：

- 便于逐步迁移和对照行为。
- 避免初始化阶段丢失历史经验。

影响：

- 新代码应从 `src/` 开始维护。
- legacy 文件不作为长期运行入口。

## Decision 003: 不默认启用自动提交/审核类动作

状态：Accepted

背景：报告提交、审核、发送等动作具有临床和流程风险。

决策：项目默认不实现、不启用自动最终提交或审核类动作。

原因：

- 必须保留人工确认。
- 避免误触发不可逆流程。

影响：

- 自动化只作为辅助输入和窗口操作。
- 任何高风险动作都必须单独评审。

## Decision 004: 普通用户文档使用中文且假设无软件知识

状态：Accepted

背景：未来使用者可能完全不了解 Git、AHK、脚本、路径或配置文件。

决策：普通用户文档使用中文，并采用简单操作步骤。

原因：

- 降低培训成本。
- 减少误操作。

影响：

- `docs/user/` 不解释复杂工程概念。
- 技术细节放在 `docs/internal/`。

## Decision 005: 坐标动作必须经过本机校准

状态：Accepted

背景：阅片窗口坐标受屏幕、缩放、窗口位置和版本影响。

决策：任何坐标动作必须在本机校准和测试后才能启用。

原因：

- 未校准坐标可能点击错误位置。
- 不同工作站不能假设一致。

影响：

- 坐标配置不能直接跨机器复用。
- 发布前必须进行 Windows 手动测试。

## Decision 006: MedEx 颜色复位采用可替换 adapter V1

状态：Accepted for v0.5.0 internal testing

背景：`CF_HTML` 可以插入红色文字，但 MedEx 会把后续输入保持为红色。颜色菜单黑色项目可通过 UIA `Invoke()` 工作，而 color trigger 本身没有可用 UIA node。

决策：V1 使用 semantic region anchor、dynamic local font anchor、centralized local-offset positioning 和 UIA Invoke，并把实现限制在 MedEx-specific adapter 中。早期 `16px + ①` proportional model 已由 2026-07-14 证据废弃。

影响：

- Generic `clipboard_html.ahk` 不包含 MedEx-specific logic。
- 所有 geometry 或 UIA failure 都 fail-closed。
- Direct renderer/editor command 保持为未来 replacement candidate，不声称当前 API 存在。

## Decision 007: v0.5.0 使用外部 centralized INI config

状态：Accepted for implementation

背景：Hotkeys、built-in hotstring triggers/replacements 和 user-defined hotstrings 需要可配置，同时更新不能覆盖用户配置。

决策：普通用户配置保存在 `%LocalAppData%\MedExAHK\config.ini`，通过 defaults → read → validate → migrate → normalize 的单一 pipeline 加载。

影响：

- Feature modules 不直接调用 `IniRead()`。
- 用户不需要编辑 AHK source。
- User replacement 只作为 data，不作为 executable code。
- JSON 可在未来复杂度需要时通过 versioned migration 重新评估。

## Decision 008: 使用独立 compatibility script 渐进替代 legacy

状态：Accepted for migration planning

背景：新项目尚未覆盖 legacy daily-use functions，直接停用 legacy 会造成能力丢失；直接并行原脚本会产生 hotstring 和 shared-resource conflicts。

决策：原始 legacy 文件保持不变，新增 cleaned compatibility script，只保留新项目尚未完成并验证的功能。

影响：

- 同一个 trigger 只能有一个 active owner。
- 每次新 release 逐项缩减 compatibility，并提供中文 update notes 和 rollback method。
- 在用户确认依赖和新实现 validation 之前，不删除 legacy capability。

## Decision 009: 冻结 field-validated production baseline

状态：Accepted for `0.5.0-alpha.0`

背景：Color Reset V1 已在 MedEx 0.0.1.0、1920×1080、100% scaling 环境完成 automation 和人工最终颜色验证；下一步需要 packaging/configuration，但不能让 production 依赖 field-only paths。

决策：`src/app_metadata.ahk` 作为唯一 app version source；pinned UIA-v2 放在 `src/Lib/` 并由 source、field debug 和 generated release 共用。Production 默认只写 failure-only lightweight diagnostics，完整 schema 只由 explicit field mode 启用。

影响：

- Generated release 可以 self-contained，不依赖 `debug/` 或 global UIA installation。
- Field debug 与 production 不复制 resolver。
- 正式 config/log paths 和 executable packaging 留到下一里程碑。
