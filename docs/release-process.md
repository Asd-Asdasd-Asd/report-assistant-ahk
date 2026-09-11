# 内部发布流程

1. 只修改 `src/` 和对应文档；不要手改 `release/report_assistant.ahk`。
2. 从 clean Git commit 开始，确认 `src/app_metadata.ahk` 版本正确。
3. 运行 Python 测试和 `python scripts/build_release.py`，确认 generated release 与 source 一致。
4. 在 Windows 构建机运行 `Build EXE.cmd`，确认 EXE、版本信息和静态发布文件写入仓库同级 `report-assistant-build/`，checkout 状态不变化。
5. 按 `tests/manual-test-checklist.md` 和 `docs/internal/release-checklist.md` 完成 Windows/MedEx 现场验收。
6. 更新 `CHANGELOG.md` 及 `assets/publish/` 中的用户可见说明。
7. 通过验收后运行 `Package Release.cmd`，只分发版本化 ZIP 及对应 SHA256。

发布物不得包含患者信息、医院敏感信息、凭据、截图、真实用户配置或临床日志。不得创建 installer、self-update、rollback、旧 EXE backup 或历史版本清理机制。
