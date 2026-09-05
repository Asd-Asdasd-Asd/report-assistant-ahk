# 2026-09-06 设计审计与 Viewer 故障分析

## 范围与证据

- 审计分支：`feature/automation-diagnostics`；HEAD：`05c62e9d3d7bf8ae716870cd8774313dffdd9366`。
- 审计前工作区干净，源码版本为 `0.8.0`。
- 重点检查 Viewer 快捷键、原生按钮派发、目标会话、快速标图、诊断与对应测试/设计记录；不是全部模块的逐行完整审计。
- Python suite：360 tests，全部通过。测试输出保存在本次机器 `/private/tmp/medex-audit-tests.log`。
- 按现有发布脚本中的时间、日期和 revision 重新生成到内存，与 `release/report_assistant.ahk` 完全一致。发布脚本记录 `8798306`，其后的 `05c62e9` 是生成文件提交；未发现源代码与生成文件漂移。
- 没有连接 Windows 工作机，没有当前失效日志、实际快捷键配置及运行 EXE revision；未复现或确认两项现场故障的唯一根因。
- 本次仅新增审计记录，没有修改功能代码、配置、发布脚本或版本号。结论针对代码行为，不归因于某个模型的固有偏好。

## 主要发现

### 1. P2：原生工具按钮仍被不参与派发的几何配置否决

位置：`src/mxnm_viewer_tool_commands.ahk:213–266,269–329`；`src/mxnm_config_geometry_provider.ahk:86–147`。

当前操作最终通过原生 Button HWND、Control ID 和直接父窗口发送 `WM_COMMAND`。但建立 plan 仍调用完整图像配置加载器，要求两个 INI 可读且可计算 hash、frame size 可解析、`SCBtnPadPosX/Y` 齐全，并要求三个命令都在第一列。

因此，即使目标按钮的原生身份有效，缺失无关布局文件、窗口尺寸字段或面板位置字段仍能阻止全部工具。移除运行时面板原点比较，并没有移除启动阶段对面板原点数据的依赖。这是明确的过度耦合与历史设计残留。

建议：将工具身份发现与图像几何解析分开。保留命令 ID、进程身份、目标 HWND、直接父窗口和明确歧义的校验；仅保留能说明必要性的配置约束。不要通过删除所有校验来简化。

另有连带阻断：`ResolveMxNMViewerToolControlSet` 要求三个按钮同时可见、启用且构成完整组，任一按钮缺失就拒绝其他按钮。它可能是历史面板识别签名，但应重新评估是否仍需让无关工具的 enabled 状态否决当前工具。此公共规则不能单独解释同一状态下“箭头正常而直径/SUV 失效”。

### 2. P2：诊断状态已参与快速标图业务时序，首次等待会被提前消耗

位置：`src/automation_diagnostics.ahk:44–49`；`src/report_image_caption.ahk:275–283,1060–1071`。

`ReportImageCaptionPasteSettle(operation)` 依据诊断对象的 `FirstTargetProcessUse` 选择首次 500 ms 或普通 20 ms 等待。`ObserveTarget` 在目标解析完成时就把 PID 写入 `SeenTargetProcesses`，发生在实际粘贴之前。

可由调用顺序直接推导的失败路径：首次解析目标成功 → `ObserveTarget` 消耗首次标记 → 因 source foreground 变化退出，或之后 clipboard/activation 失败 → 下一次真正首次粘贴只有 20 ms。即使新建 target HWND，只要 PID 相同，首次进程标记也不会恢复。是否导致现场漏存还需 Windows 验证，但首次等待策略被提前消耗的代码路径明确存在。

建议：由 Caption 自己管理目标会话的首次执行状态，并在达到规定的粘贴/保存阶段后更新；诊断只观察。保留有现场依据的等待，避免把修复变成所有操作统一加长 Sleep。

此问题属于“快速标图”的粘贴/保存流程，不是 F12 截图路径。

### 3. P2：按键释放等待没有上限，且关键提前退出不留证据

位置：`src/viewer_tool_hotkeys.ahk:82–112,179–205,209–234,237–267,331–353`。

四个 handler 复制了 `static active`、轮询释放、foreground HWND 比较、finally 复位的结构。释放等待是无限 `while ... Sleep 10`；等待过程中不检查前台是否已切走。只要读取的按键状态始终为按下，该 handler 就无法结束；后续触发可能被 active guard 静默丢弃。foreground 变化时也直接退出，没有区分取消、忙碌或按键状态异常。

