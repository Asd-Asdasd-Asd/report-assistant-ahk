# Report Assistant AHK

Report Assistant AHK 是一个私有 AutoHotkey v2 项目，用于 Windows 报告书写和阅片窗口自动化辅助。

## 当前状态

Step 4 基线为 `5193403`；`2369b68`（tag `v0.6.0-candidate-g`）是 Candidate G promotion 基线。Step 5 已通过 Windows G1/G2 metadata-override 与 generated-release 验收：MedEx version 现在是 diagnostics-only metadata。`relativeMousePixelValidated` 已是 production default：UIA 精确定位 `Name="检查所见"`，经过 profile geometry 校验后以相对坐标打开颜色菜单，四点 popup signature 匹配后最多单击一次黑色。horizontal-translation v2 不再用绝对 screen X 限制 region anchor，使 sidebar 伸缩造成的工具栏整体水平平移能够沿用相同相对坐标和安全门。`uiaInvoke` 仅保留为显式 comparison/rollback；两种策略之间没有 automatic fallback。

2026-07-16 Windows 现场已验证 generated release、Candidate G black reset、phrase-specific `;fzg` caret workflow 和最终 mainline behavior；promotion 当时记录为 `75 tests passed`。本项目仍是早期内部原型，不适合科室范围推广或无人值守使用。当前 layout 只在 MedEx 0.0.1.0、1920×1080、100% scaling、DPI 96 上完成校准和现场验证。

进程状态不再是“完全未确认”：现场确认的主进程是 `medexworkstations.exe`；代码暂时兼容保留 `medexworkstation.exe`。

## 当前行为边界

- `;red`、`;fwj`、`;fjd`：由显式 `{{red:（见图）}}` 模板元素插入红色 `（见图）`；最终光标位于末尾时运行 Candidate G，将后续输入恢复为黑色。
- `;fzg`：`{{cursor}}` 将光标定位在红色 `（见图）` 前；移动距离由渲染结果计算，不运行 Candidate G。
- `;cmx`：模板 `cm×{{cursor}}cm` 插入 `cm×cm`，并将光标定位在两个单位之间。
- Production success 不写 heavy log；failure 写 privacy-safe lightweight log；field mode 才写详细 timing、geometry、UIA 和 pixel diagnostics。
- 全局 pause/exit 分别为 `Ctrl+Alt+Esc`、`Ctrl+Alt+Q`。
- Step 2 的 MedEx-only shared `#HotIf` guard 已由 `7a0d9a2` 提交。
- Step 3 已将 Candidate G 移到 clipboard restore 前，并以 field-approved 300 ms minimum paste-to-restore interval 保护 fast failure；Windows success/fast-failure 均已通过。
- Step 5 candidate 不再用 exact MedEx version 阻止 runtime/calibration；实际版本、校准版本和 match state 继续写入 diagnostics。Resolution、DPI、scaling 和所有 interaction guards 保持 hard gate。

## 便携式内部发布

普通用户发布物为 `麦旋风.exe`，可放在任意本地目录、Desktop 或 Windows Startup folder。程序不安装自身、不要求管理员权限，也不创建 shortcut、注册表状态或自动更新任务。下载的 ZIP 必须先复制到本机并完整解压，不能直接从共享盘运行。

跨版本单实例由固定 `Local\MedExReportAssistant.Singleton` mutex 保护；第二个采用该策略的版本只会显示中文冲突提示并退出，不会终止或重载当前实例。启动记录写入 `%LOCALAPPDATA%\MedExReportAssistant\logs\startup.log`，配置仍独立保存在 `%LOCALAPPDATA%\MedExReportAssistant\config.ini`。

## 自定义报告热字符串

程序首次启动时会创建：

```text
%LOCALAPPDATA%\MedExReportAssistant\config.ini
```

配置在程序启动时读取。修改并保存后，右键系统托盘图标并选择“重新加载配置”；程序会重新启动并应用新配置，无需手工退出再打开。程序不会覆盖已有配置值，但新版本可能自动补充缺失的程序默认项。补充前会把原文件保存到 `%LOCALAPPDATA%\MedExReportAssistant\backups\`，更新失败则继续使用原文件和安全的内存默认值。修改前先保存正在编辑的报告，再在 Windows 文件资源管理器地址栏粘贴上面的路径，用“记事本”打开。文件编码必须保持为带 BOM 的 **UTF-16 LE**（新版记事本“另存为”窗口的编码选项可选择 `UTF-16 LE`），这样中文才能被 Windows INI API 稳定读取。

最终 schema 为：

```ini
[Config]
SchemaVersion=2

[Features]
GlobalHjklArrows=false

