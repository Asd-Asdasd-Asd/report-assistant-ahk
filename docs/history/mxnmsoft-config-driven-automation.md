# MxNMSoft 配置驱动自动化调查

本文档固定对 MxNMSoft 配置包的只读静态调查结论，并评估“已知当前配置路径”可以为后续自动化提供什么能力。原始 vendor 配置、日志、内部地址、患者或检查信息不得复制到本仓库。

## 工程结论

把当前 MxNMSoft 配置作为自动化的首选几何来源是合理的，而且通常优于 UIA 相对偏移或写死的屏幕坐标。

但这不等于“随着所有 MedEx 更新彻底自动适应”。配置能够描述窗口、图像区、面板、按钮和候选布局的几何信息；它通常不能单独证明当前活动布局、当前图像窗格、当前工具状态、弹出菜单的 runtime control ID 或当前测量值。

更准确的目标是：

> 对 MedEx 明确写入配置的布局变化自动适应；对瞬时运行状态和语义变化继续进行轻量运行时识别；对未知 Schema 或坐标不一致 fail closed。

measurement target 当前采用 **config-only geometry + window-message transport**：
vendor config 负责静态布局与跨 layout 安全点，运行时对每个 outer-frame
候选映射安全点，并要求点下 HWND 的 `GA_ROOTOWNER` 唯一回到同一 frame，
再执行 HWND/PID/process/client-rect 核验。它不要求 outer frame 包含同进程
全部临时图像顶层窗口。UIA 已从 measurement target
resolver 移除，但仍可由其他 MedEx 功能或独立诊断使用；窗口消息和现场校验
继续保留。

配置路径采用一次发现、长期复用：首次成功测量时从运行中的
`MedExNMFusion.exe` 验证 process path，并写入独立的机器级 path cache。
后续报告助手启动时从该 process path 重新派生固定相对配置路径，校验 exe
和两个配置文件仍存在，然后在没有 viewer 窗口的情况下读取配置并建立静态
plan。cache 不保存 vendor config 原文；安装路径或配置文件失效时拒绝复用。

## 目录画像

静态配置包中与自动化最相关的内容可分为：

- `MultNMSoftInfo/**/MxNMSoft*.ini`：主窗口、图像区、面板、按钮、色条和对话框的几何配置，以及部分显示和测量行为开关。
- `MultNMSoftInfo/**/MxPetCtTemp.ini`：多种显示模式下的子窗格矩形和图像类型候选模板。
- `方屏按钮配置.txt`：按分辨率配置按钮位置的维护说明。
- `SUV_Values.xml`：可能与 SUV 状态有关的候选文件，但现有样本不足以证明它是实时状态源。
- Electron/Node/ZeroMQ 文件：证明工作站存在消息传输能力，但没有证明存在可直接消费的测量协议。
- native binaries 和第三方依赖：本次不执行、不加载、不反编译，也不作为首选探索对象。

## 高价值发现

| 文件 | 已证实的发现 | 可能用途 | 可信度 | Windows 现场验证 |
| --- | --- | --- | --- | --- |
| `MultNMSoftInfo/**/MxNMSoft*.ini` | `[ShowSetting]` 包含 `FramePos*`、`ShowImagePos*`、`StudyListPos*`、多个按钮、面板、色条和状态区的矩形字段 | 建立 viewer、图像区、导航按钮和面板的命名锚点 | 高 | 需要验证坐标原点、DPI 和当前实际加载文件 |
| 多套 `MxNMSoft*.ini` | 不同分辨率或 profile 的同名字段数值不同 | 随工作站布局和分辨率选择正确几何 profile | 高 | 需要确认 MedEx 的实际 profile 选择规则 |
| `方屏按钮配置.txt` | vendor 明确要求在 `[ShowSetting]` 中按分辨率维护按钮矩形 | 支持“这些字段确实用于布局”的判断 | 高 | 需要确认当前版本是否仍读取这些字段 |
| `MxPetCtTemp.ini` | 多个 `ShowModelN` 定义窗口大小、子窗格矩形、图像类型和方向 | 计算 PET/CT/Fusion 等候选窗格位置 | 高 | 需要找到当前活动 `ShowModelN` 和缩放关系 |
| `MxNMSoft*.ini` 的显示及测量选项 | 存在 SUV、label、活动窗选择、显示模式等行为开关 | 解释工作站差异、形成能力门控和诊断信息 | 中 | 需要确认哪些字段是启动配置、哪些会实时变化 |
| `SUV_Values.xml` | 样本只有空结构且时间较旧 | 作为未来运行时写盘观察对象 | 低 | 必须观察测量前后的内容和修改时间 |
| ZeroMQ helper 和 bridge | 存在 pub/sub transport，renderer 可发送和接收消息 | 未来探索非 UI 自动化入口 | 中 | 必须抓取脱敏消息并证明有测量语义 |

