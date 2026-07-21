# 更新说明

普通用户只需要使用维护者提供的新文件，不要自己修改脚本内容。个人配置与程序文件分开保存；更新不会覆盖已有配置值，但可能在备份后补充新版本缺少的默认项。

## 更新步骤

1. 先关闭旧脚本。
2. 按本次内部更新说明退出 compatibility script；不要同时运行原始 legacy script 和 compatibility script。
3. 用维护者提供的新文件替换旧程序文件，不删除 `%LocalAppData%\MedExReportAssistant\config.ini`。
4. 双击运行新文件，再按维护者说明启动 compatibility script。
5. 打开无患者信息的测试区域，简单测试 `;cmx` 和本次更新指定项目。

## 如果出错

1. 按 Ctrl+Alt+Q 退出新脚本。
2. 换回旧文件。
3. 联系维护者。

## 注意

- 不要自己打开脚本修改内容。
- 不要删除或手动覆盖 `%LocalAppData%\MedExReportAssistant\config.ini`；自动补项前的备份保存在同目录的 `backups` 文件夹。
- 不要把患者信息发给维护者。
- 不要在不确定时反复尝试异常功能。
