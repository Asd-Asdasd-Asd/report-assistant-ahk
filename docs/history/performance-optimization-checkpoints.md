# Candidate G 后续性能与校准边界

Candidate G 的既有性能步骤已经完成并由当前 source、tests、architecture 和
Git 历史固化。本文件只保留尚未实施的 per-machine calibration 边界。

## 已冻结的当前约束

- `relativeMousePixelValidated` 是 production default；`uiaInvoke` 仅作显式
  comparison/rollback，二者不得自动 fallback。
- `;fzg` 使用模板派生的 no-reset caret relocation，不重新加入 Color Reset、
  固定 `Left 5` 或额外 settle。
- Clipboard restore 只有一个 `finally` owner；fast failure 也必须满足
  minimum paste-to-restore interval。
- Arrow/black 各最多点击一次；popup signature、foreground、geometry、
  resolution、DPI 和 scaling 仍是硬门槛。
- Exact MedEx version 仅作 diagnostics metadata，不代表其他环境已获支持。
- Windows field validation 是最终 acceptance surface；macOS 静态测试不能证明
  UIA、鼠标、焦点、颜色或 clipboard runtime 行为。

## Per-machine layout calibration

只有获得单独授权后才实施。目标流程：

```text
UIA 定位“检查所见”
→ 用户确认 arrow center
→ 打开 popup
→ 用户确认 black center
→ 采集 popup signature
→ 保存本机 profile 与环境 metadata
→ 在非临床环境执行受控验证
```

Profile 至少包含：

- semantic anchor name；
- arrow/black relative offsets；
- popup signature；
- DPI、scaling、resolution 和可选 monitor identity；
- calibration timestamp；
- 仅作信息的 MedEx version。

不得保存 HWND、患者内容或无校验绝对 screen coordinates。环境、signature 或
geometry 漂移后旧 profile 必须失效，而不是继续点击。

## 继续或停止条件

- Calibration 和 controlled interaction 均通过，且 clipboard、mouse、
  foreground、caret 和后续输入颜色正确，才可讨论接入 production。
- Popup signature、geometry、foreground 或 profile identity 不唯一时停止。
- 不得通过删除 signature、geometry 或 at-most-once checks 换取速度。
- 现场结果缺少决定安全性的观察时，只补充缺失项，不重开已完成的历史步骤。
