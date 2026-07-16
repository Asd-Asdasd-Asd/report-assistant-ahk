# 2026-07-15 Color Reset V1 生产基线验证

本文件固化 `debug/field-result-2026-07-15/` 的结论。原始 clipboard、result 和 log artifacts 保持原样，不在本文中改写或规范化。

## Validated environment

- Application version under test：`0.5.0-development` semantic-anchor build
- MedEx：`0.0.1.0`
- Process observed：`medexworkstations.exe`（该现场结果后来作为 primary field-confirmed process；`medexworkstation.exe` 仅保留为 compatibility candidate）
- Resolution：1920×1080
- Display scaling：100%
- DPI：96
- AutoHotkey：2.0.18
- UIA-v2：pinned v1.1.3

## Verified automation behavior

三次连续运行返回 `AUTOMATION_CHAIN_OK`，约为 890 ms、859 ms、844 ms，均满足：

```text
RegionAnchorFound=true
RegionAnchorRect=296,289,352,305
FontSizeCandidateCount=1
FontSizeAnchorMatchedName=16px
FontSizeAnchorRect=502,290,529,304
CalculatedScreenPoint=672,297
ColorMenuClickSent=true
BlackItemFound=true
BlackItemInvokeSucceeded=true
RetryCount=0
```

Optional `rAI` fingerprint 同时被观察到，但它不属于成功条件。

## Verified fail-closed behavior

较早一次运行返回：

```text
COLOR_RESET_REGION_ANCHOR_NOT_FOUND
ColorMenuClickSent=false
```

这证明 region anchor 暂时未暴露时，adapter 没有继续 blind click。后续在目标界面状态稳定后连续成功。

## Manual visual validation

用户已在 approved non-clinical context 手工输入无害字符并确认其为黑色。因此本次结论为：

```text
Automation chain: PASSED
Final insertion color visual validation: PASSED BY USER
MedEx 0.0.1.0 / 1920x1080 / 100% scaling baseline: PASSED
```

Field debug 中 `FinalInsertionColorVisuallyValidated=false` 仍是预期值：脚本不能自行观察用户随后输入字符的颜色，人工确认由本文持久化。

## Validated production profile

```text
RegionAnchorName=检查所见
FontSizeNamePattern=^\d+(?:\.\d+)?px$
OptionalRightAnchorName=rAI
ColorArrowOffsetX=143
ColorArrowOffsetY=0
```

`①` 是用户可配置内容，不是 production anchor；`16px` 是动态字号值，不做 exact production match。

## Remaining limits

尚未验证：其他 DPI/scaling、其他分辨率、多显示器/per-monitor DPI、未来 MedEx layout、其他用户环境。process name 在本机连续观察为 `medexworkstations.exe`，但本里程碑继续保留 exact provisional allowlist，等待更多工作站证据后再收窄。
