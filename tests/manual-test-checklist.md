# Windows 手动测试清单

本清单在安装 AutoHotkey v2 的 Windows 目标工作站执行。不得使用真实患者报告作为测试样本。

## Optional GlobalHjklArrows（待 Windows 验证）

1. [ ] 准备一份不含 `[Features]` 的现有 UTF-16 LE 配置，只运行 regenerated release；确认自动补入 `GlobalHjklArrows=false`，原 hotstrings/custom sections 完整保留，并在 `backups` 目录生成备份。
2. [ ] 再次启动 release；确认没有缺失项时不重复生成备份。退出 release，将 `GlobalHjklArrows=true` 写入配置，确认后续启动不会改回 `false`。
3. [ ] 完全退出 `legacy/karabiner.ahk` 和 compatibility script，再启动 release。
4. [ ] 分别在记事本、MedEx 和 viewer 验证 `RAlt+H/J/K/L` 为 Left/Down/Up/Right，并验证普通 H/J/K/L、左 Alt 和 RAlt 单独按下行为与 legacy 一致。
5. [ ] 验证按住四个组合键的重复行为；确认不受 MedEx-only hotstring guard 限制。
6. [ ] 按 `Ctrl+Alt+Esc` 后确认 HJKL 和 hotstrings 均暂停，再按一次确认恢复；暂停期间 `Ctrl+Alt+Q` 仍可退出。
7. [ ] 重新启动 release，确认现有 `config.ini` 未被重写且开关继续生效；最后复测五个 production hotstrings。
8. [ ] 修改并保存一个 hotstring，右键托盘选择“重新加载配置”；确认旧 PID 退出、新 PID 启动、只有一个托盘实例，且新配置生效。
9. [ ] 分别在 Suspend 和 Pause 状态执行“重新加载配置”，确认重启后恢复 active；双击托盘图标会打开设置窗口。
10. [ ] 核对 reload 没有触发 singleton conflict，startup log 新增一条 `STARTED`。
11. [ ] 使用不支持的 `SchemaVersion` 和只读配置分别启动，确认原文件不被修改、release 不崩溃且 HJKL 保持关闭。

## 原生设置窗口（待 Windows 验证）

1. [ ] 双击托盘图标和右键选择“设置…”分别打开设置；重复操作只激活同一个窗口。
2. [ ] 修改内置模板的名称、触发词、文字、模式和启用状态；确认内置模板不能删除。
3. [ ] 新增、停用并删除自定义模板；确认界面不显示 INI section 或内部 ID。
4. [ ] 制造相同或仅大小写不同的重复触发词，确认保存被阻止并定位到对应模板。
5. [ ] 保存包含多行文字和普通反斜杠的模板，确认重启后内容和触发行为正确。
6. [ ] 保存前记录 `[Features]`、未知 section、未知 key 和注释；确认保存后仍然保留。
7. [ ] 修改后点击取消、按 Esc 和关闭窗口，分别确认选择不放弃时窗口保持打开，选择放弃时配置文件不变。
8. [ ] 设置窗口打开期间从外部修改 `config.ini`，确认保存被拒绝且外部内容没有被覆盖。
9. [ ] 将配置设为只读后保存，确认显示失败、临时文件被清理且原配置仍可用。
10. [ ] 正常保存后确认旧 PID 退出、新 PID 启动、只有一个托盘实例且新配置生效。

## Candidate G sidebar horizontal translation（待 Windows 验证）

1. [ ] sidebar 展开时连续执行 `;red`、`;fwj`、`;fjd`，确认 marker 红色、后续输入立即为黑色、clipboard 和鼠标均恢复。
2. [ ] 不重启 release，关闭左侧 sidebar；确认工具栏整体左移后重复同一组测试，颜色恢复仍成功。
3. [ ] 在 sidebar 展开/关闭之间反复切换，每种状态至少执行 10 次 `;red`，确认没有错误 toolbar click、popup signature mismatch 或 black click failure。
4. [ ] 检查 field diagnostics：两种状态的 `RegionAnchorScreenX/ClientX` 不同，但 `HorizontalGeometryPolicy=translationInvariant`，arrow/black offsets 保持 `320/0/6/83`。
5. [ ] 强制 popup 未打开、切换 foreground 和构造多个同名候选，确认 black click 被阻止且没有 automatic fallback。
6. [ ] 最后复测 `;fzg`、`;cmx` 和 `GlobalHjklArrows`，确认 sidebar 修复未改变 no-reset、caret 或全局 hotkey 行为。

## Current baseline and next checkpoint

- Candidate G promotion baseline：`2369b68` / `candidate-g`；Step 1=`87dce53`，Step 2=`7a0d9a2`，Step 3=`6c2e2dc`，Step 4=`5193403`。
- Step 3 已记录 `86 tests passed`；验收 release SHA-256=`e199466dd78012f5d7b8737406590203eef8ff3e04fd4022e34d88110cb6fbf1`。
- Step 5 已记录 `89 tests passed`；Windows version-metadata validation 与 generated-release smoke test 已通过。
- `relativeMousePixelValidated` 是 production default；`uiaInvoke` 仅显式 comparison/rollback；无 fallback。
- `;fzg` 当前不运行 Color Reset；Step 4 candidate 顺序为 paste/restore → `Left 4`，始终不使用 `Left 5`。
- Step 4 已由 `5193403` 提交；下一检查点为 Step 5 version-metadata validation。

Step 1 已于 2026-07-20 通过：

```text
Step 1 passed
TriggerToBlackClickMs=906/797/766
PasteToClipboardRestoreMs=312/312/313
No functional failures
```

Step 2 Windows 验收：

1. [x] 只运行 regenerated release；确认启动时无 parser error 或 `#Warn`。
2. [x] 在 MedEx 前景窗口逐一验证 `;red`、`;fwj`、`;fjd`、`;fzg`、`;cmx`，确认文字、颜色、caret 和 clipboard 行为不变。
3. [x] 将 clipboard 设为无害 sentinel，在 Notepad 等无关应用逐一输入五个 trigger；确认均保留为普通文本，未扩展、未发送额外按键且 clipboard 未改变。
4. [x] 在 MedEx 外按 `Ctrl+Alt+Esc` 可暂停，再按一次可恢复；suspended 时仍可执行该快捷键。
5. [x] 在 MedEx 外确认 `Ctrl+Alt+Q` 仍可退出脚本，随后重启 release 完成余下测试。
6. [x] 在 Candidate G arrow click 前切换到无关窗口，确认新窗口未收到 coordinate click，结果 fail closed。
7. [x] 在 arrow 已打开 popup、black click 前切换到无关窗口，确认新窗口未收到 black coordinate click，结果 fail closed。
8. [x] 未观察到 hotstring 漏触发、错误应用触发、clipboard 变化或跨窗口 click。

Candidate G 同轮复验：G1 row localization 稳定；G2 success path 与 closed-signature fail-closed 正常。Caret-order A/B 继续表现为 F8 reset-path `Left 3`、F9 no-reset `Left 4`；production `;fzg` 使用后者，因此不构成 Step 2 回归。

Step 3 已同时完成 success 与 deliberately induced fast-failure，确认 no wrong paste、clipboard restored 和 immediate punctuation black。

