# Viewer 跨机器自适应改造 checkpoints

本轮工作在 `feat/viewer-adaptive-runtime` 分支进行。每个 checkpoint 都必须
完成代码、静态验证和 Windows Viewer 现场验证；现场结论未通过前不得进入
下一 checkpoint。未知结构始终 fail closed，不使用未经验证的绝对坐标。

跨机器现场脚本默认同时生成 standalone 单文件版本，便于内网发布和验证后
删除。只有依赖大型 UIA 库、二进制资源，或合并后会显著增加文件大小和审查
成本时，才发布保留相对目录的依赖包；该例外必须在 checkpoint 交付说明中
列出依赖和代价。

目标机器没有 AutoHotkey 时，在一台安装了 AutoHotkey v2 与 Ahk2Exe 的
Windows 构建机双击
`tools\field-testing\Build Viewer Checkpoint EXE.cmd`。它只编译只读
standalone harness，输出
`..\report-assistant-build\viewer-checkpoint\publish\MxNM-Viewer-Checkpoint1.exe`
和 SHA-256 文件；其他机器只需要复制该 EXE。生成的 standalone AHK 也位于
外部 build root，构建不会修改 checkout。Checkpoint 1 不嵌入正式
“麦旋风.exe”，避免触碰正式配置、singleton、托盘和功能状态。

## Checkpoint 1：Vendor profile 与 HWND 只读审计

### 实现范围

- 从运行中的 `MedExNMFusion.exe` 唯一解析安装目录。
- 只枚举 `MultNMSoftInfo` 根目录及其直接子目录，不递归扫描安装目录。
- 列出同时具有 `MxNMSoft*.ini` 和 `MxPetCtTemp.ini` 的 profile 候选。
- 记录候选配置 hash、frame/image 几何、`SCBtnPad`、command rows/columns。
- 只读输出名称包含 resolution、screen、display、monitor、profile、DPI、
  scale 等关键词的 Vendor 字段；非简单值只输出 `<present>`。
- 自动采集当前算法预测的三个工具点和测量点的 native HWND ancestor chain。
- 用户依次指向箭头、长度、3D SUV 和图像区，采集真实点的 HWND chain。
- 枚举同进程中 control ID 为 `21043`、`21048`、`21193` 的控件。

本 checkpoint 不点击、不发窗口消息、不移动鼠标、不读取窗口文字或患者信息。

### Windows 现场验证

1. 启动 Viewer 并保持全屏日常布局。
2. 运行 `tests/windows/mxnm_viewer_adaptive_checkpoint1.ahk`。
   内网发布优先使用单文件
   `tests/windows/generated/mxnm_viewer_adaptive_checkpoint1_standalone.ahk`，
   目标机器只需该文件和 AutoHotkey v2。
   目标机器没有 AutoHotkey 时，发布
   `..\report-assistant-build\viewer-checkpoint\publish\MxNM-Viewer-Checkpoint1.exe`。
3. 按 `Ctrl+Alt+F6` 执行自动只读审计。
4. 按提示把鼠标依次放在箭头、长度测量、3D SUV 按钮中心和任意有效图像
   内部；每次按 `Ctrl+Alt+F7`，不要点击。
5. 确认 Viewer 前台、工具状态、鼠标位置均未被程序改变。
6. 回传
   `%TEMP%\MedExAHK\mxnm_viewer_adaptive_checkpoint1.txt`。
7. 最好在一台原验证机器和至少两台失败机器上各执行一次。

### 通过条件

- 所有机器均为 `InteractionMode=READ_ONLY`、
  `AutomaticForegroundUnchanged=true`、`AutomaticMouseUnchanged=true`、
  `ManualCaptureComplete=true`。
- 能明确判断 Vendor 当前 profile 的选择证据；如果没有 selector，必须证明
  runtime 是否能够唯一匹配一个候选，不能猜测目录编号。
