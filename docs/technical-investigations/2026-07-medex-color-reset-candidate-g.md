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
- toolbar 可能作为 rigid body 沿 Y 移动，因此 region-to-arrow offset 可能保持不变。

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

颜色、sample offsets 和 tolerance 必须由 Windows field calibration 得出；本文件不猜测阈值。允许一次 short settle 和最多一次只读 signature retry，禁止第二次 arrow click。

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

拟议结果状态：

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

Status: G1 implemented for calibration only; field validation pending.
