# 项目状态与交接

更新时间：2026-09-11。当前版本以 `src/app_metadata.ahk` 为准。

## 当前状态

- 源码版本为 `0.8.0`，当前工作区含未发布修改；Windows EXE 是否通过本轮验收需单独确认。
- Viewer 测量目标使用 `MxNMMeasurementProvider.ResolveTarget` → `MxNMContextTargetSessionProvider`，按当前 Viewer 身份发现并验证图像 surface。
- 当前 production 路径不依赖旧的 config-only 几何计划；旧实现和 checkpoint 仅作历史审计材料。
- Viewer 快捷键、测量、颜色恢复和 Caption 首次保存均要求明确的窗口/进程/控件/目标证据；证据不唯一时 fail closed。
- 详细设计审计和待现场确认的问题见 `2026-09-06-design-audit.md` 及对应的 `mxnm-*` 文档。

## 已确认的项目边界

- `src/` 是源码真相，`release/report_assistant.ahk` 是生成物。
- 应用版本唯一人工来源是 `src/app_metadata.ahk`。
- 用户配置位于 `%LocalAppData%\\MedExReportAssistant\\config.ini`；迁移必须备份、临时写入并复验。
- 报告提交、审核和发送不自动执行；Clipboard 必须保存并在 `finally` 中恢复。
- Windows 现场验证不能由 Python 测试、静态检查或 generated release 替代。

## 当前验证与未决事项

- 已完成的验证以当前源码、测试和现场证据为准，不在此重复逐项历史测试记录。
- 其他 DPI/scaling、multi-monitor、Viewer layout 和 workstation profile 不得默认视为支持。
- 重新编译后首次颜色下拉菜单的偶发残留仍需在正式 EXE 验收时记录；不得用 blind retry 掩盖。
- 用户于 2026-09-11 确认 scoped popup Montage 修复消除了半路卡住并改善整体速度；
  该反馈限定于实际测试环境，不扩展为所有机器验收。
- 本轮其他自动化就绪优化及待验收场景见 [automation-readiness.md](automation-readiness.md)。

## 读取规则

- 先读本文件和 `AGENTS.md`，再读源码/测试。
- 只有处理对应问题时才读取 `docs/technical-investigations/`、`docs/field-tests/` 和 `experiments/`。
- 历史文档中的候选方案、旧调用链和“已完成”描述不能覆盖当前源码与最新现场证据。
