# 项目状态与交接

更新时间：2026-07-27
当前版本以 `src/app_metadata.ahk` 为唯一真源，并显示在 EXE“关于麦旋风…”和发布目录 `版本信息.md`。

## 当前 mainline

- Application version source：`src/app_metadata.ahk`；版本号只在这里人工修改。
- Config：Schema 2，路径 `%LocalAppData%\MedExReportAssistant\config.ini`。
- Portable artifact：`..\report-assistant-build\publish\麦旋风.exe`。
- Production color-reset strategy：`relativeMousePixelValidated`。
- Explicit comparison/rollback：`uiaInvoke`。
- Automatic cross-strategy fallback：无。
- 当前验证 profile：MedEx `0.0.1.0`、1920×1080、100% scaling、DPI 96。
- 当前 application version：`0.6.2`。

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
- v0.6.x measurement target 已改为 config-only on-demand resolution：首次成功发现 viewer 后持久化经验证的 process path，后续应用启动直接从固定相对路径读取 vendor config 并建立静态 plan，不需要 viewer 窗口存在；进程生命周期只缓存 `mainGeometry`、跨布局 `logicalPoint`、配置 hash 和 viewer process path。每次读取对每个 outer-frame 候选映射 `screenPoint`，要求该点实际 HWND 的 `GA_ROOTOWNER` 唯一回到同一 frame，并执行 PID、进程路径、进程名和 client-rect 校验；不再要求 outer frame 包含进程内全部临时图像顶层窗口。measurement target 不再使用 UIA、shell hook、后台 warmup、重试或 15/60 秒轮询。
- v0.6.0 长短轴 workflow 已接入通用 `{{size}}` 模板，共用自动 target、context popup transport、clipboard restore、报告事务和标注清除。`复制直线测量值` 的新鲜空剪贴板映射为 `NOT_ANNOTATED`；1-3 个正数严格解析后按数值降序输出，使用 `×` 和逐项 `cm`。未标注或失败时留下人工输入锚点，可继续使用 `;cmx`。
- v0.6.x 增加 builtin `;cma -> {{size}}`。现有配置通过 additive reconciliation 获取该入口：默认 trigger 空闲时直接启用；已有等价 custom `;cma` 时不重复添加；已有不同用途的 `;cma` 时保留用户条目，并以禁用的 `;cma-size` 添加 builtin。配置 normalization 失败或 trigger 重复时继续整体 fail-closed，同时显示无焦点视觉提示。
- v0.6.1 增加默认关闭的箭头、长度测量、3D SUV、截图和清除全部标注 Viewer 快捷键。前三项共用 config-derived button plan、同 PID visible/enabled native control-set 唯一性/顺序校验和直接父窗口 `WM_COMMAND / BN_CLICKED`；outer Viewer 从有效工具面板的 `GA_ROOTOWNER` 反查，不受主图区激活后额外同进程顶层图像窗口影响。production 已移除固定按钮中心、固定首三行和固定 pitch 依赖。3D SUV 等待完整 chord 物理释放后单次投递，避免 Vendor modifier-dependent temporary state。截图仅在 Viewer 前台发送 F12，并显示约 90 ms 的无文字全窗口白色 dispatch pulse。清除快捷键复用既有 `删除全部标注` context-menu cleaner，不依赖工具面板坐标或 `21081`。设置页用独立 Win checkbox 补足 native Hotkey control 不支持 Win modifier 的限制。
- v0.6.2 将 Viewer 工具定位改为 live native command-control discovery，并以工具面板和图像 owner-family 解析跨机器 HWND 层级；measurement、SUVMax、尺寸和清除链复用同一 validated client point。快捷键允许单修饰键；无修饰时只接受单个字母或数字并自动限制为 Viewer-only。正式构建和 checkpoint 构建全部写入仓库同级 `report-assistant-build`，checkout 保持可直接 pull。
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
- 多台机器的箭头、长度和 3D SUV 各连续测试 10 次通过；native control-set resolver 不再依赖原工作站按钮间距。2026-07-28 原工作站发现合法工具面板的 root owner 不在可见 Viewer snapshot 中；direct validated-owner geometry 补丁已实现并等待该机正式 EXE 复验。
- 主图区激活产生额外同进程顶层窗口的机器上，owner-family resolver 已恢复唯一目标；独立清除快捷键现场验证成功。
- 单修饰键、Viewer-only 无修饰字母/数字、Win modifier 设置持久化、F12 pulse 仍需随 v0.6.2 EXE 做最终 Windows smoke test。

### 自动测试覆盖

- Schema 1→2 migration、Schema 2 template grammar、date/cursor/red plan semantics。
- Settings Section identity、排序后选择/编辑/删除、Text codec 和事务保存。
- CF_HTML offsets、Candidate G pure rules、dispatcher safety、single-instance/build integration。
- icon generation inputs与 Windows Ahk2Exe `/icon` wiring。
- measurement result/parser、sentinel + clipboard sequence freshness、single restore owner、provider dynamic popup/command identity 和 privacy-safe field harness。
- Viewer command schema、三按钮坐标映射、设置读写、hotkey registration 和 generated-release integration。

当前完整 Python suite 为 271 tests；Windows AHK harness 仍是 compiled/runtime 行为的最终依据，macOS 静态测试不能替代。

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
