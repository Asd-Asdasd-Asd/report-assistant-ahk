# 架构说明

本文档记录当前架构设想。项目仍处于 early personal prototype 阶段，目标是先建立可维护、安全、可逐步迁移的自动化层，而不是一次性重写全部 legacy 行为。

## 为什么选择 AHK v2

当前目标系统是 Windows 桌面环境中的报告书写窗口和阅片窗口。初始阶段选择 AutoHotkey v2，主要原因是：

- 可以在不修改原系统、不接入数据库、不绕过权限的前提下做本地辅助。
- 对键盘输入、热字符串、剪贴板、窗口激活和鼠标动作支持成熟。
- 适合先验证工作流，再决定是否需要更正式的插件或系统集成。
- 部署成本低，适合少量内部工作站试用。

暂时不直接做插件，是因为当前没有稳定公开的目标系统插件接口，也不应该在早期原型阶段引入高风险集成。

## 报告书写界面的自动化策略

报告书写界面优先使用 hotstrings、键盘快捷键和剪贴板富文本，原因是：

- 输入文本和常用短语是最高频需求。
- 键盘和剪贴板动作比鼠标坐标更稳定。
- 后续可以逐步加入 RTF / HTML 剪贴板事务，减少手工格式调整。
- 不需要接触数据库，也不需要绕过原系统权限。

红色 `（见图）` 插入的 v0.4.0 方案曾尝试动态 RTF clipboard construction。Windows 现场测试显示，RTF payload 没有被目标报告编辑器正确消费；当同时写入 `CF_UNICODETEXT` 时，编辑器插入的是黑色文本。RTF 因此降级为 experimental/reference。

v0.4.2 的活动实现改为 HTML Clipboard / `CF_HTML`。`clipboard_html.ahk` 动态构造 UTF-8 payload，按字节计算 `StartHTML`、`EndHTML`、`StartFragment` 和 `EndFragment`，并通过 Windows Clipboard API 写入注册格式 `HTML Format`。默认红字路径不写入 `CF_UNICODETEXT`，因此不支持 HTML 的编辑器不会静默插入黑色 `（见图）`。

`red_not.clip` 仍可作为诊断参考，但它依赖 `ClipboardAll` binary snapshot，可能受 session-specific registered clipboard format IDs 影响，不能成为生产依赖。RTF 代码不再进入活动运行路径，相关调查结论由 Git 历史和 `red-text-clipboard-investigation.md` 保存。

红字实现仍必须包裹在 clipboard save/restore transaction 中，最终行为必须插入红色 `（见图）`、恢复用户原始剪贴板，并让后续输入恢复黑色。

所有报告书写辅助都必须保留人工确认，不默认执行最终提交、审核或发送。

## Measurement architecture

MxNMSoft 测量值读取计划通过未来的 `ContextMeasurementProvider` adapter/provider layer 实现。line measurement 和 SUVMax 使用相同的 context-menu transport：在当前图像区域打开右键菜单，按 visible command text 找到复制命令，读取并校验剪贴板结果。

`ContextMeasurementProvider` 返回 structured measurement data，例如 measurement type、raw value、formatted value、source、timestamp、study identity 和 failure reason。hotstrings 或上层报告逻辑只负责决定最终插入的报告文本，不直接承担窗口消息、控件查找和解析细节。

当前图像读取失败时，manual fallback 仍是上层 workflow。系统应优先 false negative，不能复用旧剪贴板值，也不能把最后一条 SUV log 自动当作当前图像测量值。

## 阅片界面的自动化策略

阅片界面暂时以坐标自动化为主，因为当前阶段没有可靠的内部 API 或插件接口。坐标动作可以先覆盖少量重复点击，但风险更高：

- 受屏幕分辨率、缩放比例、窗口位置和软件布局影响。
- 不同工作站必须单独校准。
- 需要窗口校验和人工测试后才能启用。

因此阅片动作应逐个迁移，不能一次性照搬 legacy 点击序列。

## `src/` 模块职责

- `main.ahk`：项目入口，加载模块，注册全局安全热键。
- `config.example.ahk`：示例配置，包含窗口可执行文件名和示例坐标表；真实本机配置应复制到 `config.local.ahk`。
- `hotstrings.ahk`：文本扩展入口，只放文本输入相关逻辑。
- `clipboard_html.ahk`：构造 CF_HTML、调用 Windows Clipboard API、派发粘贴命令并恢复用户剪贴板。返回成功只表示粘贴命令已派发且恢复已尝试，不代表目标编辑器已经确认渲染结果。
- `report_editor.ahk`：报告书写窗口相关动作，未来包括富文本插入、格式重置、编辑区焦点校验。
- `viewer_actions.ahk`：阅片窗口动作，未来逐步迁移经过校准的坐标操作。
- `window_guard.ahk`：窗口存在、激活和焦点保护。
- `utils.ahk`：通用辅助函数，例如提示、鼠标位置恢复、坐标点击。

## `legacy/` 的作用

`legacy/` 保存原始脚本作为历史来源和行为参考。这里的文件不应在迁移过程中随意修改，也不应作为新功能直接运行入口。迁移时只提取明确、可测试、符合安全边界的行为。

## `release/` 的作用

`release/` 保存生成后的单文件脚本，便于复制到 Windows 工作站进行测试。生成文件来自 `scripts/build_release.py`，维护者应优先修改 `src/`，不要手工修改 release 文件。

## 风险边界

- 不访问数据库。
- 不绕过系统权限。
- 不默认自动提交、审核或最终发送报告。
- 不保存患者信息、医院敏感信息、账号、截图、真实内网地址或敏感日志。
- 剪贴板动作必须尽量保存并恢复原剪贴板。
- 坐标动作必须经过本机校准和人工测试。
