# Codex Chrome runtime

Codex 版通过 Codex Chrome Extension 操作用户已登录的 Chrome，不使用 Claude 版的 MCP，也不启动独立浏览器 profile。

## 第一次连接

先使用 `chrome:control-chrome` 技能。该技能会要求通过 Node REPL 加载 Chrome 插件里的 `scripts/browser-client.mjs`，并把 `agent.browsers.get("extension")` 绑定为 `browser`。

不要在本技能里硬编码插件路径。读取当前环境里 `chrome:control-chrome` 给出的 plugin root，并使用绝对路径 import：

```js
if (!globalThis.agent) {
  const { setupBrowserRuntime } = await import("<Codex Chrome plugin root>/scripts/browser-client.mjs");
  await setupBrowserRuntime({ globals: globalThis });
}
if (!globalThis.browser) {
  globalThis.browser = await agent.browsers.get("extension");
}
await browser.nameSession("ChatGPT handoff");
```

如果 `browser-client` 连接失败，按 Chrome 技能的连接检查处理：确认 Chrome 是否运行、扩展是否安装启用、native host 是否正常。不要降级到 Computer Use、AppleScript、外部 Playwright 或 cookie 读取。

## 当前烟测状态

2026-05-31 在本仓库迁移时，停掉其它 Chrome debugger 控制方后，Codex Chrome Extension 已能稳定控制用户已登录的 ChatGPT 页面：

- `browser.user.openTabs()` 可以列出现有 ChatGPT tabs，并用 `browser.user.claimTab(tab)` 复用用户 tab。
- `domSnapshot()`、受限 `evaluate()`、`screenshot()`、`dom_cua.get_visible_dom()` 都能读取 ChatGPT 页面。
- 普通 Instant 会话可提交 prompt、等待完成、读取 `<main>` 全文，并拿到 `/c/<uuid>` conversation URL。
- 带上传文件的 prompt 已实测成功：ChatGPT 能读取 `chatgpt-upload-smoke.txt`，并回复文件第一行。
- composer 模型菜单可展开并读到当前可见选项：Instant / Thinking / Pro / 配置。
- `添加文件等` 菜单可展开并读到：添加照片和文件 / 近期文件 / 创建图片 / 深度研究 / 网页搜索 / 更多。
- `更多` app 菜单可展开并读到：代理模式 / 添加源 / 画布 / 创建任务 / 财务 / GitHub / Gmail / Google 云端硬盘 / Hugging Face / OpenAI Platform。
- 草稿附件可上传后再用 `移除文件...` 按钮取消，取消后不会提交消息。
- Deep Research 已实测到启动成功路径：选择 `深度研究` 后 composer placeholder 变为 `获取详细报告`，发送 prompt 后出现研究计划卡片；点击计划卡片里的 `开始` 后，计划项开始推进，进度文本出现 `Searching ...` / `Finalizing ...`，并显示搜索次数。启动后应切到 heartbeat，而不是在主会话里干等。

保留以下阻塞形态作为诊断项：如果 ChatGPT tab 上再次出现 `Detached while handling command`，随后 `domSnapshot()`、受限 `evaluate()`、截图或 `dom_cua.get_visible_dom()` 返回 `Unknown error`，优先怀疑 Chrome debugger 控制权冲突。不要改用 cookie、localStorage、外部 Playwright profile、Computer Use 或系统脚本绕过；先停掉其它控制 Chrome 的扩展、DevTools 或 MCP，再重新跑最小对照测试。

### 已知根因线索：浏览器控制权冲突

同一轮进一步诊断确认：

- Codex Chrome Extension 可以稳定控制 `example.com`、`google.com`、`openai.com`、`platform.openai.com`、`auth.openai.com` 和 `claude.ai`。
- 只有 `chat.openai.com` / `chatgpt.com` 在 `goto()` 时返回 `Detached while handling command`，随后该 tab 的 `domSnapshot()` 返回 `Unknown error`。
- 当前 Chrome profile 同时安装了 Codex 扩展和 Claude in Chrome 扩展，二者都声明 `debugger` 权限；本机还存在 Claude Code 启动的 `chrome-devtools-mcp` 进程。

这类形态优先判断为 Chrome debugger 控制权冲突：另一个扩展、DevTools、或 MCP 已经接管/正在接管 ChatGPT tab，导致 Codex 扩展在导航或读取页面时被 detached。遇到这种形态时，不要继续调 selector；先让用户临时关闭/停用其它会控制 Chrome 的扩展、DevTools 或 Claude Chrome 会话，然后重新跑最小对照测试。

本次实测中，停掉 `chrome-devtools-mcp` 并停用 Claude in Chrome 后，ChatGPT 控制恢复正常。`pgrep -fl chrome-devtools-mcp` 可能仍显示 Claude 父进程的命令行配置，需用 `ps -p <pid>` 确认真正的 MCP 子进程是否还活着。

