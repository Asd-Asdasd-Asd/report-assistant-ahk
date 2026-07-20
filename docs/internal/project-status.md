# 项目状态与交接

更新时间：2026-07-20（Step 5 Windows 验收通过；准备独立提交）

## 冻结基线

- Branch：`main`
- Step 4 baseline commit：`5193403 perf: remove fzg cursor settle delay`
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
- `;fzg` 使用 phrase-specific no-reset 路径：paste → clipboard restore → `Left 4`，返回 `COLOR_RESET_NOT_REQUIRED`；Step 4 Windows A/B 已确认不需要额外 50 ms settle。
- Production success 无 heavy log；production failure 写 lightweight privacy-safe log；field mode 才写详细诊断。

### Windows 现场已验证

- MedEx `0.0.1.0`、1920×1080、DPI 96、100% scaling。
- 主进程名为 `medexworkstations.exe`；`medexworkstation.exe` 仅作为 compatibility candidate 暂存。
- Candidate G G1 calibration、G2 controlled interaction、caret-order A/B 和最终 generated release mainline validation 均通过。
- `;fzg` no-reset 顺序连续 6 次得到正确 caret，最终 generated release 也已验证。
- 验证 artifact SHA-256：`761a6c4261246a4bc14f44597e30eef4564db0bd1e48e92a31c1ac1e41f8ef11`。
- Step 1 已由 `87dce53` 提交，Step 2 已由 `7a0d9a2` 提交，Step 3 已由 `6c2e2dc` 提交；Step 3 记录为 `86 tests passed`，Windows success/fast-failure 验收通过。验证 artifact SHA-256：`e199466dd78012f5d7b8737406590203eef8ff3e04fd4022e34d88110cb6fbf1`。
- Step 4 五组 F9/F10 A/B、十次 generated-release `;fzg` 和一次 `;red` smoke test 均通过。验证 artifact SHA-256：`4de7f53a2498a2eda5ba4df8035339051b3d99653b5b004df0647a7517a936aa`。

### 仅静态/Python 测试覆盖

- CF_HTML UTF-8 offsets、Candidate G pure geometry/signature rules、dispatcher boundary、at-most-once clicks、no-fallback、report orchestration 和 generated-release integration。
- Step 5 已通过 89 项自动测试和 Windows G1/G2 metadata-override 验收；版本 mismatch/unknown 仅改变 diagnostics，四项 layout gates 保留。
- 当前 macOS 环境可能缺少 `pytest`；无法重跑表示本次 review 未独立复验，不表示 mainline 从未测试。

### 当前性能检查点

- MedEx-only shared `#HotIf`/foreground entry predicate 已通过 Windows scope/foreground 验收并由 Step 2 提交。
- critical-path timing fields 和 derived metrics 已由 Step 1 提交并完成 Windows baseline。
- black click 前置、clipboard restoration 后置的新 transaction ordering 已通过 Step 3 Windows 验收；`SafeMinPasteToRestoreMs=300` 已批准。
- Candidate G interaction path 的冗余 process-name queries 已移除，original active HWND checks 保留并通过 Windows 切窗验收。
- Step 4 已独立移除 `;fzg` 的 `Sleep 50`，通过 Windows A/B 并由 `5193403` 提交。
- Step 5 已将 runtime/calibration MedEx version 从 hard gate 改为 diagnostics-only metadata；Windows override validation 与 generated-release smoke test 已通过。
- 面向用户的 per-machine layout calibration/profile。

### 有意延期

- 其他 resolution/DPI/scaling、multi-monitor/per-monitor DPI 和 layout 的正式支持。
- Configuration runtime、internal-test executable、GUI/updater、measurement capture 和其他 viewer workflow migration。
- 直接 Electron/editor API 路线。

## 当前 production flow

```text
;red / ;fwj / ;fjd
→ InsertRedFigureTextAndRestoreState()
→ CF_HTML paste
→ ResetMedExInsertionColor() before restore
→ relativeMousePixelValidated
→ exact UIA Name="检查所见"
→ geometry and client-bounds validation
→ arrow click at most once
→ four-point popup signature
→ black click at most once
→ mouse restore
→ minimum paste-to-restore interval if still required
→ ClipboardAll restoration in finally
→ structured result
```

`uiaInvoke` 的 popup traversal、exact `000000` lookup 和 Invoke 仅属于显式 comparison/rollback，不是上述 production default flow。

## 当前风险

- report hotstrings 已由 Step 2 限制为 MedEx-only；全局 pause/exit 保持 suspend-exempt。
- ClipboardAll 过早恢复曾导致 MedEx 粘贴用户原剪贴板；任何优化都必须保留 `finally` 并为 fast failure 强制最小 paste-to-restore interval。
- Step 3 保留 200 ms paste settle 和 100 ms post-restore settle，以 300 ms minimum interval 替代固定 pre-restore wait，并把 black click 移到 restore 前。
- 四点 signature 来源于受控 35-point open/closed calibration grid，不是当前明显瓶颈，立即优化不得删除。
- `RELATIVE_MOUSE_CHAIN_OK` 只表示 signature 通过且 black click 已发送；最终 insertion color 仍需人工确认。
- Step 5 不再以 exact MedEx version 拒绝执行，但仅有校准环境完成真实验证；version mismatch override 不等于支持真实新版。

## 下一检查点

Step 1–5 已完成验收；Step 5 独立提交后才可规划 Step 6 per-machine calibration。主要指标仍为：

```text
TriggerToBlackClickMs = BlackClickSentMs - HotstringTriggeredMs
PasteToClipboardRestoreMs = ClipboardRestoreStartedMs - PasteCommandSentMs
```

完整 Step 0–6、Windows pass/failure 分类和简短结果续接规则见 `docs/internal/performance-optimization-checkpoints.md`。收到例如 `Step 1 passed ...` 或 `Step 3 failed ...` 后，应直接按该文档进入对应下一动作，不要求用户重述架构。
