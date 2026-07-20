# 架构说明

本文档记录当前架构设想。项目仍处于 early personal prototype 阶段，目标是先建立可维护、安全、可逐步迁移的自动化层，而不是一次性重写全部 legacy 行为。

## 为什么选择 AHK v2

当前目标系统是 Windows 桌面环境中的报告书写窗口和阅片窗口。初始阶段选择 AutoHotkey v2，主要原因是：

- 可以在不修改原系统、不接入数据库、不绕过权限的前提下做本地辅助。
- 对键盘输入、热字符串、剪贴板、窗口激活和鼠标动作支持成熟。
- 适合先验证工作流，再决定是否需要更正式的插件或系统集成。
- 部署成本低，适合少量内部工作站试用。

暂时不直接做插件，是因为当前没有稳定公开的目标系统插件接口，也不应该在早期原型阶段引入高风险集成。

## 报告书写界面的自动化策略

报告书写界面优先使用 hotstrings、键盘快捷键和剪贴板富文本，原因是：

- 输入文本和常用短语是最高频需求。
- 键盘和剪贴板动作比鼠标坐标更稳定。
- 后续可以逐步加入 RTF / HTML 剪贴板事务，减少手工格式调整。
- 不需要接触数据库，也不需要绕过原系统权限。

红色 `（见图）` 插入的 v0.4.0 方案曾尝试动态 RTF clipboard construction。Windows 现场测试显示，RTF payload 没有被目标报告编辑器正确消费；当同时写入 `CF_UNICODETEXT` 时，编辑器插入的是黑色文本。RTF 因此降级为 experimental/reference。

v0.4.2 的活动实现改为 HTML Clipboard / `CF_HTML`。`clipboard_html.ahk` 动态构造 UTF-8 payload，按字节计算 `StartHTML`、`EndHTML`、`StartFragment` 和 `EndFragment`，并通过 Windows Clipboard API 写入注册格式 `HTML Format`。默认红字路径不写入 `CF_UNICODETEXT`，因此不支持 HTML 的编辑器不会静默插入黑色 `（见图）`。

`red_not.clip` 仍可作为诊断参考，但它依赖 `ClipboardAll` binary snapshot，可能受 session-specific registered clipboard format IDs 影响，不能成为生产依赖。RTF 代码不再进入活动运行路径，相关调查结论由 Git 历史和 `red-text-clipboard-investigation.md` 保存。

MedEx 现场验证已经确认 `CF_HTML` 可以插入红色文字。仍未解决的运行时代码问题是：MedEx 继承最后插入字符的红色，导致后续输入继续为红色。空黑 span、零宽字符、Word COM 和键盘格式快捷键均不作为生产方案。

现有 `uiaInvoke` strategy 在 paste transaction 完成后，从 foreground MedEx window root 枚举 `Text` elements，以 exact Name=`检查所见` 定位目标语义行，再选择同一行的 dynamic font-size local anchor。它按 profile 计算 trigger point，并对 exact Name=`000000` 的 `Hyperlink` 调用 `Invoke()`。2026-07-16 production 测试确认 semantic/static localization 可用，但 Chromium popup traversal 延迟高且间歇失败，因此该 strategy 只保留为显式 comparison/rollback，不再是首选开发方向。

`ResetMedExInsertionColor()` 是统一 strategy dispatcher。当前有 `uiaInvoke` 和 `relativeMousePixelValidated`；两者不得自动互相 fallback。Candidate G 继续复用 report/clipboard orchestration，只把 MedEx interaction strategy 替换为 UIA toolbar-row localization、profile geometry、popup pixel validation 和 relative mouse clicks。Windows G2 controlled interaction 与 caret-order A/B 通过后，production default 已提升为 `relativeMousePixelValidated`；`uiaInvoke` 仅保留为显式 comparison/rollback strategy。

