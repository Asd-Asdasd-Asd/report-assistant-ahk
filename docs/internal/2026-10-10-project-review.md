# 2026-10-10 项目整体 Review 与整理 / 优化方案

## 0. 审查基线与证据

- 审查工作区：本地 `fix/automation-readiness` @ `17ee5e9`。`origin/main` 已领先本分支 4 个提交
  （`7de86ae`、`652c957`、`f626f13`、`a1c7738`：Windows 回归工具 UTF-8 读取、打包脚本中断恢复校验、
  hotkey 注册失败提示、配置启动失败时不注册 hotstring）。已核对这 4 个提交的 `src/` diff，
  本文结论对它们同样适用。本分支所有提交都已进入 `origin/main`，远端分支已被删除。
- 静态验证：Python 376 项测试通过；`release/report_assistant.ahk` 与 `src/` 重新生成结果一致
  （忽略时间戳与 revision 行）；`tests/windows/generated/` 下两份合成回归脚本与 builder 输出一致。
- 未做任何 Windows / MedEx 运行时验证。本文所有"性能"判断来自代码阅读与 `automation-events.log`
  已有字段，不是实测数据。
- 本次只新增本文件并移除了一个 worktree，没有修改源码、配置、测试或生成物。

## 1. 仓库与目录整理

### 1.1 已执行

- `/Users/liuzhu/1.Project/medex-ahk-montage-fix` 是本仓库的 git worktree（分支
  `fix/montage-combo-readiness` @ `36be182`），该分支已通过 `cf2847e` 合并进 `main`，
  工作区干净、无未跟踪文件。已用 `git worktree remove` 移除，`git worktree prune` 清理注册。

### 1.2 建议执行（Git 层，低风险）

```bash
git checkout main && git pull --ff-only
git branch -d fix/automation-readiness fix/montage-combo-readiness
```

本地 `main` 落后 `origin/main` 6 个提交；两个本地分支内容都已在 `origin/main` 中，`-d` 只在已合并时才删除。
以后如果 Codex / Claude 并行开发，建议统一用 `git worktree` 加固定目录前缀（例如 `../medex-ahk.wt/<branch>`），
避免再出现"不知道何时冒出来"的目录；或者干脆不用 worktree，只用分支。

### 1.3 文档整理

| 位置 | 问题 | 建议 |
| --- | --- | --- |
| `docs/hotkeys.md`、`docs/installation.md`、`docs/release-process.md` | 与 `docs/user/hotkeys.md`、`docs/user/quick-start.md`、`docs/internal/release-checklist.md` 内容重叠，且 `hotkeys.md` 是英文旧版 | 删除根目录三份，README 链接改指 `docs/user/` 与 `docs/internal/` |
| `docs/internal/` 27 个文件 | 其中约 14 份是 7–9 月的调查、checkpoint、交接记录（`passive-zmq-exploration`、`mxnmsoft-*`、`viewer-adaptive-runtime-checkpoints`、`viewer-context-menu-diagnostic`、`mxnm-montage-control-diagnostic`、`mxnm-montage-lung-field-test`、`medex-package-findings`、`performance-optimization-checkpoints`、`mxnm-montage-migration-handoff`、`mxnm-montage-combo-readiness`、`automation-readiness`、`2026-09-06-design-audit`、`report-image-caption-migration`、`mxnm-viewer-tool-hotkeys`） | 移到 `docs/history/`（或并入 `docs/technical-investigations/`），`docs/internal/` 只保留常青文档：`architecture`、`decisions`、`project-status`、`roadmap`、`maintenance`、`release-checklist`、`configuration-architecture`、`automation-diagnostics`、`viewer-failure-diagnostics`、`user-documentation-guidelines`、`icon-assets` |
| `debug/` | 名字含义模糊；实际是 Candidate G 现场诊断脚本 + 3 份现场日志 | 脚本移到 `tools/field-testing/candidate-g/`，日志移到 `docs/field-tests/` |
| `docs/internal/update-notes/` | 与 `CHANGELOG.md`、`assets/publish/更新说明.md` 三处记录同一件事 | 只保留 CHANGELOG（开发者）+ `assets/publish/更新说明.md`（用户）；update-notes 归档 |

