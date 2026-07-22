# Post-v0.6.0 Passive ZeroMQ Exploration

本文档定义 v0.6.0 稳定之后的一条独立支线：对 MedEx 已有 ZeroMQ 通道进行限时、被动、只读的工程勘察。本阶段不是“开始逆向 ZeroMQ”，也不以替换现有 context-menu measurement provider 为目标。

## 决策摘要

这项探索值得做，但应保持低承诺、强停止条件：

- 信息价值较高：它可能补足配置文件无法提供的 current viewport、active pane、layout 和 measurement lifecycle 等实时状态。
- 产品价值未知：现有静态证据只能证明 transport 存在，不能证明测量事件存在、上下文充分或 Schema 稳定。
- 工作量可控：限制为 1–2 个专注开发会话和一次 Windows 脱敏现场实验。
- 优先级低于 v0.6.0：先完成并稳定配置定位与 context-menu measurement workflow，再开始本支线。
- 探索结果必须是明确的 `GO`、`DEFER` 或 `STOP`，不能因已经投入时间而默认进入 production。

## 要回答的问题

核心问题只有一个：

> MedEx 是否已经通过 Electron shell 使用的本地 ZeroMQ pub/sub 通道，广播了可以安全复用的只读运行状态？

优先寻找：

- current viewport / active pane；
- current layout 和 image navigation；
- ROI 或 measurement 的创建、更新、删除事件；
- SUVMax、long axis、short axis；
- 能够安全关联测量值的上下文和失效事件。

当前已证实的静态事实：

- Electron shell 暴露 `window.nodeApi`；
- 存在 ZeroMQ publisher / subscriber helper；
- 配置中存在 pub/sub endpoint；
- Electron renderer 可以接收 `nodeApi` 转发的消息；
- 存在 RTF/HTML conversion wrapper。

当前未证实：

- endpoint 的实际运行方向和 bind/connect 拓扑；
- payload 编码和 Schema；
- 是否存在 measurement 或 viewport 消息；
- 新增 subscriber 是否完全不影响现有 MedEx；
- 消息能否区分当前值、历史值和不同检查上下文。

RTF/HTML conversion wrapper 是独立的文本能力候选，不纳入本次 ZeroMQ 成败判断。

## 安全边界

允许：

- 只读检查本地 JavaScript 和脱敏配置；
- 从当前配置解析 endpoint，不在 probe 中写死端口或地址；
- 仅连接已静态确认的 PUB endpoint；
- 只创建 SUB socket，不创建 PUB socket；
- 被动接收已有广播；
- 在脱敏测试检查中执行单一人工动作并观察事件差异；
- 记录经过白名单筛选的结构元数据。

禁止：

- 向任何 ZeroMQ endpoint 发送消息；
- 调用未知 request、command 或 reply path；
- bind 到 vendor 使用的端口；
- 修改 preload、renderer、`nodeApi` 或 MedEx 配置；
- 注入 JavaScript、hook 运行时或加载 vendor DLL；
- 保存完整原始 payload；
- 记录患者姓名、检查号、UID、文件路径、网络地址或报告正文；
- 把 probe 或实验依赖加入 release build。

“订阅全部 topic”只允许用于脱敏测试检查，而且完整 payload 只能在内存中经过短暂分类和脱敏，不得默认落盘。若无法在保存前可靠剔除敏感内容，本轮实验立即停止。

## 分阶段方法

### Phase 0 — Static topology

先从代码和当前配置确认：

- 每个 endpoint 的 PUB/SUB、bind/connect 和数据方向；
- 单帧或 multipart message；
- topic 位于独立 frame 还是 payload 内；
- Electron shell 是否二次包装消息；
- JSON、text、Buffer、MessagePack、protobuf 或自定义二进制的可能性。

重点文件：

- `nodeApi/index.js`
- `nodeApi/utils/zeromq/**`
- preload scripts
- renderer message listeners
- `window.nodeApi`
- `zmq.send`
- `zmq.onMessage`

输出一张经过验证的拓扑图。不能沿用对端口方向的猜测。

### Phase 1 — Isolated passive probe

仅在 Phase 0 找到明确 PUB endpoint 后，才建立与主程序完全分离的 `tools/zmq_probe/` 诊断工具。

