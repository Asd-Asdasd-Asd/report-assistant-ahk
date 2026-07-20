# Color Reset 性能优化检查点

## 目标与边界

用户真实操作是：

```text
;red
→ 立即输入。或；
```

标点必须在 insertion color 已变黑之后到达。主要指标不是函数总耗时，而是：

```text
TriggerToBlackClickMs = BlackClickSentMs - HotstringTriggeredMs
```

black click 后的 clipboard restoration、logging、structured-result completion 和其他 cleanup 不属于用户可见 critical path，但 clipboard restoration 仍是 mandatory，并必须由 `finally` 保护。

立即优化保留：exact UIA `Name="检查所见"`、geometry validation、多候选时才做 corroboration、arrow/black client-bounds checks、两次 click 各最多一次、四点 signature、immediate first sample、first failure 后才等待 20 ms 的 second sample、no fallback、mouse restoration 和显式 `uiaInvoke` rollback implementation。

## 目标执行顺序

```text
hotstring trigger
→ CF_HTML clipboard setup
→ Ctrl+V
→ minimal initial paste settle
→ Candidate G localization and interaction
→ black click
──────── critical path complete
→ enforce minimum safe paste-to-clipboard-restore interval if required
→ restore original clipboard in finally
→ diagnostics/result completion
```

不能把该计划概括为“把 200/100/100 ms 改成 50 ms”。Windows 曾观察到过早恢复 `ClipboardAll` 会让 MedEx 粘贴用户原剪贴板。新实现必须记录 `pasteSentAt`：

```text
elapsed = now - pasteSentAt
if elapsed < SafeMinPasteToRestoreMs:
    wait SafeMinPasteToRestoreMs - elapsed
```

Candidate G 成功执行的时间可自然贡献于安全间隔；fast failure 可能很快，因此也必须受剩余时间保护。`SafeMinPasteToRestoreMs` 尚未批准，必须通过 Windows field testing 决定。

## 计划 timing fields

- `HotstringTriggeredMs`
- `PasteCommandSentMs`
- `ColorResetStartedMs`
- `ArrowClickSentMs`
- `BlackClickSentMs`
- `ClipboardRestoreStartedMs`
- `ClipboardRestoreCompletedMs`
- `FunctionReturnedMs`
- derived `TriggerToBlackClickMs`
- derived `PasteToClipboardRestoreMs`

这些字段先进入现有 field/performance context；不创建第二个 internal/minimal release artifact。Logging policy 不变：production success 无 heavy log，production failure 仅 lightweight privacy-safe line，field mode 提供详细 timing、geometry、UIA 和 pixel diagnostics。

## 有序实施与停止点

### Step 0 — Documentation synchronization

当前任务。只同步文档，不改 production code、generated release 或 raw field evidence。完成后提交一个 documentation-only commit。

### Step 1 — Baseline critical-path diagnostics

实现上述 timestamps 和 derived metrics，但不改变 transaction ordering、waits、Candidate G checks 或 hotstring semantics。

Implementation status：2026-07-20 Windows baseline field test 已通过，等待 Step 1 独立提交；Step 2 尚未开始。

Windows baseline（MedEx 0.0.1.0、1920×1080、100%、DPI 96）：

| Run | TriggerToBlackClickMs | PasteToClipboardRestoreMs | ClipboardRestoreMs | ColorResetCoreMs | TotalHotstringMs |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 906 | 312 | 421 | 485 | 906 |
| 2 | 797 | 312 | 422 | 359 | 797 |
| 3 | 766 | 313 | 422 | 359 | 781 |

三次均为 `RED_TEXT_OK` / `RELATIVE_MOUSE_CHAIN_OK`，九个关键 timestamps 全部为数值且顺序正确，derived durations 与原始 timestamps 差值一致。现场确认 red marker、clipboard restoration、immediate black punctuation 均正确，无 wrong paste；field harness 和 generated release 不再报告五个 Candidate G `#Warn`。

Windows pass criteria：正常 `;red` 行为不变；得到可信的 `TriggerToBlackClickMs` 和 `PasteToClipboardRestoreMs`；红字、clipboard restoration、black reset 和 immediate punctuation 均正确。

- Pass：提交 Step 1，进入 Step 2。
- Timing 缺失/顺序为负：不提交，修正 instrumentation 后重测。
- 功能回归：停止优化，恢复 baseline behavior，只保留不改变时序的 diagnostics 修订。

可接受的简短回报：

```text
Step 1 passed
TriggerToBlackClickMs=...
PasteToClipboardRestoreMs=...
No functional failures
```

