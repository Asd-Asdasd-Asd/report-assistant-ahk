# MedEx Package Sanitized Findings

本文档只记录从本地分析包第一轮静态盘点中提取出的非敏感技术结论。不要在这里粘贴 vendor code、raw logs、截图、患者信息、真实内网地址或敏感配置。

## Summary

分析包显示 MedEx 工作站由 Electron shell、Node preload bridge、本地配置、ZeroMQ transport 和 MxNMSoft native viewer 组成。对 `medex-ahk` 最相关的结论是：

- 报告工作站 shell 是 Electron/Vue 打包应用。
- `nodeApi/index.js` 通过 preload 暴露 `window.nodeApi`，包括 IPC、进程操作、打印、ZMQ send/onMessage、RTF/HTML conversion wrappers。
- `sysconf/conf.medex` 配置本地 HTTP/WebSocket 端口、ZMQ pub/sub 和启动 URL；真实内网 URL 不应进入主仓库文档。
- ZeroMQ pub/sub 端口观察为 33000 / 33001，`nodeApi/utils/zeromq/index.js` 负责连接配置地址并转发消息。
- `Program/NM/MxNMSoft/` 是独立 native viewer，包含 `MedExNMFusion.exe`、MxNMSoft DLL、Qt/DCMTK/VTK/OpenCV 依赖。
- MxNMSoft 配置中存在 SUV/测量显示和测量信息输出相关项，但第一轮未确认可直接稳定读取当前图像测量。

## Report editor implications

Electron bundle 中包含 TinyMCE 静态资源和 paste/textcolor/colorpicker 等插件，说明富文本编辑器很可能是 Web/Chromium 路径。第一轮尚未定位到明确的 first-party `tinymce.init(...)`，可能因为实际报告页面由配置 URL 加载，不完全包含在本地 bundle 中。

对红色 `（见图）` 的当前影响：

- v0.4.2 已实现动态 `CF_HTML` 作为优先测试路径。
- 现场已经确认 MedEx 接受 `CF_HTML` 并显示红色文字；剩余问题是恢复后续 insertion color。
- 当前版本不能直接附加 DevTools，因此 DOM、iframe/contenteditable、TinyMCE 初始化和 paste policy inspection 继续 deferred。
- 不应继续把 RTF 作为主要路径。
- 源码返回成功只表示粘贴命令已经派发，不表示 DOM 或视觉渲染已经确认成功。
- 已批准 V1 通过 exact semantic region、dynamic font-size local anchor 和集中 local offsets 定位 trigger，再 Invoke Name=`000000` 的 color item；详见 `docs/technical-investigations/2026-07-medex-rich-text-color-reset.md`。

## Measurement implications

MxNMSoft 有本地 ZMQ/protobuf 线索，但第一轮未确认 `SendLabelText`、`SaveNidusInfo` 或特定病灶消息的 active production use。结合现场测试，短期更稳的路线仍是 context-menu copy command：

- line measurement：从当前图像 context menu 复制直线测量值。
- SUVMax：从当前图像 context menu 复制 SUVMax。
- 自动读取失败时必须 false negative，不复用旧剪贴板或旧 log 值。

## Next targets

1. `dist/electron/main.js`：抽取 IPC、BrowserWindow、preload、ZMQ、RTF/HTML conversion。
2. `nodeApi/index.js`：确认 renderer 暴露接口是否可替代部分 AHK UI 操作。
3. `nodeApi/utils/zeromq/index.js` 与脱敏配置：整理 pub/sub 方向和 topic。
4. MxNMSoft INI：整理 SUV/测量相关配置，不记录敏感路径。
5. Windows 运行时 DOM/TinyMCE inspection：验证 `CF_HTML` 插入可行性。
