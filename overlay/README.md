# DSH 快速问答 · 系统级悬浮窗

在任何网页、考试系统、PDF 前面按 `Ctrl+Alt+A`，拖一个框，松手就自动识别并给出答案。答案只长在这个小窗里，不碰 DSH 的主对话。

## 用法

1. 双击 `Start-QuickAsk.vbs` 启动（后台常驻，不闪黑框）。
   没反应 / 想看报错，就双击 `QuickAsk-Console.cmd`。
2. 随便打开一个网页，按 **`Ctrl+Alt+A`**。
3. 屏幕暗下来，用鼠标把题目框住，松开（只点一下不拖 = 抓整屏）。
4. 小窗弹出：上半是识别出的文字（可直接改错字），下面填问题，回车或点「问 DSH」。
5. 答案出现在下面；「复制」可一键带走。

细节：

- 小窗里 `Ctrl+Enter` 直接问，`Esc` 关掉；按住顶部插画区空白处可以拖动窗口。
- 问题框留空时，默认问「这道题怎么做？请给出答案和关键步骤」。
- 识别走 Windows 自带 OCR（离线，中日英文），不联网。

## 模式

输入框上方有四个胶囊，点一下切换，选中的是蓝紫实心：

| 模式 | 干什么 |
|---|---|
| 自动 | 按内容判断：几乎全是外语 → 翻译；有题目特征 → 解题；其余 → 讲解 |
| 翻译 | 中文译英文、外语译中文，术语准确，必要时附译注 |
| 解题 | 先给答案，再给关键步骤，最后点出易错处 |
| 讲解 | 先给结论，再拆原理与步骤，必要时举例 |

「自动」判定规则写在 QuickAsk.ps1 的 Get-AutoQuestion：汉字 ≤1 且拉丁字母 ≥8 且占比 >30% 才算外语（避免数学题被误判成外语）。

## 界面

- 顶部是一张**虚化的鲸鱼娘横幅**（标题与副标题直接烤进图里，避免透明标签发虚）。
- 下面是深色玻璃面板：分区卡片、细描边、蓝紫渐变主按钮、圆角与投影。
- 背景图是 `assets/bg.png`，由 `make-bg.py` 从插件皮肤里的鲸鱼娘立绘生成（裁上半身 → 高斯模糊 → 深海蓝调 → 烧标题）。

想换图或调虚化程度：

```powershell
python make-bg.py "<鲸鱼娘立绘.webp>" "assets\bg.png"
```

`make-bg.py` 顶部可调：`HERO`（插画区高度）、`GaussianBlur(6)`（模糊半径）、`Image.blend(..., 0.68)`（压暗强度）。

## 依赖

- Windows 10/11，系统有中文 OCR 语言包（简中系统默认有）。
- DeepSeek Harness 在跑，且装了 `dsh-quick-ask` 插件（当前 profile 已装）。端口自动发现，DSH 重启不用改配置。

## 文件

| 文件 | 作用 |
|---|---|
| `QuickAsk.ps1` | 主体：热键轮询、框选、OCR、调 DSH、结果窗口 |
| `Start-QuickAsk.vbs` | 静默启动（日常用） |
| `QuickAsk-Console.cmd` | 带控制台启动，看错误用 |
| `make-bg.py` | 生成/更新虚化背景图 |
| `assets/bg.png` | 当前背景（960×1360 @2x） |

## 自检

```powershell
# OCR 引擎 + 能否连上 DSH（会真问一句，消耗一次额度）
powershell.exe -NoProfile -ExecutionPolicy Bypass -File QuickAsk.ps1 -SelfTest

# 只构建窗口，验证界面代码没写错
powershell.exe -NoProfile -ExecutionPolicy Bypass -File QuickAsk.ps1 -UITest

# 有人值守时截图看效果（窗口会闪一下）
powershell.exe -NoProfile -ExecutionPolicy Bypass -File QuickAsk.ps1 -Snapshot "assets\_shot.png"
```

## 已知边界

- `Ctrl+Alt+A` 是轮询实现（80ms 一次），不是系统级注册，极短的按键可能漏掉。
- 手写体识别不了；印刷体与小字号公式没问题（上标会变成 `x^2`，可手改）。
- 需要 DSH 在跑；DSH 退了会提示「没找到 DSH」。
