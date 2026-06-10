---
name: codex-chatgpt-skill
description: 通过 Codex 和 Codex Chrome Extension 复用用户现有的、已登录的 ChatGPT 网页会话，把任务委托给任意 ChatGPT 模型，并管理对话/项目/Memory/库等，还能把对话/Artifact/图片落盘到本地。适合用户说"问问 ChatGPT / 让 GPT Pro 帮我想想 / 用 @Google 云端硬盘列一下 / 让 ChatGPT 做个 deep research / 删了这个对话 / 归档全部聊天 / 撤销那个分享 / 清掉 Memory / 创建一个项目 / 把这个对话存下来 / 下载那个 DR 报告 / 保留这张图片到本地"等。复用浏览器登录态，不导出 cookie/session，不发起独立浏览器 profile。
---

# codex-chatgpt-skill

让 Codex 像一个会用浏览器的人一样，**复用用户已登录的 ChatGPT 网页**，把任务交给指定的 ChatGPT 模型（Instant / Thinking / Pro 等），等结果回来。

## 何时触发

用户说类似下面的话：

- "问问 ChatGPT Pro 怎么看这件事"
- "让 Thinking 模式分析一下这个 PR"
- "用 @Google 云端硬盘列一下我的文件"
- "提交个 deep research，列五家竞品"
- "把这段代码扔给 GPT 让它批一遍"
- "等 ChatGPT 一会儿，结果出来叫我"

## 接入方式（强制）

| Host | 浏览器接入 | 禁止 |
|---|---|---|
| Codex | Codex Chrome Extension，经 `chrome:control-chrome` 技能和 `browser-client` 运行时操作用户 Chrome | `web.run`、独立 Playwright profile、Puppeteer、Computer Use 操作 Chrome、读取 cookie / localStorage / storage_state |

如果 Codex Chrome Extension 无法连接，按 `chrome:control-chrome` 的安装/修复指引停下来让用户处理，不要降级到别的浏览器自动化方案。

第一次操作前：

1. 使用 Chrome 技能初始化 `browser-client`。
2. 调用 `browser.user.openTabs()` 查看用户现有 tab。
3. 如果已有 ChatGPT tab，按标题/URL/最近使用时间选择并 `browser.user.claimTab(tab)` 复用。
4. 否则 `browser.tabs.new()` 新建 tab，再 `tab.goto("https://chatgpt.com/")`。
5. 对话结束前调用 `browser.tabs.finalize({ keep })`。等待用户继续操作、登录、授权、CAPTCHA 或长任务时，把 tab 作为 handoff 保留。

具体运行时模板见 [references/codex-chrome-runtime.md](references/codex-chrome-runtime.md)。

## 操作流程

只 4 条原则，不写固定坐标，不凭空猜选择器。每一步都先用 `domSnapshot()`、截图、或受限 `evaluate()` 看见再动。

### 1. 进入正确的上下文

- 用户提到项目（例如"在 GI2 项目里问"）→ 从侧栏找到项目 → 点 "打开项目首页" 按钮（hover 时出现）而不是项目名按钮 → 进入项目主页后再写 prompt。项目 URL 和安全规则见 [references/manage-actions.md](references/manage-actions.md)
- 用户要继续某个旧会话 → 从侧栏"最近"或 URL 直接进
- 始终记下 conversation URL，后面要用

**记 conversation URL 时**：普通对话 `/c/<uuid>`，项目内对话 `/g/g-p-<uuid>/c/<uuid>`（项目名命名后还可能带 `-<slug>`）。完整 6 种 URL 形态见 [references/manage-actions.md](references/manage-actions.md) 第 7 节。

**"是否在项目里"的可靠视觉信号**：composer placeholder 是 **"<项目名>中的新聊天"** 才算真在项目里；如果是 "有问题，尽管问" 那就是普通对话上下文，知识库不会自动可见。

### 2. 模型选择

- 用户指定了模型（Instant / Thinking / Pro / 别的命名都可能） → 先找当前页面可见的模型选择器；它可能在 composer 附近，也可能在顶部 banner 里。点开后选最接近的可见项
- 用户没指定 → 用当前选中的，不主动换
- 切不到要求的模型 → 不静默换成别的。报告 UI 上看到的实际选项，让用户决定
- 模型名和可见列表会变，免费/Plus/Pro 账户看到的项也不同。靠可见文本、placeholder、ARIA 标签和当前选中态判断，不靠固定列表

