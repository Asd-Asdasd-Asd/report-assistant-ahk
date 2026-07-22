# MxNMSoft 配置驱动自动化调查

本文档固定对 MxNMSoft 配置包的只读静态调查结论，并评估“已知当前配置路径”可以为后续自动化提供什么能力。原始 vendor 配置、日志、内部地址、患者或检查信息不得复制到本仓库。

## 工程结论

把当前 MxNMSoft 配置作为自动化的首选几何来源是合理的，而且通常优于 UIA 相对偏移或写死的屏幕坐标。

但这不等于“随着所有 MedEx 更新彻底自动适应”。配置能够描述窗口、图像区、面板、按钮和候选布局的几何信息；它通常不能单独证明当前活动布局、当前图像窗格、当前工具状态、弹出菜单的 runtime control ID 或当前测量值。

更准确的目标是：

> 对 MedEx 明确写入配置的布局变化自动适应；对瞬时运行状态和语义变化继续进行轻量运行时识别；对未知 Schema 或坐标不一致 fail closed。

因此推荐的长期路线是 **config-first hybrid automation**，而不是完全移除 UIA、窗口消息或现场校验。

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

## 下一步最小验证清单

1. 用 Windows 文件读取监控确认当前运行版本实际读取的 `MxNMSoft*.ini` 和 `MxPetCtTemp.ini` 路径。
2. 在 viewer 上绘制或记录计算矩形，验证 `FramePos*`、`ShowImagePos*` 的坐标原点、DPI 和多显示器映射。
3. 切换两个显示布局，观察 MedEx 读取或写入了什么状态，并确认如何得到当前活动 `ShowModelN`。
4. 在至少两个工作站 profile 上验证同一命名锚点是否落入预期控件或图像区。
5. 对一个按钮和一个图像内部点分别验证后台窗口消息，确认几何正确不等于动作一定可用。
6. 观察 SUV 标注前后 `SUV_Values.xml` 和 ZeroMQ 的脱敏变化；无变化即停止把它们当作近期实现依赖。
