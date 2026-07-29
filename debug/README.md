# MedEx Candidate G Windows 现场工具

`debug/` 下三个 AHK 文件只用于非临床现场诊断，不是 production 入口，不读取
或修改正常用户配置。测试时不要同时运行 generated release 与 debug script。

它们共用 repository-pinned `src/Lib/UIA.ahk` 和 production Candidate G
逻辑；不得在 `debug/` 维护第二份实现。

## `medex_color_reset_field_debug.ahk`

- `Ctrl+Alt+F12`：只运行 color-reset diagnostic，不粘贴报告文字。
- `Ctrl+Alt+F11`：执行与 production `;red` 相同的完整 paste/reset timing。
- `Ctrl+Alt+F10`：故意使用错误 process allowlist，验证 click 前 fast failure。

输出：

```text
%TEMP%\MedExAHK\medex_color_reset_field_debug.txt
%TEMP%\MedExAHK\medex_color_reset_field_debug.log
%TEMP%\MedExAHK\medex_production_timing_debug.txt
```

## `medex_candidate_g_calibration.ahk`

- `F8`：记录用户指向的 arrow center。
- `F9`：记录用户指向的 black center。
- `F10`：closed-pixel probe，不点击 black。
- `F11`：用户手工打开 popup 后采样 open signature。
- `F12`：执行一次受控 Candidate G reset。
- `F7`：验证 closed-signature gate。
- `Ctrl+Alt+F6`：用 mismatch metadata 验证版本不作为 execution gate。

输出：

```text
%TEMP%\MedExAHK\candidate_g_calibration.txt
```

## `medex_candidate_g2_test.ahk`

- `F12`：actual-version Candidate G production-chain control。
- `Ctrl+Alt+F11`：version-mismatch metadata override control。
- `Ctrl+Alt+F8`：历史 reset-path 对照，仅用于诊断现有行为。
- `Ctrl+Alt+F9/F10`：`;fzg` no-reset caret timing A/B；两者都保持模板派生的
  `Left 4` 等价行为，不得改成 `Left 5`。

输出：

```text
%TEMP%\MedExAHK\candidate_g2_test.txt
```

## 安全限制

- 只在已批准的非临床 MedEx 测试区域执行。
- 不在脚本中写入 patient data、报告文字、clipboard payload 或真实配置。
- Arrow 和 black 各最多点击一次；signature 失败时 black click 不可达。
- 不增加 blind click、自动 fallback、第二次 arrow click 或 focus-stealing UI。
- 操作者必须另行确认最终文字颜色、caret、clipboard、mouse 和 foreground。
- Structured success 只能证明自动化链已执行，不能代替视觉验收。