- 能明确判断三个 command ID 是否作为 native HWND 存在，以及真实按钮与
  当前预测点之间的结构差异。
- 能明确判断图像实际 point HWND、父链和当前错误选取的 root HWND 之间的差异。

### 2026-07-27 多机结果与退出结论

首台原验证环境完成只读采集：

- `ProfileAuditState=READY`，发现三个候选。当前生产路径
  `1/MxNMSoft.ini` 为 `Frame=1348×1000`、`Image=750×940`、
  `SCBtnPad=(280,360)`；另外两个候选分别携带 `1280×1024` 和
  `1920×1040` 的 `ScreenWidth/ScreenHeight` 提示。候选文件名和 screen
  字段尚不足以证明 Vendor 的实时选择规则。
- 三个预测工具点与用户实际指向点命中相同的 visible `Button`，control ID
  分别为 `21043`、`21048`、`21193`。同进程还存在一套相同 ID 的 hidden
  controls，因此 Checkpoint 2 必须同时要求 visible/enabled、Vendor 工具
  区域和几何顺序，不能按 ID 全局取第一个。
- 工具按钮 parent 是独立 `#32770` 工具面板，root owner 是外层 Viewer。
- 预测和人工图像点均命中独立 `#32770` 图像窗口；它由外层 Viewer owned，
  不是外层 Viewer 的 child。measurement resolver 必须保留 point HWND、
  parent 和 root-owner 关系。
- foreground 和 mouse invariants 均通过。

第二台原本快捷键失败的机器完成同版只读采集：

- 仍由生产路径 `1/MxNMSoft.ini` 提供与 runtime 一致的 frame、image 和
  `SCBtnPad`；外层 Viewer、工具面板和图像窗口层级与首台机器相同。
- 旧算法预测箭头中心 `(2469,649)`，实际命中相邻 `21044`；预测长度中心
  `(2469,725)`，实际命中相邻 `21078`。真正的 `21043` 和 `21048` 分别位于
  `y=600..637` 和 `y=682..719`。`21193` 仅因预测点仍落在按钮边缘而偶然
  命中。
- 这证明跨机器失败不是 Vendor profile 或外层分辨率选择错误，而是工具面板
  内部首行位置、按钮高度和行距并不固定。生产代码不得再依赖固定前三行、
  `38 px` pitch 或推算中心点。
- 三个目标 ID 在两台机器均存在唯一的 visible/enabled 原生 `Button` 组合，
  具有相同直接父面板，且实际纵向顺序与 Vendor command row 一致。hidden
  重复控件可通过可见性排除。
- foreground、mouse 和只读约束在两台机器均通过。

Checkpoint 1 通过，可以进入 Checkpoint 2。现有证据支持继续采用 Vendor
生产 profile 根路径 `MultNMSoftInfo\1`，但仅把 `SCBtnPadPos` 作为 runtime
工具面板身份锚点；按钮位置必须从实际 native controls 读取。

### 2026-07-27 Checkpoint 2 激活层级补充证据

第二台机器在主图区获得激活后，Viewer 顶层窗口数由 `10` 增至 `11`，
`RuntimeFrameCandidateCount` 由 `1` 变为 `0`；点击主图区以外的位置后恢复。
三个目标按钮 HWND、父面板和实际矩形在两种状态下不变。该结果证明：

- 额外图像层不完全包含在外层 Viewer frame 内，使共享的“一个窗口包含所有
  Viewer 顶层窗口”规则失败；
- 这不是按钮消失、鼠标 hover 或 command ID 变化；
- 工具 resolver 应从已经完成 ID、可见性、顺序和面板原点校验的按钮父面板
  沿 `GA_ROOTOWNER` 反向锁定外层 Viewer，而不要求它包含无关图像层；
- measurement target 同时返回 `RUNTIME_FRAME_NOT_UNIQUE`，但其处理仍属于
  Checkpoint 3，本 checkpoint 不提前修改。