probe 必须：

- 只创建 SUB socket并只执行 connect；
- 不提供 send code path；
- 不修改 MedEx 配置；
- 不要求管理员权限；
- 退出后不留下后台进程；
- 不进入 release-source generation；
- 默认只保存下列白名单字段。

允许保存的观察数据：

- relative timestamp；
- frame count；
- topic hash；
- payload length；
- encoding guess；
- 脱敏后的 JSON key names；
- top-level value types；
- sequence frequency；
- 人工动作标签。

如果消息格式是未知二进制，只记录长度、frame structure、频率和稳定 hash；不要保存 raw bytes。

### Phase 2 — Single-action correlation

在脱敏测试检查中，每次只执行一个动作，并在动作前后使用短观察窗口：

1. 启动和关闭检查；
2. 切换序列；
3. 切换 active pane 或 PET/CT/Fusion；
4. 切换布局；
5. 创建、移动、调整和删除 ROI；
6. 创建和删除 SUVMax、long-axis、short-axis measurement；
7. 切换图像 slice。

比较：

```text
manual action
-> new or changed topic
-> payload schema change
-> changed fields or structural hash
-> timing and repetition
```

只有在多次重复实验中与单一动作稳定对应的字段，才能标记为“已证实”。字段名相似只能标记为“推测”。

### Phase 3 — Classification and stability

将消息分为：

- heartbeat；
- application/window lifecycle；
- study/series context；
- viewport/layout；
- image navigation；
- measurement/ROI；
- report/editor；
- logging/diagnostics；
- unknown。

至少跨两次 MedEx 重启重复关键动作。只有 Schema、事件顺序和失效行为保持稳定，才进入 provider 评估。

## Provider 准入条件

被动事件不能因为“包含一个正确数字”就成为 measurement provider。必须同时满足：

- 消息来自已有广播，不依赖主动查询；
- 人工动作可以稳定复现；
- 不需要注入或修改 MedEx；
- 新 subscriber 不影响 Electron shell 或 native viewer；
- 测量类型和数值可以严格解析；
- 能区分 current value 与 historical value；
- 能证明测量所属的 current context，或建立可靠的瞬时 context fingerprint；
- 能在切换检查、序列、pane、layout、删除 measurement 和关闭检查时立即失效；
- 能处理晚连接、漏消息、乱序和初始状态缺失；
- 不需要持久化患者身份数据；
- 多次重启后 Schema 保持稳定。

如果不能证明上下文和失效条件，事件即使能读取 SUVMax 或轴长，也只能用于诊断，不能自动写入报告。

若全部满足，先设计独立的：

```text
PassiveMeasurementEventCache
```

而不是替换现有 provider：

```text
passive event
-> validate event and update volatile cache
-> invalidate on every relevant context transition

hotstring triggered
-> cache is fresh and context-valid
    -> return candidate value
-> otherwise
    -> use context-menu copy provider
```

缓存必须是进程内、短生命周期的，不写磁盘；context-menu provider 在较长时间内仍是当前图像值的基准实现。

## 停止条件

出现任一条件，本轮结果记为 `STOP` 或 `DEFER`：

- 没有 measurement、viewport 或 layout 相关广播；
- 只有 heartbeat、日志和窗口生命周期消息；
- 必须发送命令才能获得所需状态；
- payload 加密，或必须注入 renderer 才能解析；
- 消息包含大量无法在落盘前隔离的敏感数据；
- 多开 subscriber 会影响 MedEx；
- 无法可靠区分当前值和历史值；
- 无法定义跨检查、序列和 pane 的失效规则；
- Schema 在重启或相同动作之间不稳定；
- 1–2 个专注会话后仍不能建立稳定的动作—消息对应。

## 预期交付物

本支线只交付：

1. 脱敏的消息拓扑图；
2. topic/Schema 分类摘要；
3. 人工动作与消息变化的证据矩阵；
4. subscriber 非干扰性验证结果；
5. `GO`、`DEFER` 或 `STOP` 结论；
6. 若为 `GO`，一份独立 provider 设计，不直接修改 production workflow。

未经单独批准，不提交 probe、不修改 release build，也不开始 provider 实现。
