# Automation Diagnostics MVP

更新时间：2026-10-30

这套基础设施把“真实 Windows 环境失败但事后没有证据”收敛为统一支持流程：

```text
出问题
→ 不重启麦旋风或 MedEx
→ 托盘选择“复制诊断信息”
→ 将剪贴板内容发送给维护者
```

## Milestone A：Diagnostics Core

- 每次程序启动生成一个内存态 `sessionId`；每次被观察的操作递增
  `operationId`。
- 同时保留 wall-clock timestamp 与 `A_TickCount` 派生耗时；阶段耗时不使用
  系统时间差。
- 每次操作只写一条 `operation-summary`；阶段耗时内联在
  `stages=NAME@offsetMs>…` 中（2026-10-30 起取消单独的 `stage-event` 记录和
  “开启 10 分钟详细诊断”托盘项，因为每条 summary 已含完整时间线）。
- `targetGeneration` 随同一 action 的 PID/HWND 目标世代变化递增。
- `automation-events.log` 单文件上限 1 MiB，保留 `.1`、`.2`、`.3` 三份轮转。
- 日志写入和轮转失败不得改变原自动化结果。
- 公共层不接受任意 details Map；action-specific 字段必须进入显式白名单。

## Milestone B：Caption 与支持闭环

Caption 是第一个接入功能，记录以下语义边界：

```text
SAVE_CLICK_DISPATCHED
≠ SAVE_CONFIRMED
```

`caption.saveDispatchResult=DISPATCHED` 只证明点击已经发出。Vendor 没有可靠的
持久化完成信号，因此点击发出后始终记录：

```text
caption.persistenceState=UNOBSERVABLE
```

只有自动化动作全部完成时才写 `automationResult=COMPLETED`；这仍不表示 Caption
已经保存到 Vendor 数据层。

托盘 `复制诊断信息`：复制环境白名单（含 `PrimaryScreen`、`Monitors` 显示器
几何）、最近 12 条 summary（不按 action 过滤，按时间排列）加最多 4 条更早的
非 `COMPLETED` summary、最近 action 和推荐专项诊断。

## Milestone C：报告快捷语与颜色恢复（2026-10-30）

每次模板快捷语记录一条 `action=ReportHotstring`，成功也记录。此前颜色恢复只在
失败时写 `%TEMP%\MedExAHK\logs\medex-color-reset-failures.log`（无轮转、空格
分隔、需单独解析），"点击发出但菜单没收起"这类问题没有任何证据。该文件不再写入
也不再读取；磁盘上的旧文件不删除。

主要字段：

- `report.writeCode`、`report.requiresColorReset`、`report.redPath`、
  `report.measurementType/State`；
- 预检：`color.profileSource`（`builtin` / `machineProfile`）、
  `color.preflightCode/Reason/ElapsedMs`、exact anchor 查询次数与候选数；
- 颜色恢复：`color.resultCode`、失败时的 `color.failureReason`、
  `color.popupSampleCount`、`color.popupFirstReason`、
  `color.resetToArrowMs`、`color.arrowToBlackMs`、`color.blackToReturnMs`、
  `color.mouseRestored`、`color.clipboardRestored`；
- 写入后菜单探测：`color.menuAfterWrite=CLOSED|OPEN|UNKNOWN|NOT_CLICKED`、
  `color.menuProbeReason`、`color.menuProbeDelayMs`（距黑色点击）、
  `color.menuProbeCount`。

菜单探测在写入返回后、标注清除前执行，复用 popup signature 像素点，只观察不动作：
不点击、不按键、不重试。首次仍匹配时等到黑色点击后 400 ms 再采样一次，以排除关闭
动画；仍匹配记为 `OPEN`，summary 记 `automationResult=DEGRADED`、
`resultCode=COLOR_MENU_LEFT_OPEN`，会进入快照的失败摘要。若鼠标原位置恰在菜单区域，
hover 高亮可能让开着的菜单被判为 `CLOSED`；`UNKNOWN` 表示前台已变化未采样。
只记录 reason 和计数，不记录像素值和坐标。

## 隐私边界

统一日志和 snapshot 不记录患者信息、报告正文、Caption 文本、所选文字、剪贴板
内容、窗口标题、用户配置全文、凭证或任意异常正文。

允许的内容只包括应用版本、source revision、session/operation identity、阶段名、
结果码、候选计数、缓存/目标世代、受限环境字段和耗时。

## Windows 验收边界

macOS 静态测试可以验证 schema、白名单、轮转策略、include/build 顺序和 Caption
阶段位置，但不能证明 Windows 文件行为、UIA/Vendor 时序或 Caption 最终持久化。
合并回 `main` 前，在真实工作站至少完成一次端到端闭环：

```text
启动麦旋风
→ 首次快速标图
→ 再次快速标图
→ 复制诊断信息
→ 检查首次 detailed trace、第二次 summary 和隐私边界
```

若能复现失败，应先复制 snapshot，再决定是否运行已有 Report Image Caption 专项
诊断；不要先重启程序。