## Checkpoint 2：自适应工具按钮 resolver

### 实现范围

- 使用 Checkpoint 1 两台机器均验证的 Vendor 生产 profile
  `MultNMSoftInfo\1`，并继续校验配置路径、hash 与 runtime frame；若未来
  Vendor 暴露明确的实时 selector，再单独替换 profile 选择层。
- Vendor 配置只提供工具区域、row/column 和 command ID。
- runtime 在受限区域内枚举同 PID、visible/enabled 的 native controls。
- 目标 command ID 必须唯一，几何顺序必须与 Vendor row/column 一致。
- 从唯一有效工具父面板沿 `GA_ROOTOWNER` 反向解析 outer frame；不再要求
  outer frame 包含进程内所有临时/图像顶层窗口。
- 向真实控件的直接父窗口投递 bounded `WM_COMMAND / BN_CLICKED`。
- 删除固定按钮中心、固定 `38 px` pitch 和固定前三行的生产依赖。
- 每次 Viewer session 或配置 hash 变化后重新解析；证据不唯一时禁用该项。

### Windows 现场验证

1. 在 Windows 构建机拉取本 branch，双击仓库根目录 `Build EXE.cmd`。构建
   成功后，目标机器只需复制
   `..\report-assistant-build\publish\麦旋风.exe`；不需要 AutoHotkey、
   Python、源码或其他依赖。
2. 在设置中启用箭头、长度和 3D SUV 三个 Viewer 快捷键。先在原验证机器和
   Checkpoint 1 的失败机器上测试，再补至少一台结构不同的机器。
3. 每项连续执行 10 次，确认一次按键只改变一次工具状态；记录为
   `arrow=n/10, length=n/10, suv3d=n/10`，并注明是否出现“Viewer 工具按钮
   布局校验失败”。
4. 重新启动 Viewer 后复测三项各一次；若 Viewer 支持切换布局，再切换一个
   布局各测一次。记录分辨率、缩放、Viewer 所在屏幕和是否多屏。
5. 在报告窗口前台各触发一次，确认 Viewer 工具被选择且报告焦点不改变；在
   无关程序前台各触发一次，确认不触发也不吞键。
6. 本 checkpoint 不验收 SUV/尺寸自动读取；它们仍保持旧实现，统一留到
   Checkpoint 3。

### 通过条件

- 至少三台结构不同的机器上三个工具均通过。
- 不依赖绝对 screen point；窗口移动或重新启动 Viewer 后仍能重新解析。
- 缺失、重复或隐藏 command control 时明确 fail closed，不能尝试坐标点击。

## Checkpoint 3：自适应测量与用户自校验兜底

### 2026-07-28 原工作站最终构建回归

v0.6.2 最终构建在原工作站返回 `BUTTON_LAYOUT_INVALID`。扩展后的 field
日志证明主工具面板三个目标 ID 均唯一、visible/enabled、顺序正确，
`layoutValid=true`，但面板的 `GA_ROOTOWNER` 未出现在可见 Viewer window
snapshot 中，因 `frameFound=false` 被错误淘汰。

修复保留原 control-set、PID、进程名、完整路径、root-owner、panel origin
和几何校验；仅在 snapshot lookup 失败时，允许对同一已验证 Viewer PID 的
真正 root owner 直接读取 window/client rect。该补丁需要在原工作站使用
正式 EXE 复测三项工具，并确认 field 日志为
`snapshotFrameFound=false`、`frameFound=true`、`anchorValid=true`。

### Checkpoint 3A：主图区激活状态的 outer frame

Checkpoint 2 现场确认工具按钮修复通过，但右键清除在主图区激活状态仍返回
target unavailable。此前成对日志已经证明旧 measurement resolver 因第 11 个
同进程图像顶层窗口得到零个 containing-frame 候选。

