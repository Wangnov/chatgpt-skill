<p align="center">
  <img src="./assets/banner.svg" alt="chatgpt-skill — Codex (blue) and Claude Code (orange) orbit ChatGPT (black core)" width="100%">
</p>

<h1 align="center">chatgpt-skill</h1>

<p align="center">
  <b>Drive ChatGPT.com from Codex CLI &amp; Claude Code.</b><br>
  Two agent CLIs sharing one already-logged-in ChatGPT subscription — no API key, no scraping, no cookie export.
</p>

<p align="center">
  <a href="https://github.com/Wangnov/chatgpt-skill/releases"><img src="https://img.shields.io/badge/version-v0.7.2-4f46e5?label=skill" alt="Skill version"></a>
  <a href="https://www.npmjs.com/package/skills"><img src="https://img.shields.io/badge/install-npx%20skills%20add-38bdf8?logo=npm&logoColor=white" alt="Install via npx skills add"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/Wangnov/chatgpt-skill?color=2ea44f" alt="License"></a>
  <img src="https://img.shields.io/badge/platform-macOS-555?logo=apple&logoColor=white" alt="Platform">
  <img src="https://img.shields.io/badge/hosts-Claude%20Code%20·%20Codex%20CLI%20·%20Cursor%20·%20Cline-orange" alt="Hosts">
  <img src="https://img.shields.io/badge/zero-cookie%20·%20session%20·%20api%20key-9b6cff" alt="Zero credentials">
</p>

<p align="center">
  <a href="#readme-zh">中文</a> · <a href="#readme-en">English</a>
</p>

<p align="center">
  Watcher subagent · pull-mode for Deep Research · 3-tier conversation save · ChatGPT management (delete / archive / Memory) · safety-first
</p>

---

<a id="readme-zh"></a>

## 🇨🇳 中文

`chatgpt-skill` 是一个**手册式 Skill** —— 不是 CLI、不是 wrapper，而是一份给 **Codex CLI** 和 **Claude Code** 看的操作手册。两个 agent 装上后，**复用你已经登录的 ChatGPT 网页** 来完成咨询委托、深度研究、对话管理、内容落盘。

整套机制走 **`claude-in-chrome` MCP**（或同等浏览器接入工具）—— 主 Agent 像一个会用浏览器的人一样操作 ChatGPT，**不发起独立的自动化浏览器**、**不接触 cookie / session / API key**。

### ✨ 特性

- 📦 **零依赖** — 一份 Markdown Skill，`npx skills add` 一键装好
- 🤖 **双主线 Host** — Codex CLI（OpenAI 自家 agent）和 Claude Code（Anthropic 官方 agent）都吃这套手册
- 🌐 **复用浏览器登录态** — 用户在 Chrome 已登录的 ChatGPT 订阅 + 已连接的 Apps（Drive / GitHub / Gmail / Linear / Canva），全部直接可用
- ⚡ **Watcher subagent 异步等待** — 主进程 spawn 一个 Haiku watcher 在后台轮询页面，主 Agent 全程沉默，watcher 完成才通知（实测 21 分钟 Pro 任务，主 Sonnet 0 次被打扰）
- 🐢 **Pull 模式跨小时任务** — Deep Research 跑几小时常态，不挂 watcher：主 Agent 提交后直接报 URL 走人，用户回来（哪怕新 session、新设备）说一声"看那个 DR" 即可取回
- 💾 **聊天记录落盘** — 3 档分流：普通 message 走 `get_page_text` + Markdown / DR Canvas 走 artifact 自带导出 / 图片走"分享此图片→下载"
- 🛠️ **ChatGPT 管理面全覆盖** — 对话级（删/归档/分享/置顶/移项目）、项目级（创建/指令/知识库/删除）、Memory、库、共享链接撤销，每个操作都标注了 GUI 易踩的坑
- 🛡️ **安全优先** — 不绕 OAuth / 不替用户授权 / 不存 session / 不替用户回答 clarification / 破坏性操作要用户口头确认
- 📚 **手册式而非工程式** — 不写 selector / 不写状态机 / 不写 manifest schema，全部靠 LLM 当场视觉判断；遇到 ChatGPT UI 漂移时 agent 能自适应

### 🚀 快速开始

**前置依赖**：

- 装好 Claude Code 或 Codex CLI（至少装一个）
- 装好 `claude-in-chrome` Chrome 扩展并连接 MCP server
- Chrome 浏览器登录任意 ChatGPT 计划（Plus / Pro / Enterprise 都行）