以上“已证实”只表示文件中存在相应结构。字段是否由当前运行版本实际使用、何时读取，以及哪个文件是当前 profile，仍属于运行时问题。

## 已知当前配置路径后可以实现的能力

### 1. 建立稳定的命名几何层

从当前配置只读生成不可变快照，将 vendor 字段转换为应用内部的命名矩形，例如：

- `viewerFrame`
- `imageArea`
- `studyList`
- `pageUpButton`
- `pageDownButton`
- `showModeButton`
- `mainWindowModeButton`
- `mrResliceButton`
- `showModelPanel`
- `functionPanel`
- `hotkeyPanel`
- `colorBar`
- `grayBar`
- `progressArea`
- `textOutputArea`
- `statisticsDialog`

调用方只请求命名锚点，不直接读取 `PosX`、`PosY` 或散落保存屏幕坐标。这样 MedEx 配置变化时，只需几何层重新解析；hotstring、测量、截图和 viewer action 不需要分别修改。

### 2. 从候选布局计算图像子窗格

如果能够同时确定当前活动 `ShowModelN`，可用 `LowWndLeft_N`、`LowWndTop_N`、`LowWndWidth_N`、`LowWndHeight_N` 计算每个子窗格，并结合 `LowWndImageType_N`、`LowWndImageOrient_N` 等字段选择 PET、CT、Fusion 或特定方向的图像区域。

这可以支持：

- 为右键测量菜单选择可靠的图像内部点；
- 选择指定模态或方向的窗格；
- 对截图、定位、窗宽窗位、标注和比较操作提供统一锚点；
- 在不同工作站分辨率和布局模板间减少手工坐标校准。

配置文件目前证明了“有哪些候选布局”，没有证明“此刻激活的是哪一个布局”。活动布局仍需窗口消息、UIA、可观察状态、明确的用户选择或一次现场校验补足。

### 3. 扩展到 v0.6.0 之外的自动化

配置驱动锚点可能用于：

- viewer 翻页、显示模式切换和主窗口模式切换；
- 图像窗格选择、右键菜单调用和局部截图；
- 功能面板、显示模式面板、快捷键面板的定位；
- 色条、灰阶条及窗宽窗位相关交互；
- 统计对话框和输出区域的定位；
- label/SUV 工作流的前置布局判断和安全门控；
- 将“用户逐项录入坐标”简化为“程序计算锚点，用户一次确认”。

这些用途的可信度并不相同。配置中有明确矩形的区域可直接作为高可信几何候选；只有父面板矩形、没有子按钮位置的功能，仍可能需要 UIA 语义锚点或经过验证的局部偏移。

### 4. 提供跨机器诊断和能力门控

快照可以记录非敏感的：

- config path；
- file modification time 或 hash；
- screen dimensions；
- profile identity；
- required key availability；
- geometry validation result。

自动化开始前即可判断当前环境是否受支持。字段缺失、矩形越界、DPI 映射不一致或 runtime window 与配置严重不符时，应拒绝操作，而不是退回未经验证的固定坐标。

## 推荐实现边界

推荐新增独立的只读 `MxNMConfigGeometryProvider`，职责仅限于解析、规范化和验证几何信息：

```text
known config path
-> decode vendor INI
-> create immutable config snapshot
-> validate required keys and numeric ranges
-> resolve named rectangle or point
-> map config coordinates to the runtime viewer HWND
-> validate against current screen, window and client bounds
-> provide geometry to an action adapter
```

它不应：

- 修改 vendor 配置；
- 自动猜测多个配置文件中哪一个是当前文件；
- 把配置中的候选 `ShowModelN` 当成实时活动状态；
- 直接执行点击、粘贴、测量解析或报告输入；
- 在未知 Schema 或坐标变换下继续操作。

