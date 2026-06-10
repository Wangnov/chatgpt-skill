# Example: Codex 上传文件并取回 ChatGPT 回答

## 触发说法

- "把这个文件发给 ChatGPT，让它总结一下"
- "上传这个日志，让 GPT 看第一处错误"
- "把 PR diff 文件交给 Thinking 分析"

## 意图解析

- **浏览器**：复用用户已登录的 Chrome tab，不启动独立 profile。
- **文件**：通过 Codex Chrome Extension 的 file chooser 上传本地绝对路径。
- **预期产物**：ChatGPT 读取附件后给出回答，Codex 从 `<main>` 取回完整文本。

## 操作步骤

1. 连接 Chrome，`browser.user.openTabs()` 找现有 ChatGPT tab；有就 `browser.user.claimTab(tab)`，没有就新开 `https://chatgpt.com/`。
2. `domSnapshot()` 确认 composer 可用，并记录当前页面可见的模型选择器 / 模型 pill。模型入口可能在顶部 banner，也可能在 composer 附近。
3. 如果用户指定模型，打开模型选择器，选择最接近的可见项；切不到就停下来报告可见选项。
4. 打开 `添加文件等` → `添加照片和文件`。
5. 点击菜单项之前先启动 `waitForEvent("filechooser")`。
6. file chooser 出现后调用 `chooser.setFiles(["/absolute/path/to/file"])`。
7. 等附件 chip 出现，确认文件名和 `移除文件...` 按钮可见。
8. 输入 prompt，点击 `发送提示`。
9. 等 URL 变成 `/c/<uuid>`，记录 conversation URL。
10. 轮询 `<main>` 文本，直到停止按钮消失、disclaimer 出现，取回回答。
11. 最后 `browser.tabs.finalize({ keep })`；如果用户要看现场，保留 tab 为 `deliverable`。

## 失败处理

- `setFiles(...)` 报 `Not allowed`：Codex 扩展未开启本地文件访问。让用户到扩展详情页打开 `允许访问文件网址`，再重试上传菜单路径。
- 直接点击 `input[type="file"]` 超时：不要继续点隐藏 input，改走可见菜单 `添加文件等` → `添加照片和文件`。
- 上传后发现附件不对：点 `移除文件...`，确认 chip 消失后再重新上传，不要带错附件发送。
- 发送后页面要求 OAuth、登录、CAPTCHA 或隐私授权：停止并交给用户处理。

## 2026-05-31 实测记录

- 上传路径：`添加文件等` → `添加照片和文件` → `filechooser.setFiles(...)`。
- 测试文件：`chatgpt-upload-smoke.txt`。
- ChatGPT 成功读取文件第一行并回复 `UPLOAD_SMOKE_OK`。
- 另测草稿附件上传后移除成功，移除后不会提交消息。