### Step 3 clipboard reorder

本轮只在 approved non-clinical context 执行。F11 会把 timing output 写入 clipboard；F10 故意制造 Candidate G fast failure，并只写 `%TEMP%\MedExAHK\medex_production_timing_debug.txt`，不会覆盖用于验证 restore 的 sentinel。

1. [x] 只运行 regenerated release，在 MedEx 中把 clipboard 设为无害 sentinel 后执行 normal `;red`；marker 为红色、未粘贴 sentinel、执行后原 clipboard 恢复，立即输入标点为黑色。
2. [x] 退出 release，只运行 field harness；F11 success path 连续执行三次。
3. [x] 三次均为 `RED_TEXT_OK`、`RELATIVE_MOUSE_CHAIN_OK`、`ClipboardRestoreSucceeded=true`，且 `BlackClickSentMs = ClipboardRestoreStartedMs`。
4. [x] `TriggerToBlackClickMs=625/500/515`、`BlackClickToClipboardRestoreMs=0/0/0`；black click 较 Step 1 平均约提前 276 ms。
5. [x] 重新设置无害 sentinel，F10 fast-failure path 连续执行三次。
6. [x] F10 每次 red marker 未被 sentinel 替换，运行后 clipboard 仍为 sentinel。
7. [x] F10 每次为 `RED_TEXT_RESET_FAILED`、`COLOR_RESET_WRONG_PROCESS`，arrow/black timestamps 为 `UNKNOWN`，clipboard restore 成功。
8. [x] F10 `PasteToClipboardRestoreMs=312/313/313`，safety wait=`109/94/110`；failure feedback 均在 restore completed 后。
9. [x] Artifact SHA-256=`e199466dd78012f5d7b8737406590203eef8ff3e04fd4022e34d88110cb6fbf1`；Step 3 pass。

### Step 4 `;fzg` settle A/B

本轮只在 approved non-clinical context 执行。完全退出 release 和其他 debug scripts，只运行 `debug/medex_candidate_g2_test.ahk`；结果写入 `%TEMP%\MedExAHK\candidate_g2_test.txt`。

1. [x] 将 clipboard 设为无害 sentinel，在相同 editor state 交替完成五组 F9/F10；每次使用新的空白测试位置。
2. [x] F9 control 记录 `TestCase=step4Control50Ms SettleDelayMs=50`；F10 candidate 记录 `TestCase=step4Candidate0Ms SettleDelayMs=0`。
3. [x] 十次均确认 caret 精确为 `|（见图）`、原 clipboard 恢复，并立即输入 harmless punctuation 验证其为黑色。
4. [x] 十次均为 `ClipboardRestoreSucceeded=true`、`ColorResetResult=NOT_RUN`、`CursorRestoreRequestedCount=4`、`CursorRestoreCommandSent=true`，且没有 toolbar interaction。
5. [x] F9 `ElapsedMs=485/516/469/469/515`；F10 `ElapsedMs=437/422/422/422/438`，0 ms candidate 平均约缩短 63 ms。
6. [x] 退出 harness，只运行 regenerated release；normal `;fzg` 连续 10 次通过 caret、clipboard 和 immediate-black 验证。
7. [x] Generated release 的 normal `;red` smoke test 通过，Step 3 red insertion、black reset 和 clipboard restore 无回退。
8. [x] Artifact SHA-256=`4de7f53a2498a2eda5ba4df8035339051b3d99653b5b004df0647a7517a936aa`；Step 4 pass，提交前不得进入 Step 5。

### Step 5 version metadata gate removal

模拟 `9.9.9.9` 只验证 version 字符串不再阻止 execution/calibration，不代表真实新版支持。所有测试均在 approved non-clinical context 执行，各 harness 与 release 必须单独运行。

1. [x] 只运行 `debug/medex_candidate_g_calibration.ahk`，交替执行 F10 actual-version control 与 `Ctrl+Alt+F6` mismatch override，各 3 次。
2. [x] 六次均为 `CANDIDATE_G_ROW_OK`，row/anchor/estimated points 一致且无 black click；override 记录 `ProfileValidationMedExVersion=9.9.9.9`、`MedExVersionMatchState=MISMATCH`、`MedExVersionMetadataOverrideApplied=true`。
3. [x] 退出 G1，只运行 `debug/medex_candidate_g2_test.ahk`，交替执行 F12 actual-version control 与 `Ctrl+Alt+F11` mismatch override，各 3 次。
4. [x] 六次均为 `RELATIVE_MOUSE_CHAIN_OK`，arrow/black points、signature 和 click counts 一致；人工确认后续无害字符为黑色。
5. [x] G2 override 记录 `TestCase=step5VersionMetadataMismatch`、实际 `MedExVersion=0.0.1.0`、`ProfileValidationMedExVersion=9.9.9.9`、`CalibratedMedExVersion=0.0.1.0`、`MedExVersionMatchState=MISMATCH`。
6. [x] 确认 resolution、DPI、scaling、geometry、signature 和 foreground guards 均未放宽。
7. [x] 退出 harness，只运行 regenerated release；normal `;red` 确认 red insertion、black reset、clipboard restore 和 immediate black 无回退。
8. [x] Release SHA-256=`02f04601e2a1bb1501374c95e9d70f9961d96d87079713ecce366893988b8bae`；Step 5 pass，提交前不得进入 Step 6。

## Historical reconciled release smoke test（TEST CHECKPOINT 1，已被 promotion 取代）

该检查点记录 Candidate G promotion 前的 `uiaInvoke` control，不再是下一次 Windows 操作入口。其成果已进入后续 G1/G2 与最终 generated-release validation；当前 release 应进入 `relativeMousePixelValidated`，不得再以“release 与 F11 都进入 `uiaInvoke`”作为验收条件。

- [x] 已确认 generated release 可启动、无 BOM/parser error。
- [x] 已确认 release/debug 不同时注册 production hotstrings。
- [x] 已记录旧 `uiaInvoke` control evidence，并保留为显式 rollback reference。
- [x] 已完成 Candidate G promotion 后的最终 release-only validation。

## Candidate G1 calibration（TEST CHECKPOINT 2）

### Clipboard safety gate

- [ ] 只运行 regenerated release，并把 clipboard 设为无害 `CLIPBOARD_SENTINEL_20260716`。
- [ ] 在 approved non-clinical context 连续执行 `;red` 20 次。
- [ ] sentinel 被错误插入次数为 0/20。
- [ ] 每次执行后 clipboard 仍为 sentinel，恢复成功为 20/20。
- [ ] 本项不把现有 `uiaInvoke` 成败作为判定条件。

### Candidate G1

- [ ] 完全退出 release，只运行 `debug/medex_candidate_g_calibration.ahk`。
- [ ] toolbar high/middle/low 三个 Y 位置各完成至少 10 次 row localization。
- [ ] 每个 Y 位置使用 F8/F9 记录实际 arrow/black point 和四项 offsets。
- [ ] 每个 Y 位置使用 F10 记录 popup closed probes，使用 F11 记录 open-attempt probes。
- [ ] 四项 offsets 跨位置变化不超过 ±1 px。
- [ ] localization 成功 30/30；任何 miss、ambiguity 或错误选择均记录并停止自动推进。
- [ ] 在 report content 输入无害“检查所见”，确认 toolbar candidate 被选择或 ambiguity fail closed。
- [ ] wrong region 和 unresolved duplicate case 不发送 arrow click。
- [ ] open/closed probes 至少产生三个稳定区分点，且 popup 状态在 80 ms 内稳定。
- [ ] 所有结果 `BlackClickSent=false`，不执行最终颜色验证。

