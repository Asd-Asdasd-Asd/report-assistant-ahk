# MedEx DevTools experiments

本目录保存 MedEx 内嵌 Chromium DevTools 的实验约束与脱敏证据。它不是
production 功能实现目录。

## 目录

- `runtime/raw/`：临时原始采集物，Git 永久忽略；分析完成后删除。
- `runtime/redacted/`：允许提交的脱敏结构化证据，不含正文、Cookie、token、
  患者/检查/图片标识、内网主机或原始请求载荷。
- 结论和决策写入 `docs/technical-investigations/`。

## 现场边界

允许：

- Elements、Console、Network、Sources 的只读检查；
- 读取已知 UEditor、Vue component 和现有函数的结构或函数体；
- 给已知元素安装不读取正文的临时事件观察器；
- 记录请求方法、路径模板、字段名、状态和时间，不记录字段值。

未经单独批准不得：

- 调用名称或作用未知的函数；
- 直接调用删除、提交、上传、签名、运行程序、文件、ZMQ、MQTT 或 IPC 命令；
- 修改 MedEx 文件、bundle、配置或持久化状态；
- 导出完整 DOM、未脱敏 HAR、Cookie、token、患者资料、报告正文或图片；
- 向 MedEx 原有按钮/菜单/编辑器路径之外的本机或外部地址发送信息。

## 建议采集流程

1. 优先使用非临床测试检查。
2. 打开 DevTools 后先确认当前 target frame 和选中元素。
3. Console 输出只保留类型、字段名、长度、方法名和计时。
4. Network 使用 Preserve log，但导出前删除 header/cookie/body/URL 参数值。
5. 原始采集放入 `runtime/raw/`，完成脱敏总结后删除。

2026-07-31 首次证据见
`runtime/redacted/2026-07-31-report-image-caption-evidence.json`，完整分析见
`docs/technical-investigations/2026-07-medex-devtools-runtime.md`。
