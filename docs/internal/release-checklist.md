# v0.5.0 Internal Release 检查清单

## Source 与版本

- [ ] 从 clean commit 构建，`src/app_metadata.ahk` 中版本为 `0.5.0`。
- [ ] `src/app_metadata.ahk` 是 application version 的唯一人工维护来源。
- [ ] source 变化后运行完整 Python suite 和 `python scripts/build_release.py`。
- [ ] `release/report_assistant.ahk` 与 source modules 一致，UTF-8 without BOM，U+FEFF count 为 0。
- [ ] generated release 不依赖 source tree、debug files 或开发机 absolute paths。
- [ ] `SourceRevision` 与 clean source commit 一致，不是 `UNSTAMPED` 或 `-dirty`。

## Schema 2 与设置

- [ ] 新配置 section 只有 `Enabled`、`Name`、`Trigger`、`Text`。
- [ ] `{{cursor}}`、`{{date}}`、`{{red:（见图）}}` 均通过 parser、renderer 和 Settings validation。
- [ ] 普通字面量 `（见图）` 保持黑色，不触发 Candidate G。
- [ ] `{{red:（见图）}}` 最多一次且只能位于模板末尾。
- [ ] `ReportTemplatePlan` 根据 rendered result 推导 caret relocation 和 Candidate G；内部 cursor 优先于颜色恢复。
- [ ] Settings ListView 排序后，选择、编辑和删除仍按稳定 `Section` identity 操作。
- [ ] “插入模板元素”可在 caret 处插入、替换选区并恢复 Text editor focus。
- [ ] Schema 1 首次启动先备份，再原子迁移为 Schema 2；失败保留原配置且 fail closed。
- [ ] 已升级配置不再用旧版 EXE 打开。

## 自动与静态验证

- [ ] 运行 `python3 -m unittest discover -s tests -p 'test_*.py'`。
- [ ] 运行 `git diff --check`。
- [ ] 运行 Windows AHK regression harnesses，包含 migration、Settings、template renderer、`cmx` 和 startup。
- [ ] 核对 diagnostics 不包含患者资料、报告正文或 clipboard content。

## Windows 一键构建

- [ ] Windows 构建机已安装 AutoHotkey v2 与 Ahk2Exe。
- [ ] `assets/icon/generated/medex-icon.ico` 存在、非空且由当前 SVG 生成。
- [ ] 双击根目录 `Build EXE.cmd`，确认重新生成 release source、嵌入图标、同步静态资源并输出：

```text
publish\麦旋风.exe
```

- [ ] `publish/` 包含本轮需要分发的 `麦旋风.exe`、`首次使用.md`、`配置指南.md` 和 `更新说明.md`。
- [ ] 在资源管理器与系统托盘中确认正式图标。
- [ ] 连续构建两次，final 被安全替换且没有遗留 `.building.exe` 或 `.previous.exe`。
- [ ] 模拟 compiler path 错误：构建非零退出、清理 `.building.exe`、保留 last-known-good final。
- [ ] 若静态资源曾删除或重命名，构建前手工清空 `publish/`；正常构建不审核整个目录。

## Windows / MedEx 验收

- [ ] 从普通本地目录、Desktop 和 Windows Startup folder 启动，不要求管理员权限。
- [ ] 同名、改名、不同目录和不同版本 EXE 均由 `Local\MedExReportAssistant.Singleton` 阻止并行运行。
- [ ] startup log 包含 `AppVersion`、`SourceRevision`、`ExecutablePath`、`ConfigPath`。
- [ ] 双击托盘图标与右键“设置…”打开同一窗口；保存后 full-script Reload。
- [ ] builtin 与多个 custom templates 的新增、编辑、启停、排序、删除和重启持久化正确。
- [ ] 单行、多行、空行、末尾换行、反斜杠及字面量 `\n` round-trip 正确。
- [ ] `;red`、`;fzg`、`;fwj`、`;fjd`、`;cmx` 的文字、红色范围、caret 和后续输入颜色正确。
- [ ] hotstrings 只在 MedEx report process 生效；`Ctrl+Alt+Esc` 和 `Ctrl+Alt+Q` 保持全局。
- [ ] wrong process、missing anchor、invalid geometry、menu timeout 和 black-item failure 均 fail closed。
- [ ] 重新编译后的第一次颜色下拉操作若已选中黑色但菜单未关闭，记录一次现场结果；不得用 blind retry 掩盖，后续操作应恢复正常。
- [ ] 在目标 DPI、display scaling、resolution 和 MedEx version 上完成最终 smoke test。

## 发布

- [ ] ZIP 只包含 `publish/` 中需要分发的内容，不包含 build scripts、source、user config、logs 或 Git metadata。
- [ ] ZIP 先复制到本机并完整解压，不从共享盘或压缩包内直接运行。
- [ ] 用户说明统一使用“麦旋风”，版本统一为 `v0.5.0`。
- [ ] `更新说明.md` 写明完整文件夹替换、自动配置升级和问题留存方法。
- [ ] 不包含 installer、shortcut、registry state、self-update、EXE backup、rollback 或历史 EXE cleanup。
- [ ] 创建 tag 和上传 artifact 仅在 Windows/MedEx 验收完成后进行。
