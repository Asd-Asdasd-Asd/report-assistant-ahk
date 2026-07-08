# Report Assistant AHK

Report Assistant AHK 是一个私有 AutoHotkey v2 项目，用于 Windows 报告书写和阅片窗口自动化辅助。

## 当前状态

当前项目状态：early personal prototype。

这仍然是早期个人原型，不适合直接科室范围推广，不适合无人值守使用，也不适合在未校准的工作站上启用坐标类动作。

## 文档分层

- `docs/internal/`：维护者中文文档，用于记录架构、路线图、关键决策、维护流程和发布检查。
- `docs/user/`：普通用户中文文档，面向没有软件知识的使用者，强调简单操作和故障处理。
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

1. 文档与安全边界
2. hotstrings 重构
3. clipboard / red text 重构
4. coordinate map and viewer action migration
5. release packaging
6. internal pilot

## Requirements

- Windows
- AutoHotkey v2
- Target report-writing workstation
- Local calibration for any coordinate-based viewer actions

## Repository Layout

```text
legacy/   Historical AutoHotkey scripts kept unchanged.
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
