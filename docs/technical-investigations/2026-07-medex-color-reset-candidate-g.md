# Technical Investigation：Candidate G — UIA Localization + Guarded Relative Mouse Interaction

日期：2026-07-16
状态：G1 calibration harness 已实现；等待 TEST CHECKPOINT 2

## Objective

如果当前 Color Reset Control/Candidate A/B 最终证明 semantic anchor localization 稳定、但 Chromium popup UIA lookup/Invoke 仍不可靠，则评估把定位与交互分离：UIA 只定位 `检查所见`，鼠标负责打开颜色菜单并选择黑色。

Candidate G 是复杂度缩减路线，不是单纯性能优化。2026-07-16 测试已确认 UIA localization 可保留，但 popup UIA interaction 不适合作为首选路线。Candidate G 必须在独立分支按 calibration、controlled interaction、mainline promotion 三阶段推进，不能覆盖现有 comparison profile。

## Evidence classification

### Verified behavior

- MedEx 0.0.1.0、1920×1080、100% scaling、DPI 96 下，exact Text Name=`检查所见` 的 rectangle 为 `[296,289,352,305]`。
- 当前 validated arrow point 为 `(672,297)`。
- legacy 固定点击曾使用 arrow `(671,296)` 与 black `(678,380)`，并在用户实际工作中稳定使用。
- 当前 UIA 路线已证明 semantic localization、arrow click、exact `000000` Invoke 和最终黑色人工验证可以成功。
- 新一轮 F11/F12 中 foreground Text snapshot 得到 3 个 font-size raw matches、1 个 aligned candidate、0 个 property-read failures，继续支持 semantic/static localization 可用的结论。
- popup UIA exact-item query 每轮约 125–156 ms，常见 first lookup failure、second lookup success；normal-use success rate 仅略高于半数，已由用户判定不可接受。
- reconciled release 与 F11 均进入 `uiaInvoke`。normal release 大量失败为 `alignedFontSizeAnchorNotFound`；一次 F11 枚举到 2 个 raw font-size names，但 0 个 aligned candidate，证明 mandatory font anchor 本身也是明显不稳定边界。
- `Left 4` 在 source 和 release 中确实发送，但实际只产生三次有效 caret movement；当前证据更符合 popup/focus 消耗一个 Left，不支持改成任意 `Left 5`。
- 50 ms clipboard restoration 路线曾偶发插入原剪贴板内容；G1 前已恢复 200/100/100 ms field-validated safety timing。

### Implementation inference

- 以 region right/center 为基准，初始 arrow offset 约为 `(320,0)`。
- legacy black click 相对 legacy arrow 约为 `(7,84)`；映射到当前 arrow 时可作为 `(6–7,83–84)` 的现场校准起点。
- toolbar 可作为 rigid body 沿 Y 移动；后续 Windows 观察又确认 sidebar 关闭时整组 toolbar 沿 X 左移，而内部相对位置不变，因此 region-to-arrow offset 在两个轴上都应保持不变。

这些数值和 rigid-body assumption 尚未经过多位置测量，不是 production constants。

### Deferred investigation

- 三个以上 toolbar Y 位置的四项 offset 是否一致；
- 窗口轻微移动后 offset 是否一致；
- popup 是否发生 flipping；
- black swatch、popup background/border 和 no-popup control pixel 的实际颜色与容差；
- pixel signature 检查是否能稳定区分 popup present 与 popup absent。

## Safety correction

无条件 relative black click 与现有 fail-closed contract 冲突。如果 arrow click 未打开 popup，第二次点击可能落入 report editor。因此批准的 Candidate G 必须使用 pixel signature guard：只有 signature 匹配时才允许 black click。

Pixel signature 至少包含：

1. black swatch 内部 sample；
2. popup 浅色 background 或 border sample；
3. 用于排除 no-popup editor background 的 control sample。