## 复用 ChatGPT tab

先看用户已有 tab：

```js
const tabs = await browser.user.openTabs();
console.log(JSON.stringify(tabs.filter(t => (t.url || "").includes("chatgpt.com")), null, 2));
```

如果有 ChatGPT tab，选择标题/URL/最近使用时间最匹配的那一个：

```js
globalThis.tab = await browser.user.claimTab(selectedUserTab);
```

如果没有：

```js
globalThis.tab = await browser.tabs.new();
await tab.goto("https://chatgpt.com/");
await tab.playwright.waitForLoadState({ state: "domcontentloaded", timeoutMs: 15000 });
```

不要猜 tab id，只能 claim `browser.user.openTabs()` 返回的对象。

## 页面观察

优先用三种观察方式：

```js
// 结构和可点击元素
console.log(await tab.playwright.domSnapshot());

// 主聊天区域全文，适合完成判定和取回回答
const text = await tab.playwright.evaluate(() =>
  document.querySelector("main")?.innerText ?? document.body?.innerText ?? ""
);
console.log(text);

// 视觉确认
await nodeRepl.emitImage(await tab.screenshot({ fullPage: false }));
```

长回答完成判定不要依赖 `domSnapshot()`，它可能截断。用 `<main>` 的 `innerText` 从末尾找 disclaimer、进行中信号和用户预期关键词。

## 点击和输入

每次点击/输入前：

1. 取足够新的 `domSnapshot()`。
2. 用 snapshot 中真实存在的 role、label、placeholder、text、href 或稳定属性构造 locator。
3. 如果唯一性不明显，先 `count()`。
4. 只有唯一匹配时才点击或填充。
5. UI 改变后重新 snapshot。

常见 composer 输入流程：

```js
const promptBox = tab.playwright.getByRole("textbox", { name: "向 ChatGPT 发送消息" });
if (await promptBox.count() !== 1) {
  // 中文 UI 名称会变；重新看 snapshot，改用 placeholder 或 contenteditable 容器。
}
await promptBox.fill(prompt);
await promptBox.press("Enter");
```

不要把上面中文 label 当成固定事实；它只是示例。实际以当前 snapshot 为准。

## 文件上传

Codex Chrome Extension 支持 file chooser。优先实际输入控件：

```js
const chooserPromise = tab.playwright.waitForEvent("filechooser", { timeoutMs: 10000 });
await tab.playwright.locator('input[type="file"]').click();
const chooser = await chooserPromise;
await chooser.setFiles(["/absolute/path/to/file.txt"]);
```

如果页面只提供可见上传按钮，先 snapshot 确认它会打开文件选择器，再点击。所有路径必须是绝对路径。

ChatGPT 实测成功路径：

1. 打开 `+ / 添加文件等` 按钮。
2. 在菜单里点击 `添加照片和文件`。
3. 点击菜单项之前先启动 `waitForEvent("filechooser")`。
4. file chooser 出现后用绝对路径 `chooser.setFiles([...])`。
5. 成功后页面会出现文件 chip，例如 `chatgpt-upload-smoke.txt`，并有 `移除文件...` 按钮。

不要直接点 ChatGPT 页面的底层 `input[type="file"]`。实测它可能不会触发 Codex 运行时的 `filechooser` 事件，导致 `Timed out after 3000ms waiting for file chooser`，甚至重置当前 Node REPL kernel。

如果 `chooser.setFiles(...)` 返回 `Not allowed` / `fileChooser.setFiles failed`，这是 Codex Chrome Extension 没有本地文件访问权限。去 `chrome://extensions/?id=hehggadaopoacecdllhhajmbjkdcmajg` 的 Codex 扩展详情页，开启英文界面的 "Allow access to file URLs"；中文界面叫 `允许访问文件网址`。打开后无需重启 Chrome，重新走菜单上传路径即可成功。不要改用本地拖拽、cookie、签名 URL 或手写 multipart 请求。

## 下载

单文件下载前必须有用户明确同意。可以用浏览器下载事件：

```js
const downloadPromise = tab.playwright.waitForEvent("download", { timeoutMs: 30000 });
await linkLocator.click({});
await downloadPromise;
```

下载后文件通常落在 `~/Downloads/`。用 shell 查最新文件：

```bash
/bin/ls -lat ~/Downloads/ | head -7
```

如果要移动/改名，先确认文件名和目标路径，不要覆盖已有文件。

## 收尾

完成或停止浏览器操作后，最后一个 Chrome 动作调用：

```js
await browser.tabs.finalize({
  keep: [
    // 需要用户接手登录、授权、CAPTCHA、继续生成、长任务时，保留 handoff tab。
    // { tab, status: "handoff" }
  ]
});
```

如果 tab 本身是用户要继续看的交付物，保留为 `deliverable`。否则默认 omit，让浏览器会话清理代理创建的中间 tab。
