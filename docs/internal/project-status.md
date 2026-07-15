# 项目状态与交接

更新时间：2026-07-15（Color Reset V1 production baseline frozen）

## 当前阶段

项目处于 `v0.5.0 — Internal Test Foundation` 的 M1 完成状态，下一里程碑是 internal-alpha packaging/configuration preparation。CF_HTML 红字插入、MedEx automation chain 和后续输入恢复黑色已经在 baseline workstation 通过验证。

本里程碑只把 validated V1 接入 normal production call chain，并准备 version/dependency/diagnostics/build 边界；未进入 M2，未迁移 legacy，未实现完整 configuration、GUI、installer、updater 或 EXE packaging。

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
- Red paste/reset production path 不显示 `MsgBox`、`ToolTip` 或 `TrayTip`。

## Packaging readiness

- `src/app_metadata.ahk` 是唯一人工维护的 app version source。
- pinned UIA-v2 v1.1.3 位于 `src/Lib/`，source、field debug 和 release builder 共用。
- `scripts/build_release.py` 生成 self-contained `release/report_assistant.ahk`，不依赖 debug tree 或开发机路径。
- 正式 `%LocalAppData%\MedExAHK\config.ini` 和 production logs architecture 留到下一里程碑实现。

## Remaining risks

- 尚未验证其他 DPI/scaling、resolution、multi-monitor/per-monitor DPI、MedEx versions 或用户布局。
- `检查所见` 文案变化需要新 layout profile。
- Color trigger 仍没有 usable UIA node，依赖 validated local offset click。
- process name 尚未基于多个目标工作站收窄。
- macOS 环境没有 AutoHotkey/Ahk2Exe，本里程碑只能运行 Python/static/generated-release checks；Windows compiled smoke test 属于下一里程碑。

## Next milestone

从本 baseline 开始实现最小 centralized user configuration、正式 runtime paths、internal-alpha executable build 和 rollback instructions。保持 legacy compatibility，不进入 viewer/measurement migration，除非单独批准。