## Candidate G2 controlled interaction（TEST CHECKPOINT 3）

- [ ] 完全退出 generated release 和其他 AHK scripts，只运行 `debug/medex_candidate_g_calibration.ahk`。
- [ ] 确认 F12 输出 `ColorResetStrategy=relativeMousePixelValidated`。
- [ ] Wrong region：F12 不发送 arrow/black click。
- [ ] 在 report content 输入无害“检查所见”：真实 toolbar row 被选择；无法唯一消歧时 fail closed。
- [ ] Popup-missing：保持菜单关闭并按 F7，确认 `ClosedSignatureTestMode=true`、`ArrowClickSent=false`、`COLOR_RESET_POPUP_SIGNATURE_MISMATCH` 且 `BlackClickSent=false`。
- [ ] Unsupported profile：改变 resolution/scaling 测试时返回 `COLOR_RESET_UNSUPPORTED_PROFILE`，且两个 click count 均为 0。
- [ ] High/middle/low toolbar Y 位置各执行 F12 5 次；每次 `ArrowClickCount=1`、`PopupSignatureMatched=true`、`BlackClickCount=1`、`MouseRestored=true`。
- [ ] 每次确认 `RELATIVE_MOUSE_CHAIN_OK` 仅表示 click chain；在 approved non-clinical context 人工确认后续无害字符为黑色。
- [x] 完全退出 calibration harness 后，只运行 `debug/medex_candidate_g2_test.ahk` 完成 G2 controlled validation；该 checkpoint 当时不修改 production default。
- [x] Candidate G 提升后只运行 generated `release/report_assistant.ahk`，完成 `;red`、`;fzg` 和 immediate punctuation 的最终 mainline validation。
- [x] `;fzg` 最终 caret 为 `|（见图）`；实现保持 `Left 4`，没有使用 `Left 5` 补偿。
- [x] 2026-07-16 用户确认最终 generated release 完整通过；验证 artifact SHA-256=`761a6c4261246a4bc14f44597e30eef4564db0bd1e48e92a31c1ac1e41f8ef11`。
- [x] 全程不得同时运行 release 与 debug harness，不得在 finalized patient report 测试。

### Candidate G2 caret-order A/B

- [ ] 只运行 `debug/medex_candidate_g2_test.ahk`，在同一 approved non-clinical editor state 测试。
- [ ] `Ctrl+Alt+F8` 运行当前顺序：CF_HTML → G2 reset → 50 ms → Left 4；重复 5 次。
- [ ] `Ctrl+Alt+F9` 运行 legacy 顺序：CF_HTML → no reset → 50 ms → Left 4；重复 5 次。
- [ ] 两组都记录最终 caret 是否为 `|（见图）`，并在 caret 处输入一个无害字符确认实际继承颜色。
- [ ] F9 必须记录 `ColorResetStrategy=SKIPPED_FOR_LEGACY_ORDER_AB`、`CursorRestoreRequestedCount=4`；不得用于 finalized report。
- [x] F9 no-reset A/B 已证明正确，production 已采用 phrase-specific no-reset workflow；不实施 `Left 5`。
- [x] 2026-07-16：F9 no-reset legacy order 连续 6 次正确，production `;fzg` 已切换并完成最终 generated-release smoke test。

- [ ] Script 正常启动。
- [ ] Ctrl+Alt+Esc 可以暂停和恢复 new-project hotkeys/hotstrings。
- [ ] Ctrl+Alt+Q 可以退出新项目。
- [ ] 明确确认上述两个快捷键不会停止 compatibility process。
- [ ] `;cmx` 插入 `cm×cm` 并将光标左移 2。
- [ ] `;red` 不破坏原剪贴板内容。
- [ ] `;red` 插入红色 `（见图）`。
- [ ] `;red` 后立即输入的字符为黑色。
- [ ] `;fzg` 插入预期短语和红色 figure marker。
- [ ] `;fzg` 的光标最终位置正确。
- [ ] `;fwj` 和 `;fjd` 的每一个可见字符、红色范围和光标位置正确。
- [ ] Red insertion 失败时不静默 fallback 成黑色 `（见图）`。
- [ ] Hotstring expansion 后 report editor 仍可正常使用。
- [ ] 未经批准的 viewer coordinate actions 保持 disabled/placeholder-only。
- [ ] 没有发生 automatic final submission。

## v0.4.2 CF_HTML staged tests

### Notepad

- [ ] `;red`、`;fzg`、`;fwj`、`;fjd` 立即触发。
- [ ] 不支持 HTML 时不插入内容或给出 visible failure；不静默插入黑色 `（见图）`。
- [ ] 尝试后恢复原剪贴板。
- [ ] `;fzg` paste dispatch 失败时不移动光标。

### Microsoft Word

- [ ] `;red` 插入红色 `（见图）`。
- [ ] 紧接着输入 `abc` 时文字为黑色。
- [ ] 插入后恢复原剪贴板。
- [ ] `;fzg`、`;fwj`、`;fjd` 保持现有可见短语。
- [ ] `;fzg` 只在 paste dispatch 成功后 Left 4。

### Edge 或 Chrome contenteditable

- [ ] `;red` 在 contenteditable field 中插入红色 `（见图）`。
- [ ] 紧接着输入 `abc` 时文字为黑色。
- [ ] 没有插入 hidden/visible boundary character。
- [ ] 插入后恢复原剪贴板。

### MedEx report editor

- [ ] Editor 接受 `CF_HTML` 并把 `（见图）` 渲染为红色。
- [ ] Color reset 后输入 `abc` 为黑色。
- [ ] 正常和重复输入时 paste timing 可靠。
- [ ] 成功和失败后均恢复原剪贴板。
- [ ] 失败不会 fallback 成黑色 `（见图）`。
- [ ] `;fzg` paste 成功后光标位置正确。
- [ ] 插入失败后 report input 仍可使用。

## v0.5.0 MedEx color reset staged tests

### 2026-07-15 validated baseline

- [x] MedEx 0.0.1.0 / 1920×1080 / 100% / DPI 96 automation chain 连续三次通过。
- [x] `检查所见` region、dynamic `16px` local anchor、`672,297` point 和 exact `000000` Invoke 通过。
- [x] 一次 region missing 安全中止，没有发送 click。
- [x] 用户在 approved non-clinical context 人工确认后续字符为黑色。
- [ ] 其他 DPI/scaling、resolution、multi-monitor/per-monitor DPI、MedEx version 和用户环境。

### Field-debug 准备与执行

Prerequisite：[ ] AutoHotkey v2 可用，repository 包含 production/field 共用的 pinned `src/Lib/UIA.ahk` v1.1.3，并已准备 approved non-clinical test context。UIA-v2 不需要系统级安装，不要同时提供另一份全局版本。