### 3. Apps / 文件 / 图片

#### Apps（连接器）

- `+` / `添加文件等` 菜单通常包含：添加照片和文件 / 近期文件 / 创建图片 / 思考一下 / 深度研究 / 网页搜索 / 更多 / 项目。具体文案会随账户、语言和 UI 漂移，点击前先看当前 snapshot
- Apps 入口有两条：`+` 菜单里的 `更多` 子菜单，或在 composer 里输入 `@` 后选择候选。当前实测 `@` 候选可直接出现 `深度研究` 以及 Canva / GitHub / Linear / OpenAI Platform 等 app
- 不要根据模型名或旧菜单列表推断 app 可用性。直接 `@app` 或当前可见菜单项试 → 看到 app chip / 检索卡片 / source 引用就成功
- Deep Research 也可能作为 `@深度研究` 候选激活。选中后可靠信号是 composer placeholder 变成 `获取详细报告`，出现 `深度研究` chip / `应用` 按钮 / `推荐`、`报告` 等 DR 专属控件；不要把 `+` 菜单当成唯一入口
- 如果 app 没连接或要 OAuth → 停下来让用户去授权（参见 [references/error-and-limits.md](references/error-and-limits.md) 第 5 节），绝不替用户点同意

#### 文件 / 图片上传

Codex Chrome Extension 支持浏览器 file chooser 流程。ChatGPT 实测优先使用可见菜单路径：`添加文件等` → `添加照片和文件`，先等待 `filechooser` 事件，再用绝对路径 `setFiles(...)`。详见 [references/codex-chrome-runtime.md](references/codex-chrome-runtime.md)。

不要直接点 ChatGPT 的底层 `input[type="file"]`，实测可能不触发 file chooser 事件。若 `setFiles(...)` 报 `Not allowed` / `fileChooser.setFiles failed`，去 Codex 扩展详情页开启 "Allow access to file URLs"（中文界面：`允许访问文件网址`）。不要改用 cookie、签名 URL、或系统级拖拽旁路。

#### 产物下载

- ChatGPT 给的下载链接（PDF/CSV/代码文件等）：用户明确同意单个文件下载后，点击链接走浏览器原生下载
- ChatGPT 生成的图片：图片底部没有显式"下载"，入口藏在"分享此图片"弹窗里，点弹窗最右侧橙色"下载"按钮
- 下载后用 `/bin/ls -lat ~/Downloads/ | head -7` 或文件名 pattern 找最新文件，再按用户要求移动/落盘
- 不读取、解析下载文件内容，除非用户明确要求
- 详细路径和坑见 [references/manage-actions.md](references/manage-actions.md) 第 6.5 节"产物下载"

### 4. 提交后

记下三件事，写进当前对话上下文（不需要文件持久化）：

- ChatGPT conversation URL
- 选了哪个模型、用了哪些 app / 文件
- 用户原始诉求（一句话即可）

然后进入等待模式（见下面）。

## 完成判定

完成判定优先从 `<main>` 文本拿全文，不要依赖截断的可访问性树。Codex 侧推荐：

```js
await tab.playwright.evaluate(() => document.querySelector("main")?.innerText ?? document.body?.innerText ?? "")
```

简版完成信号（中文 UI 实测）：

- 没有"思考中 / 正在搜索 / 正在分析 / Stop generating / Researching"字样
- 末尾出现 "ChatGPT 也可能会犯错。请核查重要信息。" disclaimer
- 底部 composer 区回到可输入态（不是 stop 按钮）

拿不全（被截断、太长）→ 标注"可能不完整" + 留 conversation URL。具体错误信号见 [references/error-and-limits.md](references/error-and-limits.md) 第 7 节。

## 等待模式

Codex 版不照搬 Claude 后台 watcher 模板。按任务时长分流，详见 [references/codex-waiting.md](references/codex-waiting.md)：

| 任务 | 默认模式 |
|---|---|
| Instant / 短 Thinking | 当前回合轮询，每 20-60 秒检查一次 |
| Pro / 长 Thinking | 当前回合轮询到 30 分钟上限；期间只在真正完成、超时或需要用户操作时发消息 |
| Deep Research / 跨小时任务 | Heartbeat 模式：确认研究已启动后挂安静轮询；automation 优先，spawn agent 作为默认 fallback |

