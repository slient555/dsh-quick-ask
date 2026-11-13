# dsh-quick-ask · 快速问答

DSH 右下角的悬浮问答小窗。随手问一句、选中网页上的文字直接问，答案只在这个小窗里出现，**不写进主对话**。

## 怎么用

| 操作 | 效果 |
|---|---|
| 点右下角圆按钮（或按 `Alt+Q`） | 打开／收起小窗 |
| 在页面里选中一段文字 | 选区旁冒出「问」气泡，点它把原文带进小窗 |
| 输入框里回车 | 发送 |
| `Shift+Enter` | 换行 |
| `Esc` | 收起小窗 |
| 悬停答案 → 复制 | 把答案复制到剪贴板 |
| 标题栏 ⌫ | 清空这轮对话 |

小窗自己维护最近 12 条上下文，关掉插件即彻底消失，不落会话日志。

## 结构

```
package.json        # 清单：dsh.bundle.patch + dsh.client（web，immediately）
cordis.patch.yml    # 插入一行宿主插件 quick-ask
index.js            # 宿主半侧：POST /dsh-quick-ask/ask（SSE 流式 / JSON 二选一）
client.js           # 浏览器半侧：悬浮球 + 面板 + 划词气泡（ModuleLoader 手写 bundle）
locale/{zh,en}.json # 插件列表里的标题与描述
icon.svg            # 插件图标
test/               # 离线测试（不需要真 DSH）
```

## 配置（可选）

在 profile 的 `cordis.patch.yml` 里给这一行加 `config`：

```yaml
- id: quick-ask
  config:
    provider: deepseek-account   # 留空 = 跟随当前默认模型
    model: deepseek-flash
    maxTokens: 1200              # 64 ~ 8000
    temperature: 0.3             # 0 ~ 1.5
    system: '你是一个快速答疑助手…'
```

## 测试

```powershell
node test/smoke.mjs        # 宿主路由：SSE / JSON / 空问题 / 405 / 无模型 / 错误翻译
node test/client-load.mjs  # 客户端：模块 id、slot 注册、收起态渲染
```

## 已知边界

- 这个小窗问的是**当前默认模型**，不走主会话的上下文与文件；要接着主线聊，还是回主对话。
- `Alt+Q` 只在 DSH 窗口有焦点时生效（DSH 没有注册系统级全局热键）。
- 划词气泡只对页面内可选中文字生效；别的程序里的题目，先用 `Win+Shift+S` 截图，再粘到主对话。
