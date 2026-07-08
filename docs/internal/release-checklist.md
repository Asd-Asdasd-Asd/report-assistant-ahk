# Release 检查清单

发布前逐项确认。

- [ ] 运行 `python scripts/build_release.py`。
- [ ] 检查 `release/report_assistant.ahk` 是否生成。
- [ ] 将 release 文件复制到 Windows 测试工作站。
- [ ] Windows 上启动脚本。
- [ ] 测试 Ctrl+Alt+Q 紧急退出。
- [ ] 测试 Ctrl+Alt+Esc 暂停/恢复。
- [ ] 测试 `;cmx`。
- [ ] 测试 `;red` 不破坏剪贴板。
- [ ] 测试 `;fzg`。
- [ ] 检查没有自动提交、自动审核或自动最终发送功能。
- [ ] 更新 `CHANGELOG.md`。
- [ ] 创建 git tag。
- [ ] 在 GitHub Release 上传 `release/report_assistant.ahk`。
