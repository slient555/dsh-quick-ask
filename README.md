# dsh-quick-ask

给 [DeepSeek Harness](https://github.com/deepseek-ai)（DSH）用的**截图识题 / 翻译 / 讲解**小工具。Windows 桌面悬浮窗，按一个键框选题目，自动 OCR，直接把答案打在小窗里。

```
Ctrl+Alt+A   截图识题（框选 → 识别 → 翻译 / 讲解 / 问答）
Ctrl+Alt+T   整页翻译（左原文 / 右译文）
Ctrl+Alt+R   通话听写（实验，默认麦克风）
```

## 它由两部分组成

| 目录 | 是什么 | 怎么装 |
|---|---|---|
| `plugin/` | DSH 插件，提供 `/dsh-quick-ask/ask` 接口，把问题转给当前默认模型 | 通过 DSH 插件管理器安装 |
| `overlay/` | Windows 小窗：热键、框选、OCR、翻译页 | `install.ps1` 一键装 |

**为什么必须拆开**：DSH 插件运行在网页端，只能改界面，开不了系统级悬浮窗、也截不了屏。所以插件负责「模型入口」，小窗负责「系统交互」，两者通过本机回环 HTTP 通信（端口自动发现）。

## 安装

1. 装插件：在 DSH 里用插件管理器安装本仓库的 `plugin/` 目录（或 `plugin_manager install_bundle`）。
2. 装小窗：右键 `install.ps1` → 用 PowerShell 运行。

安装脚本会：
- 把 `overlay/` 复制到 `%LOCALAPPDATA%\dsh-quick-ask\app`
- 在桌面和「开始菜单 → 启动」建快捷方式（开机自启，可手动删）
- 自检：Windows OCR 语言包、能否找到 DSH 端口

## 使用

| 键 | 作用 |
|---|---|
| `Ctrl+Alt+A` | 框选题目 → OCR → 可选择翻译 / 讲解 / 问 DSH |
| `Ctrl+Alt+T` | 翻译页（自动判断中英方向，可手动切） |
| `Ctrl+Alt+R` | 通话听写（实验） |
| `Ctrl+Enter` | 小窗内直接提问 |
| `Esc` | 关闭小窗 |

小窗内还有「存图 / 贴图」：图形题 OCR 认不出图形关系，可以把原图存下来或放进剪贴板，交给能看图的对话。

右上角 ⚙ 可以调：

- **虚幻程度** 50%–100%（越低越透，能看到后面的桌面 / 壁纸引擎）
- **壁纸** 跟随桌面 / 内置背景 / 从 wallpaper-engine 插件库存里挑（需要装那个插件）

配置存在 `%LOCALAPPDATA%\dsh-quick-ask\config.json`，重开窗口生效。

## 依赖

- Windows 10/11
- 系统自带 OCR 语言包（简中系统默认有 `zh-Hans-CN`）
- DSH 正在运行，且 `plugin/` 已安装并启用
- 可选：`@smalltailqwq/dsh-client-ui-skin-maid-atelier`（壁纸库存来源）——没有就退回内置背景

## 开发

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File overlay\QuickAsk.ps1 -SelfTest    # OCR + DSH 连通
powershell.exe -NoProfile -ExecutionPolicy Bypass -File overlay\QuickAsk.ps1 -UITest      # 界面构建
powershell.exe -NoProfile -ExecutionPolicy Bypass -File overlay\QuickAsk.ps1 -DemoShot out.png
node plugin\test\smoke.mjs                                                                # 插件路由冒烟
node plugin\test\client-load.mjs                                                          # 客户端模块加载
```

> 改 `QuickAsk.ps1` 时注意：PowerShell 5.1 按 ANSI 读无 BOM 的文件，**改完必须保存为 UTF-8 with BOM**，否则中文会整片乱码。

## 已知边界

- OCR 只认印刷体，手写体、艺术字识别不了；图形关系拿不到（用存图/贴图绕过）。
- 动态壁纸没法嵌进窗口，只能靠窗口透明把它透出来。
- 通话听写现在是麦克风收音，要听耳机里的对方需要「立体声混音」这类系统支持。
- 全局热键是轮询实现（80ms 一次），不是系统级注册。

## License

MIT。仓库里不带任何第三方插画素材，默认背景是脚本生成的纯色顶栏。
