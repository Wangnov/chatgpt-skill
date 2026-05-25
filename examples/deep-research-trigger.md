# Example: 触发 Deep Research（**Pull 模式**——跨小时任务的正解）

## 触发说法

- "让 ChatGPT 做个 deep research，调研一下 X 的竞品"
- "提交个深度研究任务，主题是 ..."
- "做一份 deep research 报告：[topic]"

## 意图解析

- **模型**：用户没指定 → 用当前模型；DR 跑起来后 ChatGPT 用 Pro 包装结果，跟模型选择独立
- **工具**：必须打开 `+` 菜单选 **"深度研究"**。激活后 composer placeholder 会变成 **"获取详细报告"**，下方出现 `+ / 深度研究 / 应用 / 站点 / Pro` 一组专属控件
- **预期产物**：30 分钟到几小时的长报告
- **核心模式选择**：**默认走 Pull 模式（不挂 watcher）**——下面详述

## Pull 模式 vs Watcher 模式

| 维度 | Watcher（v0.3 主推，**不适合 DR**） | **Pull（DR 默认）** |
|---|---|---|
| Claude Code session 需要在线 | 是（subagent 跟主 Claude 同 process） | **否** |
| 适合时长 | < 30 分钟 | 跨小时、跨 session、跨设备都行 |
| 取回方式 | watcher 自动通知主 Claude | 用户回来主动说"看 [URL] 那个 DR" |

**为什么 DR 必须 Pull**：DR 经常 1-6 小时。Claude Code session 不能跨小时（关电脑/合盖/进程被杀都会断），watcher subagent 跟主 Claude 同进程 → 主 Claude 死，watcher 也死。但 **ChatGPT 后端不依赖客户端在线**——关浏览器都没事，DR 照样在 OpenAI 服务器跑，conversation URL 永久存在。

## 操作步骤（Pull 模式）

1. `tabs_context_mcp` → 复用或创建 ChatGPT tab
2. 点 composer 的 `+` 按钮 → "深度研究"
3. **验证 DR 模式激活**：
   - composer placeholder 变成 **"获取详细报告"**（不是普通 "有问题，尽管问"）
   - composer 下方出现一行专属控件：`+ / 深度研究（蓝色 chip）/ 应用 / 站点 / Pro`
   - 没有这些视觉信号就**没进 DR 模式**，发送下去会变普通问答
4. 写 prompt：

   ```
   做一份深度调研报告：[用户给的主题]。
   要求：
   - 至少 10 个独立信息源（含中英文）
   - 每个核心论点要有 source citation
   - 末尾给一个"信息源 / 可信度 / 时间"表
   - 不要包括：[排除项]
   ```

5. **发送**——等 5 秒看 URL 出现
6. **关键：DR 不立刻跑！** 发送后会先弹一个"研究计划确认"卡片（5 步 todo + `[编辑] [取消] [开始 N]` 三个按钮 + N 秒倒计时）。这是 NEEDS_USER_INPUT 状态
7. **点 [开始]** 真正启动 DR（如果用户没明确反对，主 Claude 可以代点；如果用户预算敏感或想看研究方向，转交用户审阅 5 步计划再决定）
8. 看到第一步 checkbox 变成 ●（正在做）+ 底部"正在研究..."进度条 = DR 真正在跑
9. **不 spawn watcher**。**告诉用户**：

   ```markdown
   Deep Research 已提交并启动。
   
   - Conversation URL: <url>
   - 侧栏标题: "<标题>"
   - 研究计划: <5 步 todo 复述>
   
   这种任务通常 30 分钟到几小时。**你现在可以走开了**——
   关 Claude Code、关浏览器、合盖电脑都不影响，ChatGPT 后端会
   继续跑，conversation URL 永久存在。
   
   **回来时怎么取**（任选一种说法）：
   - "看一下 <URL> 那个 DR 出结果没"
   - "取一下我那个 '<标题>' DR 的结果"
   - "我之前提交了个 deep research，去看看跑完没"
   ```

## 用户回来取的流程