**一行装好**：

```bash
# 装给 Claude Code 专用
npx skills add Wangnov/chatgpt-skill -g -a claude-code -y

# 或者装给所有 agent（Claude Code / Codex / Cursor / Cline / …40+）
npx skills add Wangnov/chatgpt-skill -g -a '*' -y
```

**用法** —— 直接对你的 agent 说：

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

Agent 自动按 Skill 手册流程操作 ChatGPT 网页 + 异步等待 + 取回结果。

### 🧠 模型矩阵

| ChatGPT 模型 | 推荐 sleep 间隔 | 实测典型耗时 | 用例 |
|---|---|---|---|
| Instant | 20–30 秒 | < 30 秒 | 简单咨询、画图、单段写作 |
| Thinking · 深入 | 30–60 秒 | 1–3 分钟 | 中等推理、issue 检索、归纳 |
| Pro · 进阶 | 60 秒 | 5–10 分钟 | PR 评审、长 PDF 推理、深度分析 |
| Deep Research | **Pull 模式**，不轮询 | 30 分钟 – 几小时 | 多源调研报告 + 22+ 引用 |

模型名是漂移的（5.5 → 5.6 → 进阶专业 等），Skill 靠**可见文本和 ARIA 标签**判断，不硬编码列表。

### 🤖 Agent Host 兼容性

| Host | 状态 | 备注 |
|---|---|---|
| **Claude Code** | ✅ 主推 | 实测最多。subagent + Bash run_in_background:true 支持 watcher 异步 |
| **Codex CLI** | ✅ 主推 | 用 `npx skills add ... -a '*'` 装到 `~/.agents/skills/` 通用位置后 Codex 也能识别 |
| **Cursor / Cline / Augment / Amp / Antigravity / OpenClaw / Dexto / Hermes** | ✅ 兼容 | 同上通用安装，未单独实测但 Skill 是 Markdown 不依赖特定 host 工具 |
| Claude Cowork（local-agent-mode）| ✅ 唯一能用 `file_upload` 的 host | 见下面"已知限制" |

### 📐 设计原则

1. **手册式而非工程式** — 写"看到 X 就做 Y"，不写"点击 button[aria-label='Send']"。UI 漂移时 LLM 自适应
2. **信任 LLM 当场判断** — 不堆 if-else 状态机，给原则不给脚本
3. **异步原生** — Watcher subagent + Pull 模式两套，分别对应"几分钟"和"几小时"两个时间尺度
4. **安全优先** — 8 条安全总则（详见 `references/manage-actions.md` 第 8 节）
5. **失败做减法** — `failed run 比 success run 更值得写进文档`。3 次实测 watcher 误判直接驱动了 v0.6 用 `get_page_text` 取代 `read_page` 的修复

### 🗂️ 项目结构

```
SKILL.md                       # 主指令（agent 入口）
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
CHANGELOG.md                   # v0.2 → v0.7.2 完整演进
```

### ✅ 实测覆盖

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

**`file_upload` 在 Claude Code 里永久不可用**（2026-05-31 codex 反编译 Claude app 确认根因）：

- Claude app 的 `validateLocalFileAccess` 要求 **session id 以 `local_` 开头**才放行
- Claude Code 的 session 是普通 UUID（`c9cf...`），**永远过不了这关** —— 不是 bug 是产品边界
- 错误信息 `only files the user has shared with this session can be uploaded` 是**误导性的** —— 它不区分 "session 类型不对" vs "路径没共享"

| Host | session 模式 | `file_upload` |
|---|---|---|
| Claude Code / Codex CLI | 普通 UUID | ❌ 第一关就拒，**让用户自己拖文件到浏览器** |
| Claude Cowork（local-agent-mode）| `local_*` | ✅ 但路径限 `local-agent-mode-sessions/.../uploads/` 或 `userSelectedFolders` |

详细诊断见 [CHANGELOG.md](CHANGELOG.md) v0.7.1 章节。

### 📜 Changelog

完整演进历史见 [CHANGELOG.md](CHANGELOG.md)：

- **v0.7.2** — 自制 logo / 动画 banner / 双语 README 重写
- **v0.7.1** — file_upload 根因从 "bug" 修正为 "session 类型边界"
- **v0.7** — 聊天记录落盘 3 档分流
- **v0.6** — Deep Research Pull 模式 + DR UI 状态信号
- **v0.6** — watcher 用 `get_page_text` 取代 `read_page`（避免 max_chars 截断）
- **v0.5** — 产物下载（PDF / 图片）
- **v0.4** — ChatGPT 管理操作手册
- **v0.3** — Watcher subagent + 错误处理 reference
- **v0.2** — SKILL.md 主指令 + heartbeat fallback + 5 examples

