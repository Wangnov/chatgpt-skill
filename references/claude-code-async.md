# Claude Code 异步唤醒（Fallback 模式：shell heartbeat）

> **这是 fallback。**Claude Code 主推方案是 [watcher-subagent.md](watcher-subagent.md) —— spawn 一个 background Haiku watcher，主 LLM 全程沉默。
>
> **何时用这个 fallback**：
> - 环境不支持 Agent 工具（纯 SDK 调用、自定义 host 等）
> - Agent 工具不可用或权限不够
> - 用户明确要求纯 shell 方案

## 总体模型

- **主 LLM**（Claude Code 主进程）负责所有"看页面、点东西、决定要不要再等一轮"的判断
- **`scripts/heartbeat.sh`** 只负责 `sleep N && echo 唤醒提示 && exit 0`
- 用 `Bash(..., run_in_background: true)` 起 heartbeat → 主 LLM 把当前任务返还给用户 → 后台 Bash 结束后 Claude Code 把它的 stdout 当作系统通知交付给主 LLM → 主 LLM 在下一轮用 `claude-in-chrome` MCP 亲自看页面

**关键规则：主 LLM 每轮唤醒后必须保持沉默**，除非：
- 任务完成 → 给用户最终结果
- 任务超时（累计 > 30 分钟） → 报告并问用户是否继续
- 看到错误 / 速率限制 / 登录页 → 报告并停下来

未完成的中间状态**不要发任何消息**，直接静默起下一轮 heartbeat。

这套机制的核心好处：

1. **不靠任何持久化文件**。conversation URL 在主 LLM 的对话上下文里，自然就有
2. **每次唤醒都是"重新看一眼"**。不会被脚本里缓存的 stale 状态骗
3. **shell 不碰浏览器、不依赖 osascript、不依赖 CDP**。跨平台干净

## 提交后的标准动作序列

提交完 prompt（点完发送、看到 ChatGPT 开始流式输出）后：

```
1. 把 conversation URL 写进当前 todo 的 description 或 task metadata
   （这样后续唤醒后还能找到——但不是 manifest 文件，是 task 工具或对话上下文）

2. 选一个合适的等待秒数（见下表）

3. 调用：
   Bash:
     command: scripts/heartbeat.sh <SECONDS> <URL> "<simple note like '第 1 轮等待'>"
     run_in_background: true
     description: ChatGPT 心跳

4. 告诉用户："已经提交给 ChatGPT，预计 <SECONDS> 秒后回来取结果。你可以继续问我别的。"

5. 把主控权交还，等系统通知。
```

## 等待秒数参考

主 LLM 自己判断，下表只是起点：

| 任务类型 | 起步秒数 | 备注 |
|---|---|---|
| Instant 短咨询 | 30–60 | 一般 30 秒内就完了，60 算保险 |
| 默认模型 / Thinking | 120–180 | Thinking 经常 1–3 分钟 |
| Pro | 180–300 | Pro 长一些 |
| Deep Research | 300（首轮）→ 600（后续轮） | 经常要 5–15 分钟，必要时拉到 900 |
| 上传大文件 + 推理 | 60 + (任务起步秒数) | 上传后等待文件 chip 出现也算等待 |

**不要把首轮 sleep 设得太长**。第一轮回来主 LLM 看一眼就知道大概节奏，再根据情况调下一轮。

## 收到唤醒通知后做什么

Claude Code 把 background bash 的 stdout 作为系统消息交付给主 LLM。看到 `WAKE chatgpt-web-delegate` 字样后：

```
1. 用 claude-in-chrome navigate 重新打开 conversation URL（即使当前 tab 已经在这个 URL）
   —— 强制重新刷一遍 DOM，避免被前端 stale 状态骗

2. read_page 看以下信号：
   - 还有"思考中 / 正在搜索 / 正在分析 / Stop generating / Researching"任一字样或 stop 按钮 → 没完成，回到第 4 步起新一轮 heartbeat（可以适当延长 SECONDS）
   - 全没了 + 末尾出现 "ChatGPT 也可能会犯错" disclaimer + composer 可输入 → 进入第 3 步

3. 用 get_page_text 或针对最新 assistant message ref_id 用 read_page 拉文本
   - 如果消息里有可见的 "复制" / "Copy" 按钮，优先点击复制再读剪贴板更稳
     （但 claude-in-chrome 不一定能读系统剪贴板，可降级到 get_page_text）
   - 警惕折叠区域（"思考过程"、"工具调用记录"）—— 要的是 final answer，不是中间步骤

4. 把回答交给用户
   - 如果回答可能被截断（页面有 "继续生成" 按钮、出现 "..." 结尾），告诉用户并附 URL
```

## 多轮 heartbeat 的反模式

不要这样做：

- ❌ 在 heartbeat.sh 里写 `while true; do sleep N; ... done` 让脚本自己循环 —— 这样主 LLM 拿不到 "每一轮都看一眼" 的机会
- ❌ 用 `BashOutput` 工具轮询 background bash 的输出 —— 浪费 token，不是用 background 通知的正确方式
- ❌ 起多个并发 heartbeat —— 一个任务一个 heartbeat，串行起新一轮
- ❌ 设很长的 sleep（如 1800 秒）等"一次到位" —— 脚本里已经设了 1800 秒上限，超出会拒绝；并且太长的等待会让用户体验糟糕

## 如果用户在等待中提了新问题

完全 OK，因为主 LLM 已经把控制权交回。background bash 仍在跑，等它结束你才会被通知。这正是这个设计的优点。

如果用户说"不等了"或"取消任务"：
- 用 `KillShell`（如果 Claude Code 支持）或者直接告诉用户后台 bash 还会在剩余 sleep 时间内自然结束，可以忽略下次通知
- 不要去 `kill -9` 强制干掉，会有 race condition

## 浏览器 tab 的处理

ChatGPT 的会话是 stateful 的，conversation URL 即使过几个小时再访问也能恢复。所以：

- 主 LLM 第一次提交后**可以让用户切到别的 tab 用浏览器**
- 唤醒时主 LLM 用 `claude-in-chrome` 重新 navigate 即可。如果用户当前在 ChatGPT 别的会话，navigate 会把它切走；为了对用户更礼貌，可以 `tabs_create_mcp` 新开一个 tab 看，看完关掉
- 但如果做新 tab 模式，注意每轮唤醒都新开会留下一堆历史 tab —— 一般做法是在第一次唤醒时记下 tabId，后续唤醒复用

## 错误处理

heartbeat.sh 退出非零时（极少见），主 LLM 看到的通知会带 stderr。这时不要重新起一轮 heartbeat —— 先告诉用户什么坏了。

如果主 LLM 在唤醒后发现：

- conversation URL 404 / 无法访问 → ChatGPT 会话被删了或网络断了，告诉用户
- 看到登录页 → 用户的 ChatGPT session 过期，让他重新登录后再继续（不要替他点登录）
- 看到付费墙 / 速率限制弹窗 → 告诉用户具体看到了什么，他来决定要不要换账号 / 换模型 / 等