建议的锚点优先级：

1. 当前配置中的命名矩形 + runtime viewer HWND 校验；
2. 当前布局模板中的子窗格矩形 + 已验证的活动布局状态；
3. UIA 语义锚点 + 配置提供的相对区域；
4. 用户现场确认过的集中 profile；
5. 未经验证的固定屏幕坐标不作为生产默认路径。

这里 UIA 不再承担整个布局定位，而是只补足控件语义或运行状态；固定坐标也只作为明确验证过的 fallback。这样能显著降低脆弱性，同时保留必要的安全边界。

## 不能从配置证明的事项

即使当前配置路径已知，下列事项仍不能由静态文件单独证明：

- MedEx 是否正在使用该文件，以及是在启动时读取还是运行时重读；
- `FramePos*`、`ShowImagePos*` 等字段相对屏幕、主窗口还是 client area；
- Windows DPI scaling、标题栏和多显示器坐标如何参与转换；
- 当前活动 `ShowModelN`、当前活动子窗格和当前图像类型；
- 右键菜单是否能在后台窗口打开；
- context-menu command ID 是否每次动态变化；
- caret 在焦点切换后的保持行为；
- 当前是否存在 line measurement 或 SUVMax 标注；
- `SUV_Values.xml` 是否实时写盘；
- ZeroMQ 是否传递可消费的测量值；
- MedEx 升级后字段名、Schema、坐标语义和读取规则是否保持兼容。

因此，“随着 MedEx 更新自适应”只在 vendor 继续维护兼容配置语义时成立。Schema 或控件语义变化仍需显式检测和一次新的现场验证。

## 与 v0.6.0 的关系

v0.6.0 的 `ContextMeasurementProvider` 可以继续只依赖一个 image-point resolver。当前配置路径和坐标语义通过现场验证后，优先由 `MxNMConfigGeometryProvider` 提供可靠图像点；在验证完成前，现有集中 screen-coordinate profile 仍是允许的首版方案。

这不会改变测量链路的其他安全要求：后台窗口消息、动态 popup 识别、精确菜单文字、runtime control ID、剪贴板事务、报告 HWND 检查和 false-negative 策略仍然必须保留。

当前工作站确认的首版路径关系以运行中的 `MedExNMFusion.exe` 所在目录为根：

```text
<viewerDir>\MultNMSoftInfo\1\MxNMSoft.ini
<viewerDir>\MultNMSoftInfo\1\MxPetCtTemp.ini
```

实现不得写死 `C:\MedEx`，不得递归扫描并猜测多个 profile。首个 config-first checkpoint 先进行只读 schema audit，只输出 `[ShowSetting]` 中 `FramePos*` / `ShowImagePos*` 和 `MxPetCtTemp.ini` 中 `ShowModel*` / `LowWnd*` 的 numeric entries。UIA 不参与该 checkpoint；`MxPetCtTemp.ini` 只形成候选 `ShowModelN` 快照，不推断当前活动布局。

2026-07-24 首轮 Windows audit 已确认：

- 运行时进程目录能够唯一解析上述两个配置文件，root relation、文件存在性和 SHA-256 均通过；
- 首轮 audit 只返回 `FramePosX=1000`、`FramePosY=0`、`ShowImagePosX=340`、`ShowImagePosY=56`；随后现场检查发现这是 audit whitelist 漏掉了独立的 `ShowImageWidth` / `ShowImageHeight`，不是 vendor 配置缺少宽高；
- 当前现场确认的完整逻辑主图区为 `ShowImagePosX=340`、`ShowImagePosY=56`、`ShowImageWidth=750`、`ShowImageHeight=940`，这四个字段共同控制主图区位置和大小；
- 当前 `MxPetCtTemp.ini` 包含 30 个 `ShowModelN` section；其中 `ShowModelGroup` 声明 `ShowModelSize=21`、`ShowModelPageSize=2`，但没有足以证明当前 active model 的状态字段；
- 候选布局原点均为 `(0,0)`，总体 extents 包含约 `750×945`、`800×600`、`1000×996` 等多组值，因此不得把任一候选直接当作当前运行时图像矩形；
- 首轮结果证明了 config discovery 和部分 schema shape，但没有证明逻辑主图区如何映射到 runtime screen coordinates。

