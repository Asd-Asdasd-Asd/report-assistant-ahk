# 更新说明

MedEx Report Assistant 采用便携式单文件 EXE。程序不要求固定安装目录，也不会自动下载、替换或清理其他版本。

## 更新方法

1. 在系统托盘中退出旧版 MedEx Report Assistant。
2. 删除或覆盖原来的 `麦旋风.exe`。
3. 下载并解压新版。
4. 运行新的 `麦旋风.exe`。

原有自定义配置保存在本机用户目录中，不会因删除 EXE 而丢失：

```text
%LOCALAPPDATA%\MedExReportAssistant\config.ini
```

## 下载位置

请先把维护者提供的 ZIP 复制到本机磁盘，再完整解压到 Desktop、普通本地文件夹或其他自选位置。不要直接从共享盘、共享驱动器或 ZIP 压缩包内部运行 EXE。

如果需要开机自动运行，可以由用户手工把 EXE 放入 Windows Startup folder；程序本身不会创建 Startup shortcut。

## 如果无法启动

如果看到“MedEx Report Assistant 已在运行”，请先通过系统托盘退出当前版本，再启动新版本。程序不会自动终止或替换正在运行的版本。

不要删除或手动覆盖 `config.ini`，也不要发送患者信息、报告文字、剪贴板内容或包含临床信息的截图给维护者。