1. [ ] 启动 MedEx。
2. [ ] Focus report editor。
3. [ ] 记录 actual process name，不从 sample config 推断。
4. [ ] 记录 MedEx version；无法可靠读取时记录 `UNKNOWN`。
5. [ ] 记录 Windows resolution。
6. [ ] 记录 display scaling。
7. [ ] 启动 `debug/medex_color_reset_field_debug.ahk` 并按 Ctrl+Alt+F12 运行 diagnostic hotkey。
8. [ ] 确认 exact Text Name=`检查所见` 被唯一选为 region anchor。
9. [ ] 确认同行右侧动态字号 Text（如 `14px`/`16px`）被唯一选为 local anchor。
10. [ ] 确认 calculated screen point 与 color arrow 对齐；baseline evidence 期望 `(672,297)`。
11. [ ] 确认 color menu 是否打开，以及 Name=`000000` 的 black item 是否被 Invoke。
12. [ ] 确认全过程没有 `MsgBox`、`ToolTip`、`TrayTip` 或其他 focus-stealing feedback，MedEx editor focus 未改变。
13. [ ] 在 approved non-clinical test context 手工输入一个 harmless test character，并确认它是 black；只有此步骤可将 `FinalInsertionColorVisuallyValidated` 记为 true。
14. [ ] 将自动复制的完整 diagnostic result 带回 Mac development environment。
15. [ ] 记录任何 mouse movement、focus loss、menu delay 或 unexpected side effect。

严禁在 finalized patient report 中执行本测试。Diagnostic hotkey 不插入 test text，也不得记录 clinical content。

### Production latency/cursor smoke test

本测试同样只能在 approved non-clinical context 中执行。`Ctrl+Alt+F11` 会运行与 production `;red` 相同的 shared insertion chain，显式选择 Candidate G，插入红色 `（见图）`，并把 timing result 写入 clipboard 和 `%TEMP%\MedExAHK\medex_production_timing_debug.txt`。运行 timing debug 时不要同时启动 generated release 或其他 AHK test instance。

1. [x] 启动 `debug/medex_color_reset_field_debug.ahk`，focus MedEx 测试编辑区。
2. [x] 按 `Ctrl+Alt+F11` 连续执行三次，每次使用新的空白测试位置，并立即输入 `。` 或 `；`。
3. [x] 每次确认输出含 `HotstringTriggeredMs`、`PasteCommandSentMs`、`ColorResetStartedMs`、`ArrowClickSentMs`、`BlackClickSentMs`、`ClipboardRestoreStartedMs`、`ClipboardRestoreCompletedMs`、`FunctionReturnedMs`、`TriggerToBlackClickMs` 和 `PasteToClipboardRestoreMs`。
4. [x] 确认两个 derived duration 非负，且 timestamps 顺序符合当前 baseline transaction。
5. [x] 确认 red marker 未被 clipboard sentinel 替换、原 clipboard 已恢复、immediate punctuation 为黑色。
6. [x] 记录三次 `TriggerToBlackClickMs` 和 `PasteToClipboardRestoreMs`，不以 total function runtime 代替关键路径指标。
7. [x] 确认 `ArrowClickSentMs <= BlackClickSentMs <= FunctionReturnedMs`，且当前 baseline 中 `ClipboardRestoreStartedMs < ColorResetStartedMs`。
8. [ ] 单独确认整个过程没有 `MsgBox`、`ToolTip`、`TrayTip` 或 focus-stealing feedback；本次回报未单列该观察项。
9. [x] 将完整 timing result 回传开发环境；本步骤未修改 waits、transaction ordering 或 Candidate G checks。

#### Reliability/latency remediation matrix

所有测试均使用 approved non-clinical test context；不得在 finalized patient report 执行。

1. [ ] normal `;red` 连续执行 10 次，逐次记录 red insertion、black reset、silent post-red failure 和是否需要 reload。
2. [ ] normal `;fzg` 连续执行 10 次，逐次确认最终 caret 为 `|（见图）`，并立即输入 harmless punctuation 验证其保持 black。
3. [ ] F11 记录 `RawFontSizePatternMatchCount`、`ValidFontSizeRectCount`、`AlignedFontSizeCandidateCount`、`IgnoredFontSizeReasons`、`AnchorSnapshotQueryDurationMs` 和 `FontAnchorRetryUsed`。
4. [ ] 首轮 A/B 保持 `EnableFontAnchorRetry=false`；记录 zero raw match，但不自动重试。
5. [ ] 记录 `BlackLookupFirstQueryDurationMs`、`BlackLookupRetryQueryDurationMs`、`BlackLookupAttemptCount` 和 `BlackLookupScope`。
6. [ ] Control 使用 `UseCachedAnchorSnapshot=false`；Candidate 只改为 `true`。两者保持 `MenuLookupStrategy=adaptivePolling`、timeout 600 ms、poll 40 ms、font retry disabled。
   在 `debug/medex_color_reset_field_debug.ahk` 顶部只修改 `DEBUG_USE_CACHED_ANCHOR_SNAPSHOT`；启动时该值会应用到本 debug process，因此其中的 normal `;red`/`;fzg` 也使用同一 A/B 条件。切换条件前退出并重启脚本。
7. [ ] Control/Candidate 各完成一次 cold F12、五次 warm F12、十次 `;red`、十次 `;fzg` 和一次 wrong-region test。
8. [ ] 记录 `FocusedElementBeforeCursorRestore`、`ForegroundHwndBeforeCursorRestore`、`CursorRestoreTargetHwnd`、`CursorRestoreRequestedCount=4` 和 `CursorRestoreCommandSent=true`。
   性能 A/B 保持 `DEBUG_COLLECT_FOCUS_DIAGNOSTICS=false`；另做一次专用运行临时改为 `true`，避免 focus query 污染常规 timing。
9. [ ] 若 effective cursor 仍为 3，先比较 Invoke 后和 cursor restore 前的 focused element；不得直接改为 `Left 5`。
10. [ ] 分别连续输入、插入普通字符、使用方向键/鼠标打断 `;fzg` 前缀，记录哪些事件会重置 AHK hotstring recognition buffer；该结果单独处理，不与 Color Reset 修复耦合。
11. [ ] 在错误 region 测试一次，确认 no menu click、no Invoke、明确 fail-closed result。

#### Candidate G activation gate（已完成；历史记录）

- [ ] Control/Candidate A/B 已完成。
- [ ] `检查所见` localization 重复稳定。
- [ ] 剩余主要失败明确位于 popup UIA lookup/Invoke。
- [x] 用户明确批准 Candidate G calibration milestone。
- [ ] calibration 前没有把 estimated arrow/black offsets 或 pixel thresholds 写入 production。
- [ ] 如果启动 calibration，popup absent signature 必须失败且不得发送 black click。
- [ ] 严禁在 finalized patient report 中校准或验证。

