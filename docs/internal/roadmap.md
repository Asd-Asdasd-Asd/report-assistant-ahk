# 路线图

本文只记录尚未完成且可能影响后续决策的方向；已完成事项放在 CHANGELOG 或现场记录中。

## 当前优先事项

- 完成当前 Viewer 测量、快捷键、颜色恢复和 Montage 修改的 Windows/MedEx 验收。
- 补充 failure injection、隐私安全现场证据和延迟记录。
- 验证额外 DPI/scaling、multi-monitor、Viewer layout 和 workstation profile；未知结构保持 fail closed。
- 保留人工测量、人工输入和人工确认回退；不得为了覆盖率放宽目标唯一性检查。

## 后续候选

- 逐项迁移仍由 `legacy/medex_legacy_compat.ahk` 提供的功能；每项都需要独立 window guard、现场验证和可停止的人工回退。
- 只有在有稳定公开接口或充分的被动证据时，才评估新的 Viewer provider；不得用协议猜测替换已验证路径。
- installer、更新支持和更正式的系统集成属于独立产品阶段，当前 portable release 不扩展这些职责。

## 长期边界

- 不自动提交/审核报告，不访问数据库，不绕过权限。
- 不把静态测试当作 Windows runtime acceptance。
- 不提交患者信息、医院敏感信息、真实配置、截图、凭据或临床日志。
