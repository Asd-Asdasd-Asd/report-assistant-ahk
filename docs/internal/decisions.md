# 长期工程约束

本文只保留仍会影响实现和审查的决策。历史 ADR 背景和已废弃方案由 Git 历史及技术调查文档保存。

## 技术与运行边界

- 使用 AutoHotkey v2 作为当前 Windows 本地辅助层；不接入数据库、不绕过权限。
- `src/` 是源码真相，`release/report_assistant.ahk` 是生成物；用户配置使用独立的版本化 INI。
- legacy 脚本保留作参考或兼容来源，不作为新功能默认入口；同一 hotstring/hotkey 只能有一个 active owner。
- 所有坐标动作必须在目标工作站校准并经过现场验证，不能跨机器假设绝对坐标稳定。

## 临床与交互安全

- 不自动提交、审核或发送报告，必须保留人工确认。
- 窗口、PID、owner、控件、geometry 或 popup 证据不唯一时停止，不猜测、不 blind click、不自动 fallback。
- Clipboard 只有一个事务 owner，必须在成功和失败路径恢复原值；不得复用旧测量结果。
- 诊断只保存隐私安全的必要结构，不保存患者信息、报告正文、clipboard payload、凭据或截图。

## 发布边界

- 交付采用 portable single-EXE；当前不提供 installer、self-update、shortcut、registry installation state、rollback 或其他版本清理。
- 版本号唯一人工来源为 `src/app_metadata.ahk`；正式发布必须来自 clean Git commit。
- Python/静态测试只证明对应的静态或生成检查；Windows/MedEx 现场验收仍是运行时行为的最终依据。
