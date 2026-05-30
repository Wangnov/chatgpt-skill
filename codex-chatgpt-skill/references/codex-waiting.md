# Codex waiting modes

Codex 版不依赖后台子代理 watcher。等待策略按任务时长分流。

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

## 模式 B：Pull 模式

适用：

- Deep Research
- 预计跨小时任务
- 用户不想让 Codex 占住当前回合

流程：

1. 提交 Deep Research prompt。
2. 等到 ChatGPT 展示研究计划和"开始"按钮。
3. 若用户已明确要求启动研究且没有预算/隐私新风险，可以点"开始"；否则让用户确认。
4. 确认研究已经启动，记录 conversation URL。
5. 立刻把 URL 给用户，说明可以关闭 Codex / Chrome，用户回来后说"看这个 DR"即可取回。

不要为了跨小时任务轮询到天荒地老。ChatGPT 后端不依赖客户端持续在线，conversation URL 是恢复入口。

## 模式 C：用户接手后继续

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