### 1.4 源码中的死代码与矛盾

| 文件 | 情况 | 建议 |
| --- | --- | --- |
| `src/viewer_actions.ahk` | 三个函数全是占位符，无调用 | 删除 |
| `src/utils.ahk` | `WithMouseRestore`、`ClickPoint` 及 `COORDINATES` 无生产调用 | 删除，只留 `Flash` |
| `src/window_guard.ahk` | `FocusViewer` / `FocusReportEditor` 无调用 | 删除这两个包装 |
| `src/config.example.ahk` + `#Include *i config.local.ahk` | `RED_TEXT_MODE`、`RED_TEXT_COLOR`、`RED_TEXT_RESET_TO_BLACK`、`COORDINATES` 从未被读取；更重要的是 `build_release.py` 会剥掉所有 `#Include` 行，所以 `config.local.ahk` 在编译后的 EXE 里根本不生效，`REPORT_EDITOR_EXE` / `VIEWER_EXE` 实际上是常量 | 把两个 EXE 名并入 `FeatureDefaults`（或 `config.ini` 的 `[Targets]` 段），删除 `config.example.ahk` 与 `*i` include，消除"看起来可配置实际不可配置"的误导 |
| `src/report_editor.ahk` | `RunFzgInsertion`、`RunRedInsertion`、`ResetReportFormattingPlaceholder` 仅 `debug/` 脚本使用 | 随 debug 脚本一起移到 field-testing 库 |
| `src/mxnm_config_geometry_provider.ahk`（769 行）、`src/mxnm_measurement_target_resolver.ahk`（1346 行）、`src/mxnm_config_path_cache.ahk`（99 行） | `AGENTS.md` 已声明 config-only 几何路径不是生产入口，但三者仍编入 release（约占 26k 行中的 9%），并在 `mxnm_viewer_tool_commands.ahk:223`、`mxnm_viewer_runtime_probe.ahk:205` 被引用；它们还在运行时读取 vendor 的 INI 文件（外部文件依赖） | 先确认 `mxnm_viewer_tool_commands.ahk:223` 的 `LoadStaticConfig` 是否仍在生产调用链上（设计审计称已改为 live 路径）；若仅 probe / checkpoint 使用，整体移入 `tools/field-testing/lib/`，从 `build_release.py` 的 `ORDER` 剔除 |

### 1.5 脚本整理

- `scripts/` 下 7 个 `build_*_diagnostic / regression / checkpoint.py` 各自复制了 `between()`、读文件、剥 include、
  拼接逻辑；`build_mxnm_viewer_adaptive_checkpoint.py` 还复制了一份 `build_release.py` 的 `ORDER`。
  → 抽一个 `scripts/ahk_bundle.py`（`read_component`、`strip_includes`、`between`、`stamp_metadata`），
  各 builder 只保留"取哪些片段"的声明。
- `build_exe.ps1`（418 行）与三份 `build_*_exe.ps1`（177 / 220 / 177 行）大量重复。
  → 合并为 `build_exe.ps1 -Script <path> -Out <name>`，三份 `.cmd` 只传参数。
- `tests/windows/generated/` 提交生成物是对的（Windows 机器可能没有 Python），但要有一个 Python 测试断言
  "已提交生成物 == builder 当前输出"，否则会悄悄漂移。现有 `test_readiness_regression.py` 等只构建到临时目录，
  建议补一条比对测试。

## 2. 架构评估

### 2.1 做得好的地方（保留）

- 分层明确：`measurement_model / parser / clipboard` → `context_measurement_provider` → `mxnm_measurement_provider`
  → `hotstrings`；MedEx 特定交互集中在 adapter / provider，fail-closed 原则在各模块一致。
