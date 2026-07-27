# 内部发布流程

1. 只修改 `src/` 和对应文档，不手改 generated release。
2. 运行 tests，并执行 `python scripts/build_release.py`。
3. 审查 `release/report_assistant.ahk` 与 source modules 一致。
4. 在安装 AutoHotkey v2 和 Ahk2Exe 的 Windows 构建机上双击根目录 `Build EXE.cmd`。
5. 确认脚本在仓库同级 `report-assistant-build/` 中生成 release source、将 `assets/icon/generated/medex-icon.ico` 嵌入临时 EXE、同步 `assets/publish/`，并最终输出 `..\report-assistant-build\publish\麦旋风.exe`；checkout 的 `git status` 不变化。
6. 确认 user config 位于 `%LocalAppData%\MedExReportAssistant\config.ini`，替换 EXE 不会覆盖它。
7. 按 `tests/manual-test-checklist.md` 和 `docs/internal/release-checklist.md` 在 Windows 工作站测试。
8. 核对 compatibility script 与新 build 没有 hotkey/hotstring conflicts。
9. 更新 `CHANGELOG.md`、maintainer notes 和 `assets/publish/更新说明.md`。
10. 核对 `assets/publish/首次使用.md`、`配置指南.md`、`更新说明.md`；明确 ZIP 先复制到本地再解压运行。
11. 确认 source revision 不是 `UNSTAMPED` 或 `-dirty`，再 Tag version；只压缩并分发外部 `report-assistant-build\publish\` 的内容，不分发仓库根目录或构建脚本。

Executable 没有固定安装目录。发布流程不得创建 installer、shortcut、registry state、旧 EXE backup、rollback package、self-update 或历史 EXE cleanup。维护者不应要求应用查找或处理其他目录中的 EXE。

Release artifacts 不得包含 patient data、hospital identifiers、credentials、screenshots、真实 user config 或包含临床内容的 logs。

`assets/publish/` 到外部 `report-assistant-build/publish/` 采用 overlay 同步，不删除其中的手工文档或图标。删除或重命名静态资源后，正式发布前应手工清空该外部目录再构建。构建失败时保留构建开始前已有的 last-known-good `麦旋风.exe`，并以非零退出码明确报告失败；不得把旧修改时间当作本轮成功。

Generated release source 和 icon assets 属于需要提交的可复现产物：source 变化后由维护者显式运行 `python scripts/build_release.py` 并提交 `release/report_assistant.ahk`；图标变化后提交 `assets/icon/source/medex-icon.svg`、全部 generated PNG 和 ICO。Windows 一键构建使用外部输出参数，不修改这些 tracked generated files；`report-assistant-build/` 不提交。
