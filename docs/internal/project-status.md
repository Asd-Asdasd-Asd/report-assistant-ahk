# 项目状态与交接

更新时间：2026-07-16（reconciled control；等待 Windows release smoke test）

## 当前阶段

项目处于 `v0.5.0 — Internal Test Foundation` 的 Color Reset 路线重整阶段。CF_HTML 红字插入稳定；semantic/static UIA localization 可用；但 production popup UIA lookup/Invoke 在 2026-07-16 重复测试中只有略高于半数的成功率，延迟约 0.5–0.65 秒，不能作为首选 production 路线。

当前 control node 保留 `uiaInvoke` 作为显式 comparison/rollback strategy，不再继续 popup UIA timing optimization。`relativeMousePixelValidated` 已声明为 Candidate G strategy name，但 runtime、坐标 profile 和 pixel signature 均未实现。只有 reconciled release smoke test 通过后，才在独立 `feature/candidate-g` 分支进入 G1 calibration。

## Validated baseline

- App source version：`0.5.0-alpha.0`
- MedEx：0.0.1.0
- Resolution：1920×1080
- Scaling：100%，DPI 96
- Process observed：`medexworkstations.exe`（provisional）
- 三次 automation success：约 890/859/844 ms
- 人工最终 insertion color：PASSED BY USER

详细证据结论见 `docs/field-tests/2026-07-15-color-reset-field-validation.md`；raw artifacts 不改写、不纳入 milestone commit。

## Production flow

```text
hotstring
→ InsertRedFigureTextAndRestoreState()
→ generic CF_HTML clipboard transaction/restoration
→ ResetMedExInsertionColor()
→ semantic region/local font resolver
→ validated click
→ exact 000000 Invoke
→ structured result
```

Production 默认接受两个 exact provisional candidates：`medexworkstation.exe` 和 `medexworkstations.exe`，但保留 `ProcessNameConfirmed=false`。初始错误进程返回 `COLOR_RESET_WRONG_PROCESS`；开始自动化后 foreground 改变返回 `COLOR_RESET_FOREGROUND_CHANGED`。

## Production/debug boundary

- Production success 不写 heavy field dataset。
- Production failure 只写 privacy-safe lightweight line 到 `%TEMP%\MedExAHK\logs\medex-color-reset-failures.log`。
- Field debug 显式使用 `diagnosticMode=field`，继续输出完整 clipboard/log/result schema。
- 两种模式调用同一个 adapter/resolver；没有 field-only algorithm fork。
- F11 直接调用 `report_editor.ahk` 中与 production `;fzg` 相同的 `RunFzgInsertion()`；field-debug 脚本不再 include 或注册 production hotstrings。
- Red paste/reset production path 不显示 `MsgBox`、`ToolTip` 或 `TrayTip`。

## Packaging readiness

- `src/app_metadata.ahk` 是唯一人工维护的 app version source。
- pinned UIA-v2 v1.1.3 位于 `src/Lib/`，source、field debug 和 release builder 共用。
- `scripts/build_release.py` 生成 self-contained `release/report_assistant.ahk`，不依赖 debug tree 或开发机路径。
- 正式 `%LocalAppData%\MedExAHK\config.ini` 和 production logs architecture 留到下一里程碑实现。

## Remaining risks

- 最新 Windows production smoke test 已确认 red CF_HTML insertion 与 clipboard restoration 通过；不稳定边界位于后续 black color reset。一次失败为 `COLOR_RESET_FONT_SIZE_ANCHOR_NOT_FOUND`，一次成功仍需约 656 ms。
- 2026-07-16 F11/F12 再次确认 region/font localization 可用，但每次 foreground Chromium descendant query 约 125–156 ms；popup exact item 往往第一轮失败、第二轮才成功。正常使用可靠性不可接受，因此 UIA popup route 已停止继续调参。
- 当前 reconciliation control 默认使用 live UIA Text properties；cached snapshot、font retry、fixed-attempt lookup、menu pre-settle 和 focus collection 均默认关闭，只保留为显式 diagnostics/历史实验。
- font-anchor retry 代码只允许处理 `RegionAnchorFound=true` 且 raw font match 为 0 的情况，但默认关闭；invalid rectangle、alignment rejection 和 ambiguity 均不重试。
- production default 已恢复为一次 trigger click + `600 ms / 40 ms` bounded adaptive exact `000000` polling。fixed-attempt、pre-settle 和 font retry 仅为显式实验选项。
- 源码、F11 harness 和 generated release 均请求 `Left 4`；没有 `Left 3`。新增 Invoke 后及 cursor restore 前的 privacy-safe focus diagnostics，用来区分 focus 消耗与 caret 结构差异；本轮不使用任意 `Left 5`。
- 首次 production smoke test 暴露约 1 秒级临界路径延迟和可见的光标少移动一位；源码始终请求 `Left 4`，本轮已恢复 legacy 的 50 ms caret-settle，并将固定 clipboard waits 从 400 ms 降至 50 ms，但仍待 Windows 复测。
- 首轮 Windows A/B 只比较 live properties 与 cached properties；menu strategy、font retry、clipboard timing、caret timing 和 focus behavior 必须保持相同。
- Candidate G 的启动条件已经满足并获用户批准，但必须先通过 TEST CHECKPOINT 1。G1 只做 toolbar-row localization、offset calibration 与 privacy-safe popup pixel sampling，不自动点击 black；当前没有 runtime profile constants 或 pixel thresholds。
- 仓库 generated release 可静态确认包含 normal hotstring → shared report orchestration → strategy dispatcher → `uiaInvoke`。此前“release 只插红字、F11/F12 会复位”的精确 Windows 原因尚不能从仓库单独证明；已确认的代码风险是旧 field-debug 会重复注册 production hotstrings，本轮已消除。仍需在所有旧 AHK instances 退出后核对实际 release 路径和新实例行为。
- 尚未验证其他 DPI/scaling、resolution、multi-monitor/per-monitor DPI、MedEx versions 或用户布局。
- `检查所见` 文案变化需要新 layout profile。
- Color trigger 仍没有 usable UIA node，依赖 validated local offset click。
- process name 尚未基于多个目标工作站收窄。
- macOS 环境没有 AutoHotkey/Ahk2Exe，本里程碑只能运行 Python/static/generated-release checks；Windows compiled smoke test 属于下一里程碑。

## Next milestone

先完成 TEST CHECKPOINT 1：只验证 regenerated release 启动、hotstrings 激活、release 与 F11 进入同一 shared strategy chain，并排除 stale file/instance discrepancy。通过后才进入 Candidate G1 calibration；不进入 M2、configuration、legacy migration 或 packaging。
