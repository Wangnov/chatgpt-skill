---
name: chatgpt-web-delegate
description: 通过用户现有的、已登录的 ChatGPT 网页会话委托任务给任意 ChatGPT 模型，并管理对话/项目/Memory/库等。复用浏览器登录态、文件、连接器、项目。适合用户说"问问 ChatGPT / 让 GPT Pro 帮我想想 / 用 @Google 云端硬盘列一下 / 让 ChatGPT 做个 deep research / 删了这个对话 / 归档全部聊天 / 撤销那个分享 / 清掉 Memory / 创建一个项目"等。不发起独立的自动化浏览器，不接触 cookie/session。
---

# chatgpt-web-delegate

让 Claude Code 像一个会用浏览器的人一样，**复用用户已登录的 ChatGPT 网页**，把任务交给指定的 ChatGPT 模型（Instant / Thinking / Pro 等），等结果回来。

## 何时触发

用户说类似下面的话：

- "问问 ChatGPT Pro 怎么看这件事"
- "让 Thinking 模式分析一下这个 PR"
- "用 @Google 云端硬盘列一下我的文件"
- "提交个 deep research，列五家竞品"
- "把这段代码扔给 GPT 让它批一遍"
- "等 ChatGPT 一会儿，结果出来叫我"

## 接入方式（**强制**）

| Host | 浏览器接入 | 禁止 |
|---|---|---|
| Claude Code | `claude-in-chrome` MCP（`mcp__Claude_in_Chrome__*`） | Playwright、Puppeteer、独立自动化浏览器 profile、`computer-use` 操作 Chrome（Chrome 在 read-only 层） |

如果 `claude-in-chrome` MCP 没连接，**停下来让用户安装它**，不要降级到别的方案。

第一次操作前用 `mcp__Claude_in_Chrome__tabs_context_mcp` 看用户的现有 tab。如果用户已经打开了 ChatGPT tab，复用它；否则用 `tabs_create_mcp` 开一个新的，再 `navigate` 到 `https://chatgpt.com/`。

## 操作流程

只 4 条原则，不写选择器、不写 DOM 路径、不写按钮坐标。每一步都先 `read_page` 或 `find` 看见再动。

### 1. 进入正确的上下文

- 用户提到项目（例如"在 GI2 项目里问"）→ 从侧栏找到项目 → **点 "打开项目首页" 按钮**（hover 时出现）而不是项目名按钮（后者只展开/折叠子项列表）→ 进入项目主页后再写 prompt。详细流程见 [examples/project-context-consult.md](examples/project-context-consult.md)
- 用户要继续某个旧会话 → 从侧栏"最近"或 URL 直接进
- 始终记下 conversation URL，后面要用

**记 conversation URL 时**：普通对话 `/c/<uuid>`，项目内对话 `/g/g-p-<uuid>/c/<uuid>`（项目名命名后还可能带 `-<slug>`）。完整 6 种 URL 形态见 [references/manage-actions.md](references/manage-actions.md) 第 7 节。

**"是否在项目里"的可靠视觉信号**：composer placeholder 是 **"<项目名>中的新聊天"** 才算真在项目里；如果是 "有问题，尽管问" 那就是普通对话上下文，知识库不会自动可见。

### 2. 模型选择

- 用户指定了模型（Instant / Thinking / Pro / 别的命名都可能） → 点 composer 右下角的模型 pill，选最接近的可见项
- 用户没指定 → 用当前选中的，不主动换
- 切不到要求的模型 → **不静默换成别的**。报告 UI 上看到的实际选项，让用户决定
- 模型名是会变的（5.5 改 5.6、新加 "Express"、Pro 改名"进阶专业"），靠**可见文本**和 ARIA 标签判断，不靠固定列表

### 3. Apps / 文件 / 图片

#### Apps（连接器）

- `+` 按钮 → 当前看到的子项：添加照片和文件 / 近期文件 / 创建图片 / 深度研究 / 网页搜索 / 更多 → / 项目 →
- "更多 →" 才是 apps（Canva / GitHub / Gmail / Google 云端硬盘 / Linear / OpenAI Platform 等，未来还会加）
- **不要根据模型名推断 app 可用性**。Pro 也可以用 apps（已经在 2026-05 验证过用 Pro + @Google 云端硬盘 列文件、Pro + @GitHub 评估 PR 是否可合并）。直接 `@app` 试 → 看到 app chip / 检索卡片 / source 引用就成功
- 如果 app 没连接或要 OAuth → **停下来让用户去授权**（参见 [references/error-and-limits.md](references/error-and-limits.md) 第 5 节），绝不替用户点同意

#### 文件 / 图片上传 — 暂不可用

