# MedEx DevTools runtime investigation

日期：2026-07-31

状态：静态 bundle + 单机 DevTools 现场证据；production 内部调用尚未实现

隐私：本文和配套 JSON 不含 Cookie/token 值、患者/用户/检查/图片标识、内网
主机、正文、原始请求体或图片路径

## 结论先行

这批数据已经解释快速标图“第一张保存、连续快速操作时文字可见但没有保存”的
主要原因。问题不在 `Ctrl+V` 是否到达，也不能仅靠 20 ms 或 80 ms 的粘贴后
延时解决。

MedEx 报告图像页面的 `flipImage(direction)` 有一个 500 ms 保存门槛：

1. 第一次翻页调用 `saveDescriptionByMouse(fileIndex)`；
2. 后续翻页只有距离上次翻页大于 500 ms 才再次调用保存；
3. 小于或等于 500 ms 时跳过保存，但仍立即修改图片索引和内容。

因此用户快速连续触发时，当前 caption 可以已经显示在 UEditor 中，但这一页的
保存函数没有被调用，随后页面照常切换。现场症状与代码分支完全一致。

当前 production 的可靠 UI 修复方向应是限制相邻 `WheelDown` 的实际发送时间，
保证超过 MedEx 的 500 ms 门槛。建议保留少量调度裕量，例如 550 ms，并按“上次
实际翻页时间”计算，而不是简单在每次粘贴后固定等待。直接内部调用保存属于后续
experiment，不应混入这次时序修复。

## DevTools 入口

该 MedEx 客户端使用内嵌 Electron/Chromium，现场运行信息为：

- `medexworkstations/0.0.1`；
- Electron `17.4.11`；
- Chromium `98.0.4758.141`；
- 页面完成态包含 67 个 script、4 个 stylesheet 和 6 个 iframe；
- 普通 `require`/`process` 未直接暴露，但 preload 提供了 `window.nodeApi`。

用户现场确认 Alt 可以进入应用菜单中的 DevTools 入口。此前连续快捷键后意外打开
DevTools，不足以证明是某个 Chrome 标准快捷键；更可能是 Alt 激活了 MedEx 自身
菜单入口。以后需要运行时证据时，可以明确请用户进入 DevTools，而不再依赖意外
触发。

DevTools dock 到右侧会缩小页面 viewport，引发响应式重排；看到顶部按钮或 sidebar
变化不等于业务页面本身新增了功能。采集布局证据时应记录 DevTools 是否 docked，
必要时使用独立窗口模式。

## Caption editor

现场确认页面中存在一个 ready 的 UEditor 实例：

- body 为 `contentEditable=true`；
- 观察到 45 个 command；
- 包含 `selectall`、`undo`、`redo`、`lineheight` 等已知命令；
- 页面组件持有 `editorInstance`，通过 `getContentTxt()` 和 `getContent()` 读取纯文本
  与 HTML；
- 图片切换后通过 `setImgDesc(...)`/`setDetailInfo(...)` 更新编辑器内容；
- UEditor `blur` listener 连接到 `saveNotToast()`。

这证明未来可以探索“定位已知 UEditor 实例 → 执行已知编辑命令 → 调用页面本来用于
保存/下一张的已知方法”。但当前证据只有一个时点和一个实例，尚未证明如何从任意
页面稳定定位正确 Vue component，不能直接进入 production。

## 已确认的保存链

### 明确保存

`saveDescription()`：

1. 检查 saving guard 与 editor 是否存在；
2. 从 editor 读取纯文本和 HTML；
3. 从当前选中图片取得 `pk_nm_reportimage`；
4. 调用 `saveDescriptionApi(payload, true)`。

### 静默保存

`saveNotToast()` 在 UEditor blur 时尝试保存变化，但以下情况直接返回：

- click status 是 `prevImg` 或 `nextImg`；
- 正在操作 editor toolbar；
- saving guard 已经占用；
- 当前内容与缓存文本一致；
- 页面/检查状态禁止保存。

