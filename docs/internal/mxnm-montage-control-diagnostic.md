# MxNM montage 控件探测

该探测器用于迁移 `Shift+Alt+B/H/L` 的 Body、Head、Lung montage。它只读取
鼠标下方的窗口、native control 和 UIA 元数据，不自动点击、不输入文字、不截图，
也不修改麦旋风或 Viewer 配置。

## 运行

在安装了 AutoHotkey v2 的 Windows 测试机上运行：

```text
tests\windows\mxnm_montage_control_diagnostic.ahk
```

如果需要不依赖仓库目录的单文件版本，先运行：

```text
python scripts\build_mxnm_montage_control_diagnostic.py
```

然后运行：

```text
tests\windows\generated\mxnm_montage_control_diagnostic_standalone.ahk
```

## 操作

1. 只使用不含患者隐私的测试检查，并让 `MedExNMFusion.exe` 位于前台。
2. 按 `Ctrl+Alt+Shift+F8` 开始。
3. 按 ToolTip 提示，把鼠标停在目标控件上，再按同一快捷键记录。
4. Tab 切换和 dropdown 展开由操作者手工完成；探测器不会代替操作者点击。
5. 第 5 行布局按钮应把鼠标放在被 Tab 遮挡后仍然露出、可以点击的部分。
6. dropdown 如果会被组合键收起，按 `Ctrl+Alt+Shift+F9` 布防延时取样；
   在接下来的 4 秒内重新展开 dropdown，并把鼠标停在目标选项上。
7. `Ctrl+Alt+Shift+F7` 重置；`Ctrl+Alt+Shift+F6` 提前结束并保留已采集结果。

完成后结果写入：

```text
%TEMP%\MedExAHK\mxnm_montage_control_diagnostic.txt
```

同一份结果也会复制到剪贴板。结果不包含原始 UIA Name、Value、窗口标题或截图；
只对 `null`、`default`、`lung` 三个已知选项输出安全 token。

## 当前布局假设

- 布局矩阵为 5 行 × 4 列；
- 当前目标为第 4 行第 4 列；
- 第 5 行可能被 Tab 遮住一部分，但其露出区域仍应记录为有效鼠标命中点；
- 静态探测结果只决定后续采用 UIA、native control 还是受校验的相对点击，不能
  代替 Windows 上实际执行 Body、Head、Lung 的现场验收。
