# 维护说明

本文档面向维护者。普通用户不需要阅读。

## 开发环境分工

- 本地开发主要在 Mac 上进行。
- Windows 工作电脑只用于部署、校准和测试。
- 不在 Windows 工作电脑上保存患者数据、敏感日志或截图到项目目录。

## 常规流程

1. 修改 `src/` 或 `docs/`。
2. 运行 `python scripts/build_release.py`。
3. 运行 `git status` 查看改动。
4. 运行 `git add ...` 暂存相关文件。
5. 运行 `git commit -m "..."` 提交。
6. 运行 `git push` 推送到 private repo。
7. 拷贝 `release/report_assistant.ahk` 到 Windows 测试。
8. 按 `tests/manual-test-checklist.md` 或 `docs/internal/release-checklist.md` 完成测试。

## 如何记录问题

记录问题时应包含：

- 发生时间。
- 使用的版本或 commit。
- Windows 版本和显示缩放。
- 脚本正在执行的功能。
- 期望结果和实际结果。
- 是否可以稳定复现。

不要记录：

- 患者姓名、检查号、住院号、身份证号等信息。
- 医院敏感信息。
- 账号、密码、令牌。
- 真实内网地址。
- 截图或敏感日志。

## 如何更新 CHANGELOG

- 每次可见行为变化都记录在 `CHANGELOG.md`。
- 文档、治理、发布流程变化也应记录。
- 未发布内容先放在 `[Unreleased]`。
- 准备版本发布时再整理到对应版本号。

## 不要提交的内容

- `src/config.local.ahk`
- 患者数据
- 医院敏感信息
- 账号、密码、令牌
- 截图
- 日志文件
- 本机临时文件
- 编译出的 `.exe`
- 未经确认的坐标校准文件