Claude Code MCP 桥接 bug（[#31210](https://github.com/anthropics/claude-code/issues/31210)），`file_upload` 调用任意本地路径都被白名单拒绝。**让用户自己在浏览器里上传**（点 `+` 或拖图进 composer），主 Claude 接管后续：`read_page` 验证 chip 出现 → 写 prompt → send → spawn watcher。

### 4. 提交后

记下三件事，写进当前对话上下文（不需要文件持久化）：

- ChatGPT conversation URL
- 选了哪个模型、用了哪些 app / 文件
- 用户原始诉求（一句话即可）

然后进入"异步等待"模式（见下面）。

## 完成判定

Watcher 模式下完成判定**由 watcher 做**，详见 [references/watcher-subagent.md](references/watcher-subagent.md) 的工作循环步骤 5。

Fallback / 主 Claude 直接判定的简版（中文 UI 实测）：

- 没有"思考中 / 正在搜索 / 正在分析"字样
- 末尾出现 "ChatGPT 也可能会犯错。请核查重要信息。" disclaimer
- 底部 composer 区回到可输入态（不是 stop 按钮）

拿不全（被截断、太长）→ 标注"可能不完整" + 留 conversation URL。具体错误信号见 [references/error-and-limits.md](references/error-and-limits.md) 第 7 节"Continue generating 截断"。

## 异步等待

**主推方案：spawn 一个 background Haiku watcher subagent**。详细见 [references/watcher-subagent.md](references/watcher-subagent.md)。

核心：

- 提交完任务后，用 `Agent({ run_in_background: true, subagent_type: 'general-purpose', model: 'haiku', prompt: <watcher prompt> })` 起一个 watcher
- Watcher 用 `mcp__Claude_in_Chrome__read_page` 循环检查页面，看到完成才 `get_page_text` 拉全文返回
- 主 LLM 提交完就解放，把控制权交回用户，**完全沉默**直到 watcher 通知到来
- Watcher 完成时 Claude Code 会把它的 return 作为通知交付给主 LLM
- 主 LLM 拿到 watcher 的完整输出后给用户

**为什么用 Haiku 而不是 Sonnet 跑 watcher**：
- 判断"页面是不是还在生成"这种任务 Haiku 完全够用
- 一次 5-10 分钟的监控 ~80k token，跟让主 Sonnet 反复唤醒比便宜一个数量级
- 主 Sonnet 上下文完全不被消耗

**Watcher 不许做**：
- 不许 `navigate`（会抢用户浏览器焦点）
- 不许开新 tab / 切 tab / 点页面任何按钮
- 不许给主 Claude 发中间状态
- 累计等待硬上限 30 分钟（1800s），到了带 "TIMEOUT" 返回当前可见内容

**Fallback：环境不支持 Agent 工具（纯 SDK 调用等）→ 用 `scripts/heartbeat.sh`**，详见 [references/claude-code-async.md](references/claude-code-async.md)。fallback 模式下主 LLM 在每轮唤醒时**静默检查**，未完成不打扰用户。

## 绝对不做

1. **不导出、不复制、不保存** cookie / storage_state / OAuth token / localStorage
2. **不绕过** 登录、MFA、CAPTCHA、付费墙、speed limit
3. **不替用户授权** OAuth / 第三方 app / 隐私同意，看到就停下来交还
4. **不下载文件**（用户没明确同意单个文件下载之前；下载需要单独确认）
5. **不在 ChatGPT 里发送 cookie / API key / 银行卡 / 身份证号 / 私钥**，哪怕用户原始请求里包含——明确停下来拒绝

## 失败时怎么办

详细见 [references/error-and-limits.md](references/error-and-limits.md)。**总原则**：

- 不要"重试一次再说"——除了网络瞬时抖动可以重试 1 次
- 不要静默降级模型 / 替用户授权 / 替用户回答 clarification
- 直接报告**当前在 ChatGPT 页面上看到的可见文本**，原样引述
- 让用户决定下一步

[references/error-and-limits.md](references/error-and-limits.md) 里逐一列了 10 种常见错误/限流场景的可见信号和处理方式（速率限制、Pro 配额、模型不可用、CAPTCHA、OAuth、session 过期、Continue generating 截断、中途反问、文件上传失败、整体故障）。

## 管理 ChatGPT（删/归档/分享/Memory/项目/库）

用户说"删了这个对话"、"归档全部"、"撤销那个分享"、"清掉 Memory"、"创建一个项目"、"看库里有什么"等管理类操作时，按 [references/manage-actions.md](references/manage-actions.md) 找入口和 cheat sheet。

**特别注意 3 条**（详细规则见 reference 第 8 节"安全总则"）：

1. **点开"分享"弹窗 = 立刻创建公开 URL**，哪怕不复制不发送。没用户明确授权前别点
2. **删项目 = 永久删项目内所有对话**，二次确认前要用户口头同意
3. **删对话不清 Memory**，删完后提醒用户单独去个性化 → 记忆里清

## Examples

[examples/](examples/) 里有几个典型场景示范：

- `auto-google-drive-list.md` — 默认模型 + @Google 云端硬盘 列文件
- `thinking-github-unread-issues.md` — Thinking 模式 + @GitHub 查个人未读 issues
- `deep-research-trigger.md` — 用提示词触发 deep research 并异步等待
- `pro-github-pr-review.md` — Pro 模型 + @GitHub 对 PR 做深度 review（含实测：5m 7s）
- `project-context-consult.md` — 进项目主页 + 利用项目知识库（含实测：DSE 数学 Pro 21m 5s）