原计划通过 `WinGetList()` 顺序编号显示 screen/window/client 候选标签；Windows 发现多次执行时标签位置不稳定，因此该方案已撤销，编号和视觉位置不得作为证据。

同一工作站上的 UIA Viewer 能把主图区呈现为 `Pane(50033)`，现场选中元素的 `BoundingRectangle=[l=2566,t=80,r=3991,b=1440]`，`Name`、`AccessKey` 等语义属性不存在。这个结果证明 UIA 可以读取准确的 runtime rectangle，但仅凭 `ControlType=Pane` 尚不能证明程序能够从多个 pane 中唯一重找同一元素。后续应采用双证据：

```text
config complete logical image rectangle
-> UIA Pane candidates under the validated viewer
-> require one geometry-valid runtime rectangle
-> validate containment, visibility and minimum size
-> choose an inset image point
```

配置是稳定的逻辑布局来源；UIA 是实际屏幕矩形来源。两者不一致或 UIA 候选不唯一时必须 fail closed。

修正版 Windows audit 进一步确认当前 logical frame 为
`FramePos=(1000,0)`、`FrameSize=1348×1000`，同进程暴露 10 个可见 window；唯一包含其余 window 的 runtime frame 为
`(1920,0,2561,1440)`。`FramePos` 因此不是可与 physical screen origin
直接比较的坐标，旧的 exact-position match 返回 0 属于错误判据，现已移除。
该 containing-frame 结论只作为历史 audit 证据：后续多机现场发现主图区
激活会新增第 11 个同进程顶层图像窗口，使 containing-frame 候选从 1 变为
0。production measurement resolver 已改用映射点的 root-owner 一致性，不再
依赖“包含全部窗口”。

在 runtime frame 内分别按 X/Y 比例映射逻辑主图区，得到约
`[2566,81,3991,1434]`。它与人工选中的 UIA Pane
`[2566,80,3991,1440]` 左、上、右边界基本重合，底边相差约 6 px。
这支持独立 X/Y mapping，但差值只能作为 clipping/rounding tolerance，
不得写成固定 `+6` 补偿。

独立 field harness `tests/windows/mxnm_uia_image_region_audit.ahk`
会在所有同进程 window 的 UIA root/descendants 中只读取
`ControlType`、`BoundingRectangle` 和 `IsOffscreen`，不读取 Name/Text。
它以 config-derived rectangle 的 1% bounded tolerance 过滤 `Pane`，
且只在候选数恰好为 1 时返回 `READY_FOR_FIELD_VALIDATION`。

2026-07-24 Windows field validation 已通过：

- config audit 连续得到唯一 runtime frame 和
  `MappedImageRect=[2566,81,3991,1434]`；
- UIA audit 在 9 个去重后的 `Pane` 中恰好得到 1 个 geometry match；
- 相同布局连续三次均返回
  `UiaCandidateRect=[2566,80,3991,1440]`；
- 三次均为 `READY_FOR_FIELD_VALIDATION`，未读取 UIA Name/Text。

因此 config + UIA 双证据的“主图区矩形解析”checkpoint 已完成。
这只授权下一阶段生成安全 image point；尚未证明 context-menu transport
使用新 resolver 后仍保持 foreground、mouse、clipboard 和 popup invariants。

自动目标 field checkpoint 已实现但尚待 Windows 验证。它只使用
`ShowModelGroup.ShowModelSize` 声明的 `ShowModel1..N`，不会把额外 section
猜成当前 layout，也不会识别 active model。每个声明 model 的 pane geometry
先裁剪到主图区；vendor 边缘溢出只允许在主图区长边 1.5% 且最多 16 px
的双重上限内裁剪。该上限覆盖新工作站 `ShowImageHeight=938`、声明 pane
底边 `950` 的 12 px 差异；超过上限仍 fail closed。

安全点从所有 pane 中心候选里选择：候选必须严格落在每一个声明 layout
的某个 pane 内，并最大化跨 layout 的最小边缘距离；平局选择更小 Y，
再选择更小 X。最小距离必须达到主图区短边的 5%，否则 fail closed。
当前现场配置声明 21 个 model、产生 185 个去重候选，预期 logical point
为 `(63,95)`，最小距离 `62`，高于要求的 `37.5`；映射到已验证 UIA
rectangle 后预期 screen point 为 `(2686,217)`。这些值是算法结果，
不得作为 profile 常量写死。