- 单实例 mutex、配置 schema 迁移（备份 → 临时写入 → 复验）、设置保存后整体 `Reload()`，都是简单且可靠的选择。
- 发布链路简单：拼接 → Ahk2Exe → 单 EXE。UIA 库 pinned 在仓库内，运行时只依赖 `%LocalAppData%` 下的配置、
  日志和机器 profile。**自包含要求目前是满足的**，唯一的外部文件依赖就是 1.4 中的 vendor INI 读取。
- 诊断已有 session / operation / stage 概念和各阶段时间戳，性能优化有现成的测量入口。

### 2.2 问题 A：模块粒度失衡

4 个文件超过 1000 行：`report_image_caption`（1387）、`mxnm_measurement_target_resolver`（1346）、
`adapters/medex_report_editor`（1084）、`mxnm_montage`（1046）。每个都把"目标发现、等待策略、执行、
诊断上下文拼装、失败码"揉在一起。典型例子：`ReadMxNMMeasurementWithTarget` 约 100 行在手工把 target 的
同一组字段分别复制进 `result.context` 和两个诊断 `Map`，三次列举同样的键。

### 2.3 问题 B：同类基础能力有 3–5 份实现

| 能力 | 现有实现（节选） |
| --- | --- |
| 点在矩形内 / 矩形包含 | `MxNMContextRectContainsPoint`、`MxNMPointInsideRect`、`ReportImageCaptionRectContainsPoint`、`MxNMMontageRectInside`、`MxNMPointInsideRuntimeFrameClient` |
| root owner 解析 | `ResolveMxNMRootOwnerHwnd`、`ReportImageCaptionRootOwner`、`MxNMMontageRootOwner` |
| 窗口 PID / 进程名 | `MxNMTargetWindowPid`、`ReportImageCaptionWindowPid`、`ReportImageCaptionWindowProcess`、`MedExForegroundTargetMatches` 内联 |
| client rect（屏幕坐标） | `GetClientRectScreenMap`、`ReportImageCaptionClientRect`、`MxNMTargetClientRectScreen`、`GetContextMeasurementClientRectScreen`、`MxNMMontageWindowRect` |
| 前台校验 | `MedExForegroundWindowMatches`、`MedExForegroundTargetMatches`、`ReportHotstringTargetMatches`、`MedExViewerForegroundActive`、`MedExViewerToolForegroundActive`、`MxNMMontageViewerStillActive`、`ReportImageCaptionForegroundActive` |
| 有界轮询 | `A_TickCount` 手写 deadline 循环在 15 个文件中约 120 处；超时常量散落（1500 / 1000 / 900 / 600 / 300 / 2500 / 1200 ms） |
| 剪贴板事务 | 三个 owner 各自实现 save / sentinel / wait / restore：`clipboard_html`、`measurement_clipboard`、`report_image_caption` |
| 结果对象 | `{ok, code, …}` 字面量 300+ 处、`Map(...)` 上下文 162 处；字段名不统一（`.ok` 与 `.Ok` 并存，例如 `ReportConfigMigrationResult.Ok`、`MakeViewerToolHotkeyValidation().Ok`） |
| 日志 | 4 个文件、各自 rotate：`startup.log`、`viewer-failures.log`、`automation-events.log`、montage progress log |

这是"之后加功能"时最大的成本来源：每加一个 Viewer 功能，就会再长出一套 rect / owner / 前台 / 轮询 / 结果对象。

### 2.4 问题 C：功能接入需改 5 处

新增一个带设置的 hotkey 功能要同时改 `feature_model`、`feature_normalization`、`feature_config`、
`features.ahk`、`settings_ui.ahk`（881 行中大量是逐字段重复的控件代码）。没有"功能注册表"。

### 2.5 问题 D：测试策略把实现文本锁死

