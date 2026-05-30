<p align="center">
  <img src="./assets/banner.svg" alt="chatgpt-skill — a blue Codex robot and an orange Claude Code robot operate a central ChatGPT sphere" width="100%">
</p>

<h1 align="center">chatgpt-skill</h1>

<p align="center">
  <b>给 Claude Code 用的 ChatGPT.com 操作手册。</b><br>
  让 Claude Code 复用你已经登录的 ChatGPT 订阅 —— 不复制 cookie、不存 session、不要 API key。
</p>

<p align="center">
  <a href="https://github.com/Wangnov/chatgpt-skill/releases"><img src="https://img.shields.io/badge/version-v0.7.3-4f46e5?label=skill" alt="Skill version"></a>
  <a href="https://www.npmjs.com/package/skills"><img src="https://img.shields.io/badge/install-npx%20skills%20add-38bdf8?logo=npm&logoColor=white" alt="Install via npx skills add"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/Wangnov/chatgpt-skill?color=2ea44f" alt="License"></a>
  <img src="https://img.shields.io/badge/platform-macOS-555?logo=apple&logoColor=white" alt="Platform">
  <img src="https://img.shields.io/badge/primary%20host-Claude%20Code-orange" alt="Primary host">
  <img src="https://img.shields.io/badge/browser%20MCP-claude--in--chrome-9b6cff" alt="claude-in-chrome MCP">
</p>

<p align="center">
  <a href="#readme-zh">中文</a> · <a href="#readme-en">English</a>
</p>

<p align="center">
  Watcher subagent · Pull-mode 跨小时任务 · 聊天记录 3 档落盘 · ChatGPT 管理面（删 / 归档 / Memory）· 安全优先
</p>

---

<a id="readme-zh"></a>

## 🇨🇳 中文

`chatgpt-skill` 是一个**手册式 Skill** —— 不是 CLI、不是 wrapper，而是一份给 **Claude Code** 看的操作手册。装上后，Claude Code **复用你已经登录的 ChatGPT 网页**来完成咨询委托、深度研究、对话管理、内容落盘。

