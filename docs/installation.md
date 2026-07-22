# 便携版使用说明

## 普通用户

1. 将维护者提供的 ZIP 复制到本机磁盘；不要直接从共享盘运行。
2. 完整解压 ZIP。
3. 将 `麦旋风.exe` 保留在 Desktop、普通本地文件夹、Windows Startup folder 或其他自选位置。
4. 双击 EXE 启动。无需安装 AutoHotkey、无需管理员权限，也没有固定安装目录。

程序不会创建 Desktop/Startup shortcut、修改注册表或复制自身。用户配置始终位于：

```text
%LOCALAPPDATA%\MedExReportAssistant\config.ini
```

## 维护者从源码运行

源码和 generated `.ahk` 验证仍需要 Windows、AutoHotkey v2 及 repository 中 pinned `src/Lib/UIA.ahk`。普通用户发布物是编译后的单 EXE，不要求目标机器安装 AutoHotkey。
