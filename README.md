# 麦旋风（MedEx Report Assistant）

麦旋风是一个基于 AutoHotkey v2 的 Windows 报告书写辅助工具，目前用于少量工作站内部验证，不替代人工审核，也不会自动提交报告。当前版本可在托盘“关于麦旋风…”或发布文件夹的 `版本信息.md` 中查看。

## 当前能力

- 报告快捷语只在允许的 MedEx 报告窗口中生效。
- `Ctrl+Alt+Esc` 暂停或恢复，`Ctrl+Alt+Q` 退出；两者保持全局可用。
- 双击托盘图标或右键选择“设置…”可打开原生设置窗口。
- 托盘“关于麦旋风…”显示版本、构建日期和源代码版本。
- 设置窗口支持新增、修改、启用、停用和按列查看快捷语；builtin 可编辑但不能删除，custom template 可删除。
- 设置窗口可配置箭头、长度测量、3D SUV、截图和清除全部标注快捷键，支持单修饰键及仅限 Viewer 的单字母/数字键，并可独立勾选 Win；五项默认关闭。
- 保存设置后执行完整 `Reload()`，不使用进程内热更新。
- portable EXE 不绑定安装目录；跨版本单实例由固定 `Local\MedExReportAssistant.Singleton` mutex 保护。
- `{{suvmax}}` 和 `{{size}}` 可从 MxNM 当前标注读取 SUVMax 或 1–3 个直线测量值；两者不能用于同一模板。
- 自动测量只有在取得严格合法的新结果时才写入报告；无标注或失败时保留人工输入位置，报告写入成功后再尝试清除 viewer 标注。

当前颜色恢复只在 MedEx `0.0.1.0`、1920×1080、100% scaling、DPI 96 的既有 profile 上完成现场验证。其他布局继续 fail closed，不能因为版本检测放宽而视为已支持。

## Schema 2 模板

配置位于：

```text
%LOCALAPPDATA%\MedExReportAssistant\config.ini
```

EXE 的位置不参与配置路径计算。普通用户应通过设置窗口修改快捷语，不需要手工编辑或删除 `config.ini`。

每个 Schema 2 template 只保存 `Enabled`、`Name`、`Trigger` 和 `Text`。支持：

- `{{cursor}}`：最终 caret 位置；最多一个。
- `{{date}}`：触发时展开为本机日期 `yyyy-MM-dd`；可重复。
- `{{suvmax}}`：自动读取 SUVMax；最多一个。
- `{{size}}`：自动读取并按数值降序格式化 1–3 个直线测量值；最多一个。
- `{{red:（见图）}}`：唯一合法的红色元素；最多一个且必须位于模板末尾。

`{{suvmax}}` 与 `{{size}}` 不能出现在同一模板中。普通字面量 `（见图）` 始终按黑字处理。`template_renderer.ahk` 将模板转换为 `ReportTemplatePlan`，由 plan 的最终 caret 位置推导移动距离，并且仅在 caret 位于红色尾标记之后时请求 Candidate G。纯黑模板和 caret 位于正文内部的模板不会调用 Candidate G。

内置 `;cma` 模板直接使用 `{{size}}` 自动读取尺寸；无标注或读取失败时在原位置留下人工输入光标。

Schema 1 首次启动时执行一次性迁移：先审计旧 `Mode`，再备份、写入临时文件、验证并替换。不能无歧义保留的配置会阻止迁移并保留原文件。Schema 2 配置不能再交给旧版 EXE 使用。

详细边界见：

- `docs/internal/configuration-architecture.md`
- `docs/internal/architecture.md`

## 设置窗口

`settings_ui.ahk` 使用原生 `Gui + Tab3 + ListView`。报告模板页隐藏 section 与 stable ID，只显示状态、名称、触发词和模板文字。“插入模板元素”下拉框可在当前选区或 caret 位置插入：

- 光标位置
- 当前日期
- 自动获取 SUVMax
- 自动获取尺寸
- 红色“（见图）”

保存前会检查空值、重复 trigger、模板语法和外部文件变化。写入使用备份、临时文件和最终复读验证；成功后执行全脚本 `Reload()`。