上述 config/layout resolver 现保留为 field diagnostic，不再作为 production
右键菜单准入门槛。production 使用独立 `ViewerSession`：首次从当前 Viewer
PID/root 下宽松收集可见、非空且在屏幕内的 surface，class、面积、鼠标位置
和层级只参与候选评分，不要求固定 `#32770`、直接 parent、唯一 frame、唯一
surface 或工具栏 schema。候选有多个时按分数依次尝试，只有所有候选都无法
产生有效点才失败。

discovery 先按 `(65%,35%)`、四个偏角位置尝试，首个通过 `WindowFromPoint`、
PID/root-owner 和 client bounds 的点立即采用；五点均失败才进入较密集扫描。
成功后缓存 root HWND、surface HWND 和 normalized point。后续热键只复核
缓存 HWND、PID/root-owner、process path、可见状态和一个重算后的点；rect
变化本身不触发失败。fast validation 失败时只清除缓存、discovery 一次并
重试一次。右键后仍保留同 PID popup、精确菜单文字、当前 runtime ID、
client bounds 与 clipboard freshness 校验。production 不引入 UIA。

首次 Windows automatic-target transport 返回 `FOUND`，证明在非目标 pane
保持活动且只有该 pane 存在标注时，复制命令仍能取得当前活动/全局 SUVMax；
首次结果中的 `MouseUnchanged=false` 经静止鼠标复跑后变为 `true`；
`TargetActionMatchesProviderViewer`、foreground、mouse、clipboard、popup
和 runtime ID 因此全部通过。F10/F11 分别只比较各自调用开始与结束的鼠标
位置，不要求操作者在两次测试之间持续保持鼠标静止。

复跑时 `UiaPaneCount` 从 9 变为 10，但 `UiaGeometryMatchCount` 始终为 1。
总 Pane 数受运行时 UIA tree 变化影响，只能作为诊断字段；唯一 geometry
match 才是执行门槛。

关闭 `MedExNMFusion.exe` 后，field harness 返回
`CONFIG_GEOMETRY_UNAVAILABLE / VIEWER_NOT_FOUND`，`MeasurementInvoked=false`；
clipboard、popup 和 command 均不可达，foreground/mouse 保持不变。
至此 field-only automatic target checkpoint 的成功路径、pane semantics
和 viewer-missing fail-closed 均通过 Windows 验证。

`MxNMMeasurementTargetResolver` 的 field checkpoint 已完成；v0.6.0
production candidate 现由独立 `MxNMMeasurementProvider` adapter 接入
`main.ahk`、generated release 和含 `{{suvmax}}` 的 hotstrings。底层
`ContextMeasurementProvider` 默认路径保持通用，不直接依赖 config/UIA
resolver。
resolver 会用 `WindowFromPoint` 和 process/PID/client bounds 重新验证
action HWND；field harness 再确认该 HWND 与 provider 实际选择的 viewer
一致。

## 下一步最小验证清单

1. 运行纯逻辑 Windows regression，确认 layout schema、clipping、maximin、tie-break 和 5% clearance gate。
2. 用 field harness 的 `Ctrl+Alt+F10` 预览自动点，再用 `Ctrl+Alt+F11` 执行一次自动 SUVMax。
3. 在非自动目标 pane 保持活动状态且只让该 pane 有标注：若自动点仍返回 `FOUND`，进入下一 provider-integration checkpoint；若返回 `NOT_ANNOTATED` 而手动活动点为 `FOUND`，判定 command 为 point-local，先实现 active-pane resolver。
3. 切换两个显示布局，观察 MedEx 读取或写入了什么状态，并确认如何得到当前活动 `ShowModelN`。
4. 在至少两个工作站 profile 上验证同一命名锚点是否落入预期控件或图像区。
5. 对一个按钮和一个图像内部点分别验证后台窗口消息，确认几何正确不等于动作一定可用。
6. 观察 SUV 标注前后 `SUV_Values.xml` 和 ZeroMQ 的脱敏变化；无变化即停止把它们当作近期实现依赖。
