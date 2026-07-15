# 2026-07-13 MedEx 工作站现场证据

> Historical evidence note (2026-07-15): 本文中的 `16px + ① + second candidate` 是当日被测实现和证据模型，不再是 production design。后续确认 `①` 可由用户修改，`16px` 是动态字号值；替代模型见 `2026-07-14-color-reset-validation.md`。

本文固化 2026-07-13 Windows 工作站测试结论。原始材料保存在 `debug/field-result-2026-07-13/` 和 `debug/legacy-automation-survey-2026-07-13/`，作为只读历史证据；本文不替代或改写原始记录。

环境：Windows 工作站，1920×1080，100% display scaling，DPI 96，AutoHotkey 2.0.18，MedEx 0.0.1.0。现场记录的进程名为 `medexworkstations.exe`。

## 证据分类

- **Verified behavior**：由诊断输出、截图、源码或重复操作直接支持。
- **User observation**：由现场操作者直接看到，但自动化尚不能独立验证。
- **Implementation inference**：根据多份证据形成的工程解释，仍需实现或复测。
- **Deferred investigation**：现有证据不足，不能据此作生产保证。

## Artifact inventory

| Artifact | 分类 | 能够证明 | 不能证明 | 相关实现 |
| --- | --- | --- | --- | --- |
| `field-result-2026-07-13/field_notes.txt` | User observation | 测试聚焦下方编辑器；脚本却打开上方工具栏；黑色 Invoke 后曾观察到黑色生效；完成通知导致失焦 | 目标编辑器最终插入色已经稳定恢复 | `src/adapters/medex_report_editor.ahk`、`debug/medex_color_reset_field_debug.ahk` |
| `field-result-2026-07-13/medex_color_reset_field_debug.txt` | Verified behavior | 六次选择矩形 `(502,112,529,126)` 与 `(953,111,967,127)`；计算 `(672,113)`；找到 `000000`；Invoke 可用且未抛错 | 被操作的是目标检查所见工具栏；用户后续输入一定为黑色 | adapter、diagnostics、field-debug formatter |
| `field-result-2026-07-13/medex_color_reset_field_debug.log` | Verified behavior | 六次 automation chain 均走到现有 `COLOR_RESET_OK`；耗时约 765–938 ms | 现有 result code 不等同于最终视觉成功 | `src/diagnostics.ahk` |
| `field-result-2026-07-13/wrong-toolbar-target.png` | Verified behavior | 同一页面至少存在病史信息、检查所见、检查结论三组同构工具栏；检查所见为第二组 | accessibility parent relationship 或 focused Document relationship | M1 anchor enumeration |
| `legacy-automation-survey-2026-07-13/legacy_survey_index.txt` | Implementation inventory | 列出九类待迁移业务动作及当前调查状态 | 每个动作已达到生产可靠性 | migration/roadmap docs |
| `legacy-automation-survey-2026-07-13/legacy_actions_inventory.txt` | Verified source behavior + User semantics | HHKB、三套 montage 参数、caption、F12、SUV/Arrow 时序、cover 和 measurement 业务语义 | 固定坐标在其他布局可用；UIA target 均已唯一确认 | `legacy/karabiner.ahk`、compatibility snapshot |
| `legacy-automation-survey-2026-07-13/legacy_ui_notes.txt` | Verified UI observations + Deferred investigation | 标准按钮/输入项可优先 UIA；部分自绘区只暴露父区域；measurement menu 有命名按钮 | 尚未采集的 AutomationId、pattern、parent 或状态信号 | future viewer modules |
| `script_snapshot/medex_legacy_compat_annotated_2026-07-13.ahk` | Verified source behavior | 保存当日坐标流程、参数、时序与人工注释 | 注释本身不证明生产安全，也不批准沿用 absolute coordinates | `legacy/medex_legacy_compat.ahk` |

调查目录没有 `screenshots/` 或 `uia_dumps/` 子目录，除 `wrong-toolbar-target.png` 外没有其他现场截图。缺失不构成本轮 blocker，但相关 UIA parent、AutomationId、pattern 和 custom-region geometry 继续属于 deferred investigation。

## Color reset 现场结论

### Verified behavior

- CF_HTML 已能在 MedEx report editor 插入红色文字。
- 比例 `0.337` 在被选中的工具栏上计算出约 `(672,113)`，可打开颜色菜单。
- 颜色菜单中的 `Hyperlink` Name=`000000` 可找到，支持 Invoke；六次调用均未记录异常。
- 当前实现取第一组 `16px` 和 `①`，实际选中病史信息工具栏，而不是预期的检查所见工具栏。
- 三组已观察 geometry：

| Toolbar | `16px` | `①` |
| --- | --- | --- |
| 病史信息 | `[502,112,529,126]` | `[953,111,967,127]` |
| 检查所见 | `[502,290,529,304]` | `[953,289,967,305]` |
| 检查结论 | `[502,735,529,749]` | `[953,734,967,750]` |

