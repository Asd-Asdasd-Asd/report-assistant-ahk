# 当前手工验收清单

本清单只保留当前版本仍需人工或 Windows runtime 证明的行为。已完成的阶段性
实验、旧 artifact hash 和历史 checkpoint 结果由 Git 历史保存，不在此重复。

## 自动验证前置条件

- [ ] 运行 `python3 -m unittest discover -s tests -p 'test_*.py'`。
- [ ] 运行 `git diff --check`。
- [ ] Source 有变化时运行 `python3 scripts/build_release.py`，确认 generated
  release 与 source 一致；纯文档变化不刷新 generated release。
- [ ] Windows regression harness 无 `#Warn`、解析错误或启动错误。
- [ ] Field output 不包含患者信息、报告正文、clipboard payload、真实配置内容
  或其他敏感资料。

## 报告输入与设置

- [ ] 报告 hotstrings 只在
  `medexworkstation.exe`/`medexworkstations.exe` 前台生效。
- [ ] `Ctrl+Alt+Esc` 在正常及 suspend 状态均可暂停/恢复；
  `Ctrl+Alt+Q` 始终可退出。
- [ ] `GlobalHjklArrows=true` 时 RAlt+H/J/K/L 分别发送方向键；关闭时不注册。
- [ ] 双击托盘图标和右键“设置…”只打开或激活同一个窗口。
- [ ] Settings ListView 排序后仍能正确选择、编辑、启停和删除对应 Section。
- [ ] Builtin 可编辑/停用但不可删除；custom 可新增和删除。
- [ ] 模板文字中的空行、末尾换行、反斜杠和字面量 `\n` round-trip 不变。
- [ ] `{{cursor}}`、`{{date}}`、`{{suvmax}}`、`{{size}}` 和
  `{{red:（见图）}}` 的插入、校验和保存正确。
- [ ] 同一模板拒绝多个 measurement token，并拒绝同时使用
  `{{suvmax}}` 与 `{{size}}`。
- [ ] 保存后执行完整 Reload；外部修改冲突时拒绝覆盖用户配置。

### 报告正文读取诊断

- [ ] 光标/选区诊断只信任 active caret 或实际变化的 selection；固定返回的
  inactive caret 和 `0/0` selection 不得作为 production fallback。
- [ ] 只使用非临床测试文字启动
  `tests/windows/report_editor_edit_structure_field.ahk`，聚焦“检查所见”正文框，
  将鼠标停在正文编辑区域内后按 `Ctrl+Alt+F8`；程序不得移动或点击鼠标。
- [ ] 确认提示 `STRUCTURE_CAPTURED`，将剪贴板结果回传；结果只能包含
  control type、矩形、层级、焦点和 Pattern availability，不得读取或输出
  Name、Value、URL、报告正文或患者信息。
- [ ] 只有结构诊断定位到独立、唯一且矩形合理的 editor element，才允许另建
  显式 field harness 验证全选、复制、剪贴板恢复及 foreground guard。

## Candidate G 与剪贴板

- [ ] 只在 MedEx `0.0.1.0`、1920×1080、100% scaling、DPI 96 的已验证
  profile 上执行 production Candidate G。
- [ ] `;red` 插入红色 `（见图）`，随后输入恢复黑色，原 clipboard 完整恢复。
- [ ] `;fzg` 使用模板派生的内部 caret relocation，不运行 Candidate G，
  不改成固定 `Left 5`，也不重新加入额外 settle。
- [ ] Wrong process、foreground change、缺少/重复语义锚点、非法 geometry 或
  popup signature mismatch 均在 black click 前 fail closed。
- [ ] Arrow 和 black 各最多点击一次；执行后鼠标回到原位置。
- [ ] Fast-failure path 不粘贴原 clipboard；clipboard restore 仍由唯一
  `finally` owner 完成。
- [ ] 重新编译后的第一次颜色下拉若选中黑色但菜单未关闭，只记录现象；
  不增加 blind retry 或补偿点击。

当前 Candidate G 专用 harness 说明见 `debug/README.md`。

## SUVMax、尺寸与标注清除

- [ ] `tests/windows/measurement_capture_regression.ahk` 覆盖 positive、zero、
  empty、malformed、no-update、nested-busy 和 clipboard restoration。
- [ ] `tests/windows/mxnm_measurement_target_regression.ahk` 通过纯逻辑回归。
- [ ] `tests/windows/mxnm_measurement_target_field.ahk` 在 Viewer 前台和报告
  前台均能解析唯一 target；失败时 popup/clipboard 不可达。
- [ ] `;fzg` 的 positive、`NOT_ANNOTATED` 和 automation failure 路径分别
  写入数值、留下人工输入锚点或显示无焦点失败提示。
