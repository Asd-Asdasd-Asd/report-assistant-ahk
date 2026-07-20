# Internal Release 检查清单

发布前逐项确认。

## Current mainline baseline

- [x] `2369b68` / `v0.6.0-candidate-g` 已将 `relativeMousePixelValidated` 提升为 production default。
- [x] `uiaInvoke` 仅为显式 comparison/rollback，不存在 automatic fallback。
- [x] 现场确认主进程为 `medexworkstations.exe`；`medexworkstation.exe` 仅暂作 compatibility candidate。
- [x] Final generated release 已覆盖 Candidate G reset、phrase-specific no-reset `;fzg` 和 immediate punctuation；promotion 记录为 `75 tests passed`。
- [ ] 当前环境重新运行 Python tests；若缺少 `pytest`，记录为“本次未独立重跑”，不得改写为“mainline 从未测试”。

## Next performance checkpoints

- [ ] Step 1：只增加 timing fields 和两个 derived metrics，不改 ordering/waits；Windows baseline 通过后才提交。
- [ ] Step 2：给五个 report hotstrings 加 shared MedEx-only entry guard；arrow/black click 前保留 active HWND checks；Windows scope/foreground test 通过后才提交。
- [ ] Step 3：black click 前置、clipboard restoration 后置；`finally` 和基于 `pasteSentAt` 的 minimum interval 必须覆盖 success 与 fast-failure；两条 Windows path 都通过后才提交。
- [ ] Step 4：独立删除 `;fzg` `Sleep 50`；caret 与 immediate typing 通过才提交；始终保持 `Left 4`。
- [ ] Step 5：独立删除 exact MedEx-version hard gate，version 保留在 diagnostics；不得声称因此支持其他 DPI/layout。
- [ ] Step 6：per-machine calibration 只在 latency work 稳定且另行授权后开始。

每一步的 failure category 和下一动作以 `performance-optimization-checkpoints.md` 为准。

- [ ] 确认版本 scope 与 `docs/internal/roadmap.md` 一致，没有混入 deferred features。
- [ ] 确认 `src/app_metadata.ahk` 是唯一人工维护的 application version source。
- [ ] 运行 automated/reference tests。
- [ ] 运行 `python scripts/build_release.py`。
- [ ] 检查 `release/report_assistant.ahk` 是否生成。
- [ ] 检查 generated release 已包含 pinned UIA dependency，且不依赖 `debug/Lib`、source tree 或开发机 absolute paths。
- [ ] 检查 generated release 使用 UTF-8 without BOM，完整文件中 U+FEFF count 为 0。
- [ ] 在 Windows 上直接用目标 AutoHotkey v2 启动 generated `.ahk`，确认无 parser/startup error；静态扫描不能替代本步骤。
- [ ] Windows smoke test 前完全退出所有 release、legacy 和 field-debug AHK instances；测试期间一次只运行一个脚本。
- [ ] 记录实际启动的 `release/report_assistant.ahk` 路径和 SHA-256，避免把 stale NAS/local copy 当作当前生成物。
- [ ] 分别在 release-only 与 debug-only 状态测试；确认 field-debug 不注册 production hotstrings，Step 1 F11 通过 shared `RunRedInsertion()` 调用 Candidate G production dispatcher。
- [ ] 从 source truth 生成 internal-test executable，不手改生成产物。
- [ ] 检查 executable/source release 不包含真实 `config.ini`、日志或 patient data。
- [ ] 确认更新流程不会覆盖 `%LocalAppData%\MedExAHK\config.ini`。
- [ ] 将 release artifacts 复制到 Windows 测试工作站。
- [ ] Windows 上启动新项目和经过批准的 compatibility script；确认原始 legacy instances 已退出。
- [ ] 测试 Ctrl+Alt+Q 紧急退出。
- [ ] 测试 Ctrl+Alt+Esc 暂停/恢复。
- [ ] 测试 `;cmx`。
- [ ] 测试 `;red` 不破坏剪贴板。
- [ ] 测试 `;red` 插入红色文字后，后续输入恢复黑色。
- [ ] 测试 wrong process、missing anchors、invalid geometry、menu timeout、missing black item 和 Invoke failure 全部 fail-closed。
- [ ] 检查 production success 不写 heavy field log；failure-only log 不含 geometry dump、报告文字或 clipboard content。
- [ ] 检查 explicit field mode 仍能输出完整 privacy-safe diagnostic schema。
- [x] Candidate G promotion 所需的 Windows controlled interaction、caret-order 和最终 generated-release mainline validation 已完成；后续 optimization checkpoint 仍需各自独立 reliability test。
- [x] Candidate G2 promotion 前单独运行 `debug/medex_candidate_g2_test.ahk`，完成 controlled interaction 与 caret-order validation；未与 generated release 同时运行。
- [x] 确认 generated release 的 default strategy 为 `relativeMousePixelValidated`，`uiaInvoke` 仅能通过显式 override 使用，且不存在 cross-strategy automatic fallback。
- [x] 2026-07-16 在目标 Windows supported profile 上完成最终 generated-release mainline validation。
- [ ] 确认 source、F11 harness 与 generated release 的 cursor restore request 均为 `Left 4`；若视觉位置不符，先验证 focused element，不使用任意额外 Left 补偿。
- [x] 当前 `;fzg` no-reset → `Sleep 50` → `Left 4` production flow 已完成最终 generated-release validation；Step 4 cleanup 尚未实现。
- [ ] 检查没有自动提交、自动审核或自动最终发送功能。
- [ ] 检查 new/compat hotkeys 和 hotstrings 没有重复注册。
- [ ] 检查 compatibility 保留项、移除项和 rollback method 与本 release 中文维护说明一致。
- [ ] 在目标 DPI、display scaling、resolution 和 MedEx version 上完成验证。
- [ ] 更新 `CHANGELOG.md`。
- [ ] 编写本 release 的中文 maintainer/update notes。
- [ ] 更新简单中文 internal-test user instructions。
- [ ] 创建 git tag。
- [ ] 上传经过验证的 internal release artifacts；不上传 user config、logs 或 legacy local data。
