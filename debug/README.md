# MedEx 颜色复位 Windows 现场调试

`medex_color_reset_field_debug.ahk` 是现场验证脚本，不是生产入口。它不会粘贴报告文字，也不会修改正常用户配置；它会尝试打开颜色菜单并对 Name=`000000` 的 UIA `Hyperlink` 执行 `Invoke()`。

## UIA 依赖

本实现选择 Descolada UIA-v2 v1.1.3。下载该版本后，最直接的 field-debug 目录结构是：

```text
debug\
├── medex_color_reset_field_debug.ahk
└── Lib\
    └── UIA.ahk
```

这样 AutoHotkey v2 可以通过 `<UIA>` 找到依赖。也可以使用已验证的 standard AutoHotkey user library path，但不要同时 include 两份不同版本。

- Repository: `https://github.com/Descolada/UIA-v2`
- Pinned release: `v1.1.3`

如果依赖未安装，脚本仍可启动，但 diagnostic hotkey 会返回：

```text
COLOR_RESET_UIA_UNAVAILABLE
```

不得为了绕过该结果而加入 blind clicks。

## Dedicated hotkey

```text
Ctrl+Alt+F12
```

脚本自动把完整结果复制到 clipboard，并默认追加写入：

```text
%TEMP%\MedExAHK\medex_color_reset_field_debug.txt
```

最小 development log 写入：

```text
%TEMP%\MedExAHK\medex_color_reset_field_debug.log
```

两者都不得包含 patient information、report text、clipboard text 或 pasted phrase。

## 可调 field-test overrides

只编辑脚本顶部以下 constants：

- `DEBUG_RATIO`
- `DEBUG_MENU_OPEN_TIMEOUT_MS`
- `DEBUG_MENU_POLL_INTERVAL_MS`
- `DEBUG_MAX_TRIGGER_ATTEMPTS`
- `DEBUG_ALLOW_PROVISIONAL_PROCESS`
- `DEBUG_CONFIRMED_PROCESS_NAME`

`DEBUG_MAX_TRIGGER_ATTEMPTS` 在 adapter 内始终限制为 1–2，不能通过 debug override 形成无限或重复 blind clicks。

## 安全限制

- 不在 finalized patient report 中测试。
- 使用经过批准的 non-clinical test context。
- Diagnostic hotkey 不插入 test text；颜色复位完成后，由用户手工输入一个无害字符检查颜色。
- 如果鼠标移动、窗口失焦或菜单行为异常，立即停止重复测试并退出脚本。
