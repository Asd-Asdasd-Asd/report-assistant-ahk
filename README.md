# Report Assistant AHK

Report Assistant AHK 是一个私有 AutoHotkey v2 项目，用于 Windows 报告书写和阅片窗口自动化辅助。

## 当前状态

Step 4 基线为 `5193403`；`2369b68`（tag `v0.6.0-candidate-g`）是 Candidate G promotion 基线。Step 5 已通过 Windows G1/G2 metadata-override 与 generated-release 验收：MedEx version 现在是 diagnostics-only metadata。`relativeMousePixelValidated` 已是 production default：UIA 精确定位 `Name="检查所见"`，经过 profile geometry 校验后以相对坐标打开颜色菜单，四点 popup signature 匹配后最多单击一次黑色。`uiaInvoke` 仅保留为显式 comparison/rollback；两种策略之间没有 automatic fallback。

2026-07-16 Windows 现场已验证 generated release、Candidate G black reset、phrase-specific `;fzg` caret workflow 和最终 mainline behavior；promotion 当时记录为 `75 tests passed`。本项目仍是早期内部原型，不适合科室范围推广或无人值守使用。当前 layout 只在 MedEx 0.0.1.0、1920×1080、100% scaling、DPI 96 上完成校准和现场验证。

进程状态不再是“完全未确认”：现场确认的主进程是 `medexworkstations.exe`；代码暂时兼容保留 `medexworkstation.exe`。

## 当前行为边界

- `;red`：把配置的 `Text` 作为 CF_HTML 红字粘贴，再运行 Candidate G 将后续输入颜色恢复为黑色，最后由 `finally` 恢复 clipboard。
- `;fwj`、`;fjd`：保留历史混合颜色行为；完整 `Text` 末尾的 `（见图）` 单独作为红色 CF_HTML，之前的文字按普通黑字输入，再运行 Candidate G。
- `;fzg`：保留历史混合颜色行为；黑色前缀之后仅粘贴红色 `（见图）`，依次执行 clipboard restore、固定 `Left 4`；不运行 Color Reset，也不增加额外 settle。
- `;cmx`：插入 `cm×cm` 并 `Left 2`。
- Production success 不写 heavy log；failure 写 privacy-safe lightweight log；field mode 才写详细 timing、geometry、UIA 和 pixel diagnostics。
- 全局 pause/exit 分别为 `Ctrl+Alt+Esc`、`Ctrl+Alt+Q`。
- Step 2 的 MedEx-only shared `#HotIf` guard 已由 `7a0d9a2` 提交。
- Step 3 已将 Candidate G 移到 clipboard restore 前，并以 field-approved 300 ms minimum paste-to-restore interval 保护 fast failure；Windows success/fast-failure 均已通过。
- Step 5 candidate 不再用 exact MedEx version 阻止 runtime/calibration；实际版本、校准版本和 match state 继续写入 diagnostics。Resolution、DPI、scaling 和所有 interaction guards 保持 hard gate。

## 自定义报告热字符串

程序首次启动时会创建：

```text
%LOCALAPPDATA%\MedExReportAssistant\config.ini
```

已有文件永远不会被程序覆盖。配置只在启动时读取，不支持 hot reload；修改后必须退出并重新启动 Report Assistant。建议先退出脚本，再在 Windows 文件资源管理器地址栏粘贴上面的路径，用“记事本”打开。文件编码必须保持为带 BOM 的 **UTF-16 LE**（新版记事本“另存为”窗口的编码选项可选择 `UTF-16 LE`），这样中文才能被 Windows INI API 稳定读取。

最终 schema 为：

```ini
[Config]
SchemaVersion=1

[Hotstring.builtin-red]
Enabled=true
Name=红字插入
Trigger=;red
Text=（见图）
Mode=red-reset
```

每个热字符串 section 必须命名为 `Hotstring.builtin-<stable-id>` 或 `Hotstring.custom-<user-id>`。支持的字段只有 `Enabled`、`Name`、`Trigger`、`Text`、`Mode`；未知字段会被忽略，不要添加 `Order`。`Text` 中使用两个字符 `\n` 表示换行，使用 `\\` 表示一个普通反斜杠。配置文本只作为文字发送或经过 HTML escaping 后粘贴，不会作为 AHK 代码执行。

支持三种 `Mode`：

- `text`：在当前 caret 位置插入普通黑字。
- `red-reset`：将 `Text` 作为普通黑字输入，在末尾插入红色 `（见图）`，然后运行现有 Candidate G black reset。
- `red-left4`：将 `Text` 作为普通黑字输入，在末尾插入红色 `（见图）`，跳过 Candidate G，并在 clipboard restore 后执行固定 `Left 4`。

如果 red mode 的 `Text` 已经以 `（见图）` 结尾，该标记会被拆出并作为唯一的红色内容，不会重复追加。`Text` 其他位置的所有内容都保持黑色；`text` mode 不追加红色标记。

section 在文件中的先后顺序就是优先级；不使用单独的排序字段。`Trigger` 重复时，第一个 enabled、字段有效并且成功注册的 entry 生效。`Enabled=false` 不注册该项。空 `Trigger`、未知 `Mode` 或无效 `Enabled` 的 section 会跳过，其他有效 section 仍会工作；文件缺失、不可读、schema 不支持或没有任何有效 entry 时，运行时安全回退到内置默认值。

内置默认项如下：

| Section | Trigger | Text | Mode | Enabled |
| --- | --- | --- | --- | --- |
| `Hotstring.builtin-red` | `;red` | `（见图）` | `red-reset` | `true` |
| `Hotstring.builtin-fzg` | `;fzg` | `放射性摄取增高，SUVmax约（见图）` | `red-left4` | `true` |
| `Hotstring.builtin-fwj` | `;fwj` | `放射性摄取未见明显增高（见图）` | `red-reset` | `true` |
| `Hotstring.builtin-fjd` | `;fjd` | `放射性摄取降低（见图）` | `red-reset` | `true` |
| `Hotstring.builtin-cmx` | `;cmx` | `cm×cm` | `text` | `true` |

`builtin-cmx` 在默认 `text` 模式下继续保留历史固定 `Left 2` 行为；它不是用户配置字段。所有其他 position、color、coordinate、timing、offset 和 Left-count 均不可配置。

所有 builtin 和 custom entry 使用相同的 red mode 规则：正文保持普通黑字，只有末尾完整的 `（见图）` 使用红色 CF_HTML。现有 builtin 的 `Text` 已包含该标记，因此运行时会拆分而不是再次追加，已有用户配置文件无需重写。

可在文件末尾添加自定义项，例如：

```ini
[Hotstring.custom-warning]
Enabled=true
Name=重点提示
Trigger=;warning
Text=请重点关注该病灶
Mode=red-reset
```

上述示例最终输出黑色 `请重点关注该病灶`，并在末尾追加红色 `（见图）`。

内置项和自定义项进入同一个 `HotstringEntry` 模型、动态 `Hotstring()` 注册器和 mode dispatcher，并继续共用 MedEx-only foreground guard。

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
3. 在 Windows 工作站使用 AutoHotkey v2 测试生成文件。
4. 按 `tests/manual-test-checklist.md` 和当前 performance checkpoint 完成验证。

当前状态入口：

- `docs/internal/project-status.md`
- `docs/internal/architecture.md`
- `docs/internal/performance-optimization-checkpoints.md`
- `docs/migration/legacy-feature-inventory.md`
