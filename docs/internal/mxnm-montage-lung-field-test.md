# MxNM Lung montage 受控执行测试

该工具验证 montage 迁移所需的四种执行方式：自绘布局相对点击、自绘 Tab
相对点击、标准 ComboBox/Edit/Button 的 UIA pattern，以及放大倍数输入框获得焦点后
发送 Enter。它不是 production 快捷键，不注册 `Shift+Alt+B/H/L`。

## 安全边界

- 只在无患者隐私的测试检查中运行；
- 每按一次 `Ctrl+Alt+Shift+F10` 只执行一个步骤；
- 每步开始前用 Win32 子窗口和 UIA 两条路径重新解析 Viewer Control ID，合并后仍须唯一；
- Viewer PID、root owner、前台窗口、control class、可见性或几何不符时停止；
- 自绘布局和 Tab 不响应后台窗口消息，因此按动态控件矩形计算坐标后发送真实鼠标
  单击，并立即把光标移回原位；
- Tab 点击后必须观察到该页面特有控件出现，否则立即停止；布局选中状态未暴露，仍
  需操作者目视确认；
- ComboBox 展开项属于桌面根下的 `ComboLBox`；选择前从桌面搜索同名项，再要求其
  UIA 父链回到刚展开的 ComboBox，并校验同一 Viewer PID；
- 不用键盘输入数值；
- 唯一的键盘输入是最后一步的 Enter；
- 测试会改变当前 Viewer 的布局、图注、窗宽、层厚、当前层和放大倍数，不自动
  回滚；操作者必须逐步目视确认。

## 运行

在 Windows 仓库中用 AutoHotkey v2 运行：

```text
tests\windows\mxnm_montage_lung_field_test.ahk
```

如需生成单文件脚本：

```text
python scripts\build_mxnm_montage_lung_field_test.py
```

## 操作

1. 打开无患者隐私的 Viewer 测试检查并保持 Viewer 前台。
2. 按 `Ctrl+Alt+Shift+F10` 开始并绑定当前 Viewer；第一次不会执行操作。
3. 再按一次，执行布局第 4 行第 4 列；目视确认后再继续。
4. 以后每按一次只执行 ToolTip 显示的下一步。
5. 任一步视觉结果不正确，立即按 `Ctrl+Alt+Shift+F7` 中止，不要继续。

完整顺序为：

```text
layout R4C4
→ Tab 3
→ caption null
→ Tab 5
→ window lung
→ thickness 7.5
→ apply thickness
→ current slice 23
→ jump
→ Tab 4
→ zoom 0.9
→ Enter
```

结果写入并复制到剪贴板：

```text
%TEMP%\MedExAHK\mxnm_montage_lung_field_test.txt
```

`STATIC_CLICK_EFFECT_CONFIRMED` 表示 Tab 点击后已经观察到目标页面特有控件；布局
步骤的 `STATIC_CLICK_VISUAL_CONFIRMATION_REQUIRED` 仍须操作者目视确认。
`BUTTON_INVOKE_DISPATCHED` 和 `ENTER_DISPATCHED` 只代表操作已投递；最终 Viewer
是否呈现正确结果仍以操作者目视确认为准。
失败报告中的 `win32CandidateCount`、`uiaRawCandidateCount`、
`uiaCandidateCount` 和 `uiaQuerySucceeded` 用于区分控件是未被 Win32 枚举，还是
未被 UIA 找到或因进程、窗口层级、可见性与几何边界不符而被拒绝。
下拉项失败时，`optionRawCandidateCount` 表示桌面同名候选数，
`optionCandidateCount` 表示经 ComboBox 父链关联后保留的候选数。