1. 主 Claude 用 `claude-in-chrome navigate` 到 conversation URL
2. `read_page` 看：
   - **5 步 todo 全部 ✓** + 下方出现报告正文 = COMPLETE
   - 还有空 checkbox + "正在研究..." = 仍在跑 → 告诉用户当前进度（已完成 N/5 步） + conversation URL 让他再过一会儿来
   - 看到 NEEDS_USER_INPUT 信号（中途反问/速率限制/服务故障）→ 转交用户
3. COMPLETE → `get_page_text` 拉全文
4. 报告通常很长（几千字 + 几十个 source link）→ **建议落盘到 `.chatgpt-skill/results/<task-name>-<date>.md`**（用户授权后），给用户文件路径而不是把整篇贴回主对话窗口

## DR 特有的 UI 状态（写给 watcher 和主 Claude 看的信号清单）

| 信号 | 含义 | 处理 |
|---|---|---|
| Composer placeholder = "获取详细报告" | DR 模式已激活 | OK，可以发 |
| 5 步 todo 卡片 + "开始 N" 倒计时按钮 | 等用户确认才跑 | NEEDS_USER_INPUT，主 Claude 决定是否替用户点"开始" |
| 第一步 checkbox 为 ● + "正在研究..." 进度条 | DR 真正在跑 | 走 Pull 模式记 URL 走人 |
| 卡片右上有"更新"按钮 | 用户可中途调整研究计划 | 不是 error，告诉用户这个能力 |
| 全部 5 步 ✓ + 报告正文出现 | COMPLETE | get_page_text 取回 |
| 中途冒出"需要更多信息" / 反问 | NEEDS_USER_INPUT | 转交用户回答，不要主 Claude 替他选 |

## 容易踩的坑

- **没看到 "获取详细报告" placeholder 就发**：会变成普通问答，烧不了 DR
- **以为提交完就开始跑了**：错，要点"开始"或等倒计时。如果你提交完就给用户报 URL 走人，**用户可能根本没点"开始"，DR 没启动**——倒计时 30s 跑完会不会自动开始没实测确认，安全做法是主 Claude 提交后等 confirm 卡片出来 → 自己点"开始"或问用户
- **DR 中途弹"需要更多信息"**：ChatGPT 有时会反问。这种情况 watcher 看不到（pull 模式没 watcher），需要用户回来时主 Claude navigate 后才发现——告诉用户当前看到的反问，等他回答
- **跑完几小时回来发现页面只显示 "Researching..."**：说明任务被中途打断（速率限制、服务故障、用户关 tab 太久导致 SSE 断流）。重新 navigate 看后端状态——大概率任务在后端跑完了但前端没接到 final event，刷新即出结果
- **首轮跑 90 分钟 timeout 怎么办**：DR 极少 timeout，但如果真碰到，conversation 里会显示 "research timed out"。重新提交即可（ChatGPT 没有"继续上次未完成的 DR" 功能）

## 2026-05-25 端到端验证（Pull 模式实测）

| 指标 | 数值 |
|---|---|
| 主题 | 2026 年中期"复用浏览器登录态"型 agentic browsing 工具横向对比（Claude in Chrome / Codex Chrome Extension / Operator / Comet / Dia / Arc Max / Cursor / browser-use 等） |
| Conversation URL | https://chatgpt.com/c/6a142e3d-a7a0-83ea-bf11-2f64484f4635 |
| 侧栏标题 | "中期复用浏览器对比" |
| 触发流程 | `+` → 深度研究 → 写 prompt → 发送 → confirm 卡片 → 点"开始" |
| 提交后等待 | 0 秒（pull 模式，主 Claude 报完 URL 立刻撤） |
| 是否 spawn watcher | **否**（DR 不适合 watcher） |
| 用户回来取的设计 | 用户保存 URL / 标题，回来说一声主 Claude 去拉 |

**这次验证暴露的 DR 特性**：
- DR **不是提交即跑**——必须显式点"开始"
- DR 有研究计划预览（5 步 todo），用户可"编辑"中途调整
- 真正跑起来后底部"开始"按钮变"更新"
- conversation URL 即使关浏览器后再访问也能继续看进度
