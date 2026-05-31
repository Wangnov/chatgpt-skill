# Codex waiting modes

Codex 版不复用 Claude 版后台 watcher 模板。等待策略按任务时长分流；Deep Research 默认用 heartbeat 安静轮询。

Heartbeat 的实现顺序：

1. 先用 tool_search 搜 `automation_update` / wakeup / reminder；如果当前 Codex 环境暴露 automation / wakeup 工具，优先创建 automation。
2. 如果没有 automation 工具，默认 spawn 一个后台 agent 做 heartbeat fallback。
3. 如果既不能 automation，也不能 spawn agent，才退回 Pull 模式。

## 模式 A：当前回合轮询

适用：

- Instant 短咨询
- 大多数 Thinking
- 预计 30 分钟内能完成的 Pro 任务

提交 prompt 后：

1. 记录 conversation URL、模型、app / 文件、用户原始诉求。
2. 用 `<main>` 文本检查完成状态。
3. 未完成时 `waitForTimeout` 或 shell `sleep`，再检查。
4. 只在 COMPLETE、NEEDS_USER_INPUT、TIMEOUT、ERROR 时告诉用户。
5. 不输出"还在等"类中间状态。

建议间隔：

| 任务类型 | sleep |
|---|---:|
| Instant 短咨询 | 20-30 秒 |
| Thinking | 30-60 秒 |
| Pro | 60 秒 |

建议硬上限 1800 秒。到上限仍未完成，返回 TIMEOUT，附当前可见内容和 conversation URL。

## 轮询检查模板

```js
async function getMainText() {
  return await tab.playwright.evaluate(() =>
    document.querySelector("main")?.innerText ?? document.body?.innerText ?? ""
  );
}

function classifyChatGPTText(text, expectedKeywords = []) {
  const runningSignals = [
    "正在思考",
    "Pro 思考中",
    "Researching",
    "正在搜索",
    "正在分析",
    "Synthesizing",
    "Stop generating",
  ];
  const needUserSignals = [
    "Continue generating",
    "继续生成",
    "Please log in",
    "Verifying you are human",
    "Authorize",
    "允许 ChatGPT 访问",
  ];
  const hasRunning = runningSignals.some(s => text.includes(s));
  const needsUser = needUserSignals.some(s => text.includes(s));
  const hasDisclaimer = text.includes("ChatGPT 也可能会犯错。请核查重要信息。");
  const hasExpected = expectedKeywords.length === 0 || expectedKeywords.some(s => text.includes(s));
  if (needsUser) return "NEEDS_USER_INPUT";
  if (!hasRunning && hasDisclaimer && hasExpected) return "COMPLETE";
  return "RUNNING";
}
```

上面是参考，不要把关键词列表当成完整协议。遇到 app 授权、速率限制、配额耗尽、模型不可用、CAPTCHA、反问、继续生成等，按 [error-and-limits.md](error-and-limits.md) 处理。

## 模式 B：Heartbeat 模式

适用：

- Deep Research
- 预计跨小时任务
- 用户希望 Codex 在完成后提醒，但不想让主会话干等

流程：

1. 提交 Deep Research prompt。
2. 等到 ChatGPT 展示研究计划和"开始"按钮。
3. 若用户已明确要求启动研究且没有预算/隐私新风险，可以点"开始"；否则让用户确认。
4. 点击"开始"后，确认进入研究进度态：计划项开始打勾 / 当前步骤文本变化 / 出现搜索次数 / 有停止按钮。
5. 记录 conversation URL、标题、marker、当前计划和启动时间。
6. 挂一个安静 heartbeat：每 3-5 分钟检查一次，最多 45-120 分钟。RUNNING 时不发中间状态；只有 COMPLETE、NEEDS_USER_INPUT、TIMEOUT、ERROR 才通知主会话/用户。
   - 首选 automation / wakeup 工具。
   - 没有 automation 工具时，spawn 一个后台 agent 作为默认 fallback。
   - 两者都不可用时，退回 Pull。

