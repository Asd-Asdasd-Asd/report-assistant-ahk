# MedEx Report Assistant：模型工作边界

本文件只记录无法可靠从源码、测试或当前任务本身推导出的项目约束。详细调查和发布清单不在此重复。

## 当前项目

- 这是面向 Windows/MedEx 的 AutoHotkey v2 本地辅助工具，仍属于少量工作站内部验证。
- `src/` 是源码真相；`release/report_assistant.ahk` 是由构建脚本生成的产物，不手工编辑。
- 应用版本的唯一人工来源是 `src/app_metadata.ahk`。
- 用户配置位于 `%LocalAppData%\\MedExReportAssistant\\config.ini`，替换 EXE 不得覆盖或删除用户配置。
- 发布物是 portable single-EXE；当前不提供 installer、self-update、shortcut、registry installation state、rollback 或历史 EXE 清理。

## 当前实现边界

- Viewer 测量目标由 `MxNMContextTargetSessionProvider` 发现并验证；旧的 config-only 几何路径不是当前 production 入口。
- 测量、Viewer 快捷键和颜色恢复都必须在目标窗口、进程、owner、控件或几何证据不唯一时停止，不猜测、不盲点、不自动重试。
- 现场 Windows/MedEx 验证是运行时行为的最终证据；Python 静态测试和 generated release 不能替代它。
- `legacy/` 只作为历史参考或尚未迁移功能的兼容来源，不是新功能的默认实现入口；同一 trigger 只能有一个 active owner。

## 不可违反的安全边界

- 不访问数据库，不绕过权限，不自动提交、审核或发送报告；保留人工确认。
- Clipboard 操作必须事务性保存和恢复；不得复用旧测量值，也不得把缺失值解释成阴性结果。
- 诊断日志只记录必要的、隐私安全的结构化信息；不得写入患者信息、报告正文、clipboard payload、凭据、截图或真实医院信息。
- 坐标或界面动作必须经过目标工作站验证，不能把一个机器的绝对坐标当作通用配置。
- 不自动终止、替换、备份、清理或回滚其他 EXE、用户配置、legacy 脚本或人工工作流。

## 工作方式

- 修改前先检查 `git status --short`，保留用户已有改动，不覆盖无关文件。
- 诊断、调查和规划不等于实现授权；只有用户明确要求修改时才改代码或删除内容。
- 优先读取当前源码和测试；按需读取 `docs/technical-investigations/`、`docs/field-tests/` 和 `experiments/`，其中的候选方案、历史调用链和未验证结论不得直接当作当前 production 行为。
- 修改 source 后运行相关测试并按需运行 `python3 scripts/build_release.py`；不要为了纯文档修改重写 generated release。
- Windows 构建和 MedEx 现场验收不能在 macOS 上假设完成。

## 关键入口

- 当前状态：`docs/internal/project-status.md`
- 当前架构与安全边界：`docs/internal/architecture.md`
- 日常维护与发布：`docs/internal/maintenance.md`、`docs/internal/release-checklist.md`
- 用户文档：`docs/user/`、`assets/publish/`
- 历史调查：`docs/technical-investigations/`、`docs/field-tests/`、`experiments/`