- [ ] Foreground process 正确时进入 UIA lookup；错误时返回 `COLOR_RESET_WRONG_PROCESS` 且不点击。
- [x] 现场主进程名确认为 `medexworkstations.exe`；另测 compatibility candidate 与 wrong-process fail-closed，不再把主进程描述为未确认。
- [ ] UIA-v2 缺失时返回 `COLOR_RESET_UIA_UNAVAILABLE` 且不点击。
- [ ] Anchor enumeration 以 foreground MedEx window root 或经确认的报告区域父容器为 scope，不要求 toolbar 是 focused `Document` descendant。
- [ ] 不使用 exact `16px` 或 shortcut `①` 作为 production lookup。
- [ ] Region anchor 缺失返回 `COLOR_RESET_REGION_ANCHOR_NOT_FOUND` 且不点击。
- [ ] 多个有效 `检查所见` 返回 `COLOR_RESET_REGION_ANCHOR_AMBIGUOUS` 且不点击。
- [ ] 同行没有匹配 `^\d+(?:\.\d+)?px$` 的字号 Text，返回 `COLOR_RESET_FONT_SIZE_ANCHOR_NOT_FOUND`。
- [ ] 同行存在多个匹配字号 Text，返回 `COLOR_RESET_FONT_SIZE_ANCHOR_AMBIGUOUS`。
- [ ] 其他 toolbar 全局存在多个字号 Text 时，只要目标行唯一，仍可正确选择。
- [ ] `①` 缺失、改名或出现多个 shortcut symbols 不影响 normal path。
- [ ] optional `rAI` 存在时输出 fingerprint；缺失、改名或歧义时不阻塞。
- [ ] Rectangles 无效或相对位置异常时返回 `COLOR_RESET_INVALID_GEOMETRY` 且不点击。
- [ ] Zero-width/non-finite rectangle 返回 `COLOR_RESET_INVALID_RECTANGLE`。
- [ ] Calculated point 位于 client area 和 local toolbar band；否则 fail closed。
- [ ] 不要求整个 UIA root rectangle 位于 client area。
- [ ] 字号 value 从 `16px` 改为 `14px`、rectangle 不变时，point 不变。
- [ ] 工具栏整体沿 Y 移动时，calculated Y 移动相同 delta。
- [ ] `ColorArrowOffsetX/Y` 改变时 point 按相同 delta 改变，不修改 resolver。
- [ ] Trigger click exception 返回 `COLOR_RESET_TRIGGER_CLICK_FAILED`。
- [ ] Click 前 foreground hwnd/process 改变时停止且不点击。
- [ ] Menu 未出现时返回 `COLOR_RESET_MENU_NOT_OPENED`，不继续 blind click。
- [ ] Menu 中没有 Name=`000000` 时返回 `COLOR_RESET_BLACK_ITEM_NOT_FOUND`。
- [ ] Black item 不支持 InvokePattern 时返回 `COLOR_RESET_INVOKE_UNAVAILABLE`。
- [ ] `Invoke()` 抛错或失败时返回 `COLOR_RESET_INVOKE_FAILED`。
- [ ] 未分类异常返回 `COLOR_RESET_UNEXPECTED_ERROR`，不继续点击。
- [ ] 自动化字段记录 region/font/optional anchor、active profile/offsets、`ColorMenuClickSent`、`BlackItemFound` 和 `BlackItemInvokeSucceeded`。
- [ ] Invoke 成功时只报告 `AUTOMATION_CHAIN_OK` / `FINAL_COLOR_PENDING_VISUAL_VALIDATION`，不得自动报告最终成功。
- [ ] `FinalInsertionColorVisuallyValidated` 初始为 false/unknown，人工确认无害字符为黑色后才单独记录 true。
- [ ] `RetryCount` 输出为整数 `0` 或 `1`，不得序列化为 Boolean。
- [ ] `ProcessNameConfirmed=false` 必须与 provisional candidate accepted 的含义分开记录。
- [ ] Field debug 默认只写 clipboard/log，不显示成功提示；任何可选提示必须先证明不改变 focus 和颜色状态。
- [ ] 只执行一次 validated trigger click；随后以 40 ms interval 在 600 ms bounded window 内查询 exact `000000`，找到即停止，不再次点击 trigger。
- [ ] Mouse position 在 interaction 结束后恢复。
- [ ] 在目标 DPI、display scaling、resolution、window width 和 MedEx version 上重复测试。
- [ ] Logs 只包含 timestamp、action、result code、process、rectangles、point、timing、retry 和安全检测到的 version。
- [ ] Logs 不包含患者信息、report text、hotstring replacement 或 clipboard payload。
- [ ] Copied field result 包含 process、window handle、DPI/scaling、profile、region/font/optional rectangles、screen/client point、Invoke flags 和 elapsed timings。

## v0.5.0 configuration staged tests

### Production fixes: cold UIA, Settings identity and text codec

- [ ] 完全退出并重新启动 release，在 approved non-clinical MedEx 报告编辑区首次输入一个末尾带 `{{red:（见图）}}` 的模板；确认首次即成功，或只提示界面尚未准备好且没有点击、正文或红字插入。
- [ ] 对首次 readiness failure 检查 `%TEMP%\MedExAHK\logs\medex-color-reset-failures.log`；只包含 reason code、窗口/进程、次数和耗时，不包含报告文字、患者信息或 clipboard 内容。
- [ ] 准备至少三个 custom templates；在正式设置窗口和 Windows regression harness 中对状态、名称、触发词分别升序、降序，确认视觉行解析到同一 `Section`。
- [ ] 排序后分别选择、编辑和删除不同 custom template；确认对话框名称与视觉选中项一致。
- [ ] 保存触发 Reload 后，目标 trigger 立即失效；再次启动后目标 section 仍不存在，其余 builtin/custom templates 和 triggers 保持不变。
- [ ] builtin template 的删除按钮不可用，且不能通过持久化 helper 删除。
- [ ] 分别保存单行、多行、空行、末尾换行、反斜杠和字面量 `\n`；连续打开并保存三次，Edit 内容及实际 trigger 输出保持不变。
- [ ] compatibility layer 的 Alt+Shift+S 单次触发仍可用；持续按住 Alt+Shift 连续按 S 是本版本已知限制，不在本轮修复。

### Schema 2 template engine

