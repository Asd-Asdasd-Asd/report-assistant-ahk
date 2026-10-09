# 维护说明

## 日常修改

- 修改前先运行 `git status --short`，不要覆盖用户已有改动。
- 新功能进入 `src/`；不要把逻辑复制到 `release/`、`tools/field-testing/` 或 `legacy/`。
- `release/report_assistant.ahk` 由 `scripts/build_release.py` 生成；source 变化后重新生成并检查，不手工编辑。
- 所有生成物（release 和 `tests/windows/generated/` 下的合成回归 / 诊断）都经由 `scripts/ahk_bundle.py` 拼接；
  新增 builder 只声明组件列表和文件头，不复制拼接逻辑。`tests/test_generated_harnesses_in_sync.py` 要求已提交的
  生成物与 builder 输出一致，改了被打包的源码后要重新运行对应 builder。
- 现场工具 EXE 统一用 `scripts/build_tool_exe.ps1` 构建，`tools/field-testing/*.cmd` 只传参数。
- Candidate G 现场脚本在 `tools/field-testing/candidate-g/`，历史记录在 `docs/history/`。
- 纯文档修改不需要重写 generated release。

## 验证

- Python 测试：`python3 -m unittest discover -s tests -p 'test_*.py'`
- Windows 上的 `test_maintenance_windows.py` 会用 AutoHotkey v2 在独立进程中验证快捷键和配置启动失败路径；只使用永不激活的快捷键条件和模拟配置入口，不操作 MedEx、剪贴板或用户配置。可通过 `AUTOHOTKEY_EXE` 指定 v2 解释器；缺少运行环境时明确跳过。
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