[Hotstring.builtin-red]
Enabled=true
Name=红字插入
Trigger=;red
Text={{red:（见图）}}
```

`[Features]` 保存非 hotstring 功能开关。`GlobalHjklArrows` 默认关闭；旧配置缺少该键时，程序会安全补入 `false`。手动改为 `true` 并重启后，会在所有应用中启用 `RAlt+H/J/K/L` 方向键。无效值保持原样但运行时视为关闭。

每个热字符串 section 必须命名为 `Hotstring.builtin-<stable-id>` 或 `Hotstring.custom-<user-id>`。Schema 2 只使用 `Enabled`、`Name`、`Trigger`、`Text` 四个字段，不再使用 `Mode` 或固定 Left 数。`Text` 中使用两个字符 `\n` 表示换行，使用 `\\` 表示一个普通反斜杠。配置文本只作为文字发送或经过 HTML escaping 后粘贴，不会作为 AHK 代码执行。

模板支持以下双花括号元素：

- `{{cursor}}`：插入后光标停留的位置；每个模板最多一个。
- `{{date}}`：触发时的本机日期，格式为 `yyyy-MM-dd`；可以重复使用。
- `{{red:（见图）}}`：插入红色 `（见图）`；每个模板最多一个，并且必须是模板最后一个元素。

普通单花括号仍是普通文字。未知、拼错、未闭合、重复或位置错误的模板元素会在设置窗口中被拒绝，不会原样插入报告。普通字面量 `（见图）` 始终是黑字；只有精确的 `{{red:（见图）}}` 具有红字含义，不支持其他 `{{red:...}}`。光标若位于插入文字内部，程序只移动光标而不运行 Candidate G；光标在红色尾标记之后时才恢复黑色。普通黑字模板不会调用 Candidate G。

section 在文件中的先后顺序就是注册顺序，不使用单独排序字段。`Trigger` 必须保持不重复。现有配置无法读取、Schema 不支持或迁移不安全时，报告模板会 fail closed，不再回退到另一套内置模板。

内置默认项如下：

| Section | Trigger | Text | Enabled |
| --- | --- | --- | --- |
| `Hotstring.builtin-red` | `;red` | `{{red:（见图）}}` | `true` |
| `Hotstring.builtin-fzg` | `;fzg` | `放射性摄取增高，SUVmax约为{{cursor}}{{red:（见图）}}` | `true` |
| `Hotstring.builtin-fwj` | `;fwj` | `放射性摄取未见明显增高{{red:（见图）}}` | `true` |
| `Hotstring.builtin-fjd` | `;fjd` | `放射性摄取降低{{red:（见图）}}` | `true` |
| `Hotstring.builtin-cmx` | `;cmx` | `cm×{{cursor}}cm` | `true` |

可在文件末尾添加自定义项，例如：

```ini
[Hotstring.custom-warning]
Enabled=true
Name=重点提示
Trigger=;warning
Text=请重点关注该病灶
```

旧 Schema 1 配置首次由本版本启动时，会先进行只读审计，再创建时间戳备份、写入临时文件并验证，最后才替换为 Schema 2。旧 `text`、`red-reset`、`red-left4` 和 builtin `cmx` 会按已知语义迁移；无法无歧义保留的自定义项会阻止迁移并保留原文件。Schema 2 不能由已发布的旧 EXE 正确读取；若要降级，必须退出程序并恢复迁移前备份。

## 可选全局 HJKL 方向键

将配置改为：

```ini
[Features]
GlobalHjklArrows=true
```

重启后，`RAlt+H/J/K/L` 分别发送 `Left/Down/Up/Right`。该功能保持 legacy 的全局作用域，不受 MedEx-only hotstring guard 限制；`Ctrl+Alt+Esc` 可以随其他普通功能一起暂停它。启用前必须退出原始 `legacy/karabiner.ahk`。当前清理后的 `medex_legacy_compat.ahk` 已移除这四个重复按键，可以与 EXE 同时运行。

## 下一开发路线

下一目标是缩短用户可见的关键路径，而不是泛化地缩短函数总运行时间。主要指标是：

```text
TriggerToBlackClickMs = BlackClickSentMs - HotstringTriggeredMs
```

计划按独立检查点推进：基线 timing diagnostics → MedEx-only hotstring scope 与冗余 process check 清理 → 将 clipboard restoration 移到 black click 后并保留安全最小间隔 → 独立验证移除 `;fzg` 的 `Sleep 50` → 独立移除 MedEx version hard gate → 经另行授权后实现本机 layout calibration。

详细顺序、pass/failure 判定以及 Windows 简短结果的续接规则见 `docs/internal/performance-optimization-checkpoints.md`。

## 文档分层

- `docs/internal/`：维护状态、架构、路线图、检查点和发布流程。
- `docs/user/`：普通用户说明、故障处理和紧急停止。
- `docs/technical-investigations/`：有证据边界的技术调查。
- `docs/migration/`：legacy inventory、共存所有权和渐进替代计划。

## 开发原则

- Code and identifiers in English.
- Human-facing documentation in Chinese when appropriate.
- No patient data or credentials.
- No automatic final submission by default.
- Coordinate actions require local calibration and fail-closed checks.
- 不提交患者信息、医院敏感信息、截图、真实内网地址或敏感日志。

## Requirements

- Windows
- AutoHotkey v2
- Target report-writing workstation
- Local calibration for coordinate-sensitive actions

## Repository Layout

```text
legacy/   Preserved historical scripts and compatibility references.
src/      AutoHotkey v2 source modules.
docs/     Maintainer, user, investigation, and migration documentation.
scripts/  Development and release helpers.
release/  Generated single-file release script.
tests/    Static tests and manual workstation checkpoints.
```

## Quick Start for Maintainers

1. 修改 `src/` 或 `docs/`；应用版本只修改 `src/app_metadata.ahk`。
2. 源码变化后运行 `python scripts/build_release.py`；纯文档变化不需要刷新 generated release。
3. Windows 构建机安装 AutoHotkey v2 与 Ahk2Exe 后，双击根目录 `Build EXE.cmd`。
4. 测试 `publish/麦旋风.exe`，按 `tests/manual-test-checklist.md` 和当前 performance checkpoint 完成验证。
5. 只压缩并分发 `publish/` 的内容；不要分发仓库或构建脚本。

当前状态入口：

- `docs/internal/project-status.md`
- `docs/internal/architecture.md`
- `docs/internal/performance-optimization-checkpoints.md`
- `docs/migration/legacy-feature-inventory.md`
