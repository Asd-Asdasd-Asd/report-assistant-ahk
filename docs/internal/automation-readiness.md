# 自动化首次/偶发失败：本轮修改

分支：`fix/automation-readiness`。基于已合并 Montage 修复的 main。

- 测量复制：同步消息使用 1000 ms 超时；发送前复核 popup、控件的 PID、
  可见性、启用状态、父子关系和 command ID。超时结果为
  `COMMAND_RESULT_UNKNOWN`，不重发命令。
- 菜单：等待唯一、可见、可用命令，多个匹配不能按枚举顺序选择。
- 剪贴板：读取异常不计作空值，并重置空值确认窗口；持续异常返回
  `CLIPBOARD_READ_FAILED`。成功读空才允许进入未标注解释。
- Caption：首次发现允许最多 1500 ms 的只读准备轮询；前台或源 PID 改变就停止。
  复用时检查缓存 UIA 锚点及矩形；失效后只在已绑定目标窗口重新定位，
  不重放复制、粘贴、保存或翻页。保存相关等待保持原值。
- Viewer：移除进程级“只恢复一次”标记，每次需要重新发现时允许最多
  1500 ms 的同 PID/root 窗口准备轮询；缓存命中不增加等待。
- 红字：保留当前窗口范围查询，记录 `anchorRootMaxMs` 和
  `anchorQueryMaxMs`，用于区分节点晚出现与查询本身慢。

上述 UIA 轮询期限不能中断单次同步 UIA 调用。Caption 整窗 Pane 查询是否
能进一步收缩，需要现场控件树证据；当前不猜测它与保存按钮的父子关系。

## 验证

macOS：Python suite、生成文件一致性与 diff 检查。
Windows：先运行下列合成回归，再构建 EXE 做实际 MedEx 验收：

```powershell
AutoHotkey64.exe /ErrorStdOut tests\windows\generated\readiness_regression_standalone.ahk
AutoHotkey64.exe /ErrorStdOut tests\windows\generated\viewer_state_regression_standalone.ahk
```

新增合成回归运行 production 剪贴板等待函数，用替代读取接口模拟占用、
空值、后续恢复、旧序列和 sentinel；用临时测试窗口验证禁用、隐藏、
command ID 变化及正常命令发送。不会操作 MedEx 或写入系统剪贴板。
该合成回归不验证跨进程接收方挂起，消息超时仍需 Windows 专项测试。

现场验收：首次/连续 SUV 和尺寸读取；未标注；重启 Viewer 而不重启助手；
首次 Caption、调整窗口后复用、操作中切换前台；红字首次/连续操作；
已确认恢复正常的 Montage 三种 profile。失败后先复制本次诊断。
仅发送成功不代表保存、截图或业务处理已完成。
