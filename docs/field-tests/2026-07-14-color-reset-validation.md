# 2026-07-14 Color Reset V1 工作站验证

本文件固化 `debug/field-result-2026-07-14/` 的结果。原始 clipboard、result 和 log 文件保持不修改。

## 环境

- MedEx：`0.0.1.0`
- Process：`medexworkstations.exe`
- Resolution：1920×1080
- Display scaling：100%
- DPI：96
- AutoHotkey：2.0.18
- UIA dependency：pinned UIA-v2 v1.1.3

## Verified behavior

四次 M1 运行均成功枚举旧模型的三组 anchors，并选择 index 2：

```text
ToolbarCandidateCount=3
SelectedToolbarIndex=2
SelectedFontSizeRect=502,290,529,304
SelectedNumberButtonRect=953,289,967,305
```

所有运行随后返回 `COLOR_RESET_INVALID_COORDINATE_SPACE`，没有发送 click：

```text
UiaRootRect=-8,-8,1928,1048
ColorMenuClickSent=false
BlackItemFound=false
BlackItemInvokeSucceeded=false
```

这证明旧 M1 的 enumeration、pairing、sorting 和 fail-closed 工作，但 entire-root/client containment 错误地拒绝了包含 Windows invisible resize frame 的有效窗口。

## Newly invalidated assumptions

后续 UIA 检查确认：

- `①` 是用户可配置 shortcut content，可改名、重排或移除，不能作为 required production anchor。
- `16px` 是 font-size selector 的当前值；切换到 `14px` 后 Name 改变，但 rectangle 保持 `[502,290,529,304]`。
- Font-size element 是 `ControlType=Text` leaf，当前没有可用 ComboBox/container parent。
- `检查所见` 是目标区域标题，`ControlType=Text`，rectangle `[296,289,352,305]`，可作为 semantic row anchor。
- `rAI` rectangle `[1474,291,1490,306]` 可作为 optional layout fingerprint，但不是 production dependency。

因此，旧 `16px + ① + second candidate` 模型已废弃。原数据只保留为历史证据。

## Approved replacement model

- Required region anchor：exact Text Name=`检查所见`。
- Required local anchor：同一 row、位于 region 右侧、Name 匹配 `^\d+(?:\.\d+)?px$` 的唯一 Text。
- Optional right anchor：Name=`rAI`，只用于 diagnostics。
- Click point：`fontRect.r + ColorArrowOffsetX`、`fontCenterY + ColorArrowOffsetY`。
- Baseline calibration：`ColorArrowOffsetX=143`、`ColorArrowOffsetY=0`，预期 `(672,297)`。

## Remaining workstation validation

新 resolver 尚未在 Windows 执行。下一次测试必须确认 semantic region/font selection、`(672,297)` menu click、exact `000000` Invoke，以及人工输入字符最终为黑色。严禁在 finalized patient report 中测试。