2026-07-16 Windows G1 calibration 已在多个 toolbar Y 位置完成。自动计算的 arrow point 均能打开菜单，且 popup 从 `t=0` 到 `t=80 ms` 保持稳定。G2 允许一次 immediate sample 和失败后的单次 20 ms passive sample；禁止第二次 arrow click。

## Proposed runtime contract

```text
Validate foreground MedEx
→ locate unique Text("检查所见")
→ validate RegionAnchor rectangle
→ calculate and validate ArrowPoint
→ save mouse position
→ recheck foreground
→ click ArrowPoint once
→ bounded short settle
→ validate popup pixel signature
→ recheck foreground
→ click BlackPoint once
→ restore mouse position
→ structured result
```

Candidate G 不依赖 dynamic font-size anchor、`①`、popup UIA traversal、exact `000000` lookup 或 InvokePattern。它也不允许 UIA/blind-coordinate fallback。

拟议的独立 profile fields：

```text
ProfileName
RegionAnchorName
ArrowOffsetX
ArrowOffsetY
BlackOffsetX
BlackOffsetY
MenuSettleMs
SignatureRetryDelayMs
PopupPixelSignature
```

G2 result states：

```text
COLOR_RESET_POPUP_SIGNATURE_MISMATCH
COLOR_RESET_BLACK_CLICK_FAILED
RELATIVE_MOUSE_CHAIN_OK
FINAL_COLOR_PENDING_VISUAL_VALIDATION
```

`RELATIVE_MOUSE_CHAIN_OK` 只表示 signature 通过且 black click 已发送；最终 insertion color 必须继续由操作者在 approved non-clinical context 人工验证。

## Activation boundary

以下启动条件已经满足：

1. 当前 Control/Candidate A/B 已完成；
2. semantic `检查所见` localization 在重复测试中稳定；
3. 主要失败仍集中于 popup UIA lookup/Invoke；
4. 当前 UIA interaction 未达到可接受可靠性；
5. 用户明确批准进入 Candidate G field-calibration milestone。

reconciled release smoke test 已完成。G1 允许建立 calibration-only pure logic 和 pixel reader，但不接入 production strategy，不创建 relative-black-click runtime，也不把 estimated offsets 或现场采样前 RGB 写成 production profile。

## Field validation if activated

第一阶段只做 calibration：手工打开菜单，在至少三个 toolbar Y 位置记录 region/arrow/black coordinates 与 privacy-safe pixel samples，验证 popup absent 时 signature 必须失败，并补测轻微窗口移动。

第二阶段执行一次 cold start、至少 20 次 `;red`、20 次 `;fzg`、20 次 immediate punctuation、一次 wrong-region、一次 forced popup-missing，以及多个 toolbar Y 位置各至少五次。任何 popup-missing case 发送 black click 都视为架构失败。

Supported initial environment 限定为 MedEx 0.0.1.0、1920×1080、100% scaling、DPI 96。其他环境必须返回 unsupported profile，不能复用坐标。

## G1 calibration controls

独立 `debug/medex_candidate_g_calibration.ahk` 不注册 production hotstrings：

- `F8`：记录人工 arrow center；
- `F9`：记录人工 black center，但不点击；
- `F10`：读取 popup-closed pixel grid；
- `F11`：validated region 后点击 arrow 一次，在 0/20/40/80 ms 读取相同 pixel grid；不点击 black。

Pixel grid 仅保存 screen coordinate 与 RGB，不保存截图或文字。结果写入 clipboard 和 `%TEMP%\MedExAHK\candidate_g_calibration.txt`。

## G1 field result and G2 profile

Clipboard sentinel gate 已通过。多位置 region rectangles 包括 Y≈200、309、340、353、689；每次 exact region query 均得到一个 geometry-valid toolbar candidate。人工指针测量有 1–5 px 抖动，但自动 profile point 在所有位置均实际打开 popup，因此 G2 使用经过点击验证的：

