# Candidate G 当前技术边界

Candidate G 将 UIA 语义定位与受保护的相对鼠标交互组合。它已经成为
production `relativeMousePixelValidated` strategy；`uiaInvoke` 只保留为显式
comparison/rollback，二者不得自动 fallback。

## 已验证 profile

- MedEx `0.0.1.0`
- Process：`medexworkstations.exe`
- Resolution：1920×1080
- Display scaling：100%
- DPI：96
- Semantic anchor：exact Text Name=`检查所见`
- Arrow offset：`(320,0)`
- Black offset：`(6,83)`
- Popup：四点 pixel signature

Exact MedEx version 只作为 diagnostics metadata；resolution、DPI、scaling、
geometry、foreground 和 signature 仍是硬门槛。Version mismatch 不代表其他
layout 已获支持。

## Runtime contract

```text
validate foreground MedEx
→ locate unique Text("检查所见")
→ validate supported profile and region geometry
→ calculate and validate arrow/black points
→ save mouse position
→ recheck foreground
→ click arrow at most once
→ bounded passive settle
→ validate popup pixel signature
→ recheck foreground
→ click black at most once
→ restore mouse position
→ return structured result
```

如果 arrow click 没有打开已验证 popup，black click 必须不可达。不得用无条件
relative click、第二次 arrow click、UIA fallback 或 absolute screen-coordinate
fallback 绕过 signature。

## Report 与 clipboard 边界

- Candidate G 只负责 MedEx interaction，不复制 report/clipboard orchestration。
- CF_HTML paste、minimum paste-to-restore interval 和 `ClipboardAll()` restore
  仍由 report transaction 管理。
- Clipboard restore 只有一个 `finally` owner，fast failure 也必须恢复原值。
- `ReportTemplatePlan` 决定是否运行 Candidate G。Caret 位于红色尾段之后才
  reset；内部 caret relocation 返回 `COLOR_RESET_NOT_REQUIRED`。
- `;fzg` 的视觉等价移动量由模板推导，保持 no-reset `Left 4` 等价行为；
  不使用 `Left 5`，不重新加入旧 settle。

## Fail-closed 与验收

- Wrong process、foreground change、unsupported profile、重复/缺少 anchor、
  invalid rectangle/point、popup signature mismatch 或 click failure 均返回
  structured failure。
- Arrow 和 black 各最多点击一次，所有路径恢复鼠标。
- Production 默认只写 privacy-safe failure diagnostics；field 模式才记录
  geometry/timing，不记录报告或 clipboard payload。
- `RELATIVE_MOUSE_CHAIN_OK` 只证明受保护交互已执行。最终插入颜色、随后输入
  黑色、caret、clipboard、mouse 和 foreground 必须由 Windows 非临床现场
  验证。

## 尚未实施

Per-machine layout calibration 需要单独授权。相关 profile 字段、漂移失效和
停止条件见 `docs/internal/performance-optimization-checkpoints.md`。