- [ ] 先运行 `tests\windows\config_v2_migration_audit.ahk`；确认结果文件位于 `%TEMP%\MedExAHK\config-v2-migration-audit.txt`，不含任何 `Text` 或报告内容，且显示 `READY_FOR_SCHEMA_2_MIGRATION`。
- [ ] 冷启动一次完成 Schema 1 → 2 升级；确认 `backups\` 中存在迁移前配置，现配置为 `SchemaVersion=2`，所有 hotstring section 均无 `Mode`。
- [ ] 输入 `;fzg`，确认文字为“放射性摄取增高，SUVmax约为（见图）”，光标位于“为”和“（见图）”之间，且不执行 Candidate G。
- [ ] 运行 `tests\windows\cmx_template_regression.ahk`；并在 MedEx 输入 `3.5;cmx`，确认得到 `3.5cm×cm`，光标位于 `×` 后、末尾 `cm` 前。
- [ ] 测试 `{{cursor}}{{red:（见图）}}`、无 cursor 的红色尾标记、`{{date}}` 位于 cursor 前、多次 `{{date}}` 和纯黑模板；确认 Left 与 Candidate G 决策符合模板最终光标位置。
- [ ] 确认普通字面量 `（见图）` 只插入黑字且不调用 Candidate G；只有精确 `{{red:（见图）}}` 插入红字。
- [ ] 在设置中尝试多个 `{{cursor}}`、多个 `{{red:（见图）}}`、红色尾标记后追加正文或 placeholder、`{{red:重要}}`、`{{cursur}}`、`{{unknown}}`、未闭合 `{{` 和孤立 `}}`；确认均不能保存，普通 `{正文}` 可保存。
- [ ] 在 Text 编辑框中分别选中正文和只放置 caret，通过“插入模板元素”插入三种 token；确认替换选区、caret 停在 token 后、焦点返回编辑框，并可连续插入同一项。
- [ ] 将升级前配置复制到测试目录，制造未知 Mode、重复 trigger 或重复字段；确认审计失败且原文件 SHA-256 不变。另用 `text` mode 且以字面量 `（见图）` 结尾的模板确认迁移成功并保持黑字。
- [ ] 迁移后使用设置窗口进行多行、空行、末尾换行、反斜杠、字面量 `\n` 和占位符的连续三次保存；确认无 double escaping。

- [ ] `config.ini` 不存在时使用 safe defaults。
- [ ] 单项 invalid value 只使对应项回退或禁用，不使整个应用崩溃。
- [ ] Higher unsupported `SchemaVersion` 不覆盖原配置，并明确提示 incompatibility。
- [ ] Built-in 与 user-defined trigger collision 被检测并 fail-safe。
- [ ] Configured hotkeys、built-in triggers/replacements 和 user-defined hotstrings 正确注册。
- [ ] User replacement 只作为 text data，不执行 AHK code。
- [ ] 更新 executable 后 `%LocalAppData%\MedExReportAssistant\config.ini` 保持不变。

## v0.6.0 measurement provider staged tests

### Report editor text/caret read-only exploration

- [ ] 只使用非临床测试文字；退出 production release 和其他 AHK harness。
- [ ] 启动 `tests\windows\report_editor_text_snapshot_field.ahk`，在“检查所见”正文框中输入固定测试文本 `甲乙丙`。
- [ ] 光标依次放在文本开头、`甲|乙`、文本末尾，每次按 `Ctrl+Alt+F7`。
- [ ] 再输入两行文字，分别在第一行末尾和第二行开头按 `Ctrl+Alt+F7`。
- [ ] 选中单个字符和跨行文字，各按一次 `Ctrl+Alt+F7`。
- [ ] 检查 `%TEMP%\MedExAHK\report_editor_text_snapshot_field.txt`；每个 run 都应找到同一 focused `Document`，并记录 text length、selection range/offset、caret offset/source。
- [ ] `CaretActive=false` 时不得把 `CaretCandidateOffset` 当成可信 caret；结果必须为 `TEXT_READY_CARET_UNRESOLVED`。
- [ ] 比较 `TextLength`、`ValueLength` 和 `TextValueEqual`，判断 `DocumentRange` 与 `ValuePattern` 是否暴露同一文本范围。
- [ ] 确认结果文件不包含测试正文、选中文字、clipboard 内容、患者信息或报告正文。
- [ ] 确认 `ForegroundUnchanged=true`、`MouseUnchanged=true`，执行前后正文、选区和光标位置均未改变。
- [ ] 回传完整结果文件，并说明每个 run 对应“开头/中间/末尾/多行/选区”中的哪一种。

### Generic acquisition core revalidation

- [x] 重新运行 `tests\windows\measurement_capture_regression.ahk`；确认 spec validation、components copy、原 positive/zero/malformed/no-update/nested-busy 和 clipboard restoration 全部通过。
- [x] 重新运行 `tests\windows\context_measurement_provider_field.ahk`；脚本启动时 invalid-spec preflight 不报错。
- [x] 复测 positive SUVMax → `FOUND`、numeric zero → `NOT_ANNOTATED`、关闭 viewer → `VIEWER_NOT_FOUND`；结果、视觉提示、foreground/mouse invariants 和 clipboard restoration 与重构前一致。
- [x] 本 checkpoint 未读取 vendor INI，未使用 UIA，未接入 `;fzg`，未实现 line parser。

### Config-first geometry schema audit

- [x] 首轮 Windows audit：从运行中 `MedExNMFusion.exe` 唯一解析两个固定相对 INI；两个 Exists、root safety 和 SHA-256 均通过。
- [x] 首轮 exact keys 返回 `FramePosX/Y`、`ShowImagePosX/Y`；随后确认 whitelist 错误漏掉 `ShowImageWidth=750` / `ShowImageHeight=940`，layout 配置有 30 个 `ShowModelN` 候选但没有可靠 active model。
- [x] screen/window/client 候选标签在多次执行时位置不稳定；该验证方案作废，不得用 `Wn/Cn` 编号形成坐标结论。
- [x] UIA Viewer 现场可选中主图区 `Pane(50033)` 并读取准确 `BoundingRectangle`；该元素没有可用 Name/AccessKey，尚未证明程序化唯一重找。
- [ ] 保持 `MedExNMFusion.exe` 运行，重新启动修正版 `tests\windows\mxnm_config_geometry_audit.ahk`。
- [x] 修正版 audit：`FrameSize=1348,1000`、`ShowImageSize=750,940`、10 个 viewer windows 均已回传；旧 `FrameMatchedWindowCount=0` 证明 physical exact-position 判据无效并已移除。
- [x] 修正版 config audit：`RuntimeFrameCandidateCount=1`、`RuntimeFrameResolved=true`、`MappedImageRectResolved=true`、`MappedImageRect=2566,81,3991,1434`。
- [x] 确认结果不包含 absolute path、raw vendor config、患者信息、检查信息或报告内容。
- [x] 本阶段未调用 context menu/provider，未读写 clipboard，未移动鼠标或切换焦点。
- [x] 历史 checkpoint 曾单独运行现已移除的 `mxnm_uia_image_region_audit.ahk`；`State=READY_FOR_FIELD_VALIDATION`、两个 resolved 字段和 `ConfigReady` 均为 `true`，`UiaPaneCount=9`、`UiaGeometryMatchCount=1`。
- [x] 相同布局连续运行三次；`UiaCandidateRect=2566,80,3991,1440` 保持不变，使用视觉反馈且无声音。
- [x] Config + UIA 主图区矩形 checkpoint 通过；本 checkpoint 未生成 production image point，未接入 provider 或 `;fzg`。

### Field-only automatic measurement target

- [ ] 先运行 `tests\windows\mxnm_measurement_target_regression.ahk`；看到纯逻辑回归通过的视觉提示，无 warning/error。
- [ ] 单独启动 `tests\windows\mxnm_measurement_target_field.ahk`，保持报告编辑器为前台，按 `Ctrl+Alt+F10`；确认视觉标记落入图像 pane 内且远离分隔线。
- [x] 检查 `%TEMP%\MedExAHK\mxnm_measurement_target_field.txt`：`TargetState=READY_FOR_FIELD_VALIDATION`、`LayoutModelCount=21`、`LogicalPoint=63,95`、`MinimumLogicalClearance=62`、`UiaGeometryMatchCount=1`、`ActionWindowResolved=true`。
- [x] 在一个不同于自动目标点的 pane 保持活动状态，并只让该活动 pane 存在 SUVMax 标注；自动读取返回 `FOUND`，确认 command 可读取当前活动/全局测量。
- [x] 以静止鼠标复跑 F11 完整 transport；`TargetActionMatchesProviderViewer`、foreground/mouse、clipboard、popup 和 runtime ID 字段均为 `true`。F10/F11 各自独立比较调用前后位置，不要求两次测试之间持续静止。
- [x] 记录 `UiaPaneCount` 可从 9 变为 10；它只用于诊断，`UiaGeometryMatchCount=1` 才是硬门槛。
- [ ] 若自动点为 `NOT_ANNOTATED` 而手动活动 pane point 为 `FOUND`，记录 command 为 point-local 并停止；不得尝试第二自动 transport，下一步改为 active-pane resolver。
- [x] 关闭 viewer 后复跑：`TargetState=CONFIG_GEOMETRY_UNAVAILABLE`、`ConfigState=VIEWER_NOT_FOUND`、`MeasurementInvoked=false`；foreground/mouse 不变，clipboard/popup/command 均不可达。
- [x] Field-only automatic target checkpoint 通过 Windows 验证；下一 checkpoint 才允许设计 provider 默认集成。
- [x] 本 checkpoint 未修改 `main.ahk`、generated release、provider 默认行为、hotstrings 或 `;fzg`。

### Config-only on-demand measurement target（待 Windows 复验）

- [ ] 只运行 regenerated release；确认启动后没有 measurement shell hook、后台 warmup 或周期性 target timer。
- [ ] 删除或暂时移走 `%LocalAppData%\MedExReportAssistant\mxnm-config-path-cache.ini`，保持 viewer 运行并执行一次 `;fzg`；确认成功后生成 cache，且 cache 只包含 schema、viewer exe/process path 和时间，不包含 vendor config 原文。
- [ ] 完全退出并重新启动 release；先不启动 viewer，确认 release 正常启动且没有窗口查找提示。随后启动 viewer，首次 `;fzg` 的 `TargetResolutionMs` 不再包含配置读取/布局解析停顿。
- [ ] viewer 运行时将 cache 中的 process path 改为另一不存在路径并重启 release；确认 cache 被拒绝，测量 fail closed 或在当前 viewer 上重新发现并修复 cache，不使用错误路径。
- [ ] 保持 viewer 在日常固定位置，连续执行 `;fzg` 与 `;cma`；记录 `targetResolutionMs`，确认第二次及以后使用 cached config plan，且 target resolution 无偶发秒级延迟。
- [ ] 单独运行 `tests\windows\mxnm_measurement_target_field.ahk`，按 `Ctrl+Alt+F10`；确认 `LogicalPoint`、config-derived `ImageRect`、`ScreenPoint` 和 `ActionWindowResolved` 正确，不再输出 UIA 字段。
- [ ] 移动或调整可调整的上层 viewer frame 后复跑；确认每次按当前 rect 重算坐标，未复用旧 `screenPoint` 或 action HWND。
- [ ] 关闭 viewer 后复跑；确认在 popup/clipboard 前快速 fail closed。
- [ ] 完成 SUVMax、长短轴、annotation cleanup、foreground/mouse/clipboard/popup invariants 复验。

### SUVMax production candidate

- [ ] 启动 generated release，无 `#Warn`、解析错误或启动错误；全程没有提示音。
- [ ] 配置中的精确历史 `;fzg` 默认值升级为 `放射性摄取增高，SUVmax约为{{suvmax}}{{red:（见图）}}`；用户修改过的 builtin/custom 文本不变。
- [x] 有正数 SUVMax 时运行 `;fzg`：自动插入结果正确；target cache 优化后现场确认延迟可接受。
- [ ] 无标注时运行 `;fzg`：不插入数值、无即时提示，caret 位于 `{{suvmax}}` 空位。
- [ ] 关闭 viewer 或制造 command failure：报告其余部分仍写入，caret 位于空位，右下角短暂显示无焦点视觉提示。
- [ ] 人为改变前台报告 HWND 或制造 red/clipboard failure：报告事务返回失败且不执行清除。
- [x] 单独启动 `tests\windows\mxnm_annotation_cleanup_field.ahk`，只使用非临床测试标注，按 `Ctrl+Alt+F12`。
- [x] 检查 `%TEMP%\MedExAHK\mxnm_annotation_cleanup_field.txt`：`CleanupState=OK`、`CommandInvoked=true`、`ConfirmationDetected=false`、`VerificationState=NOT_ANNOTATED`、foreground/mouse 均不变。
- [ ] 若出现二次确认：`CleanupState=CONFIRMATION_REQUIRED`，未自动确认；报告内容不回滚。
- [ ] production 清除失败时只显示“报告已写入，标注未清除”，不撤销正文、不切换焦点、不移动鼠标。
- [x] 重启 release 后完成 target 预热，再切回报告运行 `;fzg`；现场确认不再出现不可接受的 config/UIA 重算停顿。
- [ ] 清除 field 输出中的 `InitialTargetResolutionMs` 在 cache 命中时接近 0；记录 `InitialMeasurementTotalMs` 供后续 clipboard latency 优化。

