# Internal Release 检查清单

发布前逐项确认。

## Current mainline baseline

- [x] `2369b68` / `v0.6.0-candidate-g` 已将 `relativeMousePixelValidated` 提升为 production default。
- [x] `uiaInvoke` 仅为显式 comparison/rollback，不存在 automatic fallback。
- [x] 现场确认主进程为 `medexworkstations.exe`；`medexworkstation.exe` 仅暂作 compatibility candidate。
- [x] Final generated release 已覆盖 Candidate G reset、phrase-specific no-reset `;fzg` 和 immediate punctuation；promotion 记录为 `75 tests passed`。
- [x] 当前环境重新运行 Python tests；Step 5 working tree 为 `89 tests passed`。

## Next performance checkpoints

- [x] Step 1：只增加 timing fields 和两个 derived metrics，不改 ordering/waits；Windows baseline 通过并由 `87dce53` 提交。
- [x] Step 2：五个 report hotstrings 已加入 shared MedEx-only entry guard；active HWND checks 保留，Windows scope/foreground test 已通过。
- [x] Step 3：black click 前置、clipboard restoration 后置；300 ms minimum interval 已通过 success/fast-failure Windows paths，并由 `6c2e2dc` 提交。
- [x] Step 4：已独立删除 `;fzg` `Sleep 50`；Windows 验收通过并由 `5193403` 提交。
- [x] Step 5：runtime/calibration exact-version gate 已移除，version 保留在 diagnostics；G1/G2 metadata-override、人工 immediate-black 与 generated-release 验收通过，不得声称因此支持其他 DPI/layout。
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
- [ ] Windows 构建机已安装 AutoHotkey v2 与 Ahk2Exe；双击根目录 `Build EXE.cmd` 后窗口保持打开并明确报告结果。
- [ ] 确认最终 artifact 为 `publish\麦旋风.exe`，文件非空且修改时间属于本轮成功构建。
- [ ] 确认 `assets/publish/首次使用.md` 与 `assets/publish/配置指南.md` 已同步到 `publish/`；构建没有审核或删除其他手工文档、图标。
- [ ] 连续构建两次，确认 final 被干净替换，且没有遗留 `麦旋风.building.exe` 或 `麦旋风.previous.exe`。
- [ ] 临时改错 compiler path，确认构建以非零退出码失败、清理 `.building.exe`，并保留构建前 last-known-good final 的内容和修改时间。
- [ ] 若静态资源自上次发布后删除或重命名，手工清空 `publish/` 后再从 clean commit 构建。
- [ ] 确认 `AppMetadata.Version` 是唯一人工维护版本值，EXE metadata 与 startup log 一致。
- [ ] 确认正式 artifact 的 `SourceRevision` 是 clean source commit，不含 `UNSTAMPED` 或 `-dirty`。
- [ ] 检查 executable/source release 不包含真实 `config.ini`、日志或 patient data。
- [ ] 确认更新流程不会覆盖 `%LocalAppData%\MedExReportAssistant\config.ini` 的已有值；缺少 managed defaults 时先生成唯一备份，再只补缺失项。
- [ ] 将 ZIP 复制到本机并完整解压；不得直接从共享盘或 ZIP 内运行 EXE。
- [ ] 分别从普通本地目录、Desktop 和 Windows Startup folder 启动，确认不要求固定路径或管理员权限。
- [ ] 验证同一 EXE 重复启动时第二进程显示中文提示并退出，原进程 PID 和状态不变。
- [ ] 验证改名 EXE、不同目录 EXE 和不同 policy-aware version 仍由 `Local\MedExReportAssistant.Singleton` 阻止并行运行。
- [ ] 核对 `%LocalAppData%\MedExReportAssistant\logs\startup.log` 包含 `AppVersion`、`SourceRevision`、`ExecutablePath`、`ConfigPath`。
- [ ] 核对没有 installer、shortcut、registry state、EXE backup、rollback、self-update 或 historical EXE cleanup。
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
- [x] `;fzg` no-reset → `Left 4` 已完成 Step 4 A/B 和 generated-release validation；50 ms control 仅保留在独立 harness。
- [ ] 检查没有自动提交、自动审核或自动最终发送功能。
- [ ] 检查 new/compat hotkeys 和 hotstrings 没有重复注册。
- [ ] 检查 compatibility 保留项、移除项和停止测试方法与本 release 中文维护说明一致。
- [ ] 在目标 DPI、display scaling、resolution 和 MedEx version 上完成验证。
- [ ] 更新 `CHANGELOG.md`。
- [ ] 编写本 release 的中文 maintainer/update notes。
- [ ] 更新简单中文 internal-test user instructions。
- [ ] 创建 git tag。
- [ ] 上传经过验证的 internal release artifacts；不上传 user config、logs 或 legacy local data。
