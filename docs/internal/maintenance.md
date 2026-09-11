# 维护说明

## 日常修改

- 修改前先运行 `git status --short`，不要覆盖用户已有改动。
- 新功能进入 `src/`；不要把逻辑复制到 `release/`、`debug/` 或 `legacy/`。
- `release/report_assistant.ahk` 由 `scripts/build_release.py` 生成；source 变化后重新生成并检查，不手工编辑。
- 纯文档修改不需要重写 generated release。

## 验证

- Python 测试：`python3 -m unittest discover -s tests -p 'test_*.py'`
- 静态检查：`git diff --check`
- source 变化后按影响范围运行测试，并按需运行 `python3 scripts/build_release.py`。
- AHK/Viewer/MedEx 行为必须在 Windows 目标环境现场验证；macOS 静态检查不能替代现场验收。

## 配置与生成物

- 用户配置位于 `%LocalAppData%\\MedExReportAssistant\\config.ini`，不得随意覆盖、删除或把用户值当作默认值写回。
- Schema migration 必须先备份、临时写入、最终复验；失败时保留原配置并 fail closed。
- Windows 构建使用仓库同级 `report-assistant-build/`；该目录不提交。
- 正式 ZIP 只包含 EXE、版本信息和必要的用户说明，不包含 source、诊断工具、配置、日志或 Git metadata。

## 问题记录与隐私

- 记录版本、脚本功能、期望/实际结果、复现条件和安全失败码。
- 不记录患者姓名、检查号、报告正文、clipboard payload、账号、凭据、真实医院地址或未经脱敏的截图。
- 诊断成功不等于 Windows UI 成功；明确区分静态验证、生成验证、现场观察和用户确认。