- [x] 运行 `tests\windows\measurement_capture_regression.ahk`；确认 positive、zero、malformed、no-update、nested-busy 和 clipboard restoration 全部通过。
- [x] 只运行 `tests\windows\context_measurement_provider_field.ahk`，退出 production release，避免两个脚本同时操作 clipboard。
- [x] 在 viewer 图像内部将鼠标放到无害测试点并按 `Ctrl+Alt+F8`；看到“测量点已记录”视觉提示后，将焦点返回报告编辑器，设置无害 clipboard sentinel，再按 `Ctrl+Alt+F9`。
- [x] 确认 `Ctrl+Alt+F9` 后显示短时视觉结果提示且没有提示音；最终判据仍以结果文件为准。
- [x] 检查 `%TEMP%\MedExAHK\context_measurement_provider_field.txt`：`ForegroundUnchanged=true`、`MouseUnchanged=true`、`ClipboardCaptureSucceeded=true`、`ClipboardRestoreSucceeded=true`、`PopupCreated=true`、`CommandRuntimeIdResolved=true`。
- [x] 确认结果文件不包含 raw/formatted SUVMax、clipboard payload、患者信息、检查信息或报告正文。
- [x] 分别验证 positive SUVMax → `FOUND`、numeric zero → `NOT_ANNOTATED`、无 popup/command/clipboard update → `AUTOMATION_FAILED`；每次操作后原 clipboard 均完整恢复。
- [ ] 制造多个 viewer window、越界 image point 和错误进程环境；确认 provider fail closed，不激活 viewer、不移动鼠标、不调用第二 transport。
- [x] 本阶段 provider 未接入 `;fzg`；任何 field result 都不得导致报告插入、caret movement 或 Color Reset。

### Line axes production candidate

