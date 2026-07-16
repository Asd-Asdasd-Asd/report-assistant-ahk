# Report Assistant AHK

Report Assistant AHK 是一个私有 AutoHotkey v2 项目，用于 Windows 报告书写和阅片窗口自动化辅助。

## 当前状态

当前项目状态：`v0.5.0-alpha.0` field baseline 之后的 reconciled control。红字插入稳定，但 popup UIA black-reset interaction 在 production 重复测试中延迟高且不可靠；下一阶段是在独立分支验证 Candidate G。

这仍然是早期内部原型，不适合科室范围推广或无人值守使用。MedEx 0.0.1.0、1920×1080、100% scaling baseline 已验证红字插入和后续输入恢复黑色；其他显示环境与 MedEx 版本仍待验证，未校准坐标动作仍不得启用。

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

1. 完成 reconciled generated release 的 Windows smoke test
2. Candidate G1：toolbar-row localization、relative geometry 与 popup pixel-signature calibration
3. Candidate G2：受控 relative mouse interaction，并完成重复现场验证
4. 经明确批准后再切换默认 strategy
5. 后续才进入 centralized configuration、legacy migration 与 internal-alpha packaging

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

1. 在本地修改 `src/` 或 `docs/`；应用版本只修改 `src/app_metadata.ahk`。
2. 运行 `python scripts/build_release.py` 生成 `release/report_assistant.ahk`。
3. 在 Windows 工作站上用 AutoHotkey v2 测试生成文件。
4. 按 `tests/manual-test-checklist.md` 完成手动检查。

当前调查结论、legacy inventory 和交接状态分别见：

- `docs/technical-investigations/2026-07-medex-rich-text-color-reset.md`
- `docs/migration/legacy-feature-inventory.md`
- `docs/internal/project-status.md`
