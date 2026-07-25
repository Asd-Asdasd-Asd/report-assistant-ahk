# 项目状态与交接

更新时间：2026-07-26
当前版本以 `src/app_metadata.ahk` 为唯一真源，并显示在 EXE“关于麦旋风…”和发布目录 `版本信息.md`。

## 当前 mainline

- Application version source：`src/app_metadata.ahk`；版本号只在这里人工修改。
- Config：Schema 2，路径 `%LocalAppData%\MedExReportAssistant\config.ini`。
- Portable artifact：`publish\麦旋风.exe`。
- Production color-reset strategy：`relativeMousePixelValidated`。
- Explicit comparison/rollback：`uiaInvoke`。
- Automatic cross-strategy fallback：无。
- 当前验证 profile：MedEx `0.0.1.0`、1920×1080、100% scaling、DPI 96。
- 当前 application version：`0.6.1`。

## 当前已实现

- 固定 `Local\MedExReportAssistant.Singleton` 在 config bootstrap 前保护不同版本、文件名和目录。
- Schema 2 template engine 支持 `{{cursor}}`、`{{date}}`、`{{suvmax}}`、`{{size}}`、`{{red:（见图）}}`。
- 普通字面量 `（见图）` 保持黑色；caret movement 和 Candidate G 均由 `ReportTemplatePlan` 派生。
- Schema 1 配置可经只读审计、backup、临时写入和最终验证一次性升级；legacy Mode 只存在于 migration module。
- 原生 Settings UI 支持稳定 Section identity、ListView sorting、custom add/delete、builtin edit/disable、template-element insertion、严格校验和事务保存。
- 保存设置后执行完整 `Reload()`；托盘“重新加载配置”同样是全脚本 Reload。
- report hotstrings 通过 shared MedEx-only foreground predicate 限制作用窗口；`Ctrl+Alt+Esc` 与 `Ctrl+Alt+Q` 保持 suspend-exempt/global。
- CF_HTML、clipboard `finally` restoration、Candidate G popup signature 和 at-most-once clicks 保持 fail closed。
- 正式图标以 `assets/icon/source/medex-icon.svg` 为 source，由 `scripts/generate-icon.sh` 生成多尺寸 PNG/ICO。
- Windows 一键构建自动生成 release source、以 `/icon` 嵌入 ICO、编译 temporary EXE、同步静态发布资源并事务提升 final。
- v0.6.0 SUVMax workflow 已接入通用 `{{suvmax}}` 模板：自动 target、strict parser、报告事务和右键清除 provider 均已实现；`NOT_ANNOTATED`/失败会留下人工输入锚点，失败提示为无焦点视觉浮层。
- v0.6.x measurement target 已改为 config-only on-demand resolution：首次成功发现 viewer 后持久化经验证的 process path，后续应用启动直接从固定相对路径读取 vendor config 并建立静态 plan，不需要 viewer 窗口存在；进程生命周期只缓存 `mainGeometry`、跨布局 `logicalPoint`、配置 hash 和 viewer process path。每次读取重新查找唯一 runtime frame、读取当前 rect、映射 `screenPoint`，并执行 `WindowFromPoint`、PID、进程路径、进程名和 client-rect 校验。measurement target 不再使用 UIA、shell hook、后台 warmup、重试或 15/60 秒轮询；Windows 现场已确认启动约 4 秒后配置 plan 可用，后续 `;fzg` 延迟稳定。
- v0.6.0 长短轴 workflow 已接入通用 `{{size}}` 模板，共用自动 target、context popup transport、clipboard restore、报告事务和标注清除。`复制直线测量值` 的新鲜空剪贴板映射为 `NOT_ANNOTATED`；1-3 个正数严格解析后按数值降序输出，使用 `×` 和逐项 `cm`。未标注或失败时留下人工输入锚点，可继续使用 `;cmx`。
- v0.6.x 增加 builtin `;cma -> {{size}}`。现有配置通过 additive reconciliation 获取该入口：默认 trigger 空闲时直接启用；已有等价 custom `;cma` 时不重复添加；已有不同用途的 `;cma` 时保留用户条目，并以禁用的 `;cma-size` 添加 builtin。配置 normalization 失败或 trigger 重复时继续整体 fail-closed，同时显示无焦点视觉提示。
- v0.6.1 增加默认关闭的箭头、长度测量和 3D SUV Viewer 工具快捷键。三项共用 config-derived button plan、runtime frame mapping、native HWND/control-ID 校验和直接父窗口 `WM_COMMAND / BN_CLICKED`；不依赖 UIA、hover、鼠标移动、焦点切换或后台轮询。
- 历史 Config + UIA measurement target checkpoint 已通过 Windows 验证；当前 config-only production resolver 保留相同跨布局安全点、runtime frame mapping、action HWND ownership 和 transport invariants，并已完成当前工作站 Windows 延迟与 transport 复验。

## 验证状态

### Windows 现场已验证