`medex_candidate_g_logic.ahk` 集中提供 toolbar-row selection、supported-profile validation、relative point calculations 和 field-calibrated popup signature。独立 calibration harness 使用 exact region query；只有出现多个 geometry-valid region candidates 时才收集 full Text snapshot 进行 same-row corroboration。F8–F11 保持 G1 行为；F12 经统一 dispatcher 执行 G2，arrow 和 black 各最多点击一次，signature 失败时 black interaction 不可达。

红字实现仍必须包裹在 clipboard save/restore transaction 中，最终行为必须插入红色 `（见图）`、恢复用户原始剪贴板，并让后续输入恢复黑色。颜色复位不得插入可见、零宽或隐藏字符，也不得改变 clipboard restoration contract。

`Color Reset` 是 phrase-specific orchestration，而不是所有红色 marker 的无条件尾处理。Standalone `;red` 的 caret 留在 marker 后方，因此需要 adapter reset；`;fzg` 的 caret 必须移动到 marker 前方，Windows A/B 已验证其正确顺序是 paste/clipboard restore → 50 ms → `Left 4`，不经过 toolbar reset。该路径返回 `COLOR_RESET_NOT_REQUIRED`，不能伪报 `AUTOMATION_CHAIN_OK`。

当前 `;red` transaction 先完成 CF_HTML paste 和 clipboard restoration，再调用 Candidate G。下一轮性能工作的 critical path 定义为 `HotstringTriggeredMs → BlackClickSentMs`，不是整个函数返回时间。计划在独立检查点中把 black click 提前到 clipboard restoration 之前，同时继续用 `finally` 强制恢复剪贴板，并以 `pasteSentAt`/`SafeMinPasteToRestoreMs` 保护快速失败路径；安全最小值必须由 Windows 测试决定。

Report hotstrings 的 Step 2 working tree 已用 shared `#HotIf`/foreground predicate 限制 MedEx-specific entries；全局 pause/exit 保持 suspend-exempt。Candidate G interaction path 已移除冗余的 process-name 重查，但 arrow、second signature sample 和 black click 前继续验证 original HWND 仍 active。该变更已通过 Windows scope/foreground 验收，等待提交。

所有报告书写辅助都必须保留人工确认，不默认执行最终提交、审核或发送。

## Measurement architecture

MxNMSoft 测量值读取计划通过未来的 `ContextMeasurementProvider` adapter/provider layer 实现。line measurement 和 SUVMax 使用相同的 context-menu transport：在当前图像区域打开右键菜单，按 visible command text 找到复制命令，读取并校验剪贴板结果。

`ContextMeasurementProvider` 返回 structured measurement data，例如 measurement type、raw value、formatted value、source、timestamp、study identity 和 failure reason。hotstrings 或上层报告逻辑只负责决定最终插入的报告文本，不直接承担窗口消息、控件查找和解析细节。

当前图像读取失败时，manual fallback 仍是上层 workflow。系统应优先 false negative，不能复用旧剪贴板值，也不能把最后一条 SUV log 自动当作当前图像测量值。

## 阅片界面的自动化策略

阅片界面采用 mixed automation policy：有可靠语义的标准控件使用 exact accessible Name 和 UIA Invoke/Value/SelectionItem/ExpandCollapse；官方快捷键比 UI 元素更稳定时优先使用快捷键；只有自绘 child 未暴露时，才通过 UIA 定位并校验父区域后使用区域内相对坐标。absolute screen coordinates 只用于诊断或临时 compatibility fallback。

- 受屏幕分辨率、缩放比例、窗口位置和软件布局影响。
- 不同工作站必须单独校准。
- 需要窗口校验和人工测试后才能启用。

因此阅片动作应逐个迁移，不能一次性照搬 legacy 点击序列。每个动作必须验证 process/window、fail closed、避免 modal feedback，并在需要移动鼠标时恢复原位置。

## `src/` 模块职责