轮询时不要给用户发"还在等"的例行状态。只有这些情况才报告：

- COMPLETE：完整回答已取回
- NEEDS_USER_INPUT：OAuth / CAPTCHA / login / clarification / Continue generating 等需要用户动作
- TIMEOUT：达到本轮上限，带当前可见内容和 URL
- ERROR：页面或浏览器控制失败

## 绝对不做

1. 不导出、不复制、不保存 cookie / storage_state / OAuth token / localStorage
2. 不绕过登录、MFA、CAPTCHA、付费墙、speed limit
3. 不替用户授权 OAuth / 第三方 app / 隐私同意，看到就停下来交还
4. 不下载文件（用户没明确同意单个文件下载之前；下载需要单独确认）
5. 不在 ChatGPT 里发送 cookie / API key / 银行卡 / 身份证号 / 私钥，哪怕用户原始请求里包含，明确停下来拒绝

## 失败时怎么办

详细见 [references/error-and-limits.md](references/error-and-limits.md)。总原则：

- 不要"重试一次再说"。除了网络瞬时抖动可以重试 1 次
- 不要静默降级模型 / 替用户授权 / 替用户回答 clarification
- 直接报告当前在 ChatGPT 页面上看到的可见文本，原样引述
- 让用户决定下一步

## 管理 ChatGPT（删/归档/分享/Memory/项目/库）

用户说"删了这个对话"、"归档全部"、"撤销那个分享"、"清掉 Memory"、"创建一个项目"、"看库里有什么"等管理类操作时，按 [references/manage-actions.md](references/manage-actions.md) 找入口和 cheat sheet。

特别注意：

1. 点开"分享"弹窗 = 立刻创建公开 URL，没用户明确授权前别点
2. 删除项目会永久删除项目内所有对话，二次确认前要用户口头同意
3. 删除对话不清 Memory，删完后提醒用户单独去个性化 → 记忆里清

## 聊天记录落盘到本地

用户说"把这个对话存下来"、"下载那个 DR"、"保留这张图片"等时，按 [references/save-conversation.md](references/save-conversation.md) 走 3 档分流：

| 档 | 内容 | 路径 |
|---|---|---|
| A | 普通 chat message | `<main>` 文本 + Codex 写 `.md` |
| B | Artifact（DR / Canvas）| 点 artifact 自带下载菜单 → "导出到 Markdown" → mv |
| C | 图片 | "分享此图片"→"下载" → mv |

默认目录 `~/Downloads/chatgpt-skill/`，文件名 `YYYY-MM-DD_<title>_<uuid8>.<ext>`。

显式触发：用户没说要存就不要自动写盘，避免污染硬盘。取回结果后用户回一句"存下来"才动手。

## Examples

[examples/](examples/) 里放 Codex 专属场景，不复用 Claude 版后台 watcher 模板：

- `file-upload-roundtrip.md` — 上传本地文件、提交带附件 prompt、等待完成、取回回答（已实测）
- `deep-research-pull.md` — 用 Codex 触发 Deep Research，启动后挂 heartbeat；automation 优先，spawn agent fallback，都没有才 Pull

Claude 版更完整的历史场景仍在 `claude-chatgpt-skill/examples/`，只能借鉴任务意图；不要照搬其中的 `Agent({ run_in_background: true })` / watcher 做法。

## 迁移状态

Claude 版的端到端 examples 保留在 `claude-chatgpt-skill/examples/`。Codex 版先以运行时、安全流程和专属 examples 为准。

当前烟测状态（2026-05-31）：停掉其它 Chrome debugger 控制方后，Codex Chrome Extension 可以复用用户已登录的 ChatGPT tab，读取页面结构和截图，展开模型菜单和 app 菜单，上传文件，提交带附件 prompt，等待完成并读取回答。已知阻塞形态仍是 `Detached while handling command` / `Unknown error`；出现时优先排查 Claude in Chrome、DevTools 或 `chrome-devtools-mcp` 等控制权冲突，详见 [references/codex-chrome-runtime.md](references/codex-chrome-runtime.md)。不要尝试 cookie / storage / 外部浏览器自动化旁路。