Heartbeat 每轮只读页面，不点按钮、不改 prompt、不授权、不停止研究。检查方式：

1. claim 或打开 conversation URL。
2. 读取 `<main>` 文本，同时检查页面里的 `iframe[title="internal://deep-research"]` 是否存在；必要时补一张截图看 iframe 内的计划/报告卡。
3. 若仍有研究进度卡、停止按钮、"Searching..."、"Finalizing..."、搜索次数等信号，判定 RUNNING 并继续沉默。
4. 若轮询接近完成但外层文本仍旧，刷新 conversation URL 一次再看截图；完成报告有时先渲染在 Deep Research iframe 里，外层 `<main>` 不会包含正文。
5. 若截图或 iframe 卡片显示"研究完成情况"、报告标题，且没有停止/研究中信号，判定 COMPLETE，取回报告摘要；不要只等 `<main>` 出现报告正文。
6. 若出现 login / OAuth / CAPTCHA / Continue generating / clarification，判定 NEEDS_USER_INPUT。

Spawn-agent fallback prompt 模板：

```text
你是 ChatGPT Deep Research heartbeat 监控。目标 URL 是 <conversation-url>，标题是 <title>，marker 是 <marker>。

使用 Codex Chrome Extension 复用用户已登录的 Chrome。不要使用外部浏览器、cookie、localStorage、storage_state 或系统脚本绕过。不要编辑仓库文件。

每 <interval> 分钟检查一次，最多 <max-wait>。每次只读页面状态：claim 或打开 conversation URL，读取截图、<main> 文本和是否存在 title 为 internal://deep-research 的 iframe。不要点击"停止"、不要点分享、不要改 prompt、不要授权 OAuth、不要处理 CAPTCHA/登录。若外层文本长时间不变，刷新 conversation URL 一次再判定。

如果还在研究中，保持沉默继续下一轮。看到"研究完成情况"、报告标题且没有停止/研究中信号时，判定 COMPLETE。只有 COMPLETE / NEEDS_USER_INPUT / ERROR / TIMEOUT 才最终返回。
```

如果当前环境既不能 automation，也不能 spawn agent，才退回 Pull：把 URL 和当前进度交给用户，用户回来后说"看这个 DR"再取。

不要为了跨小时任务在主会话里轮询到天荒地老。ChatGPT 后端不依赖客户端持续在线，conversation URL 是恢复入口。

## 模式 C：Pull 模式

适用：

- 环境不支持后台 heartbeat
- 用户只想启动任务，不需要完成提醒
- 任务预期特别久，超过 heartbeat 上限

流程：

1. 确认研究已经启动，记录 conversation URL。
2. 把 URL、标题、当前计划和可见进度交给用户。
3. 用户回来后说"看这个 DR"，再按"取回结果"流程读取。

## 模式 D：用户接手后继续

适用：

- OAuth / connector 授权
- CAPTCHA
- 登录
- Continue generating
- ChatGPT 中途反问

流程：

1. 报告页面上看到的原文。
2. 说明需要用户做什么。
3. 调用 `browser.tabs.finalize({ keep: [{ tab, status: "handoff" }] })` 保留页面。
4. 用户说"好了"后，重新 claim 或复用 tab，继续轮询。

不要替用户授权、登录、解 CAPTCHA、回答 ChatGPT 的澄清问题，除非用户回到当前对话里明确给出要发送的内容。

## 取回结果

COMPLETE 后：

1. 用 `<main>` 文本取全文。
2. 从用户提问之后提取最新 assistant 部分。
3. 剥离 Thinking 折叠思考过程，保留 final answer。
4. 把 conversation URL、模型、等待时长、app 调用迹象和完整输出交给用户。

如果文本可能不完整，明确标注"可能不完整"，并附 URL。
