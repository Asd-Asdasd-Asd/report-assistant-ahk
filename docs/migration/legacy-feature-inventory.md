# Legacy 当前功能清单

本清单只记录仍影响当前 ownership、冲突或迁移决策的内容。已经完整迁移的
阶段性实现细节由现行 source、tests 和 Git 历史保存。

## 已由麦旋风接管

| Capability | 当前实现与边界 |
| --- | --- |
| 报告模板 `;red`、`;fzg`、`;fwj`、`;fjd`、`;cma`、`;cmx` | Schema 2、MedEx-only scope、transactional clipboard；不得同时运行 legacy duplicate |
| RAlt+H/J/K/L | `GlobalHjklArrows=true` 时由麦旋风独占；compatibility 不注册 |
| Viewer 箭头、长度、3D SUV | Native command-control resolver；完整松键后投递一次 |
| Viewer F12 截图 | 仅 Viewer 前台发送；pulse 不表示截图已完成 |
| 清除全部标注 | Context-menu cleaner；失败不撤销已写入报告 |
| SUVMax 与尺寸读取 | 严格区分 `FOUND`、`NOT_ANNOTATED`、automation failure；不复用旧 clipboard 值 |
| 红字与后续黑字 | CF_HTML + Candidate G；只支持已验证 profile，其他环境 fail closed |
| Shift+Alt+S 快速标图 | 唯一同 PID target signature；首次 fresh copy，随后只在绑定 target 前台复用；有意保留 caption clipboard 并恢复鼠标 |
| Body/Head/Lung Montage（Beta） | production 独占；设置页可启用并修改三组快捷键及 5×4 布局行列；compatibility 不再注册 |

## Compatibility 仍保留

| Hotkey | 行为 | 当前风险 |
| --- | --- | --- |
| Ctrl+Win+Shift+C | 左 MIP、右 coronal sectional/fusion cover workflow | 多个固定坐标，中途失败仍可能继续 |
| XButton1 | 一秒 ToolTip notification | 历史测试项，不作为迁移目标 |

这些动作仍是 global hotkeys。启用前必须确认目标工作站布局，不得与原始
`karabiner.ahk` 同时运行。

## 明确不再迁移的旧入口

- Shift+Alt+R `red_not.clip` snapshot save；
- Ctrl+Win+Shift+S Viewer screenshot；
- Ctrl+Win+Shift+M SUV activate/clear 复按状态机；
- Ctrl+Win+Shift+A Arrow activate/clear 复按状态机。

旧 snapshot 依赖固定路径和 session-specific clipboard formats。SUV/Arrow
复按状态会与真实 Viewer state 漂移，因此由显式“选择工具”和“清除”动作取代。

## 共存风险

- 两个 AHK 进程不共享 suspend state、配置、clipboard lock 或 mouse lock。
- 麦旋风的暂停/退出不控制 compatibility。
- Compatibility 剩余动作仍可能在错误前台窗口执行固定坐标动作。
- 旧 compatibility 运行实例若尚未重启，可能仍注册 Shift+Alt+S；测试新版本前
  必须退出旧实例并启动本 branch 的新版脚本。
- 原始 legacy hotstrings 与当前报告 hotstrings 同名，不能并行注册。
- 用户配置、旧脚本和 `red_not.clip` 副本属于用户数据，不得自动覆盖或删除。

## 迁移完成条件

每个保留动作只有在明确业务语义、建立 fail-closed window/geometry guard、
完成目标工作站 runtime 验证并更新 ownership 回归后，才能从
`medex_legacy_compat.ahk` 移除。

Montage 的已验证 transport、可调参数和分支开发顺序见
[MxNM montage 迁移交接](../internal/mxnm-montage-migration-handoff.md)。