以下既包含当前模块，也包含按里程碑逐步建立的目标边界。M0/M1 不为未来 viewer、configuration 或 packaging 工作创建空模块。

- `main.ahk`：项目入口，加载模块，注册全局安全热键。
- `app_metadata.ahk`：唯一人工维护的 application version/channel/source revision metadata。
- `config.example.ahk`：当前原型示例配置；v0.5.0 将由 centralized external INI config 取代其用户配置职责。
- `config_defaults.ahk` / `config_loader.ahk` / `config_validator.ahk` / `config_migrations.ahk`：v0.5.0 planned config pipeline，集中返回 normalized config。
- `runtime_registry.ahk`：根据 normalized config 动态注册 configured hotkeys/hotstrings。
- `hotstrings.ahk`：文本扩展 workflow handlers，不直接读取 INI，不把 user replacement 当作代码执行。
- `clipboard_html.ahk`：构造 CF_HTML、调用 Windows Clipboard API、派发粘贴命令并恢复用户剪贴板。返回成功只表示粘贴命令已派发且恢复已尝试，不代表目标编辑器已经确认渲染结果。
- `report_editor.ahk`：editor-level orchestration，例如插入格式化报告文字、调用目标 editor adapter 恢复 insertion state、处理 workflow result；不得包含 generic clipboard wire-format implementation。
- `medex_color_reset_logic.ahk`：layout profile、pure anchor selection、rectangle/geometry、local-offset calculation、screen/client conversion 和 structured result definitions。
- `adapters/medex_report_editor.ahk`：MedEx-specific strategy dispatch、target validation 和 interaction。`relativeMousePixelValidated` 是 production mainline；`uiaInvoke` 暂存于同一 adapter 作为显式 comparison/rollback。后续如按真实复杂度拆分文件，不得复制 clipboard/report orchestration。
- `diagnostics.ahk`：区分 production failure-only lightweight log 与 explicit field schema；不得记录报告内容、replacement text 或 clipboard payload。
- `Lib/UIA.ahk`：production、field debug 和 release build 共用的 pinned UIA-v2 dependency；不得在 debug tree 维护第二份实现。
- `viewer_actions.ahk`：阅片窗口动作，未来逐步迁移经过校准的坐标操作。
- `window_guard.ahk`：窗口存在、激活和焦点保护。
- `utils.ahk`：通用辅助函数，例如提示、鼠标位置恢复、坐标点击。

## `legacy/` 的作用

`legacy/` 保存原始脚本作为历史来源和行为参考。原始文件不应在迁移过程中修改或覆盖。迁移期允许新增明确标识的 compatibility script，仅保留新项目尚未替代的日常功能；它不是新的源码真相来源。功能归属和缩减规则记录在 `docs/migration/`。

## `release/` 的作用

`release/` 保存生成后的单文件脚本，便于复制到 Windows 工作站进行测试。生成文件来自 `scripts/build_release.py`，维护者应优先修改 `src/`，不要手工修改 release 文件。

v0.5.0 增加 internal-test executable。Executable、单文件 `.ahk` 和模块化 source 都不能包含真实 user config。用户配置保存在 `%LocalAppData%\MedExAHK\config.ini`，更新应用 artifact 时必须保留。

## Editor adapter boundary

```text
hotstring workflow
→ report_editor.ahk
   ├── clipboard_html.ahk (generic CF_HTML transaction)
   └── editor adapter
       └── medex_report_editor.ahk
           ├── uiaInvoke (comparison/rollback)
           └── relativeMousePixelValidated (production default)
```

未来 Word、browser editor 或其他 HIS 必须通过新的 adapter 接入。不能通过向 generic clipboard module 添加 MedEx 条件分支实现 multi-editor support。

## Structured result boundary

MedEx color reset 返回 stable result code 和诊断 context，而不是单个 Boolean。`Invoke()` 未抛错不得直接代表最终颜色已验证。M1 diagnostics 分别记录 semantic/local anchor selection、`ColorMenuClickSent`、`BlackItemFound`、`BlackItemInvokeSucceeded` 和 `FinalInsertionColorVisuallyValidated`。