### Step 2 — Hotstring scope and foreground-guard cleanup

用 shared `#HotIf`/foreground predicate 限制 `;red`、`;fwj`、`;fjd`、`;fzg`、`;cmx` 仅在 MedEx 前景窗口触发。全局 pause/exit 必须继续在 MedEx 外和 suspended 状态工作。

在 entry guard 建立后，移除 Candidate G interaction path 中冗余的重复 `WinGetProcessName`；仍在 arrow click 和 black click 前检查 original target HWND 仍为 active。

Windows pass criteria：五个 report hotstrings 在 MedEx 正常；在无关应用不触发、不改 clipboard；切换窗口时两次 coordinate click 都 fail closed；pause/exit 保持全局。

- Pass：提交 Step 2，进入 Step 3。
- Hotstring 漏触发：修正 predicate/window ownership，不放宽为 global。
- 错误应用仍触发：停止并修正 entry guard，不进入 transaction reorder。
- Click 可落入已切换窗口：恢复/加强 HWND guard 后重测。

### Step 3 — Move clipboard restoration after Color Reset

在 shared orchestration 中让 Candidate G localization 和 black click 发生在 clipboard restore 之前；restore 仍位于 `finally`。使用 `pasteSentAt` 和待现场确定的 `SafeMinPasteToRestoreMs`，只等待不足的剩余间隔。

Windows 必测：成功 Candidate G path，以及故意制造的 fast-failure path。

Pass criteria：

- red marker 不被原 clipboard 替换；
- 原 clipboard 最终恢复；
- successful black click 明显提前；
- fast failure 不破坏 paste 或 clipboard state；
- successful reset 后立即输入的标点为黑色。

Decision rules：

- 全部通过：提交 Step 3，记录批准的 `SafeMinPasteToRestoreMs` 和 measurements，进入 Step 4。
- Success 正确、fast failure 粘贴原 clipboard：不提交；增加或重新测定 minimum interval，只改该参数/保护逻辑后重测两条路径。
- Clipboard 未恢复：不提交；先修复 `finally` ownership/exception path。
- Black click 未明显提前：保留 correctness，检查 initial paste settle 与 orchestration 是否仍在 critical path；不得删除 signature/geometry 来换时间。
- Immediate punctuation 仍为红色：停止；核对 click/focus/insertion state，不进入 Step 4。

可接受的失败回报：

```text
Step 3 failed
Success path okay
Fast-failure path pasted original clipboard
```

### Step 4 — Remove redundant `;fzg` `Sleep 50`

独立提交将：

```text
CF_HTML paste and clipboard restoration
→ Sleep 50
→ Left 4
```

改为：

```text
CF_HTML paste and clipboard restoration
→ Left 4
```

不得改为 `Left 5`，不得与 Step 3 合并。

- Caret=`|（见图）` 且 immediate typing 为黑色：提交 Step 4。
- Caret 错位或输入颜色异常：不提交，恢复 `Sleep 50`，记录它仍是必要 editor-settle interval。

### Step 5 — Remove exact MedEx-version hard gate

将 exact MedEx version 从 execution gate 改为 diagnostics-only metadata；semantic localization、geometry、signature 和 foreground checks 仍决定是否安全执行。

- 新旧已测试版本 checks/interaction 均正确：提交 Step 5。
- UI/layout 改变导致 checks 失败：保持 fail closed；不得用删除 geometry/signature 绕过。

此步骤不宣称支持任意 resolution、DPI、scaling 或 layout。

### Step 6 — Per-machine layout calibration

仅在 latency work 稳定并获得单独授权后实现。目标用户流程：UIA 定位 `检查所见` → 用户确认 arrow center → 打开 popup → 用户确认 black center → 本地保存 offsets、signature 和环境 metadata → runtime 加载 local profile。

建议 profile fields：anchor name、arrow offset、black offset、popup signature、DPI、scaling、resolution、可选 monitor identity、calibration timestamp，以及仅作信息的 MedEx version。用户体验应为一到两个 guided confirmation steps，不暴露 developer harness。

## Windows-result continuation contract

收到只包含 step、metrics 和简短现象的现场回报时，先按本文件对应 step 分类，再执行明确的 commit/revise/stop 动作；不要要求用户重述 architecture、clipboard race、Candidate G safety checks 或既往 A/B 理由。

如果回报缺少决定安全性的关键项，只询问缺失的具体观察，例如 fast-failure 是否粘贴原 clipboard，而不是重新发整套测试说明。
