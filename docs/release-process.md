# 内部发布流程

1. 只修改 `src/` 和对应文档，不手改 generated release。
2. 运行 tests，并执行 `python scripts/build_release.py`。
3. 审查 `release/report_assistant.ahk` 与 source modules 一致。
4. 从审查后的 source truth 构建 internal-test executable。
5. 确认 user config 位于 `%LocalAppData%\MedExAHK\config.ini`，升级不会覆盖它。
6. 按 `tests/manual-test-checklist.md` 和 `docs/internal/release-checklist.md` 在 Windows 工作站测试。
7. 核对 compatibility script 与新 build 没有 hotkey/hotstring conflicts。
8. 更新 `CHANGELOG.md`，并为每个 internal release 编写中文 maintainer/update notes。
9. 更新简单中文 internal-test user instructions 和 rollback steps。
10. Tag version，并上传经过验证的 `.ahk`/`.exe` artifacts。

Release artifacts 不得包含 patient data、hospital identifiers、credentials、screenshots、真实 user config 或包含临床内容的 logs。