整套机制**强制走 [`claude-in-chrome` MCP](https://chromewebstore.google.com/)** —— Claude Code 像一个会用浏览器的人一样操作 ChatGPT.com，**不发起独立的自动化浏览器**（禁 Playwright / Puppeteer / `computer-use`）、**不接触 cookie / session / API key**。

> **Host 范围**：所有操作指令、watcher 异步等待、所有实测都在 **Claude Code** 上完成。Skill 文件本身是通用 Markdown，理论上其他能加载 Markdown skill 的 MCP host（Codex CLI、Cursor、Cline 等）也能读到指令，但 watcher 用的是 Claude Code 自家的 `Agent({ run_in_background: true, … })` API —— 其他 host 需要自己提供等价的 background-subagent 模式才能跑异步等待。当前版本未针对其他 host 做适配验证。

### ✨ 特性

- 📦 **零依赖** —— 一份 Markdown Skill，`npx skills add` 一键装好
- 🌐 **复用浏览器登录态** —— 你在 Chrome 已登录的 ChatGPT 订阅 + 已连接的 Apps（Drive / GitHub / Gmail / Linear / Canva），全部直接可用
- ⚡ **Watcher subagent 异步等待** —— 主 Claude `Agent({ run_in_background: true, model: 'haiku' })` 起一个后台 watcher 轮询页面，主 Sonnet 全程沉默，watcher 完成才通知（实测 21 分钟 Pro 任务，**主 Sonnet 0 次被打扰**，watcher 消耗 ~86k Haiku token）
- 🐢 **Pull 模式跨小时任务** —— Deep Research 跑几小时是常态，**不挂 watcher**：主 Claude 提交后直接报 conversation URL 走人，用户回来（哪怕新 session、新设备）说一声"看那个 DR" 即可取回
- 💾 **聊天记录落盘** —— 3 档分流：普通 message 走 `get_page_text` + Markdown；DR / Canvas artifact 走 artifact 自带的"导出到 Markdown"；图片走"分享此图片→下载"
- 🛠️ **ChatGPT 管理面全覆盖** —— 对话级（删 / 归档 / 分享 / 置顶 / 移项目）、项目级（创建 / 指令 / 知识库 / 删除）、Memory、库、共享链接撤销，每个操作都标注了 GUI 易踩的坑
- 🛡️ **安全优先** —— 不绕 OAuth / 不替用户授权 / 不存 session / 不替用户回答 clarification / 破坏性操作要用户口头确认
- 📚 **手册式而非工程式** —— 不写 selector / 不写状态机 / 不写 manifest schema，全部靠 LLM 当场视觉判断；遇到 ChatGPT UI 漂移时 agent 能自适应

### 🚀 快速开始

**前置依赖**：

- 装好 Claude Code（[官方安装文档](https://docs.anthropic.com/claude/docs/claude-code)）
- 装好 [`claude-in-chrome` Chrome 扩展](https://chromewebstore.google.com/) 并把它的 MCP server 连到 Claude Code
- Chrome 浏览器登录任意 ChatGPT 计划（Plus / Pro / Enterprise 都行）

**一行装好**：

```bash
# 装给 Claude Code（推荐，主要测试 host）
npx skills add Wangnov/chatgpt-skill -g -a claude-code -y

# 或者装到通用 ~/.agents/skills/，让任何支持 Markdown skill 的 host 都能加载
npx skills add Wangnov/chatgpt-skill -g -a '*' -y
```

**用法** —— 直接对 Claude Code 说：

```
"问问 ChatGPT Pro 怎么看这件事"
"让 Thinking 模式分析一下这个 PR"
"用 @Google 云端硬盘 列一下我的文件"
"提交个 deep research，列五家竞品"
"在 DSE 数学项目里问 X"
"把这个对话存下来"
"删了那个对话"
"清掉我的 Memory"
```

Claude Code 自动按 Skill 手册流程操作 ChatGPT 网页 + 异步等待 + 取回结果。

### 🧠 模型矩阵

| ChatGPT 模型 | 推荐 watcher sleep | 实测典型耗时 | 用例 |
|---|---|---|---|
| Instant（默认）| 20–30 秒 | < 30 秒 | 简单咨询、画图、单段写作 |
| Thinking · 深入 | 30–60 秒 | 1–3 分钟 | 中等推理、issue 检索、归纳 |
| Pro · 进阶 | 60 秒 | 5–10 分钟（最长实测 21m） | PR 评审、长 PDF 推理、深度分析 |
| Deep Research | **Pull 模式**，不轮询 | 30 分钟 – 几小时 | 多源调研报告 + 22+ 引用 |

模型名是漂移的（5.5 → 5.6 → "进阶专业" 等），Skill 靠**可见文本和 ARIA 标签**判断，不硬编码列表。

### 🎯 设计原则

1. **手册式而非工程式** —— 写"看到 X 就做 Y"，不写"点击 button[aria-label='Send']"。UI 漂移时 LLM 自适应
2. **信任 LLM 当场判断** —— 不堆 if-else 状态机，给原则不给脚本
3. **异步原生** —— Watcher subagent + Pull 模式两套，分别对应"几分钟"和"几小时"两个时间尺度
4. **安全优先** —— 8 条安全总则（详见 [`references/manage-actions.md`](references/manage-actions.md) 第 8 节）
5. **失败做减法** —— *failed run 比 success run 更值得写进文档*。3 次实测 watcher 误判直接驱动了 v0.6 用 `get_page_text` 取代 `read_page` 的修复

### 🗂️ 项目结构

```
SKILL.md                       # 主指令（Claude Code 入口）
scripts/heartbeat.sh           # fallback：纯 shell heartbeat（非 Agent 环境用）
references/
  watcher-subagent.md          # 主推异步方案 + NEEDS_USER_INPUT + 失败教训
  claude-code-async.md         # heartbeat fallback 文档
  error-and-limits.md          # 10 种错误/限流场景的可见信号与处理
  manage-actions.md            # 对话/项目/Memory/库 管理操作手册（235 行）
  save-conversation.md         # 聊天记录落盘 3 档分流（240 行）
examples/                      # 6 个端到端实测场景
  auto-google-drive-list.md
  thinking-github-unread-issues.md
  deep-research-trigger.md
  pro-github-pr-review.md
  project-context-consult.md
  save-conversation.md
assets/                        # 项目视觉资产（logo / banner）
CHANGELOG.md                   # v0.2 → v0.7.3 完整演进
```

### ✅ 实测覆盖

全部实测均在 **Claude Code + claude-in-chrome MCP** 上完成（2026-05）：

| 场景 | 模型 | 实测结果 |
|---|---|---|
| @Google 云端硬盘 列文件 + 归纳 | Thinking | 14 秒完成 |
| @Google 云端硬盘 推断工作轨迹 | Pro | 5m 25s |
| @GitHub PR 评审 | Pro + watcher | 5m 7s，主 Sonnet 0 次被打扰 |
| @GitHub `rust-silk` 全仓库 review | Pro + watcher | 16m 14s，6 P1 + 9 P2 + 落地顺序 |
| @GitHub `codex-asr` 全仓库 review | Pro + watcher | 18m 56s（两轮），6 P1 + 10 P2 + 4 阶段路线图 |
| DSE 数学项目知识库（10+ PDF）| Pro 项目内 | 21m 5s，watcher 累计 19 分钟 |
| Deep Research 横向竞品对比 | DR | 55 分钟，22 source、279 网页搜索 |
| Instant 生成图片 + 保存 | Instant | 30 秒，PNG 自动落 ~/Downloads/ |
| ChatGPT 给的 PDF 链接下载 | — | 浏览器原生通道，~/Downloads/ |
| 聊天记录档 A 落盘（19.5KB / 399 行 .md）| — | YAML frontmatter + 完整对话历史 |
| 删除对话 / 归档 / 项目创建 / Memory 管理 / 共享链接撤销 | — | 全部端到端跑通 |

### ⚠️ 已知限制

#### 1. `file_upload` 在 Claude Code 里永久不可用

2026-05-31 用户用 codex 反编译 Claude app 确认了根因：

- Claude app 的 `validateLocalFileAccess` 要求 **session id 以 `local_` 开头**才放行
- Claude Code 的 session 是普通 UUID（`c9cf...`），**永远过不了这关** —— 不是 bug 是产品边界
- 错误信息 `only files the user has shared with this session can be uploaded` 是**误导性的** —— 它不区分"session 类型不对" vs "路径没共享"

| Host | session 模式 | `file_upload` |
|---|---|---|
| **Claude Code** | 普通 UUID（`c9cf...`）| ❌ **第一关就拒，让用户自己拖文件到浏览器** |
| **Claude Cowork**（local-agent-mode）| `local_*` | ✅ 但路径限 `local-agent-mode-sessions/.../uploads/` 或 `userSelectedFolders` |
| 其他 host（Codex CLI / Cursor / …）| 未测 | 取决于其 session 是否会过 Claude app 的 `validateLocalFileAccess`；多数应该不依赖这个验证模型 |

**Claude Code 唯一可行方案**：让用户自己在浏览器里上传（点 `+` 或拖图进 composer），主 Claude 接管后续：`read_page` 验证 chip 出现 → 写 prompt → send → spawn watcher。

详细诊断见 [CHANGELOG.md](CHANGELOG.md) v0.7.1 章节。

#### 2. Watcher 异步等待是 Claude Code 专属

Watcher 模式用的是 `Agent({ run_in_background: true, subagent_type: 'general-purpose', model: 'haiku', prompt: ... })`，这是 Claude Code 的 Agent tool API。其他 MCP host（Codex CLI、Cursor 等）装上这个 Skill 后，**operational 流程读得到，但 watcher 段需要 host 各自的 background-subagent 等价物**。当前版本未对其他 host 做适配验证 —— 欢迎 PR。

### 📜 Changelog

完整演进历史见 [CHANGELOG.md](CHANGELOG.md)：

- **v0.7.3** —— Logo / banner 重设计（机器人操控 ChatGPT）+ CSS 动画 banner + README 口径更正
- **v0.7.2** —— 自制 logo / 动画 banner / 双语 README 重写
- **v0.7.1** —— file_upload 根因从 "bug" 修正为 "session 类型边界"
- **v0.7** —— 聊天记录落盘 3 档分流
- **v0.6** —— Deep Research Pull 模式 + DR UI 状态信号
- **v0.6** —— watcher 用 `get_page_text` 取代 `read_page`（避免 max_chars 截断）
- **v0.5** —— 产物下载（PDF / 图片）
- **v0.4** —— ChatGPT 管理操作手册
- **v0.3** —— Watcher subagent + 错误处理 reference
- **v0.2** —— SKILL.md 主指令 + heartbeat fallback + 5 examples

### 📄 License

MIT © 2026 wangnov

---

<a id="readme-en"></a>

## 🇬🇧 English

`chatgpt-skill` is a **manual-style Skill** — not a CLI, not a wrapper — a single Markdown playbook that **Claude Code** loads. Once installed, Claude Code **reuses your already-logged-in ChatGPT subscription** to delegate consultations, run deep research, manage conversations, and save outputs to disk.

Everything runs through the **[`claude-in-chrome` MCP](https://chromewebstore.google.com/)** (mandatory — no Playwright / Puppeteer / `computer-use` fallback). Claude Code operates ChatGPT.com like a human would — **no headless browser**, **no cookie / session / API key extraction**.

> **Host scope**: All operational instructions, watcher async-wait, and all field-tested scenarios are on **Claude Code**. The Skill file itself is plain Markdown, so any MCP host that can load Markdown skills (Codex CLI, Cursor, Cline, …) will see the playbook. But the watcher relies on Claude Code's own `Agent({ run_in_background: true, … })` API — other hosts need to provide their own equivalent background-subagent primitive to run the async-wait pattern. Other-host adaptation is not currently validated.

### ✨ Features

- 📦 **Zero dependencies** — a single Markdown skill, install with `npx skills add`
- 🌐 **Reuse browser login** — your already-signed-in Chrome ChatGPT + connected Apps (Drive / GitHub / Gmail / Linear / Canva) all work out of the box
- ⚡ **Watcher subagent for async waits** — main Claude spawns a background Haiku watcher (`Agent({ run_in_background: true, model: 'haiku' })`) that polls the page silently; main Sonnet stays quiet until the watcher returns (verified on a 21-minute Pro task: **main Sonnet interrupted 0 times**, watcher used ~86k Haiku tokens)
- 🐢 **Pull mode for hours-long tasks** — Deep Research routinely runs hours; the main agent submits, hands you the URL, and walks away. Come back later (new session, new device) and just say *"check that DR"*
- 💾 **Conversation save-to-disk** — 3 tiers: plain chat via `get_page_text` + Markdown; DR / Canvas artifacts via the artifact's built-in export; images via "share-image → download"
- 🛠️ **Full ChatGPT management surface** — conversation level (delete / archive / share / pin / move-to-project), project level (create / instructions / sources / delete), Memory, library, share-link revocation, with every GUI footgun documented
- 🛡️ **Safety-first** — never bypass OAuth, never authorize on the user's behalf, never persist session, never answer clarifications for the user, destructive ops require verbal confirmation
- 📚 **Manual-style, not engineered** — no selectors / no state machines / no manifest schemas; the LLM decides on-screen. When ChatGPT's UI drifts, the agent adapts.

### 🚀 Quick start

```bash
# Claude Code only (recommended — this is the tested host)
npx skills add Wangnov/chatgpt-skill -g -a claude-code -y

# Or install globally so any agent loading ~/.agents/skills/ can read the playbook
npx skills add Wangnov/chatgpt-skill -g -a '*' -y
```

Then just talk to Claude Code:

```
"Ask ChatGPT Pro to review this PR"
"Use Thinking to summarize my unread GitHub issues via @GitHub"
"Submit a deep research on Q3 competitors"
"Save that conversation to disk"
"Delete that chat and clean its Memory"
```

### 🧠 Model matrix

| ChatGPT model | Recommended watcher sleep | Typical wall-clock | Use case |
|---|---|---|---|
| Instant (default) | 20–30s | < 30s | Quick Q&A, image gen, short writing |
| Thinking | 30–60s | 1–3 min | Mid-depth reasoning, search, summarization |
| Pro | 60s | 5–10 min (max observed 21m) | PR review, long-PDF inference, deep analysis |
| Deep Research | **Pull mode**, no polling | 30 min – several hours | Multi-source research with 22+ citations |

Model names drift (5.5 → 5.6 → "进阶专业" etc.). The skill matches on visible text and ARIA labels, never hardcoded names.

### ⚠️ Known limitations

#### 1. `file_upload` is permanently unavailable in Claude Code

Root cause confirmed 2026-05-31 by reverse-engineering Claude app with codex:

- Claude app's `validateLocalFileAccess` requires the session id to begin with `local_`
- Claude Code sessions are plain UUIDs (`c9cf...`) and will **never** pass this gate — this is a **product boundary, not a bug**
- The error message `only files the user has shared with this session can be uploaded` is **misleading**: it does not distinguish "wrong session type" from "path not shared"

To upload local files into ChatGPT, you must either (a) have the user manually drag/drop in the browser, or (b) use **Claude Cowork** (local-agent-mode, `local_*` sessions). Other MCP hosts (Codex CLI, Cursor, …) likely don't pass through Claude app's `validateLocalFileAccess` at all, but this is untested. Full diagnosis in [CHANGELOG.md](CHANGELOG.md) v0.7.1.

#### 2. Watcher async-wait is Claude-Code-specific

The watcher pattern uses Claude Code's `Agent({ run_in_background: true, subagent_type: 'general-purpose', model: 'haiku', … })` API. Other MCP hosts will read the operational playbook fine, but the watcher section requires each host to supply its own background-subagent equivalent. Not currently validated on other hosts — PRs welcome.

### 📄 License

MIT © 2026 wangnov
