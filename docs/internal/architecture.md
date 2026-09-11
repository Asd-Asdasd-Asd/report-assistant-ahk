# 当前架构与安全边界

本文只描述当前实现，不记录已经废弃的调用链和实验过程。历史证据按需读取 `docs/technical-investigations/`、`docs/field-tests/` 和 `experiments/`。

## 代码边界

- `src/` 是源码真相；`release/report_assistant.ahk` 是生成产物；`legacy/` 是历史/兼容来源。
- 通用报告模板、剪贴板事务和结构化结果不直接承担 MedEx 特定的窗口定位细节。
- MedEx 特定 UI 交互必须集中在对应 adapter/provider 中，不能扩散到通用模块。

## 报告与测量

- 报告 hotstring 只在 MedEx report process 的前台条件满足时生效；全局暂停和退出动作保持明确的安全例外。
- `{{suvmax}}` 和 `{{size}}` 通过 measurement provider 读取当前图像值；只有严格解析得到 `FOUND` 才插入数值，其他状态保留人工输入路径。
- measurement provider 使用当前 Viewer context 发现和验证图像 surface，并在每次动作前验证 PID、root owner、client bounds 和消息 receiver。
- 不能复用旧 clipboard 内容；缺失、过期或目标不明确时必须停止。

## Viewer 交互

- Viewer 工具使用 live native command/control discovery 或经验证的 context transport；不依赖固定按钮间距、固定坐标或枚举顺序。
- action 前后必须保持前台、鼠标和目标窗口不被意外改变；证据不唯一时 fail closed。
- 不使用无条件 blind click、静默重试或自动策略 fallback 来掩盖现场不确定性。

## 颜色与剪贴板

- 红色模板通过 `CF_HTML` 插入；颜色恢复属于 MedEx-specific adapter。
- Clipboard 必须由唯一事务 owner 保存并在 `finally` 恢复；不得插入隐藏字符、改变用户原始剪贴板或自动提交报告。
- 颜色恢复成功与否必须区分自动化链路结果和 Windows 现场视觉确认。

## 证据层级

- 源码和单元测试：静态/结构性证据。
- generated release：生成一致性证据。
- Windows/MedEx 现场操作：运行时证据。
- 用户确认和独立复验：更高等级的验收证据。

后一层不能由前一层自动推导。任何文档中的历史“已验证”描述都必须与当前版本、目标机器和现场记录对应。
