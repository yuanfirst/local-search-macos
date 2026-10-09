# 本地搜索（macOS）

一个原生 macOS 本地文件搜索工具，支持递归搜索文件名和纯文本内容。

## 功能

- 选择文件夹后搜索当前目录及全部子目录。
- 搜索文件名中包含指定文字的文件。
- 搜索文本内容中包含指定字符串的文件，例如 `tsl76.vfoo.cc:47810`。
- 文件夹留空时从整机根目录 `/` 开始搜索。
- 两个条件同时填写时，文件必须同时满足。
- 支持 UTF-8、GB18030 和带 BOM 的 UTF-16 文本。
- 可停止正在进行的扫描，并查看读取异常。
- 支持打开结果文件或在 Finder 中定位。

## 下载使用

进入 [`outputs/本地搜索`](outputs/本地搜索)，双击 `本地搜索.app`，或下载 [`本地搜索-Mac.zip`](outputs/本地搜索/本地搜索-Mac.zip)。

当前构建面向 Apple Silicon Mac。应用不需要第三方运行依赖。

内容搜索面向 TXT、日志、CSV、JSON 和代码等纯文本，不解析 Word、PDF、压缩包或图片。整机搜索受 macOS 文件权限限制，无法读取的路径会在应用中显示。

## 从源码构建

需要 macOS Command Line Tools（包含 Swift 编译器）：

```sh
cd outputs/本地搜索
zsh build.command
```

运行测试：

```sh
cd outputs/本地搜索
swiftc -parse-as-library Search.swift Tests.swift -o /tmp/local-search-tests
/tmp/local-search-tests
```

应用图标是蓝色背景的白色放大镜，源文件为 `make_icon.swift`，构建时会自动生成 `AppIcon.icns`。