3A 不取消校验。新规则对每个 outer-frame 候选分别映射 Vendor 图像安全点，
只接受该点实际 HWND 的 `GA_ROOTOWNER` 唯一回到同一候选的结果；随后继续
校验 action HWND 的进程名、PID、root owner 和 client bounds。这样临时图像
层可以成为实际右键接收窗口，但它必须仍属于唯一 outer Viewer。

现场先验证：

1. 主图区激活并保持旧版持续失败状态，分别执行清除、SUVMax 和尺寸。
2. 点击 Viewer 通用位置恢复旧状态后重复。
3. 原机器执行同样回归。
4. 每条路径记录是否出现一次菜单、结果、foreground/mouse/clipboard，以及
   `RuntimeFrameCandidateCount`。

3A 通过只证明当前多顶层窗口问题已解决；不同机器若仍存在右键接收 ancestor
差异，再继续执行下面的自动 receiver 与用户自校验范围。

第二轮主图区证据确认人工图像点仍命中 `#32770` 图像 HWND，且
`rootOwnerHwnd` 正确回到与工具面板相同的 outer Viewer。为消除清除链路与
测量链路之间的重复解析，target resolver 在完成 point HWND、root owner、
PID 和 client bounds 校验时同时返回 `actionClientPoint`；清除直接复用该
点，不再单独调用一次 `ScreenToClient`。失败提示也拆分为 target resolution
和 client-point validation 两个阶段。

第三轮完整 EXE 提示进一步确认主图区激活时存在两个通过“映射点 root owner
回到自身”校验的 frame 候选。resolver 不取消唯一性，也不按枚举顺序选择：
它统计每个候选作为 `GA_ROOTOWNER` 所拥有的去重 Viewer window family，
只接受 owner-family 数量唯一且严格最大的候选；多候选时最大 family 至少
包含两个窗口。若两套结构得分相同则继续 fail closed。

### 实现范围

- Vendor profile、`ShowImage*`、`ShowModelN/LowWnd*` 继续提供逻辑图像区和
  跨布局安全点。
- 保留 `WindowFromPoint` 得到的 point HWND 和完整 parent chain，不再无条件
  提升到 root。
- 根据 Checkpoint 1 的多机证据自动选择右键消息接收层级。
- popup 以同 PID、owner/parent 关系、精确命令文字和有效 runtime control ID
  共同确认；`#32770` 仅作为候选，不作为唯一类。
- 自动证据不唯一时启动一次性校验：用户只需指向图像区；程序经确认后向一个
  候选接收 HWND 发送一次右键，只验证并关闭菜单，不执行复制命令。
- 保存的是 ancestor/class/geometry 选择规则，不保存 HWND 或绝对坐标。
- profile 绑定 Viewer build、Vendor 配置 hash、DPI/scaling、monitor topology
  和 runtime class signature；任一关键证据变化即失效。

### Windows 现场验证

1. 在原机器及 SUV/尺寸成功、失败的不同机器上分别运行自动预检。
2. 自动通过的机器连续读取 SUVMax 和尺寸各 10 次，检查值、尾延迟、前台、
   鼠标和剪贴板恢复。
3. 自动无法唯一证明的机器执行一次用户校验，再重复上述测试。
4. 切换至少两个 Viewer layout，重新启动 Viewer，并改变非关键窗口状态复测。
5. 修改/替换测试配置副本或改变 monitor topology，确认旧 profile 自动失效。
6. 验证无标注、无测量、Viewer 未运行、菜单文本缺失等负向场景。

### 通过条件

- 各机器分别进入 `AUTOMATIC_VERIFIED`、`USER_VALIDATED` 或 `UNAVAILABLE`，
  不存在隐式坐标 fallback。
- 自动或用户验证后的 SUV/尺寸读取均连续通过，且失败不写入旧值。
- 现场日志证明一次调用最多出现一次菜单，不移动鼠标、不切换前台，剪贴板
  始终事务性恢复。
- 配置、Viewer build 或 runtime signature 漂移后不会继续复用旧 profile。