Python 测试中 `assertIn / assertNotIn / index` 约 1763 处，18 个测试文件直接读源码字符串。
`2026-09-06-design-audit.md` 第 5 条已指出这一点。后果：任何重命名或拆文件都要同步改几十个测试，
而测试通过并不能说明行为正确。真正的行为验证只有 Windows 合成回归（`tests/windows/generated/`）和现场。

## 3. 性能评估（代码推断，待实测）

### 3.1 `;fzg` 一次触发的时间去向

```text
HotIf(WinActive ×2)
→ ValidateReportTemplate
→ ResolveTarget        cache hit: 快速校验；miss: 发现 + 最多 1500 ms readiness 轮询
→ context menu 命令    popup 发现 + SendMessageTimeout(1000 ms 上限)
→ clipboard wait       最多 1000 ms，20 ms 轮询；RestoreSettleMs 100
→ SendText 正文
→ PrepareMedExRedReset UIA 锚点查询，最多 1500 ms readiness
→ CF_HTML 粘贴         固定 30 + 80 + 100 ms；caret settle 60 ms
→ Candidate G 颜色恢复 像素采样 + 相对鼠标点击 + popup signature
→ clipboard restore    最小 300 ms paste-to-restore 间隔
→ annotation cleanup   第二次 context menu 往返
```

成功路径上的**固定** `Sleep` 合计约 300–400 ms；其余全部是 UIA 跨进程查询和有界轮询。
UIA 查询（`ElementFromHandle` + 全窗口 `FindFirst / FindAll`：`FindMedExDocument`、
`CollectMedExTextAnchorSnapshot`、Caption 的整窗 Pane 查询）是最大的不确定项，对 Electron
应用尤其慢，因为它的 UIA 树深且会变。

Map 拼装、诊断字段复制、字符串处理在 AHK 里是微秒级，**不是瓶颈，不要优化这些**。
启动时加载 26k 行脚本和 UIA COM 初始化只发生一次；`Reload()` 秒级，可接受。

### 3.2 性能建议（按顺序）

1. **先测量再改。** `automation-events.log` 已有 stage 时间戳。在托盘"复制诊断信息"里加一个
   "最近 N 次操作各阶段耗时表"（target resolve / command / clipboard wait / paste / color reset /
   cleanup），目标机器跑 20 次取 p50 / p95。没有这张表之前不要调任何 Sleep 或超时。
2. **收缩 UIA 查询范围。** 用 `TreeScope.Children` 或限定子树、`CacheRequest` 一次取回需要的属性
   （UIA-v2 支持 `ElementFromHandle(hwnd, cacheRequest)`），避免整窗 Pane 查询。
   这是最可能带来可感知改善的一项，也是 `automation-readiness.md` 已经指出的方向。
3. **固定 Sleep 换成可观察条件。** `clipboard_html` 的 30 / 80 / 100、`RestoreSettleMs 100`、
   `EmptyResultSettleMs 40`：粘贴完成可观察 clipboard sequence number 或 UIA 文档长度变化；
   只有确实不可观察的才保留固定等待（这本来就是项目原则，落实它）。
4. **annotation cleanup 异步化（待现场评估）。** 报告写入成功后用 `SetTimer(-1)` 执行清除，
   用户感知延迟少一次 context menu 往返；代价是清除失败的提示会延后。需要现场判断是否可接受。
5. HotIf 回调里的 `WinActive` 调用很便宜，不用动。

## 4. 分阶段整理方案（面向持续加功能）

### Phase 0：清理，无行为变化（约 1–2 个工作日）

- 1.2 的 Git 清理；1.3 文档归档；1.4 死代码删除与 EXE 名常量化；1.5 脚本合并。
- 测试：把"只检查某个函数名存在"的断言删掉，保留"顺序 / 安全不变量"类断言
  （clipboard `finally` 恢复、不自动重试、不 blind click）。
- 完成后重新生成 release，Python 测试与 `git diff --check` 通过即可，不需要 Windows 验收。