因此用 Tab、额外点击或纯粹延长等待来“制造 blur”不是已证明的修复；页面本身可能
在翻页状态下主动忽略 blur 保存。

### 鼠标翻页保存

`saveDescriptionByMouse(fileIndex)` 比较当前 editor 文本与对应 `fileList[index]`
缓存；不同时构造 payload 并调用 `saveDescriptionApi(payload, false)`。

`flipImage(direction)` 对这个调用施加 500 ms 门槛，并且不等待保存 Promise 完成就
更新图片索引。这是当前快速标图竞态的直接证据。

### HTTP contract

现场捕获到页面自身使用：

- `POST /mdap_nm/reportimage/saveDescription`；
- `Content-Type: application/json`；
- 请求字段：`pk_nm_reportimage`、`imagedescribe`、`imagedescribetxt`；
- 认证使用 session Cookie；Cookie 值已删除；
- 两次捕获请求内容相同，开始时间相差约 84 ms，均返回 HTTP 200；
- 单次网络耗时约 22–23 ms。

HTTP 200 只证明传输成功，业务成功仍应由页面已有 `state` 规则解释。实验阶段优先
调用页面已知 method，而不是自行拼 Cookie 和 HTTP 请求；这样可以复用页面的状态
检查、payload 生成、缓存更新和错误处理。

## 本地桥接面

页面同时暴露：

- `window.nodeApi`，观察到 42 个方法，覆盖进程、文件、IPC、ZMQ、窗口、打印和
  dialog 等高权限能力；
- `medex.Message` 与 `medex.Message2`；
- MQTT library 和 WebSocket 状态全局变量；
- JS wrapper 中存在运行程序、下载、上传、读卡、监控窗口等业务消息。

本次没有调用任何桥接命令。方法存在不等于已知其协议、目标和副作用。后续实验必须
按 allowlist 逐个确认，只允许与现有按钮、菜单或编辑器动作一一对应的已知命令；
不得探测删除、上传、签名、文件、进程、ZMQ/MQTT/IPC 等未知调用。

## 后续路线

### Production UI 路径

先修复现有快速标图：相邻实际滚轮发送至少间隔 550 ms。仍保留目标窗口、caption
point、image point、foreground、PID 和 root-owner 校验。这个修复只适配 MedEx 已
确认的业务节流，不依赖 DevTools 或内部 API。

### Experiment 1：只读定位

在独立 experiment branch 中确认如何从页面稳定取得：

- 报告图像 Vue component；
- 当前 UEditor instance；
- `selectImg`、`fileIndex` 与 `fileList` 的只读一致性；
- `saveDescription`、`saveDescriptionByMouse`、`nextImg`/`flipImage` 的函数身份。

不得读取或输出正文和各类 ID 的值，只记录存在性、类型、数组长度和相等关系。

### Experiment 2：已知命令最小写入

只在测试检查中验证：

1. 通过已知 UEditor command 全选并写入脱敏测试 caption；
2. 调用页面自身明确的保存 method；
3. 等待 method Promise/业务成功状态；
4. 再调用页面自身明确的 next method；
5. Network 仅验证 endpoint、状态、计时和调用次数。

如果不能稳定定位唯一 component/method，或业务状态不可验证，立即停止，不退回枚举
第一个对象或调用同名未知函数。

## 数据处置

原始压缩包包含失效 session Cookie、业务 ID、内网 URL、图片资源路径、完整 DOM、
请求 payload 和可能遗漏的临床/用户信息，不进入 Git。完成本次分析后删除原 ZIP 与
临时解压副本。

仓库只保留：

- 本文；
- `experiments/devtools/README.md`；
- 脱敏证据 `experiments/devtools/runtime/redacted/2026-07-31-report-image-caption-evidence.json`。

原始采集物 SHA-256 仅用于确认本次分析来源：
`575c51ec749ab71701e2d4dcbed81ac85527c7138a4f27265ee5f496dc70eee5`。
