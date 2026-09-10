# Montage 下拉选项就绪修正（2026-09-10）

现场版本 `644469e` 在第 3 步（图注 null）和第 5 步（窗宽预设）返回
`COMBO_OPTION_POINT_MISMATCH`。操作者反馈：重启无效，等待并重复触发后有时可以完成。
这支持时序问题的可能性，但未确认具体是弹出窗口延迟、坐标变化还是其他遮挡。

## 修正范围

- 在原有 1500 ms 轮询预算内，重新查找唯一选项、读取最新矩形，并验证中心点命中
  同一 Viewer PID 的 `ComboLBox`，全部满足才退出等待。
- 每轮保留选项的启用/可见状态、UIA 父链归属校验；点击前再次检查 Viewer 前台。
- 成功路径不增加固定等待。等待过程中没有鼠标输入，不重新展开菜单、不重放
  Montage 前序步骤。实际选项点击仍只发送一次。
- 同步 UIA 调用本身不能被轮询期限中断，因此 1500 ms 不是整个操作的硬超时保证。
- 失败保留 controlId/class、选项查询是否成功、原始/过滤后候选数、检查次数、等待
  耗时、中心坐标、命中 PID/HWND，以及固定类别 `COMBOLBOX`/`OTHER`/`UNKNOWN`。
  不记录窗口标题、选项正文或剪贴板内容。`uiaQuerySucceeded` 仍指控件解析路径；
  判断下拉项查询应使用新的 `optionQuerySucceeded`。

## Windows 验收

1. 拉取修复分支后，运行 `release/report_assistant.ahk`（AutoHotkey v2），或重新编译
   此文件并启动新 EXE。仅拉取代码不会更新正在运行的旧进程。
2. 在无隐私测试检查中分别执行 Head、Body、Lung，确认一次触发完成，图注和窗宽
   实际正确；记录首次和重复执行结果。
3. 若仍失败，立即用托盘“复制诊断信息”提供最新记录；重点查看新增的 `option*`
   字段和 `pointProbes`、`comboReadyElapsedMs`。
4. 菜单被遮挡、目标进程不同或前台切走时应停止，不得向其他窗口点击。

随分支提交的 `tests/windows/generated/mxnm_montage_lung_field_test_standalone.ahk`
是原有 0.7 逐步诊断工具，用于对照采样，未改成新版生产等待逻辑。按
`Ctrl+Alt+Shift+F10` 首次绑定，后续每次一步；最多测到第 5 步，成功后按
`Ctrl+Alt+Shift+F7` 结束。它采用旧控件解析规则，若提前失败应保留结果，不能把
该失败直接解释为新版生产逻辑失败。结果复制到剪贴板，同时保存在
`%TEMP%\MedExAHK\mxnm_montage_lung_field_test.txt`。

本地静态测试和生成校验不能替代 Windows/MedEx 现场验收。
