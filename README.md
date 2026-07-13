# Report Assistant AHK

Report Assistant AHK 是一个私有 AutoHotkey v2 项目，用于 Windows 报告书写和阅片窗口自动化辅助。

## 当前状态

当前项目状态：正在准备 `v0.5.0 — Internal Test Foundation`。

这仍然是早期内部原型，不适合科室范围推广或无人值守使用。MedEx 红字插入已经确认可行，插入颜色恢复为黑色的 V1 runtime 已实现但尚待 Windows 工作站验证；未校准坐标动作仍不得启用。

## 文档分层

- `docs/internal/`：维护者中文文档，用于记录架构、路线图、关键决策、维护流程和发布检查。
- `docs/user/`：普通用户中文文档，面向没有软件知识的使用者，强调简单操作和故障处理。
- `docs/technical-investigations/`：有证据、结论和状态边界的正式技术调查。
- `docs/migration/`：legacy inventory、共存所有权和渐进替代计划。
- `docs/*.md`：早期英文技术草稿，暂时保留，后续再决定是否迁移或合并。

## 开发原则

- Code and identifiers in English.
- Human-facing documentation in Chinese when appropriate.
- No patient data.
- No credentials.
- No automatic final submission by default.
- Coordinate actions require local calibration.
- 不提交患者信息、医院敏感信息、账号、截图、真实内网地址或敏感日志。

## 当前开发路线

1. 完成并验证 MedEx insertion-color reset
2. 引入 centralized external user configuration
3. 配置化现有 hotkeys/hotstrings，并支持 user-defined hotstrings
4. 增加 structured diagnostics and logging
5. 以 non-conflicting compatibility script 保留未迁移 legacy 功能
6. 打包 v0.5.0 internal-test executable 并开始小范围内测

## Requirements

- Windows
- AutoHotkey v2
- Target report-writing workstation
- Local calibration for any coordinate-based viewer actions

## Repository Layout

```text
legacy/   Preserved historical scripts plus a separately named compatibility scaffold.
src/      AutoHotkey v2 source modules.
docs/     Documentation for maintainers, users, and early technical drafts.
scripts/  Development helper scripts.
release/  Generated single-file release script.
tests/    Manual workstation test checklist.
```

## Quick Start for Maintainers

1. 在本地修改 `src/` 或 `docs/`。
2. 运行 `python scripts/build_release.py` 生成 `release/report_assistant.ahk`。
3. 在 Windows 工作站上用 AutoHotkey v2 测试生成文件。
4. 按 `tests/manual-test-checklist.md` 完成手动检查。

当前调查结论、legacy inventory 和交接状态分别见：

- `docs/technical-investigations/2026-07-medex-rich-text-color-reset.md`
- `docs/migration/legacy-feature-inventory.md`
- `docs/internal/project-status.md`