这些是明确的恢复能力和诊断缺口，但不是本次症状的已确认根因：箭头和直径共用同一个函数内的 `static active`，provider 也有三者共用的 Busy。如果箭头确实通过同一脚本正常派发，单纯“直径共享锁一直为 true”不符合代码。

代码依赖 `GetKeyState(..., "P")`，主入口没有显式安装键盘 hook；其他热键可能令 AHK 自动安装，不能由此直接断言 hook 缺失。物理/逻辑状态与 hook 的区别见 [AutoHotkey 官方文档源码](https://github.com/AutoHotkey/AutoHotkeyDocs/blob/v2/docs/lib/GetKeyState.htm)。外部改键产生的组合键也需要现场区分。

建议：统一释放处理，采用有界等待和前台取消，记录精简结果码；在验证实际按键/hook 行为前不更改 modifier 语义。不要为每个按钮继续增加独立锁和恢复分支。

### 4. P2：F12 和“已派发但没有生效”的按钮操作缺少可用诊断

位置：`src/viewer_tool_hotkeys.ahk:95–109,346–378`；`src/mxnm_viewer_tool_commands.ahk:885–902`。

F12 handler 等待释放、检查前台后调用 `Send "{F12}"`，只要没有抛出异常就闪烁。它既不观察截图产物，也不建立 automation operation 或写 Viewer failure 日志。所以白色闪烁只能证明运行到了 Send 之后，不能证明 Viewer 接收并生成图片。

工具按钮以 `SendMessageTimeoutW != 0` 作为派发成功。这个 API 的非零返回值与输出参数中的消息处理结果不是同一个概念；本身也不能说明 Viewer 已进入测量模式。见 [Microsoft 官方 API 文档](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendmessagetimeoutw)。不能把返回值为零/非零机械解释为业务状态。

目前工具失败仅在 provider 返回失败后记录，入口未触发、释放等待、foreground 取消和返回成功但工具未切换都没有对应证据。托盘快照可能因此仍把之前的 Caption 操作当作“最近相关操作”。

建议：首先给 F12/工具入口接入已有精简诊断：动作、阶段、释放耗时、modifier mask、foreground/focus HWND、目标/父 HWND、Control ID、消息派发结果。日常避免每次扫描庞大 UIA 树；关键等待/取消记失败，正常派发可保留紧凑摘要或临时诊断记录。不要记录图像、报告文本或剪贴板内容。

### 5. P2：静态测试在固化实现文本，无法验证本次故障

位置：`tests/test_viewer_tool_hotkeys.py:40–54,156–169,201–256`；`tests/windows/mxnm_viewer_tool_command_field.ahk:11–21`。

相关 Python 测试大量检查源码包含某个函数名、判断条件和调用顺序。例如测试明确要求保留 `SCBtnPadPos`、`matches[1].column != 1` 和旧映射 helper 名称。这能防止意外删代码，也会让历史约束在测试保护下长期保留；通过不代表这些约束合理，更不代表按键实际成功。

旧 Windows 工具 field harness 直接在 key-down 调用 provider，绕过 production 的松键等待；对于已经有 modifier-dependent 行为证据的 SUV，它与真实入口并不等价。

建议：保留少量生成/接线检查。新增或调整测试时优先覆盖“第一次操作取消后仍保留首次状态”“释放异常后能再次触发”“真实入口与直接命令的结果差异”等行为；原生 field probe 明确标记为 provider 测试，不能替代生产热键验收。

### 6. P3：项目状态与设计说明滞后，旧实验仍混在生产模块

`docs/internal/project-status.md` 仍写 `0.6.3`、283 tests 和 config-only measurement target。当前为 `0.8.0`、360 tests；production `MxNMMeasurementProvider.ResolveTarget` 已调用 context-session resolver。

`docs/internal/mxnm-viewer-tool-hotkeys.md` 一处说明面板原点没有运行时否决权，后面又把“原点不匹配”列入当前 fail-closed 边界，混用了不同历史阶段。

`MapMxNMViewerToolPadOriginToRuntimeFrame`、`MxNMViewerToolPanelMatchesPadOrigin` 等仍存在于生产模块，主要由旧 checkpoint/field audit 使用。不能直接整文件删除：现场工具和构建脚本还有引用。

建议：更新当前调用链与验收状态，历史说明明确日期并移入对应实验材料；先检查构建/诊断引用，再搬迁旧 helper。没有发现发布脚本内容落后于源码。

## 对本次两个现场现象的判断

### 第一张 F12 截图失败，但闪烁出现

已能排除该次 handler 根本未进入，以及一直卡在发送前的松键循环：闪烁位于 Send 后。不能据此排除消息未被正确消费、首次图像焦点/接收窗口不对、Viewer 截图功能尚未就绪、输入时序问题。

pulse 为了覆盖整块 Viewer，会选择同 owner-family 中更大的窗口，但这只影响闪烁覆盖范围，完全没有改变 F12 的接收方式。它不是截图目标修复。

优先现场对照：在相近的首次状态下分别直接按物理 F12、使用配置热键；记录是否需要先点图像、是否只是首张失败，以及图片是否随后延迟出现。不要一开始就增加第二次 F12 或任意固定延迟，否则无法区分根因，也可能改变图片数量。

### SUV/直径失效，箭头正常，重新加载恢复

三者共用 plan、完整按钮组校验、provider Busy；每次重新枚举 Button HWND，没有分别缓存 SUV/直径 HWND。箭头和直径还共用 hotkey active guard。因而“某个测量 HWND 缓存过期”或“公共校验一直失败”不是充分解释。

先区分两层：原生鼠标按钮是否也失效；以及重新加载的是麦旋风还是 Viewer。若麦旋风重载恢复而原生按钮始终可用，更值得优先检查按键映射、释放状态、handler 退出与命令上下文；若原生按钮也失效，则需要查看 Viewer 自身工具状态。

工具 plan 的确只在进程内复用，不重新检查配置 hash；更改 vendor 按钮布局后，重载可以刷新它。这是设计限制，但如果同一状态下箭头仍正常，不能仅凭“重载恢复”把它确定为此次根因。

## 建议实施顺序

1. 补齐 F12/工具的最小入口与派发证据，确认实际快捷键、重载对象及 Windows EXE revision。
2. 修正 Caption 的业务状态对诊断状态的依赖；统一有界松键与取消处理。
3. 去除原生工具路径中无关的几何配置门槛，逐项复核完整组签名的必要性。
4. 同步当前文档、调整锁死旧实现的测试，并通过生产入口做 Windows 首次/连续/重载回归。

不建议删除所有 try/catch、目标身份校验或 clipboard finally restoration。配置事务备份、精确命令身份、未标注与解析失败的区别、已有副作用后不自动重放等仍有明确用途。

## 执行结果（用户批准后，2026-09-06）

上述审计是修改前的记录。后续已完成以下源码修订：

- Viewer 五类快捷键统一事务、3 秒松键上限、前台取消和 finally 复位；补充现有诊断的动作摘要、松键耗时、物理/逻辑 modifier mask、焦点/目标 HWND、命令 ID 和派发状态。
- F12 仍只发送一次，白闪窗口解析后再次检查前台；没有新增自动补发或固定截图延迟。
- 工具生产计划改为 live 进程路径与固定原生命令定义，不再读取 vendor INI 或持久化配置计划。完整面板仍须唯一；其他禁用工具不连带否决，当前目标禁用返回 `BUTTON_DISABLED`。派发前再次检查前台。
- Caption 首次等待由业务 target PID/HWND session 管理，实际派发保存点击后才标记已使用；目标解析或诊断观察不再提前消耗标记。
- 当前架构和状态说明已同步，历史基线明确分隔。旧配置/映射 helper 仍用于 checkpoint，未整块删除。
- 已生成 `viewer_state_regression_standalone.ahk`，直接提取生产状态逻辑，使用合成 Button 面板验证禁用 sibling、按钮位置变化和完整面板歧义；不操作 MedEx。

验证：364 项 Python 测试通过，`git diff --check` 通过；重新生成的 release 与当前源码完全一致，构建日期为 2026-09-06，revision 标记为 `05c62e9-dirty`。没有提交或推送。版本仍为 0.8.0，本次尚非正式发布。

Windows 验收尚未执行：当前环境为 macOS，未提供 Windows AHK/Ahk2Exe 运行入口。需运行生成的状态回归脚本，再通过 `Build EXE.cmd` 构建，测试实际配置键位的首次/连续调用、持键超时、前台切换、Viewer 重启及麦旋风重载。F12 首张失败与“直径/SUV 失效但箭头正常”的唯一根因仍待当前工作机证据，不应把本次静态通过标记成现场修复成功。
