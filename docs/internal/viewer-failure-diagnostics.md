# Viewer failure-only 诊断日志

正式程序把 Viewer 自动化失败和成功触发的冷启动恢复追加到配置目录下的：

```text
%LOCALAPPDATA%\MedExReportAssistant\logs\viewer-failures.log
```

实际位置以 `startup.log` 的 `ConfigPath` 所在目录为准。文件达到 512 KiB
后轮转为 `viewer-failures.log.1`。日志写入是 best-effort；日志目录不可写或
轮转失败不得改变原自动化结果。

日志只记录稳定错误码、阶段、Control ID/class、候选数量、PID/HWND、session
generation、cold-recovery 状态和耗时。禁止记录患者标识、窗口标题、报告正文、
模板内容、剪贴板 payload、测量值或截图。

每行使用 `schema=1` 和 `|` 分隔的 `key=value` 字段；同一操作产生多条记录时，
可结合 `timestamp` 与 `tickCount` 对照。

## 覆盖范围

- `Montage`：Body/Head/Lung 的失败 step、Control ID、Win32/UIA/合并候选数；
- `ContextTarget`：SUVMax、尺寸和清除共用目标 session 的 discovery/validation
  失败；
- `ContextMeasurement`：目标已解析后，右键菜单、命令或剪贴板 transport 失败；
- `AnnotationCleanup`：删除标注命令或确认失败；
- `ViewerTool`：Arrow、Length、3D SUV 的 Viewer PID、按钮候选和布局失败。

`uiaRawCandidates` 是 UIA 原始 AutomationId 命中数，`uiaCandidates` 是经过
PID、class、可见性、root owner 和几何边界过滤后的数量，`mergedCandidates`
是与 Win32 HWND 合并去重后的最终数量。`CONTROL_NOT_UNIQUE` 配合这些字段可区分
零候选和多候选。

## 冷启动恢复

正常成功路径不增加等待。

- Montage 仅在第一步尚未点击、结果为 `CONTROL_NOT_UNIQUE` 时消费一次进程级
  cold recovery：等待 350 ms，重新绑定前台 Viewer，并最多等待初始布局控件
  2500 ms。任何已经可能产生副作用的失败都不自动重放。
- Context target 仅在首次 surface discovery 或 discovery 后立即 validation 失败
  时消费一次进程级 cold recovery：等待 350 ms，完整 rediscovery 并重新验证。
- 日志用 `coldRecoveryAttempted`、`coldRecoverySucceeded` 和
  `coldRecoveryDelayMs` 区分恢复是否发生。
- 正常成功不写日志；只有实际消费冷启动恢复并成功时，额外写入一次
  `COLD_RECOVERY_SUCCEEDED`，用于确认首次失败是否被恢复策略吸收。

## 现场读取

PowerShell：

```powershell
Get-Content "$env:LOCALAPPDATA\MedExReportAssistant\logs\viewer-failures.log" -Tail 50
```

如配置目录被迁移，先读取：

```powershell
Get-Content "$env:LOCALAPPDATA\MedExReportAssistant\logs\startup.log" -Tail 30
```

然后以最新 `ConfigPath` 所在目录下的 `logs\viewer-failures.log` 为准。
