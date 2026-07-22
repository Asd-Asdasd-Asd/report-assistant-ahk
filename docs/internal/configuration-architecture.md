# v0.5.0 用户配置架构

## 决策摘要

v0.5.0 采用外部 INI 文件作为普通用户支持的配置格式。运行时配置目录为：

```text
%LocalAppData%\MedExReportAssistant\
├── config.ini
├── backups\
│   └── config-YYYYMMDD-HHMMSS.ini
└── logs\
```

配置不得放在 executable 同目录作为唯一来源，也不得编译进 executable。替换或升级应用文件时不能覆盖已有配置值；新增的 managed defaults 可以在唯一备份、临时副本写入和重新验证后补入。

选择 INI 的原因：

- AHK v2 原生提供 `IniRead()` / `IniWrite()`，不需要引入或维护第三方 JSON parser。
- 对当前单行 trigger、replacement、hotkey 和 Boolean 配置足够直观。
- 非技术用户在维护者指导下可以查看，未来 GUI 也能读写同一 normalized model。
- `ConfigVersion` 和稳定 feature IDs 可以支持显式迁移。
- v0.5.0 内测阶段减少 parser、escaping 和打包依赖风险。

没有选择 JSON 的主要原因不是数据模型不适合，而是 AHK v2 没有内置 JSON parser。未来若 GUI 或嵌套配置复杂度显著增加，可以在版本化 migration 后切换，不能让 feature modules 同时读取两种格式。

INI 的限制必须明确：v0.5.0 replacement 只支持单行文字；不承诺保留值首尾空格；复杂换行、富文本或嵌套对象不进入首版配置。普通用户仍不需要编辑 AHK source。

## Centralized load flow

唯一受支持的入口应为：

```text
Load defaults
→ Read user config
→ Parse typed values
→ Validate
→ Migrate if required
→ Resolve collisions
→ Return normalized config
```

建议模块边界：

```text
src/config_defaults.ahk   ; compiled safe defaults and stable IDs
src/config_loader.ahk     ; locate/read/parse INI
src/config_validator.ahk  ; type, range, trigger and collision validation
src/config_migrations.ahk ; ConfigVersion migrations
src/runtime_registry.ahk  ; register configured Hotkey()/Hotstring() callbacks
```

业务模块只能接收 normalized config 或通过单一 `GetConfig()` read-only accessor 读取。不得在 `hotstrings.ahk`、`report_editor.ahk`、MedEx adapter 等 feature modules 中散落直接 `IniRead()`。

## Proposed INI structure

```ini
[General]
ConfigVersion=1

[Features]
MedEx.Enabled=true
MedEx.ColorReset.Enabled=true
Diagnostics.Enabled=true

[Hotkeys]
EmergencySuspend=^!Esc
EmergencyExit=^!q

[BuiltInHotstringTriggers]
RedFigure=;red
UptakeIncreased=;fzg
UptakeNotIncreased=;fwj
UptakeDecreased=;fjd
Dimensions=;cmx

[BuiltInHotstringReplacements]
RedFigure=（见图）
UptakeIncreased=放射性摄取增高，SUVmax约
UptakeNotIncreased=放射性摄取未见明显增高
UptakeDecreased=放射性摄取降低
Dimensions=cm×cm

[UserHotstring.001]
Enabled=false
Trigger=;example
Replacement=示例文字
Options=*?

[UserHotstring.002]
Enabled=false
Trigger=
Replacement=
Options=*?
```

不能把 `;trigger` 直接用作 INI key，因为行首分号可能被解析为注释。用户自定义项必须使用编号 section 或稳定 ID，将 `Trigger` 作为 value 保存。

## Normalized config model

读取完成后返回单一对象，概念结构如下：

```text
Config
├── version
├── paths
│   ├── configFile
│   └── logDirectory
├── features
│   ├── medExEnabled
│   ├── medExColorResetEnabled
│   └── diagnosticsEnabled
├── hotkeys
│   ├── emergencySuspend
│   └── emergencyExit
├── builtInHotstrings[]
│   ├── id
│   ├── enabled
│   ├── trigger
│   ├── replacement
│   ├── options
│   └── handlerId
└── userHotstrings[]
    ├── id
    ├── enabled
    ├── trigger
    ├── replacement
    └── options
```

Built-in replacement 与 handler 必须分开。例如 `UptakeIncreased` 仍需要在红字插入成功后执行特定 cursor movement，不能把所有 built-ins 降级成简单 text-to-text map。

## Validation and safe defaults

启动时至少执行以下校验：

- `ConfigVersion` 是受支持的正整数。
- Boolean 只接受明确白名单，例如 `true/false`、`1/0`。
- Hotkey syntax 可以被 AHK v2 `Hotkey()` 注册；注册失败时不使整个应用崩溃。
- Hotstring trigger 非空、长度受限、不包含 CR/LF/NUL。
- Replacement 长度受限、不包含 NUL；v0.5.0 拒绝 multiline。
- Options 只允许受支持白名单，不允许用户注入任意 AHK code。
- Built-in 与 user-defined triggers 之间不能重复。
- 两个 hotkeys 之间不能重复；不能覆盖由应用保留的 emergency controls，除非未来提供明确的安全替代策略。
- MedEx executable name、比例和 timeout 使用安全范围。

