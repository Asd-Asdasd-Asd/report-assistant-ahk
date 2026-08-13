# Automation Diagnostics MVP

更新时间：2026-08-13

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
- 每次操作正常情况下只写一条 `operation-summary`。
- 首次 session 使用、首次目标进程使用、失败、recovery 或详细诊断窗口中，追加
  `stage-event`。
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

托盘新增：

- `复制诊断信息`：复制环境白名单、最近 60 条统一事件、最近 action 和推荐专项
  诊断；
- `开启 10 分钟详细诊断`：只设置内存态 deadline，程序重启自动关闭，不持久化。

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