- [ ] `;cma`/custom `{{size}}` 对 1–3 个正数按数值降序输出，使用 `×` 和逐项
  `cm`；无标注或失败时留下人工输入锚点。
- [ ] 报告写入成功后才尝试清除标注；清除失败不回滚报告内容。
- [ ] `tests/windows/mxnm_annotation_cleanup_field.ahk` 验证一次调用最多打开
  一次菜单，并保持 foreground、mouse 和 clipboard。
- [ ] Viewer 未运行、多个候选、错误进程、越界 client point、菜单文字不匹配
  或 clipboard 未更新时不使用第二 transport，不复用旧值。

## Viewer 工具快捷键

- [ ] 运行 `tests/windows/mxnm_viewer_tool_command_regression.ahk`。
- [ ] 运行 `tests/windows/mxnm_viewer_tool_command_field.ahk`，验证箭头、长度
  和 3D SUV 的 command ID 为 `21043/21048/21193`。
- [ ] Native control group 必须同 PID、visible/enabled、原生 `Button`、
  同一直接父面板、ID/顺序完整且组唯一；缺失或多组时 fail closed。
- [ ] 不使用固定按钮中心、固定 pitch、固定前三行、outer-frame snapshot
  membership 或 `SCBtnPadPos` 作为 dispatch veto。
- [ ] 箭头、长度和 3D SUV 在目标机器各连续执行 10 次，完整松键后只投递一次。
- [ ] 带修饰键的工具和清除在报告或 Viewer 前台生效；其他程序不触发、不吞键。
- [ ] 单个无修饰字母/数字只在 Viewer 前台生效，在报告和其他程序中不拦截。
- [ ] Win modifier 保存、Reload 和重开设置后保持不变。
- [ ] 截图只在 Viewer 前台发送 F12；约 90 ms 白色 pulse 不表示截图完成。
- [ ] 清除快捷键复用 context-menu cleaner，不移动鼠标，不依赖工具按钮坐标。

跨机器 target resolver 的现场顺序与判据见
`docs/internal/viewer-adaptive-runtime-checkpoints.md`。

## Portable release 与 singleton

- [ ] 从 clean commit 在 Windows 双击根目录 `Build EXE.cmd`。
- [ ] 构建前后 checkout 的 `git status --short` 一致。
- [ ] 外部 `report-assistant-build/publish/` 包含 `麦旋风.exe`、版本信息及三份
  发布说明；不分发源码、构建脚本或 Git metadata。
- [ ] EXE 可从普通本地目录、Desktop 和 Windows Startup folder 启动。
- [ ] 同名、改名、不同目录和不同版本的 policy-aware EXE 不能并行运行。
- [ ] 第二进程退出时不终止或 reload 原进程。
- [ ] Config 始终位于
  `%LOCALAPPDATA%\MedExReportAssistant\config.ini`，替换 EXE 不改变用户值。
- [ ] Startup metadata 中的 version、source revision、executable path 和
  config path 正确；正式 release 不含 `UNSTAMPED` 或 `-dirty`。
- [ ] 构建失败保留 last-known-good final，不遗留 `.building.exe`。
- [ ] 不创建 installer、shortcut、registry state、self-update、旧 EXE backup
  或历史 EXE cleanup。

## Legacy compatibility

- [ ] 原始 `karabiner.ahk` 和 `string_change.ahk` 的运行实例已退出。
- [ ] `medex_legacy_compat.ahk` 不注册报告 hotstrings、RAlt+H/J/K/L、
  Viewer screenshot、SUV/Arrow 复按状态机或 snapshot save。
- [ ] Compatibility 只保留当前仍未迁移的固定坐标动作，并使用独立 tray tooltip。
- [ ] Shift+Alt+S 不与新项目 clipboard transaction 并发。
- [ ] 新项目的暂停/退出不控制 compatibility；停止测试时分别退出两个进程。
- [ ] 不删除或覆盖用户的旧脚本、`red_not.clip`、配置或人工回退路径。

### Shift+Alt+S caption + advance 迁移诊断

- [ ] 使用非临床测试文字运行
  `tests/windows/report_image_caption_migration_diagnostic.ahk`，按说明依次采集
  source selection、caption input point 和 image wheel point。
- [ ] 诊断只发送一次 `Ctrl+C` 并恢复原 clipboard；不得点击、粘贴、滚轮、
  激活其他窗口或写出 copied payload。
- [ ] 输出不得包含窗口标题、URL、accessible Name/Value、选中文字、报告正文
  或患者信息；`图像描述`/`保存` 仅作为固定 exact-query 常量。
- [ ] 正式迁移完成并通过 Windows field validation 前，
  `Shift+Alt+S` ownership 继续属于 compatibility。
