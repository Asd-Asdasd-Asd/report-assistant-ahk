# 项目状态与交接

更新时间：2026-07-24
当前版本：v0.5.0 internal test

## 当前 mainline

- Application version source：`src/app_metadata.ahk`，值为 `0.5.0`。
- Config：Schema 2，路径 `%LocalAppData%\MedExReportAssistant\config.ini`。
- Portable artifact：`publish\麦旋风.exe`。
- Production color-reset strategy：`relativeMousePixelValidated`。
- Explicit comparison/rollback：`uiaInvoke`。
- Automatic cross-strategy fallback：无。
- 当前验证 profile：MedEx `0.0.1.0`、1920×1080、100% scaling、DPI 96。

## 当前已实现

- 固定 `Local\MedExReportAssistant.Singleton` 在 config bootstrap 前保护不同版本、文件名和目录。
- Schema 2 template engine 支持 `{{cursor}}`、`{{date}}`、`{{suvmax}}`、`{{red:（见图）}}`。
- 普通字面量 `（见图）` 保持黑色；caret movement 和 Candidate G 均由 `ReportTemplatePlan` 派生。
- Schema 1 配置可经只读审计、backup、临时写入和最终验证一次性升级；legacy Mode 只存在于 migration module。
- 原生 Settings UI 支持稳定 Section identity、ListView sorting、custom add/delete、builtin edit/disable、template-element insertion、严格校验和事务保存。
- 保存设置后执行完整 `Reload()`；托盘“重新加载配置”同样是全脚本 Reload。
- report hotstrings 通过 shared MedEx-only foreground predicate 限制作用窗口；`Ctrl+Alt+Esc` 与 `Ctrl+Alt+Q` 保持 suspend-exempt/global。
- CF_HTML、clipboard `finally` restoration、Candidate G popup signature 和 at-most-once clicks 保持 fail closed。
- 正式图标以 `assets/icon/source/medex-icon.svg` 为 source，由 `scripts/generate-icon.sh` 生成多尺寸 PNG/ICO。
- Windows 一键构建自动生成 release source、以 `/icon` 嵌入 ICO、编译 temporary EXE、同步静态发布资源并事务提升 final。
- v0.6.0 SUVMax production candidate 已接入通用 `{{suvmax}}` 模板：自动 target、strict parser、报告事务和右键清除 provider 均已实现；`NOT_ANNOTATED`/失败会留下人工输入锚点，失败提示为无焦点视觉浮层。首次 production 复测发现同步重算 config/UIA target 导致 trigger-to-text 超过 1 秒；增加 viewer-session target 预热/cache，并在复用前核对 HWND、PID、进程名和 client rect 后，现场确认延迟可接受。
- Config-first measurement target foundation 和 field-only automatic target checkpoint 已通过 Windows 验证。自动 target 已从非目标活动 pane 成功读取 SUVMax，success-path invariants 全部通过；viewer missing 时 provider、clipboard、popup 和 command 均不可达。总 UIA Pane 数是诊断字段，唯一 geometry match 才是硬门槛。本轮已在其外增加 production adapter，底层 provider 默认边界不变。

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

### 自动测试覆盖

- Schema 1→2 migration、Schema 2 template grammar、date/cursor/red plan semantics。
- Settings Section identity、排序后选择/编辑/删除、Text codec 和事务保存。
- CF_HTML offsets、Candidate G pure rules、dispatcher safety、single-instance/build integration。
- icon generation inputs与 Windows Ahk2Exe `/icon` wiring。
- measurement result/parser、sentinel + clipboard sequence freshness、single restore owner、provider dynamic popup/command identity 和 privacy-safe field harness。

当前完整 Python suite 为 223 tests；Windows AHK harness 仍是 compiled/runtime 行为的最终依据，macOS 静态测试不能替代。

## 当前 production flow

```text
configured report hotstring
→ optional MxNMMeasurementProvider.ReadSuvMax()
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
- SUVMax acquisition、automatic target、production FOUND orchestration、`删除全部标注` 清除链及 cache latency 已通过 Windows checkpoint；`NOT_ANNOTATED`/automation failure 的 production 组合验收仍保留在 checklist。long-axis/short-axis 和 `size` placeholder 尚未实现。
- Config logical-to-runtime mapping 和 privacy-safe UIA geometry-only 唯一重找已通过当前工作站相同布局三次复验；其他布局/profile 尚未正式验证，active `ShowModelN` 识别仍不属于当前 checkpoint。
- Settings 的“快捷键”“其他”标签页仍是占位页。

## v0.5.0 发布前剩余验收

1. 在 Windows 从 clean commit 双击 `Build EXE.cmd`，确认 EXE 与 tray 使用正式图标。
2. 运行 `tests\windows\config_v2_migration_audit.ahk`、`template_engine_regression.ahk`、`settings_ui_regression.ahk` 和 `cmx_template_regression.ahk`。
3. 验证旧配置 backup/migration、设置保存 Reload、排序后编辑/删除和 custom trigger。
4. 验证 portable locations、跨版本 singleton 与 `publish/` 完整内容。
5. 单独观察首次颜色下拉菜单残留限制，避免用重复点击掩盖。

下一阶段证据和边界见：

- `docs/internal/mxnmsoft-measurement-investigation.md`
- `docs/internal/mxnmsoft-config-driven-automation.md`
- `docs/internal/passive-zmq-exploration.md`
