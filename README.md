# Report Assistant AHK

Report Assistant AHK 是一个私有 AutoHotkey v2 项目，用于 Windows 报告书写和阅片窗口自动化辅助。

## 当前状态

当前冻结基线为 `main` commit `2369b68`（tag `v0.6.0-candidate-g`）。`relativeMousePixelValidated` 已是 production default：UIA 精确定位 `Name="检查所见"`，经过 profile geometry 校验后以相对坐标打开颜色菜单，四点 popup signature 匹配后最多单击一次黑色。`uiaInvoke` 仅保留为显式 comparison/rollback；两种策略之间没有 automatic fallback。

2026-07-16 Windows 现场已验证 generated release、Candidate G black reset、phrase-specific `;fzg` caret workflow 和最终 mainline behavior；promotion 当时记录为 `75 tests passed`。本项目仍是早期内部原型，不适合科室范围推广或无人值守使用。当前 layout 只在 MedEx 0.0.1.0、1920×1080、100% scaling、DPI 96 上完成校准和现场验证。

进程状态不再是“完全未确认”：现场确认的主进程是 `medexworkstations.exe`；代码暂时兼容保留 `medexworkstation.exe`。

## 当前行为边界

- `;red`、`;fwj`、`;fjd`：CF_HTML 红字粘贴、恢复剪贴板，再运行 Candidate G 将后续输入颜色恢复为黑色。
- `;fzg`：phrase-specific no-reset 路径，依次执行 CF_HTML paste、clipboard restore、`Sleep 50`、`Left 4`；不运行 Color Reset。
- `;cmx`：插入 `cm×cm` 并 `Left 2`。
- Production success 不写 heavy log；failure 写 privacy-safe lightweight log；field mode 才写详细 timing、geometry、UIA 和 pixel diagnostics。
- 全局 pause/exit 分别为 `Ctrl+Alt+Esc`、`Ctrl+Alt+Q`。
- 当前 report hotstrings 尚未限制为 MedEx-only；entry-level `#HotIf` guard 是下一轮明确计划，而不是已实现行为。

## 下一开发路线

下一目标是缩短用户可见的关键路径，而不是泛化地缩短函数总运行时间。主要指标是：

```text
TriggerToBlackClickMs = BlackClickSentMs - HotstringTriggeredMs
```

计划按独立检查点推进：基线 timing diagnostics → MedEx-only hotstring scope 与冗余 process check 清理 → 将 clipboard restoration 移到 black click 后并保留安全最小间隔 → 独立验证移除 `;fzg` 的 `Sleep 50` → 独立移除 MedEx version hard gate → 经另行授权后实现本机 layout calibration。

详细顺序、pass/failure 判定以及 Windows 简短结果的续接规则见 `docs/internal/performance-optimization-checkpoints.md`。

## 文档分层

- `docs/internal/`：维护状态、架构、路线图、检查点和发布流程。
- `docs/user/`：普通用户说明、故障处理和紧急停止。
- `docs/technical-investigations/`：有证据边界的技术调查。
- `docs/migration/`：legacy inventory、共存所有权和渐进替代计划。

## 开发原则

- Code and identifiers in English.
- Human-facing documentation in Chinese when appropriate.
- No patient data or credentials.
- No automatic final submission by default.
- Coordinate actions require local calibration and fail-closed checks.
- 不提交患者信息、医院敏感信息、截图、真实内网地址或敏感日志。

## Requirements

- Windows
- AutoHotkey v2
- Target report-writing workstation
- Local calibration for coordinate-sensitive actions

## Repository Layout

```text
legacy/   Preserved historical scripts and compatibility references.
src/      AutoHotkey v2 source modules.
docs/     Maintainer, user, investigation, and migration documentation.
scripts/  Development and release helpers.
release/  Generated single-file release script.
tests/    Static tests and manual workstation checkpoints.
```

## Quick Start for Maintainers

1. 修改 `src/` 或 `docs/`；应用版本只修改 `src/app_metadata.ahk`。
2. 源码变化后运行 `python scripts/build_release.py`；纯文档变化不需要刷新 generated release。
3. 在 Windows 工作站使用 AutoHotkey v2 测试生成文件。
4. 按 `tests/manual-test-checklist.md` 和当前 performance checkpoint 完成验证。

当前状态入口：

- `docs/internal/project-status.md`
- `docs/internal/architecture.md`
- `docs/internal/performance-optimization-checkpoints.md`
- `docs/migration/legacy-feature-inventory.md`
