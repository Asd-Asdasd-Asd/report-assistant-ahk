# Viewer 跨机器自适应改造 checkpoints

本轮工作在 `feat/viewer-adaptive-runtime` 分支进行。每个 checkpoint 都必须
完成代码、静态验证和 Windows Viewer 现场验证；现场结论未通过前不得进入
下一 checkpoint。未知结构始终 fail closed，不使用未经验证的绝对坐标。

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

## Checkpoint 2：自适应工具按钮 resolver

### 实现范围

- 用 Checkpoint 1 证明的 Vendor profile 选择规则代替固定目录 `1`。
- Vendor 配置只提供工具区域、row/column 和 command ID。
- runtime 在受限区域内枚举同 PID、visible/enabled 的 native controls。
- 目标 command ID 必须唯一，几何顺序必须与 Vendor row/column 一致。
- 向真实控件的直接父窗口投递 bounded `WM_COMMAND / BN_CLICKED`。
- 删除固定按钮中心、固定 `38 px` pitch 和固定前三行的生产依赖。
- 每次 Viewer session 或配置 hash 变化后重新解析；证据不唯一时禁用该项。

### Windows 现场验证

1. 在原验证机器和 Checkpoint 1 的失败机器上分别测试箭头、长度和 3D SUV。
2. 每项连续执行 10 次，确认一次按键只改变一次工具状态。
3. 验证不同显示布局、同分辨率不同机器、多屏副屏场景。
4. 验证报告窗口或其他程序前台时不触发、不吞键。
5. 保存 field result，确认 command ID、实际 HWND/parent、配置 hash、
   profile identity、foreground/mouse invariants。

### 通过条件

- 至少三台结构不同的机器上三个工具均通过。
- 不依赖绝对 screen point；窗口移动或重新启动 Viewer 后仍能重新解析。
- 缺失、重复或隐藏 command control 时明确 fail closed，不能尝试坐标点击。

## Checkpoint 3：自适应测量与用户自校验兜底

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
