# 红字剪贴板调查记录

本文档记录 v0.4.0 后在 Windows 工作站上的红色 `（见图）` 插入测试结果。`bugfix_report_assistant.ahk` 是一次性现场诊断文件，不是源码真相来源；其有效发现已记录在本文档中，文件随后应从仓库根目录删除。

## Original goal

以下 hotstrings 应插入红色 `（见图）`：

- `;red`
- `;fzg`
- `;fwj`
- `;fjd`

实现应满足：

- 恢复用户原始剪贴板；
- 不要求用户从 Word 手动复制/粘贴红字；
- 不依赖已保存的 clipboard snapshot；
- 插入后继续输入的文字应恢复黑色。

## Original syntax failure

v0.4.0 生成文件在 Windows 上出现 AHK 语法错误：

```text
Error: Missing """
Text: return "{\rtf1\ansi\deff0{\fonttbl{\f0 Microsoft YaHei;}}" . "{\colortbl
```

问题位置是 `BuildRedRtf()` 中脆弱的多段字符串拼接。RTF 中的分号也容易被 AHK v2 当作注释起点处理。

## Manual minimum bugfix

手工编辑的诊断文件显示，语法问题可以通过以下方式避开：

- 用显式字符串累加替代脆弱的 multiline return concatenation；
- 用 `Chr(59)` 表示分号，避免 AHK v2 注释解析。

现场诊断修复片段：

```autohotkey
BuildRedRtf(text) {
    escapedText := RtfEscapeUnicode(text)
    semi := Chr(59)

    rtf := ""
    rtf .= "{\rtf1\ansi\deff0{\fonttbl{\f0 Microsoft YaHei" semi "}}"
    rtf .= "{\colortbl" semi "\red255\green0\blue0" semi "\red0\green0\blue0" semi "}"
    rtf .= "\f0\fs22\cf1 " escapedText "\cf2}"

    return rtf
}
```

这个修复只证明 AHK 语法可以通过；它没有证明目标报告编辑器接受当前 RTF 剪贴板数据。

## Behavior after syntax fix

Windows 现场观察结果：

- RTF + `CF_UNICODETEXT`：插入黑色 `（见图）`。
- RTF only：没有插入内容，也没有明显错误。

解释：

- hotstring 和 paste chain 很可能已经工作；
- 目标报告编辑器没有消费当前 RTF clipboard payload；
- 黑色文本来自 `CF_UNICODETEXT` fallback；
- RTF 不应继续作为主要计划实现路径。

## `red_not.clip` finding

旧的 `red_not.clip` 方法：

- 保存的是 `ClipboardAll` 二进制 snapshot；
- 可能依赖 session-specific registered clipboard format IDs；
- 重启后可能失效；
- 重启后可能需要人工重新保存；
- 不应作为生产实现继续保留。

但是：

- 它仍可作为诊断样本；
- 它提示真正可工作的富文本格式可能是 HTML Format / `CF_HTML`，而不是 RTF。

## New direction

新的红字实现方向：

- 下一步应优先实现 dynamic HTML Clipboard / `CF_HTML`；
- RTF 保留为实验/参考路径；
- `;red` 不应静默 fallback 成黑色文本；
- 失败必须可见；
- 最终行为必须插入红色 `（见图）`、恢复剪贴板，并让后续输入恢复黑色。

## v0.4.2 implementation

v0.4.2 将活动实现从 `clipboard_rtf.ahk` 切换为 `clipboard_html.ahk`：

- 动态生成符合 CF_HTML header 约定的 UTF-8 payload；
- offset 按完整 payload 的 UTF-8 byte position 计算；
- 只写入注册格式 `HTML Format`，不写 `CF_UNICODETEXT` fallback；
- 使用 `ClipboardAll()` 保存并在 finally-style cleanup 中恢复原剪贴板；
- 首版只使用红色 span 和黑色外层容器，不增加零宽字符或其他隐藏边界；
- 返回成功表示 paste command dispatch success，不表示目标编辑器已经视觉确认红字。

后续 MedEx 现场调查已确认 `CF_HTML` 可以正确显示红色文字，但 MedEx 会继承最后插入字符的红色，后续输入不会自动恢复黑色。颜色复位已经形成独立 Technical Investigation 和获批 V1，不应把空黑 span workaround 当作永久架构。详见 `docs/technical-investigations/2026-07-medex-rich-text-color-reset.md`。

`bugfix_report_assistant.ahk` 是临时一次性 field-test artifact。其发现记录到本文档后，应从仓库根目录删除，不能进入生产源码。