```text
ArrowOffsetX=320
ArrowOffsetY=0
BlackOffsetX=6
BlackOffsetY=83
```

G2 popup signature 要求四点全部匹配：

```text
(6,16)  = #FFFFFF tolerance 4
(6,83)  = #000000 tolerance 8
(20,83) = #EEEDE2 tolerance 12
(40,83) = #22447A tolerance 12
```

closed probes 在 black/beige/blue 位置为 white，且 toolbar background 与 popup light point 不同；因此 signature mismatch 会阻止 black click。`(64,83)` 因 closed state 可能与下方内容颜色重合，不进入 required signature。

Status: G2 controlled interaction, caret-order A/B, and the final generated-release validation passed on the supported Windows profile. `relativeMousePixelValidated` is the production mainline; `uiaInvoke` remains an explicit comparison/rollback strategy with no automatic fallback.

## Sidebar horizontal-translation correction

后续现场测试发现，MedEx 左侧 sidebar 关闭时工具栏整体向左平移。旧 production resolver 仍要求 `RegionAnchorRect.l` 位于绝对 screen X `272–320`，因此在点击 arrow 前以 `leftOutsideProfile` fail closed。该绝对范围不是 region-to-arrow 相对校准的一部分。

horizontal-translation v2 删除该绝对 X gate，继续保留 exact `检查所见`、锚点宽高、foreground client bounds、toolbar row band、arrow/black bounds、foreground recheck 和四点 popup signature。多个同名候选仍要求唯一 corroboration。`ArrowOffsetX=320`、black offsets、signature 数值和全部时序不变。

## Final mainline validation

2026-07-16 用户确认 generated `release/report_assistant.ahk` 完整验证通过。被验证 artifact 的 SHA-256 为：

```text
761a6c4261246a4bc14f44597e30eef4564db0bd1e48e92a31c1ac1e41f8ef11
```

验证结论覆盖 normal Candidate G color reset、`relativeMousePixelValidated` default dispatch、phrase-specific no-reset `;fzg` caret workflow，以及测试清单中的 mainline interaction/safety checks。该结论只适用于当前 supported profile：MedEx 0.0.1.0、1920×1080、100% scaling、DPI 96。其他环境仍须 fail closed 并单独校准。

红字插入后仍有轻微延迟，但不影响本次 mainline acceptance。延迟优化必须在后续独立提交中进行，每次只改变一个 named wait，并重新验证 clipboard sentinel、caret 和 immediate typing；不得顺带修改 Candidate G geometry 或 pixel signature。

## Caret-order discrepancy

Legacy `;fzg` does not run the black-color reset: it pastes `red_not.clip`, waits 50 ms, and sends `Left 4`. Only legacy `;red` performs the two fixed black-reset clicks. The current `;fzg` instead completes clipboard restoration and the selected Color Reset strategy before the same 50 ms / `Left 4` sequence. Field logs prove `CursorRestoreRequestedCount=4` and `CursorRestoreCommandSent=true`, but the visible caret remains one position late.

The first controlled discriminator therefore keeps the current CF_HTML payload constant and changes only execution order: current G2 reset path versus no-reset legacy order. If no-reset restores the correct caret, `;fzg` should become a phrase-specific workflow rather than inheriting `;red` reset orchestration. If both remain wrong, investigation moves to CF_HTML/Chromium caret boundaries. Arbitrary `Left 5` and speculative focus restoration remain prohibited until this A/B result is known.

Windows result：带 G2 reset 的 control 仍表现为少一次有效 caret movement；no-reset legacy-order candidate 连续 6 次记录 paste/clipboard restoration 成功、请求并发送 `Left 4`，且用户确认最终 caret 正确。因此根因是把 standalone `;red` 的 reset tail 错误复用于 `;fzg`，而不是 `Left 4` 常量或当前 CF_HTML caret boundary。Production fix 保持 `Left 4`，不增加 focus restoration，也不改变 Candidate G geometry/signature。
