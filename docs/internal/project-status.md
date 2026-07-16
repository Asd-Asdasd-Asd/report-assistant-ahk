# 项目状态与交接

更新时间：2026-07-16（Candidate G production mainline；最终 generated-release 验证通过）

## 当前阶段

项目处于 `v0.5.0 — Internal Test Foundation` 的 Color Reset 路线重整阶段。CF_HTML 红字插入稳定；semantic/static UIA localization 可用；但 production popup UIA lookup/Invoke 在 2026-07-16 重复测试中只有略高于半数的成功率，延迟约 0.5–0.65 秒，不能作为首选 production 路线。

当前 control node 保留 `uiaInvoke` 作为显式 comparison/rollback strategy，不再继续 popup UIA timing optimization。Candidate G1 已完成多 Y 位置校准：自动计算的 arrow point 均能打开菜单，popup 在 `t=0` 已形成稳定像素签名。Candidate G2 interaction、caret-order A/B 和最终 generated release 均已通过 Windows 验证；`relativeMousePixelValidated` 现为后续开发的 production mainline。

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
- 后续 release 测试反复返回 `COLOR_RESET_FONT_SIZE_ANCHOR_NOT_FOUND`；一次 F11 有 2 个 raw font matches，但没有 aligned candidate。Candidate G1 因此不把 dynamic font-size 作为 mandatory coordinate anchor。
- Windows 观察到极少数 red insertion 被原剪贴板内容替代。根因与 50 ms 后过早恢复 `ClipboardAll` 一致；G1 分支已恢复 field-validated 的 200/100/100 ms 时序，必须完成 sentinel 20-run 才能确认关闭风险。
- 当前 reconciliation control 默认使用 live UIA Text properties；cached snapshot、font retry、fixed-attempt lookup、menu pre-settle 和 focus collection 均默认关闭，只保留为显式 diagnostics/历史实验。
- font-anchor retry 代码只允许处理 `RegionAnchorFound=true` 且 raw font match 为 0 的情况，但默认关闭；invalid rectangle、alignment rejection 和 ambiguity 均不重试。
- `uiaInvoke` 保留一次 trigger click + `600 ms / 40 ms` bounded adaptive exact `000000` polling，且只能显式选择。fixed-attempt、pre-settle 和 font retry 仅为显式实验选项。
- 源码、F11 harness 和 generated release 均请求 `Left 4`；没有 `Left 3`。新增 Invoke 后及 cursor restore 前的 privacy-safe focus diagnostics，用来区分 focus 消耗与 caret 结构差异；本轮不使用任意 `Left 5`。
- 首次 production smoke test 暴露约 1 秒级临界路径延迟和可见的光标少移动一位；源码始终请求 `Left 4`，本轮已恢复 legacy 的 50 ms caret-settle，并将固定 clipboard waits 从 400 ms 降至 50 ms，但仍待 Windows 复测。
- 首轮 Windows A/B 只比较 live properties 与 cached properties；menu strategy、font retry、clipboard timing、caret timing 和 focus behavior 必须保持相同。
- Candidate G 使用 narrow supported profile：MedEx 0.0.1.0、1920×1080、100%、DPI 96。runtime calibration 为 `ArrowOffset=(320,0)`、`BlackOffset=(6,83)`；popup signature 同时验证 light、black、beige 和 blue 四个点。它现为 production default；F12 仍提供显式 reset-only 验证入口。
- `;fzg` caret-order A/B 已得到决定性结果：带 Color Reset 的路径仍少一位；保持相同 CF_HTML 但跳过 reset 的 legacy 顺序连续 6 次正确。Production `;fzg` 因此改为 phrase-specific caret-relocation workflow，并以 `COLOR_RESET_NOT_REQUIRED` 明确记录；`Left 4` 不变。
- 更新后的 `;fzg` production workflow 已由用户确认 caret 正确。红字插入后仍有轻微可感知延迟；当前优先保留已验证的 clipboard transaction waits 与 legacy `Sleep 50`。如最终 release 重复验证稳定，后续应一次只调整一个 named wait 并重新做 clipboard sentinel/caret 测试，不在本次 promotion 中压缩时序。
- 2026-07-16 用户确认 SHA-256 `761a6c4261246a4bc14f44597e30eef4564db0bd1e48e92a31c1ac1e41f8ef11` 的 generated release 完整验证通过，包括 Candidate G black reset、phrase-specific `;fzg` caret workflow 和最终 mainline behavior。
- 仓库 generated release 可静态确认包含 normal hotstring → shared report orchestration → strategy dispatcher → `uiaInvoke`。此前“release 只插红字、F11/F12 会复位”的精确 Windows 原因尚不能从仓库单独证明；已确认的代码风险是旧 field-debug 会重复注册 production hotstrings，本轮已消除。仍需在所有旧 AHK instances 退出后核对实际 release 路径和新实例行为。
- 尚未验证其他 DPI/scaling、resolution、multi-monitor/per-monitor DPI、MedEx versions 或用户布局。
- `检查所见` 文案变化需要新 layout profile。
- Color trigger 仍没有 usable UIA node，依赖 validated local offset click。
- process name 尚未基于多个目标工作站收窄。
- macOS 环境没有 AutoHotkey/Ahk2Exe，本里程碑只能运行 Python/static/generated-release checks；Windows compiled smoke test 属于下一里程碑。

## Next milestone

下一步将把剩余轻微延迟作为独立、可回滚的性能提交处理；不得在同一提交中改变 Candidate G geometry/signature 或 `;fzg` caret semantics。之后进入 internal-alpha packaging/configuration phase。当前不创建新 baseline tag，除非用户另行批准。
