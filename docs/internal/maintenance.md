# 维护说明

本文档面向维护者。普通用户不需要阅读。

## 开发环境分工

- 本地开发主要在 Mac 上进行。
- Windows 工作电脑只用于部署、校准和测试。
- 不在 Windows 工作电脑上保存患者数据、敏感日志或截图到项目目录。

## 常规流程

1. 修改 source、tests 或 documentation。
2. 运行对应 tests 和 `git diff --check`。
3. source 或 release metadata 有变化时，运行 `python scripts/build_release.py`；纯文档修改不应重写 generated release。
4. 审查 `git status` 和 diff，确认没有混入本机配置、日志或患者资料。
5. 按 `tests/manual-test-checklist.md` 或 `docs/internal/release-checklist.md` 完成测试。
6. 只在验证完成后提交并推送。

形成新的可交付验证点时，维护者应同步评估并修改
`AppMetadata.Version`：兼容修复增加 patch，新的能力阶段增加 minor。
普通开发提交不为追求数字变化而机械升版。

## Source truth 与 generated files

- `src/app_metadata.ahk` 是 application version 的唯一人工维护来源。
- `release/report_assistant.ahk` 由 `scripts/build_release.py` 生成；source 变化后必须重新生成并提交，不得手改。
- `assets/publish/版本信息.md` 与 release 同次生成；不得手改版本、日期或 revision。
- `assets/icon/source/medex-icon.svg` 是图标唯一可编辑来源。
- `assets/icon/generated/*.png` 与 `assets/icon/generated/medex-icon.ico` 由 `scripts/generate-icon.sh` 生成，并与 SVG 一起提交。
- 除自动生成的 `版本信息.md` 外，`assets/publish/*.md` 是发布包静态资源的 source truth；Windows 构建时 overlay 到 `publish/`。
- `..\report-assistant-build\` 是仓库外的本地构建根目录，不提交。

## Windows 一键构建

Windows 构建机需安装 Python 3、AutoHotkey v2，并包含 Ahk2Exe compiler。Git checkout 用于注入准确 source revision；无 Git 或无 `.git` 时允许构建，但“关于”和 `版本信息.md` 会显示“未标记”及临时测试警告，不得作为正式发布。默认使用：

- `C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe`
- `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe`

双击仓库根目录的 `Build EXE.cmd`。脚本从当前 checkout 在仓库同级
`report-assistant-build/` 中生成临时 release source 和版本信息，使用
`assets/icon/generated/medex-icon.ico` 作为 Ahk2Exe 图标，编译并验证临时
EXE，同步 `assets/publish/` 中的发布资源，最后把产物安全提升为：

```text
..\report-assistant-build\publish\麦旋风.exe
```

构建过程不写入 checkout，完成后 `git status` 应保持不变，可以直接
`git pull`。构建成功后先测试 EXE。验收通过后双击根目录
`Package Release.cmd`，由它生成：

```text
..\report-assistant-build\dist\麦旋风-v<版本>.zip
```

只分发这个版本化 ZIP。不要手工压缩 `publish/`，也不要分发仓库根目录
或构建脚本；此流程不会创建 installer 或 automatic updater。

静态资源使用 overlay 同步：构建只复制 `assets/publish/` 中当前存在的文件，不审核或删除 `publish/` 中的其他文档、图标。若静态资源被删除或重命名，正式发布前应手工清空 `publish/`，再从 clean commit 重新构建。

`publish/` 始终是固定名称的当前构建工作区。`Package Release.cmd` 使用
干净的临时 staging，只复制 `麦旋风.exe`、`版本信息.md`、`更新说明.md`、
`首次使用.md` 和 `配置指南.md`。ZIP 验证成功后才清理 `dist/` 中旧的
`麦旋风-v*.zip` 与对应 SHA256；失败时恢复上一份。诊断工具和 checkpoint
位于各自独立目录，不属于打包白名单。

每个 v0.5+ internal release 还必须：

- 从 source truth 生成 internal-test executable，不手改 generated artifact；
- 只从 clean Git commit 构建正式 EXE，确认 startup metadata 中 `SourceRevision` 是该 source commit；
- dirty checkout 允许生成现场测试 EXE，但“关于”和 `版本信息.md` 必须显示 `-dirty` 与测试警告；
- 为每个 internal release 编写中文 maintainer notes，并更新 `assets/publish/更新说明.md`；
- 核对 `%LocalAppData%\MedExReportAssistant\config.ini` 的 Schema 1 → 2 备份、迁移和验证流程；失败不得产生半迁移文件；
- 核对 compatibility script 与新 build 没有重复 hotkeys/hotstrings；
- 记录本 release 从 compatibility 移除了哪些 capability，以及出现问题时如何停止测试和恢复人工工作流。

v0.6.0 还必须核对 SUVMax/尺寸的 strict parser、fresh clipboard、人工输入锚点、报告成功后清除及清除后 `NOT_ANNOTATED` 复验。

初始内测使用 portable single-EXE：不提供 installer、固定安装路径、shortcut、自动更新、旧 EXE backup 或 rollback system。ZIP 必须先复制到本机并完整解压，不能直接从共享盘运行。

## 如何记录问题

记录问题时应包含：

- 发生时间。
- 使用的版本或 commit。
- Windows 版本和显示缩放。
- 脚本正在执行的功能。
- 期望结果和实际结果。
- 是否可以稳定复现。

不要记录：

- 患者姓名、检查号、住院号、身份证号等信息。
- 医院敏感信息。
- 账号、密码、令牌。
- 真实内网地址。
- 截图或敏感日志。

## 如何更新 CHANGELOG

- 每次可见行为变化都记录在 `CHANGELOG.md`。
- 文档、治理、发布流程变化也应记录。
- 未发布内容先放在 `[Unreleased]`。
- 准备版本发布时再整理到对应版本号。

## 不要提交的内容

- `src/config.local.ahk`
- 患者数据
- 医院敏感信息
- 账号、密码、令牌
- 截图
- 日志文件
- 本机临时文件
- 编译出的 `.exe`
- 未经确认的坐标校准文件

`%LocalAppData%\MedExReportAssistant\config.ini` 是用户持久数据，不属于 release source。Schema migration 和 managed-default reconciliation 必须先备份、使用临时文件并复验；除明确的 Schema 1 → 2 migration 外，不得覆盖已有用户值或删除用户 section。诊断日志可以在用户授权的本机内测流程中生成，但不得提交到仓库，也不得包含患者信息或 report text。