- Candidate G calibration、controlled interaction、caret-order A/B 和 generated-release mainline。
- `;fzg` no-reset caret workflow、clipboard restoration 和 immediate black typing。
- MedEx-only hotstring scope、foreground change fail-closed、version diagnostics-only behavior。
- 当前 supported profile 上的 red marker 与 black reset 主路径。
- v0.6.0 SUVMax provider 的 `FOUND`、`NOT_ANNOTATED` 和 `VIEWER_NOT_FOUND` 路径；background popup/command、clipboard freshness/restoration、foreground/mouse invariants 和无音频视觉反馈均通过现场验证。
- Config + UIA 主图区 resolver foundation：唯一 runtime frame、logical-to-runtime mapping、9→1 UIA Pane geometry match，以及相同布局三次稳定复验。
- Field-only automatic target：21 个声明布局的 maximin point、非目标活动 pane `FOUND`、完整 no-focus/no-mouse/clipboard invariants，以及 viewer-missing early fail-closed。
- Production `;fzg` FOUND path：自动插入结果正确，target cache 后延迟可接受。
- `删除全部标注` field path：`CleanupState=OK`、command invoked、无 confirmation、复查 `NOT_ANNOTATED`，foreground/mouse 均保持不变。
- 长短轴 workflow 已在 Windows 完成端到端验证并由用户确认通过。
- Config-only measurement target：无 UIA、无 warmup timer、无周期轮询的启动缓存和按次 runtime mapping 已通过当前工作站复验。
- v0.6.1 Viewer 工具快捷键：箭头 `21043`、长度 `21048`、3D SUV `21193` 均已验证；从 Viewer/报告窗口切换焦点后单次触发成功，foreground 与鼠标保持不变。

### 自动测试覆盖

- Schema 1→2 migration、Schema 2 template grammar、date/cursor/red plan semantics。
- Settings Section identity、排序后选择/编辑/删除、Text codec 和事务保存。
- CF_HTML offsets、Candidate G pure rules、dispatcher safety、single-instance/build integration。
- icon generation inputs与 Windows Ahk2Exe `/icon` wiring。
- measurement result/parser、sentinel + clipboard sequence freshness、single restore owner、provider dynamic popup/command identity 和 privacy-safe field harness。
- Viewer command schema、三按钮坐标映射、设置读写、hotkey registration 和 generated-release integration。

当前完整 Python suite 为 247 tests；Windows AHK harness 仍是 compiled/runtime 行为的最终依据，macOS 静态测试不能替代。

## 当前 production flow

```text
configured report hotstring
→ optional MxNMMeasurementProvider.ReadSuvMax()/ReadLineAxes()
→ BuildReportTemplatePlan(runtimeContext)
→ send PlainText
→ optional red CF_HTML transaction
→ caret internal: derived Left count, no Candidate G
→ caret after red suffix: Candidate G preflight and reset
→ minimum paste-to-restore interval if required
→ ClipboardAll restoration in finally
→ structured result
→ FOUND + report transaction success: DeleteAll + NOT_ANNOTATED verification
```

Candidate G：

```text
exact UIA Name="检查所见"
→ supported profile geometry
→ arrow click at most once
→ four-point popup signature
→ black click at most once
→ mouse restore
```

## 已知限制与延期

- **重新编译后的首次颜色下拉操作**：偶尔会正确选中黑色，但颜色菜单仍留在屏幕上；之后的操作通常正常。当前不增加额外 blind click 或自动重试。Windows release 验收需记录是否复现、菜单状态和后续一次行为。
- 其他 resolution/DPI/scaling、multi-monitor/per-monitor DPI 和 MedEx layout 尚未正式支持。
- Compatibility layer 的 Alt+Shift+S 只保证单次触发；持续按住修饰键连续按 S 延后到 compatibility 重构。
- updater、installer、self-update、rollback、shortcut 和 registry installation state 均不在范围内。
- SUVMax、long-axis/short-axis、automatic target、production orchestration、`删除全部标注` 清除链及 cache latency 已进入 v0.6.0 baseline。更细的 failure injection 和多模板 measurement/caret 组合属于 v0.6.x 后续验证，不扩大 v0.6.0 release scope。
- Config logical-to-runtime mapping 和 privacy-safe UIA geometry-only 唯一重找已通过当前工作站相同布局三次复验；其他布局/profile 尚未正式验证，active `ShowModelN` 识别仍不属于当前 checkpoint。
- Settings 的“其他”标签页仍是占位页；“快捷键”页已用于三项 Viewer 工具。

## v0.6.x 后续验证

1. 补充 measurement failure injection 和 privacy-safe field evidence。
2. 继续验证其他 resolution/DPI/scaling、viewer layout 和 workstation profile。
3. 单独探索报告正文/caret 的只读可见性，不进入 v0.6.0 release。
4. 暂缓同一模板同时支持 `{{suvmax}}` 与 `{{size}}`；需要独立设计多 measurement anchor/caret 语义。

下一阶段证据和边界见：

- `docs/internal/mxnmsoft-measurement-investigation.md`
- `docs/internal/mxnmsoft-config-driven-automation.md`
- `docs/internal/mxnm-viewer-tool-hotkeys.md`
- `docs/internal/passive-zmq-exploration.md`