错误处理采用每项 fail-safe，而不是整份配置 all-or-nothing：

- 配置文件不存在：使用 compiled safe defaults，可选择首次复制一个 user template。
- 某个 built-in trigger 无效：该项回退到对应默认值并记录非敏感 warning。
- 某个 user-defined item 无效或冲突：只禁用该项并记录 section ID 和 reason，不记录 replacement text。
- `ConfigVersion` 高于程序支持版本：不得猜测解析；使用 safe defaults，明确提示 config incompatible，且不覆盖原文件。
- 解析异常：使用 safe defaults，保留原文件，避免自动写坏。

## Migration policy

每个发布版本声明 `SupportedConfigVersion`。迁移步骤必须是顺序函数，例如：

```text
MigrateV1ToV2(config)
MigrateV2ToV3(config)
```

迁移建议：

1. 读取原始文件并保留未知 sections/keys。
2. 在 `backups` 目录创建带时间戳且不覆盖已有文件的备份。
3. 在内存中迁移并重新验证。
4. 只有验证成功才写入临时文件并替换目标文件。
5. 迁移失败时继续使用能够安全解释的 defaults，并保留原文件供诊断。

当前 `SchemaVersion=1` 对新增可选项采用 additive reconciliation：只补缺失的 managed defaults。只有不兼容格式变化才提升版本并增加顺序 migration；future-version 继续 fail closed。

## Runtime registration

硬编码 label hotstrings 不能满足动态 trigger。v0.5.0 应通过 AHK v2 的 `Hotstring()` 和 `Hotkey()` functions 注册 normalized config 中的 callbacks。

注册过程需要：

- 先完成全部 validation 和 collision detection；
- 使用 stable handler IDs 映射到已知 functions；
- 用户 replacement 只作为 data 传递，绝不当作 AHK code 执行；
- 记录成功/禁用的 item IDs，不记录 replacement content；
- 在单次启动中保持确定的注册顺序。

## MedEx-specific settings

首版至少提供：

```ini
[Features]
MedEx.Enabled=true
MedEx.ColorReset.Enabled=true
Diagnostics.Enabled=true
```

更细的 V1 geometry/timing 可以先作为 validated defaults，不必全部暴露给普通用户。若内测显示工作站差异确实需要调整，再加入专门 section：

```ini
[MedExColorReset]
LayoutProfile=medex-0.0.1-baseline
ColorArrowOffsetX=143
ColorArrowOffsetY=0
MenuOpenTimeoutMs=500
MenuPollIntervalMs=25
MaxRetries=1
```

首个内测版本可以把 layout profile 保持为受版本控制的 adapter profile，而不向普通用户开放位置校准。若后续开放 override，上述数值必须限制范围；错误配置不得导致 blind clicks。旧 `ArrowHorizontalRatio=0.337` 属于已废弃的双锚点模型，不再是生产配置候选。

## Diagnostics

建议日志路径：

```text
%LocalAppData%\MedExReportAssistant\logs\medex-report-assistant.log
```

日志事件使用 stable keys：

```text
timestamp
appVersion
action
resultCode
processName
layoutProfileName
regionAnchorRect
fontSizeRect
fontSizeMatchedName
optionalRightAnchorRect
colorArrowOffsetX
colorArrowOffsetY
calculatedPoint
elapsedMs
retryCount
medExVersion
```

不得记录 report text、hotstring replacement、clipboard payload、患者标识、窗口正文或 screenshot。M1 field debug 不显示任何提示，只写 clipboard/log/file；未来 ordinary runtime 是否采用非模态提示需另行验证其不会干扰 MedEx focus 和 insertion state。

## Update preservation

- Executable 和 source release 可以放在由维护者管理的版本目录。
- 用户配置固定放在 `%LocalAppData%\MedExReportAssistant\config.ini`。
- 打包脚本不得把真实 user config 包入 executable。
- 更新过程只替换 app artifact，不删除配置目录或覆盖已有配置值。
- release 可以通过 managed defaults 安全补充缺失项，但不能重建或整体覆盖已有 `config.ini`。

## Advanced-user extension boundary

v0.5.0 不需要支持可执行的 user AHK extension file。若未来保留该能力，必须放在与 `config.ini` 不同的显式 advanced path，并标明：

- 不属于普通用户支持路径；
- 可以执行任意本机代码；
- 不自动加载，必须显式 opt-in；
- 不能用来绕过正常 trigger/replacement config。

普通用户定义 custom hotstrings 的唯一正常路径是外部配置，不能要求编辑 executable 或 `src/*.ahk`。