### User observation

- 操作者聚焦检查所见编辑器，但脚本打开了病史信息颜色菜单。
- `000000` Invoke 后，黑色激活本身看起来成功。
- 完成通知改变了焦点；焦点恢复后颜色状态又受到干扰。因此该次测试不能确认为最终颜色复位成功。

### Implementation inference

- 颜色 trigger 比例定位与 black-item Invoke 的技术路线可继续使用。
- 当前主要缺陷是 toolbar candidate selection，不是比例公式或 Invoke 本身失败。
- V1 应从 foreground MedEx window root，或经证据确认的报告区域父容器，枚举 anchors；不能假设 toolbar anchors 是 focused `Document` 的 descendants。
- 将唯一有效 pairs 按 Y 排序后选择第二个，是当前基线布局下最低风险的内测实现。

### Deferred investigation

- V1 第二候选策略在其他 MedEx 版本、窗口宽度、DPI、缩放或布局下是否仍成立。
- focused editable `DocumentRect` 与最近上方 toolbar 的稳定关系；这是 V2 候选，不属于 V1。
- Electron renderer、IPC 或 embedded editor API 是否可直接设置颜色。

## 输出与实际观察的矛盾

1. 日志报告 `COLOR_RESET_OK`，但操作了错误工具栏，且最终输入色未完成有效人工确认。最可能解释是现有 code 只表示 black item Invoke 未抛错，不表示目标 editor 最终状态正确。
2. `Process=medexworkstations.exe` 同时出现 `ProcessNameConfirmed=false`。前者命中 provisional candidate；后者表示 production confirmed-name 尚为空，不表示进程名称读取失败。
3. `RetryCount=false` 应为整数 `0`，属于 diagnostic serialization/type defect。
4. `UIALibraryVersion=EXPECTED_1.1.3_NOT_RUNTIME_DETECTED` 只表示预期依赖版本，不是 runtime detection。当前仓库 pinned `debug/Lib/UIA.ahk` v1.1.3；没有证据证明其他版本绝对不可用。
5. 现场记录称完成通知改变焦点。无论具体来自 `MsgBox` 还是其他 UI，本轮 M1 默认不得显示反馈，只写 clipboard/log。

## V1 已批准安全边界

- 分别枚举所有 `16px` 和 `①`，按 vertical alignment、horizontal order 和 plausible gap 形成唯一 pairs。
- 不要求候选数严格等于三；至少需要两个唯一有效候选。
- 按 Y 排序并选择第二个候选。
- 缺少第二候选、一个 anchor 多重配对、排序相同/不稳定、rectangle/geometry/coordinate space 异常时 fail closed，不发送 click。
- automation diagnostics 分别记录 `ToolbarCandidateSelected`、`ColorMenuClickSent`、`BlackItemFound`、`BlackItemInvokeSucceeded`。
- 自动化链路可以报告 `AUTOMATION_CHAIN_OK`，但必须同时报告 `FINAL_COLOR_PENDING_VISUAL_VALIDATION`。
- `FinalInsertionColorVisuallyValidated` 只能由操作者在 approved non-clinical context 输入无害字符后记录；不得由 Invoke 结果自动设为 true。
- 禁止 `MsgBox`。未经 Windows 验证无干扰的 ToolTip/TrayTip 也不启用；默认仅写 clipboard 和 privacy-safe log。

## Legacy survey 固化结论

- RAlt+H/J/K/L 是需要保留的全局 HHKB navigation，不应受 MedEx `#HotIf` 限制。
- Body/Head/Lung montage 的参数分别为 `8.5/8/0.8`、`4/11/1.2`、`7.5/23/0.9`；Lung 额外恢复 lung window。
- Caption workflow 为复制选中文字、粘贴 caption、移动指针到图像、WheelDown、恢复鼠标；不需要额外 click。
- Screenshot 优先使用官方 F12；命令已发送不能冒充截图已生成。
- SUV 与 Arrow 保留独立 3000 ms/1000 ms repeat-press clear semantics 和各自 clear controls。
- Cover workflow 保持为独立业务：左侧 MIP，右侧 coronal sectional/fusion。
- `复制SUVMax值` 与 `复制直线测量值` 是命名 UIA Button。`SUVMax: 0.000` 不证明有 ROI；line 输出保持 MedEx 创建顺序，不数值排序，第四条及以后不进入返回值。
- XButton1 notification 是历史测试项，不属于正式功能或迁移任务；只有发生实际 hotkey conflict 时才需要处理。

## 下一验证步骤

M1 完成后，在非临床测试环境确认第二组 toolbar 被选中、没有任何 focus-stealing feedback、black item Invoke 成功，并人工输入无害字符确认最终颜色为黑色。严禁在 finalized patient report 中测试。
