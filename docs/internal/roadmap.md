# 路线图

本文只记录当前方向和未来边界。已完成版本及用户可见变化由
`CHANGELOG.md` 和发布说明保存，不在路线图重复展开。

## 当前 v0.6.x

- 完成 Viewer native command-control resolver 和 measurement target 的跨机器
  回归，以原工作站作为最终验收环境之一。
- 继续验证其他 resolution、DPI/scaling、Viewer layout、multi-monitor 和
  workstation profile；未知结构保持 fail closed。
- 补充 SUVMax、尺寸和清除链的 failure injection、privacy-safe field evidence
  与尾延迟记录。
- 完成单修饰键、Viewer-only 无修饰字母/数字、Win modifier 持久化和 F12
  dispatch pulse 的 release smoke test。
- 保持 Manual measurement/caret fallback；同一模板暂不混用
  `{{suvmax}}` 与 `{{size}}`。

## 后续候选

- 在获得单独授权后评估 per-machine Candidate G layout calibration。校准只能
  保存本机 profile 与环境 metadata，不能引入无校验绝对坐标 fallback。
- 逐项迁移 `medex_legacy_compat.ahk` 尚存的 montage、caption/advance 和 cover
  actions；每项都需独立 window guard、现场验证和可停止的人工回退。
- 仅在有稳定公开接口或充分被动证据时评估新的 Viewer provider；不得用协议
  猜测替换现有 validated provider。
- 是否需要 installer、更新支持或更正式集成，必须作为独立产品阶段评估；
  当前 portable release 不扩展这些职责。

## 长期交付策略

- 模块化 `src/` 是源码真相；`release/report_assistant.ahk` 是可复现生成物。
- 普通用户交付 portable single EXE，配置保存在
  `%LOCALAPPDATA%\MedExReportAssistant\config.ini`。
- Source、Windows runtime 和用户现场观察是不同证据层；静态测试不能替代
  AHK/UIA/MedEx 现场验收。
- 每个可交付版本同步维护中文用户说明、维护说明、CHANGELOG 和 release
  checklist。

## 长期安全边界

- 不访问数据库，不绕过权限，不自动审核或提交报告。
- 不提交患者信息、医院敏感信息、真实用户配置、截图、凭据或临床日志。
- Clipboard 必须事务性恢复；报告失败不得误用旧测量值。
- Window、PID、native control、geometry 或 popup 证据不唯一时停止，不猜测。
- 不自动终止、替换、备份、清理或回滚其他 EXE。
- 不静默删除用户配置、模板、legacy 脚本或人工工作流。
