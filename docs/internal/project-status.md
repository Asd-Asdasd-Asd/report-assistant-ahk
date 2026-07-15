# 项目状态与交接

更新时间：2026-07-15（M1 semantic-anchor redesign，等待 Windows 复测）

## 当前阶段

项目处于 `v0.5.0 — Internal Test Foundation` 的 M1。CF_HTML 红字插入已确认；颜色菜单 black-item Invoke mechanism 已部分验证；最终 insertion color 尚未通过新的 semantic-anchor build 人工验证。本轮只处理 Color Reset V1，不修改 legacy、configuration、measurement 或 packaging。

## Repository 状态

- Branch：`main`，当前相对 `origin/main` ahead 3。
- 基线提交：`3457248`。
- 现场 evidence 目录均保留原样，尤其是未跟踪的 `debug/field-result-2026-07-14/`。
- 不 commit、不 push；durable conclusions 写入 `docs/field-tests/`。

## 2026-07-14 新证据

### Verified behavior

- 四次旧 M1 均枚举三组 old-model pairs 并正确选择 index 2。
- 全部因 UIA root `[-8,-8,1928,1048]` 超出 client area 返回 `COLOR_RESET_INVALID_COORDINATE_SPACE`，没有发送 click。
- `检查所见` 是 Text `[296,289,352,305]`。
- `14px`/`16px` 是同一位置的动态 Text leaf `[502,290,529,304]`。

### User observation

- `①` 是用户可配置 shortcut content，可改名、重排或移除。
- 当前字号变化会改变 Text Name。

### Implementation inference

- entire-root/client containment 是过严且无助于防止实际 misclick 的约束，已移除。
- semantic region + same-row dynamic font + local offset 比 second-candidate model 稳定。
- 局部字号到 color control 的水平布局在当前 `medex-0.0.1-baseline` profile 内假定稳定。

### Deferred investigation

- 新 profile 在 Windows 上的实际 click/Invoke 和最终颜色。
- 其他 DPI/scaling/window size/MedEx version。
- direct Electron/editor command。

## 已实现的 Revised V1

1. foreground MedEx root 枚举 Text elements。
2. exact Name=`检查所见` 必须唯一。
3. 同行右侧动态字号必须唯一匹配 `^\d+(?:\.\d+)?px$`。
4. optional `rAI` 只写 diagnostics，不阻塞。
5. click 使用 `fontRect.r + 143`、`fontCenterY + 0`；baseline 为 `(672,297)`。
6. point 必须在 foreground client area 和目标 local toolbar band。
7. click/Invoke 前复核 foreground hwnd/process。
8. 一次 validated click，必要时最多一次 bounded retry；exact black-item Invoke，无 guessed fallback。
9. field debug 只写 clipboard/log/file，不显示 `MsgBox`、`ToolTip` 或 `TrayTip`。
10. automation success 与人工 final color validation 保持分离。

集中 profile：`MedExColorResetLayoutProfile`。小版本布局改变通常只需重新校准 `ColorArrowOffsetX/Y`，无需修改 resolver。

## Diagnostic contract

输出 region/font/optional anchors、active profile、offsets、screen/client point、selection/geometry/coordinate/foreground reasons、timings 和 retry。`AUTOMATION_CHAIN_OK` 不等于最终成功；人工确认前保持 `FINAL_COLOR_PENDING_VISUAL_VALIDATION` 和 `FinalInsertionColorVisuallyValidated=false`。日志不得包含临床内容。

## UIA dependency

UIA-v2 v1.1.3 是 pinned reproducible dependency，不表示其他版本绝对不可用。现场脚本使用 repository `debug/Lib/UIA.ahk`，无需系统级安装，也不应另放一份 global library。

## Windows 下一次验收

在 approved non-clinical context：聚焦检查所见，运行 Ctrl+Alt+F12；确认 region/font 选择、期望 `(672,297)`、菜单打开和 exact `000000` Invoke；随后手工输入无害字符并确认黑色。严禁在 finalized patient report 测试。

## 风险

- Color trigger 没有 usable UIA node，仍需一次局部校准 click。
- `检查所见` 的语言或产品文案变化需要新 profile。
- 同行存在多个 px-like Text 时会 fail closed。
- 多显示器、DPI、缩放和 MedEx version variations 尚未覆盖。
- Process name 仍以两个 provisional candidates 接受；production name 待目标工作站最终固定。

## Scope boundary / next step

当前只需完成 Windows M1 复测并回传 field result。通过人工最终颜色验证后再评估 M1 exit；不自动进入 M2，不修改额外 legacy 行为，不编译 executable。
