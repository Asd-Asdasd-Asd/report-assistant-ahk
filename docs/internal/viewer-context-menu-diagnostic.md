# Viewer 右键接收窗口诊断

这个工具用于定位 `POPUP_NOT_CREATED`。它不会执行任何右键菜单命令：
只向受限候选窗口发送右键按下/抬起消息，记录新建或由隐藏转为可见的
Viewer 窗口，然后关闭识别到的 popup。

## 构建

在 Windows 源代码目录运行：

`tools\field-testing\Build Viewer Context Diagnostic EXE.cmd`

生成文件位于同级构建目录：

`..\report-assistant-build\viewer-context-diagnostic\publish\MxNM-Viewer-Context-Diagnostic.exe`

## 采集

1. 打开 Viewer，并保持需要测试的图像正常显示。
2. 启动诊断 EXE。
3. 把鼠标放到一个没有标注、右键应能弹出菜单的图像内部位置。
4. 按 `Ctrl+Alt+F8`，等待“结果已复制到剪贴板”。
5. 直接粘贴并回传剪贴板中的完整文本。

诊断会分别探测手工点和当前算法自动点。输出不包含任意窗口标题、
患者信息或测量值；只包含 HWND/PID 关系、窗口类名、矩形、已知菜单
项是否存在以及 popup 探测结果。