### Phase 1：抽公共层 `src/core/`，行为不变（约 3–5 个工作日，每步可独立提交）

| 新文件 | 内容 | 替换对象 |
| --- | --- | --- |
| `core/win32_window.ahk` | pid、进程名、root owner、client rect、point-in-rect、window-from-point、is-descendant | 2.3 表前四行的所有副本 |
| `core/foreground_guard.ahk` | `ForegroundGuard(expectedHwnd, expectedExe)` + `.StillValid()` | 7 个前台校验函数 |
| `core/wait.ahk` | `WaitUntil(predicate, timeoutMs, pollMs, cancel := 0)` → `{ok, elapsedMs, reason}`；`Timing` 类集中所有超时常量并注明哪些有现场证据 | 约 30 处手写轮询 |
| `core/result.ahk` | `Result.Ok(data)` / `Result.Fail(code, details)`；统一 `.ok / .code / .details` | 逐模块迁移字面量 |
| `core/clipboard_transaction.ahk` | `ClipboardTransaction.Run(action, opts)`：save、sentinel、wait、restore、最小间隔、单一 `finally` | 三个 owner。**这是安全边界最敏感的一步**，必须配合 `readiness_regression_standalone.ahk` 在 Windows 验证 |
| `core/diagnostics.ahk` | 一个 logger（session、rotate、隐私字段过滤）；4 个日志文件名保持不变（用户文档已引用） | 4 套写入 / rotate 实现 |
| `core/uia_query.ahk` | 封装 `ElementFromHandle` + `CacheRequest` + 范围限定 + 计时 | 所有 UIA 调用经过它，方便 3.2 第 1 条统计 |

顺序建议：`result` → `win32_window` → `foreground_guard` → `wait` → `diagnostics` → `uia_query` → `clipboard_transaction`
（最敏感的放最后，前面的都完成且 Windows 回归通过后再动）。

### Phase 2：功能模块化，作为"加功能"的模板（约 3–5 个工作日）

- 定义 feature module 约定：每个功能一个文件，导出 `Definition()`（id、默认 chord、设置字段、
  HotIf 上下文、是否默认关闭）和 `Invoke(ctx)`。`features.ahk` 改为遍历注册表；`settings_ui`
  根据 definition 自动生成设置行。之后加一个新 Viewer 功能 = 新增一个文件 + 一行注册。
- 处理 1.4 中的旧几何路径：确认后移出 release。
- 拆 `adapters/medex_report_editor.ahk` 为 `medex/color_reset_relative_mouse.ahk`、
  `medex/color_reset_uia.ahk`、`medex/report_document.ahk`；拆 `report_image_caption.ahk` 为
  target 发现 / 捕获 / 复用 / 几何四块；`mxnm_montage.ahk` 拆为 settings / session / control 三块。

### Phase 3：性能（需要 Windows 实测数据）

按 3.2 顺序执行；每一项都要有"改前 / 改后 p50 / p95"记录进 `docs/field-tests/`。

## 5. 约束：不建议做的事

- 不引入任何外部运行时（.NET、Python、第三方 DLL）。以上全部建议都在 AHK v2 + 现有 pinned UIA 库内完成，
  单 EXE 自包含不变。
- 不把 Python 测试改成"真的跑 AHK"（macOS 做不到），而是降低对实现文本的耦合、扩展 Windows 合成回归
  （`tests/windows/generated/` 这套模式很好，继续用）。
- 不改变 fail-closed 语义、clipboard 单 owner + `finally` 恢复、不自动重试这些安全边界；重构只是把它们
  集中到一处实现。
- 不为了性能删除 target 唯一性校验或 popup signature 检查。

## 6. 可直接转为任务的清单