- [x] 2026-07-24 用户回报长短轴 candidate 在 Windows 一次端到端通过；本条只记录 smoke pass，不替代以下逐项结果与 field output。
- [ ] 先运行 `tests\windows\measurement_capture_regression.ahk`；确认新增的空值、1/2/3 轴、首尾 `U+200B`、zero、negative、malformed 和 4 轴 fixtures 全部通过，无 `#Warn` 或 parser error。
- [ ] 单独启动 `tests\windows\mxnm_line_axes_field.ahk`；保持报告编辑器为前台、鼠标静止，且不要同时运行 production release。
- [ ] 无直线测量标注时按 `Ctrl+Alt+F11`；确认 `MeasurementState=NOT_ANNOTATED`、`ClipboardCaptureSucceeded=true`、`ClipboardRestoreSucceeded=true`，foreground/mouse 均不变。
- [ ] 分别创建 1、2、3 条非临床测试测量后按 `Ctrl+Alt+F11`；确认 `MeasurementState=FOUND`、`ComponentCount=1/2/3`，视觉提示依次使用逐项 `cm` 和 Unicode `×`。
- [ ] 特意让 vendor 返回值不按大小排列；确认视觉提示已按数值从大到小排列，而不是沿用 vendor 创建顺序。
- [ ] 有测量时按 `Ctrl+Alt+F12`；确认 `CleanupState=OK`、`VerificationState=NOT_ANNOTATED`，报告前台、鼠标和原 clipboard 保持不变。
- [ ] 检查 `%TEMP%\MedExAHK\mxnm_line_axes_field.txt` 不包含 raw/formatted measurement、clipboard payload、患者信息、检查信息或报告正文。

### Viewer 工具快捷键（config + native HWND/WM_COMMAND，当前工作站已通过）

- [ ] 退出 production release，先运行 `tests\windows\mxnm_viewer_tool_command_regression.ahk`；确认纯配置解析回归通过。
- [x] 单独运行 `tests\windows\mxnm_viewer_tool_command_field.ahk`，仅使用非临床 Viewer；在 Viewer 前台依次按 `Ctrl+Alt+F9/F10/F11`。
- [x] 确认三个命令分别等价于点击第 4 个箭头、第 6 个长度测量和第 9 个 3D SUV 按钮；不需要预先 hover。
- [x] 将报告编辑器置于前台后重复，确认 Viewer 工具仍正确切换，前台窗口和鼠标位置保持不变。
- [x] 检查 `%TEMP%\MedExAHK\mxnm_viewer_tool_command_field.txt`：`State=READY`、对应 `CommandId` 与 `RuntimeControlId` 均为 `21043/21048/21193`、`CommandRow=1/3/6`、`TargetScreenPoint` 分别落在目标按钮、`ForegroundUnchanged=true`、`MouseUnchanged=true`。
- [ ] 启动 regenerated release，在设置页逐项启用 `Ctrl+Alt+1/2/3`；确认仅在报告程序或 Viewer 前台生效，在其他应用中不触发也不吞键。
- [ ] 分别为四项勾选 Win，保存并重开设置；确认 Win 状态与完整 chord 原样恢复，Win+单键可用，未勾 Win 的单个 Ctrl/Alt/Shift 仍被拒绝。
- [ ] 启用截图映射；保持 Viewer 前台按一次配置键，确认等价于 F12，整个 Viewer 只快速白闪约 90 ms，无文字、声音、焦点或鼠标变化，且闪光未进入最终截图。
- [ ] 保持报告窗口及其他程序前台按截图映射；确认不发送 F12、不显示闪光，也不吞掉原程序按键。
- [ ] 按下并完全松开 3D SUV 快捷键一次，再完成一次无害测量；确认松开全部按键后工具仍保持选中，不需要按住主键或修饰键，也不会持续重复 command。
- [ ] 在 custom template 中配置 `大小{{size}}{{red:（见图）}}`，重新加载 release，无 `#Warn`、解析错误或提示音。
- [ ] 1/2/3 轴分别触发 custom hotstring；确认报告插入 `1.2cm`、`2.2cm×1.2cm` 或三轴降序格式，并在写入成功后清除 viewer 标注。
- [ ] 无标注时触发：不插入尺寸、不提示，caret 留在 `{{size}}`；键入第一个数值后运行 `;cmx`，确认继续得到手动 `cm×cm` 流程。
- [ ] 关闭 viewer 或制造 command failure：其余报告内容仍写入，caret 留在空位，仅显示短暂视觉提示“尺寸获取失败，请手动输入”。
- [ ] 在设置中确认同一模板不能保存两个 `{{size}}`，也不能同时保存 `{{size}}` 与 `{{suvmax}}`。
- [ ] 清除失败时不回滚已经写入的尺寸，只显示简短视觉提示。

## Portable release 与 singleton

- [ ] 将 ZIP 复制到本机并完整解压，不直接从共享盘或压缩包内运行。
- [ ] `publish/` 包含 `麦旋风.exe`、`首次使用.md`、`配置指南.md` 和 `更新说明.md`，且 EXE 与 tray 使用正式图标。
- [ ] EXE 从任意普通本地目录启动正常。
- [ ] EXE 从 Desktop 启动正常。
- [ ] EXE 放在 Windows Startup folder 时启动正常。
- [ ] 启动后 config 仍为 `%LocalAppData%\MedExReportAssistant\config.ini`。
- [ ] 对完整测试配置记录 SHA-256；删除或替换 EXE 后 config SHA-256 与 custom sections 不变。
- [ ] 同一 EXE 启动两次时只有一个 active instance。
- [ ] 改名后的两个 EXE 启动时只有一个 active instance。
- [ ] 两个不同目录、不同 metadata 的 policy-aware builds 启动时只有一个 active instance。
- [ ] 第二进程显示“MedEx Report Assistant 已在运行”，随后 clean exit。
- [ ] 原进程 PID、tray、suspend state 和 hotkey registrations 没有被终止或 reload。
- [ ] `%LocalAppData%\MedExReportAssistant\logs\startup.log` 记录 version、revision、executable path 和 config path。
- [ ] 没有创建 installer、shortcut、registry state、EXE backup、rollback、self-update 或 old-version cleanup。
- [ ] 重新编译后的第一次颜色下拉若已选中黑色但菜单未关闭，记录现象并确认后续一次恢复正常；不要用重复点击掩盖。

## Compatibility staged tests

- [ ] 原始 `karabiner.ahk` 和 `string_change.ahk` instances 均已退出。
- [ ] 将 EXE 配置设为 `GlobalHjklArrows=true`，再与 `medex_legacy_compat.ahk` 同时运行；确认五个 report hotstrings 和 RAlt+H/J/K/L 都只有 EXE 一个 owner。
- [ ] 逐项验证 RAlt+H/J/K/L 为 Left/Down/Up/Right，并确认 compatibility 不再注册相同按键。
- [ ] Compatibility tray tooltip 可与新项目区分。
- [ ] 每个保留的 legacy hotkey 在用户确认的工作站和窗口上逐项测试。
- [ ] Shift+Alt+S 与新 clipboard transaction 不并发触发。
- [ ] SUV 3000 ms 与 Arrow 1000 ms 复按行为保持用户确认的语义。
- [ ] 停止测试时能够同时退出新项目和 compatibility，且 user config 保持不变。
