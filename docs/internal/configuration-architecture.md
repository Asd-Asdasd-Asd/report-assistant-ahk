# v0.5.0 配置与模板架构

## 持久化边界

用户数据固定保存在：

```text
%LocalAppData%\MedExReportAssistant\
├── config.ini
├── backups\
│   └── config-YYYYMMDD-HHMMSS[-N].ini
└── logs\
    └── startup.log
```

路径由 `ReportAssistantConfig.Path()` 无副作用地计算，不依赖 EXE 所在目录。路径 helper 不读取、创建或修改配置；singleton 更早建立且不依赖配置初始化。

真实 `config.ini`、backup 和 log 不属于 release artifact，不得编译或提交。删除、移动或替换 EXE 不得影响用户配置。

## 当前模块所有权

- `app_config.ahk`：Schema version、配置目录和通用 managed-entry model。
- `hotstring_model.ahk`：builtin defaults、Schema 2 raw/normalized hotstring model、模板元素常量。
- `hotstring_config.ahk`：Schema 2 INI 读取、默认文件生成、Text 换行与反斜杠 codec。
- `template_renderer.ahk`：严格模板校验、执行时展开和 `ReportTemplatePlan`。
- `hotstring_normalization.ahk`：字段、trigger collision 和模板校验；任一报告模板不安全时整体 fail closed。
- `hotstring_config_migration.ahk`：唯一允许读取 Schema 1 `Mode` 的模块；负责审计、迁移、备份和复验。
- `config_reconciliation.ahk`：补充缺失 managed defaults，并只把仍等于开发期旧默认值的 builtin 升级为显式红色 token。
- `config_bootstrap.ahk`：启动顺序协调；在任何 hotstring 注册前完成创建、迁移和 reconciliation。
- `hotstring_config_editor.ahk`：设置窗口的严格读取、校验和事务保存。
- `settings_ui.ahk`：GUI state 与事件；不直接实现运行时 hotstring。
- `hotstring_registration.ahk`：基于 normalized entries 调用 `Hotstring()`。
- `hotstrings.ahk`：执行 `ReportTemplatePlan`，不读取 INI。

Feature 和 MedEx adapter 不得自行读取或重写 template config。

## Schema 2

```ini
[Config]
SchemaVersion=2

[Features]
GlobalHjklArrows=false

[Hotstring.builtin-red]
Enabled=true
Name=红字插入
Trigger=;red
Text={{red:（见图）}}
```

报告模板 section 仅使用：

- `Enabled`
- `Name`
- `Trigger`
- `Text`

Section 使用稳定且不区分大小写的 identity：

```text
Hotstring.builtin-<stable-id>
Hotstring.custom-<stable-id>
```

ListView row number 不是 identity。Settings UI 使用隐藏 `Section` 映射排序后的视觉行，选择、编辑、保存和删除均按 `Section` 查找模型。

Text codec 将真实换行保存为 `\n`，普通反斜杠保存为 `\\`；Windows Edit 的 CRLF 在 UI 边界归一化，重复打开和保存不得 double escaping。

## 模板语法

支持的元素只有：

- `{{cursor}}`：最终 caret 位置；最多一个。不出现时默认为渲染文本末尾。
- `{{date}}`：执行时读取本机日期并展开为 `yyyy-MM-dd`；可重复。
- `{{red:（见图）}}`：渲染为红色 `（见图）`；最多一个且必须是模板最后一个元素。

未知、拼错、未闭合、嵌套、位置错误或多个 cursor/red element 均拒绝。普通单花括号不作为模板语法。普通字面量 `（见图）` 始终是黑色正文，不产生红色语义。

Parser 返回已展开文本、caret index 和红色尾段位置。`BuildReportTemplatePlan()` 生成：

```text
ReportTemplatePlan
├── RenderedText
├── PlainText
├── RedText
├── CaretLeftCount
└── RequiresColorReset
```

决策只来自渲染结果：

```text
caret 在渲染文本内部
→ 发送派生的 Left count
→ 不运行 Candidate G

caret 在文本末尾 + 存在显式红色尾段
→ 不移动 caret
→ 运行 Candidate G

caret 在文本末尾 + 纯黑正文
→ 不移动 caret
→ 不运行 Candidate G
```

当前 `;fzg` 会派生 `CaretLeftCount=4`，但这是 `{{cursor}}{{red:（见图）}}` 渲染后的结果，不是配置字段。

## 启动与 Schema 1 → 2 migration

```text
singleton established
→ resolve config path
→ config missing: create Schema 2 defaults
→ Schema 1: audit and migrate
→ Schema 2: reconcile exact old builtin defaults and missing managed keys
→ strict load and normalize
→ register features and hotstrings
```

Schema 1 migration 是唯一保留 legacy `text`、`red-reset` 和 `red-left4` 解释的路径：

- `text` 保持普通模板语义；
- `red-reset` 转换为显式红色尾标记；
- `red-left4` 按旧最终 Left 语义插入 `{{cursor}}`，已知 builtin 使用精确 mapping；
- builtin `cmx` 转换为 `cm×{{cursor}}cm`；
- 未知 Mode、重复字段/trigger、已有双花括号或无法验证的语义均阻止迁移。

迁移顺序：

1. 只读审计原文件；
2. 创建不覆盖的时间戳 backup；
3. 复制到临时文件；
4. 只重写已审计的 hotstring sections 并更新 SchemaVersion；
5. 严格读取，比较渲染文字、caret、红色范围和颜色恢复决策；
6. 验证后替换原文件；
7. final validation 失败时从 backup 恢复。

迁移失败不得产生半迁移文件，也不得用另一套 defaults 掩盖错误。升级成功后不能再使用旧 EXE 打开配置。

## Settings UI 保存

设置窗口使用与运行时相同的 template validator 和 Text codec。GUI 隐藏 section、builtin/custom 分类和内部 identity，只显示用户概念。

“插入模板元素”下拉数据定义集中在 `TemplateElementDefinitions()`；当前可插入 cursor、date 和 red element。插入使用原生 Edit selection：有选区时替换，否则在 caret 处插入，随后 caret 位于 token 后并恢复编辑框焦点。

保存前检查：

- 名称与 trigger 非空且不含换行；
- 所有 entries（包括停用项）的 trigger 不区分大小写且不重复；
- template grammar 有效；
- 原文件内容仍与窗口打开时一致；
- builtin 不能删除，custom 只能按 stable Section 明确删除。

保存使用 backup + 同目录临时文件。未修改的 hotstring section、`[Features]`、未知 sections/keys 和注释通过复制原文件保留；只重写 UI 明确修改的 section。临时与 final 均重新读取并比较目标/非目标 sections。成功后调用完整 `Reload()`。

## Update preservation

- 新版本可以补充缺失的 managed defaults，但不能覆盖已有用户值。
- 开发期 Schema 2 旧 builtin 只在 Text 与旧默认值完全一致时升级；用户修改的 builtin 和所有 custom templates 保持不变。
- 所有写入先创建 backup；失败时保留或恢复原配置。
- 应用不扫描、迁移或清理其他 EXE。

## Diagnostics 与隐私

`startup.log` 记录：

```text
AppVersion
SourceRevision
ExecutablePath
ConfigPath
```

运行时失败日志和 field diagnostics 不得包含 report text、template Text、clipboard payload、患者标识、窗口正文或 screenshot。
