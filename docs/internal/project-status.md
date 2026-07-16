# 项目状态与交接

更新时间：2026-07-17（documentation synchronization；无 production-code 变化）

## 冻结基线

- Branch：`main`
- Commit：`2369b68 Promote pixel-validated Color Reset to mainline`
- Tag：`v0.6.0-candidate-g`
- App source version：`0.5.0-alpha.0`
- Production default：`relativeMousePixelValidated`
- Explicit comparison/rollback：`uiaInvoke`
- Automatic fallback：无

工作树中的 `debug/field-result-2026-07-14/` 和 `debug/field-result-2026-07-15/` 是未跟踪 raw field evidence，本次不改写、不纳入提交。

## 当前实现与验证状态

### 当前代码已实现

- `;red`、`;fwj`、`;fjd` 经 shared report orchestration 执行 CF_HTML paste、clipboard restoration 和 Candidate G reset。
- Candidate G 使用 exact UIA `Name="检查所见"`、geometry validation、必要时的 ambiguity corroboration、client-bounds checks、at-most-once arrow/black clicks、四点 popup signature、鼠标恢复和 structured result。
- 第一次 signature 立即采样；只在失败时等待 20 ms 再采一次。
- `;fzg` 使用 phrase-specific no-reset 路径：paste → clipboard restore → `Sleep 50` → `Left 4`，返回 `COLOR_RESET_NOT_REQUIRED`。
- Production success 无 heavy log；production failure 写 lightweight privacy-safe log；field mode 才写详细诊断。

### Windows 现场已验证

- MedEx `0.0.1.0`、1920×1080、DPI 96、100% scaling。
- 主进程名为 `medexworkstations.exe`；`medexworkstation.exe` 仅作为 compatibility candidate 暂存。
- Candidate G G1 calibration、G2 controlled interaction、caret-order A/B 和最终 generated release mainline validation 均通过。
- `;fzg` no-reset 顺序连续 6 次得到正确 caret，最终 generated release 也已验证。
- 验证 artifact SHA-256：`761a6c4261246a4bc14f44597e30eef4564db0bd1e48e92a31c1ac1e41f8ef11`。
- Mainline promotion 记录为 `75 tests passed`。

### 仅静态/Python 测试覆盖

- CF_HTML UTF-8 offsets、Candidate G pure geometry/signature rules、dispatcher boundary、at-most-once clicks、no-fallback、report orchestration 和 generated-release integration。
- 当前 macOS 环境可能缺少 `pytest`；无法重跑表示本次 review 未独立复验，不表示 mainline 从未测试。

### 计划但未实现

- MedEx-only shared `#HotIf`/foreground entry predicate。
- 新 critical-path timing fields 和 derived metrics。
- black click 前置、clipboard restoration 后置的新 transaction ordering，以及 `SafeMinPasteToRestoreMs` 剩余时间保护。
- 移除冗余 Candidate G process-name queries，但保留两次 click 前的 active HWND checks。
- 独立移除 `;fzg` 的 `Sleep 50`。
- 将 MedEx version 从 hard gate 改为 diagnostics-only metadata。
- 面向用户的 per-machine layout calibration/profile。

### 有意延期

- 其他 resolution/DPI/scaling、multi-monitor/per-monitor DPI 和 layout 的正式支持。
- Configuration runtime、internal-test executable、GUI/updater、measurement capture 和其他 viewer workflow migration。
- 直接 Electron/editor API 路线。

## 当前 production flow

```text
;red / ;fwj / ;fjd
→ InsertRedFigureTextAndRestoreState()
→ CF_HTML paste and ClipboardAll restoration
→ ResetMedExInsertionColor()
→ relativeMousePixelValidated
→ exact UIA Name="检查所见"
→ geometry and client-bounds validation
→ arrow click at most once
→ four-point popup signature
→ black click at most once
→ mouse restore and structured result
```

`uiaInvoke` 的 popup traversal、exact `000000` lookup 和 Invoke 仅属于显式 comparison/rollback，不是上述 production default flow。

## 当前风险

- Hotstrings 仍为 global，可能在非 MedEx 应用修改文字或剪贴板；Step 2 将加入 entry guard。
- ClipboardAll 过早恢复曾导致 MedEx 粘贴用户原剪贴板；任何优化都必须保留 `finally` 并为 fast failure 强制最小 paste-to-restore interval。
- 当前 fixed `200/100/100 ms` waits 保护 clipboard correctness，但 black click 被排在 restoration 后，形成用户可感知延迟。
- 四点 signature 来源于受控 35-point open/closed calibration grid，不是当前明显瓶颈，立即优化不得删除。
- `RELATIVE_MOUSE_CHAIN_OK` 只表示 signature 通过且 black click 已发送；最终 insertion color 仍需人工确认。
- 当前 exact MedEx version gate 会拒绝未单独验证的新版本；计划独立移除，但这不等于获得多环境支持。

## 下一检查点

下一步不是直接改 waits，而是先增加 baseline critical-path diagnostics。主要指标：

```text
TriggerToBlackClickMs = BlackClickSentMs - HotstringTriggeredMs
PasteToClipboardRestoreMs = ClipboardRestoreStartedMs - PasteCommandSentMs
```

完整 Step 0–6、Windows pass/failure 分类和简短结果续接规则见 `docs/internal/performance-optimization-checkpoints.md`。收到例如 `Step 1 passed ...` 或 `Step 3 failed ...` 后，应直接按该文档进入对应下一动作，不要求用户重述架构。