- `COLOR_RESET_OK`（现有兼容 code；M1 后不得单独用作最终视觉成功结论）；
- `COLOR_RESET_WRONG_PROCESS`；
- `COLOR_RESET_FOREGROUND_CHANGED`；
- `COLOR_RESET_PROCESS_NAME_UNCONFIRMED`；
- `COLOR_RESET_UIA_UNAVAILABLE`；
- `COLOR_RESET_DOCUMENT_NOT_FOUND`；
- `COLOR_RESET_REGION_ANCHOR_NOT_FOUND`；
- `COLOR_RESET_REGION_ANCHOR_AMBIGUOUS`；
- `COLOR_RESET_FONT_SIZE_ANCHOR_NOT_FOUND`；
- `COLOR_RESET_FONT_SIZE_ANCHOR_AMBIGUOUS`；
- `COLOR_RESET_INVALID_RECTANGLE`；
- `COLOR_RESET_INVALID_GEOMETRY`；
- `COLOR_RESET_INVALID_COORDINATE_SPACE`；
- `COLOR_RESET_TRIGGER_CLICK_FAILED`；
- `COLOR_RESET_MENU_NOT_OPENED`；
- `COLOR_RESET_BLACK_ITEM_NOT_FOUND`；
- `COLOR_RESET_INVOKE_UNAVAILABLE`；
- `COLOR_RESET_INVOKE_FAILED`；
- `COLOR_RESET_UNSUPPORTED_PROFILE`；
- `COLOR_RESET_INVALID_ARROW_POINT`；
- `COLOR_RESET_INVALID_BLACK_POINT`；
- `COLOR_RESET_POPUP_SIGNATURE_MISMATCH`；
- `COLOR_RESET_BLACK_CLICK_FAILED`；
- `RELATIVE_MOUSE_CHAIN_OK`；
- `COLOR_RESET_NOT_REQUIRED`；
- `COLOR_RESET_UNEXPECTED_ERROR`。

自动化链路可报告 `AUTOMATION_CHAIN_OK` 和 `FINAL_COLOR_PENDING_VISUAL_VALIDATION`。只有 Windows 操作者在 approved non-clinical context 输入无害字符后，才能将 `FinalInsertionColorVisuallyValidated` 记录为 true。调用层决定如何处理结果；adapter 在所有不确定状态下 fail-closed，绝不继续 blind clicks。Production 默认只在失败时写 lightweight privacy-safe diagnostic；field debug 必须显式选择 `diagnosticMode=field` 才输出完整 geometry schema。下一轮 timing fields 进入现有 performance context，不创建第二个 release artifact。两种模式共享同一个 adapter 和 resolver，且不显示 `MsgBox`、`ToolTip` 或 `TrayTip`。

MedEx version 当前仍是 narrow runtime profile 的 hard gate。计划把 version 独立改为 diagnostics-only metadata；resolution、DPI 和 scaling 的 hard gate 不能简单删除后宣称多环境支持，真正 rollout 需要本机 calibration/profile。

## Configuration boundary

配置唯一入口为 centralized load pipeline：defaults → read → parse → validate → migrate → normalize。Feature modules 不得直接调用 `IniRead()`。Built-in handlers 使用 stable IDs，trigger 和 replacement 是 data；user-defined hotstrings 也只能生成受控 text callbacks，不能执行用户输入的 AHK code。

详细方案见 `docs/internal/configuration-architecture.md`。

## 风险边界

- 不访问数据库。
- 不绕过系统权限。
- 不默认自动提交、审核或最终发送报告。
- 不保存患者信息、医院敏感信息、账号、截图、真实内网地址或敏感日志。
- 剪贴板动作必须尽量保存并恢复原剪贴板。
- 坐标动作必须经过本机校准和人工测试。
