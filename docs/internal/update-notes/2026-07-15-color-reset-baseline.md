# 2026-07-15 Color Reset V1 基线维护说明

版本：`0.5.0-alpha.0`

## 本基线冻结内容

- normal hotstring 的 CF_HTML paste/clipboard restoration 后调用 field-validated MedEx Color Reset V1。
- `检查所见` exact Text 作为 semantic region；同行动态 `Npx` Text 作为 local anchor。
- `ColorArrowOffsetX=143`、`ColorArrowOffsetY=0`。
- exact black item `000000`、foreground recheck 和最多一次 bounded retry。
- production failure-only lightweight log 与 explicit field diagnostics 分离。
- UIA-v2 v1.1.3 作为 source/build 共用 pinned dependency。

## 已验证环境

MedEx 0.0.1.0、1920×1080、100% scaling、DPI 96；观察到 process `medexworkstations.exe`。三次 automation chain 连续成功，用户完成人工最终黑色确认。

## Rollback

若后续 packaging/configuration 工作造成回归，回退到 annotated tag `v0.5.0-color-reset-field-validated`。该 tag 是 source baseline，不是已发布 installer/executable。

## Recalibration

1. 检查目标字号 Text rectangle。
2. 确定 color-arrow target screen point。
3. 计算 `ColorArrowOffsetX = targetX - fontRect.r`。
4. 计算 `ColorArrowOffsetY = targetY - Round((fontRect.t + fontRect.b) / 2)`。
5. 只更新 `MedExColorResetLayoutProfile` 的两个 offset values。
6. 运行 geometry tests，并在 approved non-clinical context 完成一次现场验证后发布新版本。

不得添加 absolute coordinate fallback，也不得使用 `①` 或 exact `16px` 恢复旧模型。