快捷键页提供箭头、长度测量、3D SUV、截图和清除全部标注。默认组合为 `Ctrl+Alt+1/2/3/4/5`，首次升级保持停用；Win 键通过输入框旁的独立选项加入。前三项在报告程序或 Viewer 前台时可用，并已完成当前工作站 Windows 非临床验证；3D SUV 会等待完整组合键松开后单次选择，之后不需要继续按住。截图只在 Viewer 前台时把所配按键映射为 MedEx F12，派发后让整个 Viewer 快速白闪约 90 ms，不声称截图已经完成。清除快捷键复用已经验证的右键菜单“删除全部标注”路径，不依赖工具面板坐标。以上操作不移动鼠标或切换前台窗口，并在目标不满足安全条件时拒绝执行。实现与现场发现见 `docs/internal/mxnm-viewer-tool-hotkeys.md`。

## Portable build

Windows 构建机安装 Python 3、AutoHotkey v2 与 Ahk2Exe 后，双击根目录 `Build EXE.cmd`。Git checkout 可提供准确 source revision；没有 Git 元数据时仍可生成带“未标记”警告的临时测试构建：

```text
existing source
→ scripts/build_release.py
→ ..\report-assistant-build\release-source\report_assistant.ahk
→ Ahk2Exe + assets/icon/generated/medex-icon.ico
→ ..\report-assistant-build\publish\麦旋风.building.exe
→ validate
→ ..\report-assistant-build\publish\麦旋风.exe
```

所有 Windows 构建产物都写入仓库同级的 `report-assistant-build/`，不会修改
checkout 内任何文件，因此构建后可直接 `git pull`。构建会 overlay 同步
`assets/publish/`，不会审核或删除外部 `publish/` 中的其他文件。失败时删除
本轮 `.building.exe` 并保留 last-known-good final；promotion 阶段使用短期
`.previous.exe` 恢复保护。

需要提交到 Git 的生成文件：

- `release/report_assistant.ahk`（源码变化后生成）
- `assets/publish/版本信息.md`（与 release 同一次生成）
- `assets/icon/generated/medex-icon-*.png`
- `assets/icon/generated/medex-icon.ico`

`assets/icon/source/medex-icon.svg` 是图标唯一可编辑源文件；macOS 生成方法见 `docs/internal/icon-assets.md`。外部 `report-assistant-build/` 不属于仓库，也不提交。

## 发布验证

1. 运行全部 Python tests。
2. 源码变化时运行 `python3 scripts/build_release.py`；纯文档变化不刷新 generated release。
3. 运行 `git diff --check`。
4. 从 clean commit 在 Windows 双击 `Build EXE.cmd`。
5. 按 `docs/internal/release-checklist.md` 和 `tests/manual-test-checklist.md` 完成 Windows/MedEx 验收。
6. Windows/MedEx 验收通过后，双击根目录 `Package Release.cmd`。
7. 只分发自动生成的版本化 ZIP：

```text
..\report-assistant-build\dist\麦旋风-v<版本>.zip
```

`publish/` 保持固定名称并作为当前构建工作区；打包器只从中复制
`麦旋风.exe` 和四份发布文档，不会包含诊断工具、源码、日志或其他
遗留文件。新 ZIP 验证成功后，`dist/` 中旧的受管版本包才会被清理。

当前已知延期：重新编译后的首次颜色下拉操作，偶尔会正确选中黑色但菜单仍留在屏幕上；之后的操作通常正常。本问题暂不通过额外盲点或重复点击规避，发布验收时应单独记录。

## 目录

```text
assets/    发布文档与图标源/生成物
docs/      架构、维护、调查和用户文档
legacy/    历史脚本与 compatibility reference
release/   生成的单文件 AHK source
scripts/   release、EXE 和图标生成工具
src/       模块化 AutoHotkey v2 source
tests/     Python static tests 与 Windows/manual harnesses
```

项目不得提交患者信息、医院敏感信息、真实用户配置、截图、凭据或包含临床内容的日志。