| # | 事项 | 阶段 | 需要 Windows |
| --- | --- | --- | --- |
| 1 | `git pull --ff-only` 主干，删除两个已合并本地分支 | 0 | 否 |
| 2 | 删除 `docs/` 根下三份重复文档；`docs/internal/` 历史文档归档到 `docs/history/` | 0 | 否 |
| 3 | `debug/` 迁到 `tools/field-testing/candidate-g/`，日志迁到 `docs/field-tests/` | 0 | 否 |
| 4 | 删除 `viewer_actions.ahk`、`utils` 坐标 helper、`window_guard` 包装；EXE 名常量化，移除 `config.example.ahk` / `config.local` 机制 | 0 | 否 |
| 5 | `scripts/ahk_bundle.py` + 合并 `build_*_exe.ps1`；补"生成物与 builder 一致"测试 | 0 | 否 |
| 6 | 清理只检查函数名存在的 Python 断言 | 0 | 否 |
| 7 | `core/result`、`core/win32_window`、`core/foreground_guard`、`core/wait` | 1 | 回归脚本 |
| 8 | `core/diagnostics` 合并 4 套日志实现 | 1 | 回归脚本 |
| 9 | `core/uia_query` + 阶段耗时汇总输出 | 1 | 是 |
| 10 | `core/clipboard_transaction` 统一三个 owner | 1 | **是，必须** |
| 11 | 确认并移出旧 config-geometry 路径 | 2 | 是 |
| 12 | feature registry + settings 自动生成 | 2 | 是 |
| 13 | 拆分四个 >1000 行文件 | 2 | 回归脚本 |
| 14 | 延迟预算表 → UIA 范围收缩 → 固定 Sleep 替换 → cleanup 异步化评估 | 3 | **是** |

## 7. 进度（2026-10-10，分支 `refactor/core-cleanup`）

| 事项 | 状态 |
| --- | --- |
| 1 Git 清理、2 文档归档、3 debug 迁移、4 死代码与 EXE 常量、5 脚本合并 + 生成物一致性测试 | 完成，Python 测试与生成物比对通过 |
| 6 清理只检查函数名的断言 | 未做整体清扫；本轮只改了因重构必须改的断言，其余留到对应模块重构时一起处理 |
| 7 `core/win32_window`（含前台判断） | 完成，**待 Windows 验证** |
| 8 `core/log_file` | 完成，**待 Windows 验证** |
| 7 中的 `core/result`、`core/wait` | 未开始，等本轮 Windows 验证通过后再做 |
| 9–14 | 未开始 |

### 本轮 Windows 验证清单

1. 在仓库根目录运行 Python 测试（Windows 下会额外执行 `test_maintenance_windows.py` 的真实 AHK 用例）：

   ```powershell
   python -m unittest discover -s tests -p "test_*.py"
   ```

2. 运行两份合成回归，均应输出 PASS 且无 `#Warn` 提示：

   ```powershell
   AutoHotkey64.exe /ErrorStdOut tests\windows\generated\readiness_regression_standalone.ahk
   AutoHotkey64.exe /ErrorStdOut tests\windows\generated\viewer_state_regression_standalone.ahk
   ```

3. 用 `Build EXE.cmd` 构建，启动 EXE，确认托盘出现、`%LocalAppData%\MedExReportAssistant\logs\startup.log` 新增一条 `STARTED`。
4. 现场回归（非临床测试区），每项做一次首次 + 一次连续：`;fzg`（SUVMax 读取 + 红字）、`;cma`（尺寸）、
   Viewer 箭头 / 长度 / 3D SUV / 截图 / 清除标注、Shift+Alt+S 快速标图、三种 Montage。
5. 任一失败后先在托盘"复制诊断信息"，确认 `viewer-failures.log` / `automation-events.log` /
   `montage-progress.log` 仍写入同一 `logs\` 目录并按原大小轮转。
6. 现场工具 EXE 至少构建一个（例如 `tools\field-testing\Build Viewer Checkpoint EXE.cmd`），
   确认新的 `build_tool_exe.ps1` 参数传递正常。
