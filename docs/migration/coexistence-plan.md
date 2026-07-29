# 当前新项目与 Legacy 共存边界

迁移期允许同时运行：

1. 当前麦旋风 EXE，负责报告模板、测量读取和已迁移的 Viewer 快捷键。
2. `legacy/medex_legacy_compat.ahk`，只负责尚未迁移的固定坐标动作。

原始 `legacy/karabiner.ahk` 和 `legacy/string_change.ahk` 只作为行为参考和人工
回退来源，不得与 compatibility script 同时运行。

## 当前 ownership

| Capability | Owner |
| --- | --- |
| `;red`、`;fzg`、`;fwj`、`;fjd`、`;cma`、`;cmx` | 麦旋风 |
| RAlt+H/J/K/L | 麦旋风，需 `GlobalHjklArrows=true` |
| Viewer 箭头、长度、3D SUV、F12 截图、清除全部标注 | 麦旋风，默认关闭 |
| Shift+Alt+B/H/L montage | Compatibility |
| Shift+Alt+S caption + advance | Compatibility |
| Ctrl+Win+Shift+C cover images | Compatibility |
| XButton1 notification | 历史测试入口，不视为正式功能 |

Compatibility 不再提供报告 hotstrings、RAlt+H/J/K/L、red snapshot save、
Viewer screenshot 或 SUV/Arrow 复按状态机。

## 启动与停止

1. 退出原始 `karabiner.ahk` 和 `string_change.ahk` 实例。
2. 启动麦旋风并确认版本。
3. 仅在仍需要未迁移动作时启动 `medex_legacy_compat.ahk`。
4. 在无患者信息的测试区域逐项确认 ownership。

`Ctrl+Alt+Esc` 和 `Ctrl+Alt+Q` 只控制麦旋风。停止测试时必须从独立 tray
分别退出两个进程。不得假设暂停一个进程会停止另一个。

## 冲突与安全

- 同一个 trigger 只能有一个 owner；禁止同时运行原始 legacy hotstrings。
- Compatibility 的 fixed-coordinate actions 仍是高风险行为，没有当前 Viewer
  resolver 的 window、PID、geometry 和 fail-closed 保护。
- Shift+Alt+S 使用系统 clipboard 且不恢复旧值，不得与麦旋风的 clipboard
  transaction 并发。
- 两个进程不共享 suspend state、busy flag、clipboard lock 或鼠标事务。
- 一个动作结束前不得触发另一个动作；失败后不得增加补偿性 blind click。
- 新项目暂停、退出或更新不得删除用户配置、legacy scripts、`red_not.clip`
  副本或人工回退流程。

## 迁移准入

仍待迁移的 montage、caption/advance 和 cover actions 必须逐项：

1. 确认真实用户语义和仍有价值的参数。
2. 建立独立 window/process/geometry guard。
3. 保持临床文字、clipboard 和 mouse 行为。
4. 在目标 Windows 工作站验证 success 与 fail-closed。
5. 更新 ownership 测试后，才从 compatibility 移除。

Compatibility 清空后可以归档，但原始 legacy reference 是否删除需另行确认。
