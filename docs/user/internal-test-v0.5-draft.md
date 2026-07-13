# v0.5.0 内部测试说明（草案）

> 当前尚未发布 v0.5.0 executable。本文件用于准备内测流程，只有维护者明确通知后才能按此启用。

## 这次内测的目标

- 检查红色 `（见图）` 是否正确插入。
- 检查插入后继续输入是否恢复黑色。
- 检查个人 hotkeys/hotstrings 配置是否正确加载。
- 收集不包含患者信息的 failure result 和 timing logs。

本次不测试 automatic SUVmax、long-axis/short-axis retrieval、automatic updater 或 complete settings GUI。

## 启动前

1. 保存当前已知可用版本，确保可以回滚。
2. 退出原始 legacy scripts。
3. 确认维护者提供了匹配版本的新 executable 和 compatibility script。
4. 不删除 `%LocalAppData%\MedExAHK\config.ini`。

## 启动顺序

1. 启动 v0.5.0 internal-test executable。
2. 确认启动提示。
3. 启动 `medex_legacy_compat.ahk`。
4. 确认没有同时运行原始 `karabiner.ahk` 或 `string_change.ahk`。

## 出现异常时

1. 停止继续输入或重复触发。
2. 按 Ctrl+Alt+Esc 暂停新项目。
3. 必要时按 Ctrl+Alt+Q 退出新项目。
4. 从独立 tray icon 退出 compatibility script；新项目快捷键不会自动停止它。
5. 检查报告中可见文字和颜色，必要时手工修正。
6. 联系维护者，只提供时间、版本、result code 和操作名称。

不要发送患者信息、报告文字、剪贴板内容或包含临床信息的截图。

## 回滚

1. 退出新项目和 compatibility 两个进程。
2. 启动维护者指定的上一版已知可用组合。
3. 保留 user config 和 diagnostics，等待维护者判断；不要自行覆盖配置。
