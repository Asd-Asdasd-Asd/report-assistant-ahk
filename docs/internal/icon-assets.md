# 图标资源

`assets/icon/source/medex-icon.svg` 是图标唯一可编辑的源文件。不要手工修改 `assets/icon/generated/` 中的 PNG 或 ICO。

## macOS 生成环境

使用 Homebrew 安装所需工具：

```sh
brew install librsvg imagemagick
```

在仓库根目录运行：

```sh
./scripts/generate-icon.sh
```

脚本会重新生成 16、20、24、32、40、48、64、128 和 256 px PNG，并生成：

```text
assets/icon/generated/medex-icon.ico
```

Windows 使用 Ahk2Exe 编译 EXE 时，应把这个 ICO 文件作为图标输入。生成的 PNG 与 ICO 均随源 SVG 一起提交到仓库。