### 📄 License

MIT © 2026 wangnov

---

<a id="readme-en"></a>

## 🇬🇧 English

`chatgpt-skill` is a **manual-style Skill** — not a CLI, not a wrapper — a single Markdown playbook that **Codex CLI** and **Claude Code** both load. Once installed, those agents **reuse your already-logged-in ChatGPT subscription** to delegate consultations, run deep research, manage conversations, and save outputs to disk.

Everything runs through the **`claude-in-chrome` MCP** (or any equivalent browser-control MCP). The agent operates ChatGPT.com like a human would — **no headless Playwright**, **no cookie / session / API key extraction**.

### ✨ Features

- 📦 **Zero dependencies** — a single Markdown skill, install with `npx skills add`
- 🤖 **Two primary hosts** — both Codex CLI (OpenAI's agent) and Claude Code (Anthropic's agent) execute the same playbook
- 🌐 **Reuse browser login** — your already-signed-in Chrome ChatGPT + connected Apps (Drive / GitHub / Gmail / Linear / Canva) all work out of the box
- ⚡ **Watcher subagent for async waits** — main agent spawns a background Haiku watcher that polls the page silently; main agent stays quiet until watcher returns (verified on a 21-minute Pro task, **main Sonnet interrupted 0 times**)
- 🐢 **Pull mode for hours-long tasks** — Deep Research routinely runs hours; the main agent submits, hands you the URL, and walks away. Come back later (new session, new device) and just say *"check that DR"*
- 💾 **Conversation save-to-disk** — 3 tiers: plain chat via `get_page_text` + Markdown; DR / Canvas artifacts via the artifact's built-in export; images via "share-image → download"
- 🛠️ **Full ChatGPT management surface** — conversation level (delete / archive / share / pin / move-to-project), project level (create / instructions / sources / delete), Memory, library, share-link revocation, with every GUI footgun documented
- 🛡️ **Safety-first** — never bypass OAuth, never authorize on the user's behalf, never persist session, never answer clarifications for the user, destructive ops require verbal confirmation
- 📚 **Manual-style, not engineered** — no selectors / no state machines / no manifest schemas; the LLM decides on-screen. When ChatGPT's UI drifts, the agent adapts.

### 🚀 Quick start

```bash
# Claude Code only
npx skills add Wangnov/chatgpt-skill -g -a claude-code -y

# Or all 40+ agents (Claude Code / Codex / Cursor / Cline / …)
npx skills add Wangnov/chatgpt-skill -g -a '*' -y
```

Then just talk to your agent:

```
"Ask ChatGPT Pro to review this PR"
"Use Thinking to summarize my unread GitHub issues via @GitHub"
"Submit a deep research on Q3 competitors"
"Save that conversation to disk"
"Delete that chat and clean its Memory"
```

### 🧠 Model matrix

| ChatGPT model | Recommended sleep | Typical wall-clock | Use case |
|---|---|---|---|
| Instant | 20–30s | < 30s | Quick Q&A, image gen, short writing |
| Thinking | 30–60s | 1–3 min | Mid-depth reasoning, search, summarization |
| Pro | 60s | 5–10 min | PR review, long-PDF inference, deep analysis |
| Deep Research | **Pull mode**, no polling | 30 min – several hours | Multi-source research with 22+ citations |

Model names drift (5.5 → 5.6 → "进阶专业" etc.). The skill matches on visible text and ARIA labels, never hardcoded names.

### ⚠️ Known limitation

**`file_upload` is permanently unavailable in Claude Code** (root cause confirmed 2026-05-31 by reverse-engineering Claude app with codex):

- Claude app's `validateLocalFileAccess` requires the session id to begin with `local_`
- Claude Code sessions are plain UUIDs (`c9cf...`) and will **never** pass this gate — this is a **product boundary, not a bug**
- The error message `only files the user has shared with this session can be uploaded` is **misleading**: it does not distinguish "wrong session type" from "path not shared"

To upload local files into ChatGPT, you must either (a) have the user manually drag/drop in the browser, or (b) use **Claude Cowork** (local-agent-mode, `local_*` sessions). Full diagnosis in [CHANGELOG.md](CHANGELOG.md) v0.7.1.

### 📄 License

MIT © 2026 wangnov
