# chatgpt-web-delegate

让 **Claude Code** 通过 `claude-in-chrome` MCP 操控用户**已登录的 ChatGPT 网页**，把咨询任务委托给指定 ChatGPT 模型（Instant / Thinking / Pro / Deep Research），异步等待并取回结果。同时支持管理 ChatGPT 的对话/项目/Memory/库/分享。

不发起独立的自动化浏览器，不接触 cookie/session。

## 安装

```bash
git clone https://github.com/Wangnov/chatgpt-skill.git ~/.claude/skills/chatgpt-web-delegate
```

或者把整个目录复制到你想要的 Skill 路径下（Claude Code 会自动识别 SKILL.md 的 frontmatter）。

**前置依赖**：
- Claude Code 已安装并配置好 `claude-in-chrome` MCP server
- Chrome 浏览器里已登录 ChatGPT（任意 Plus/Pro/Enterprise 计划）

## 用法

安装后直接对 Claude Code 说话，例如：

- "问问 ChatGPT Pro 怎么看这件事"
- "让 Thinking 模式分析一下这个 PR"
- "用 @Google 云端硬盘 列一下我的文件"
- "提交个 deep research，列五家竞品"
- "在 DSE 数学项目里问 X"
- "删了那个对话"
- "归档全部聊天"
- "撤销我之前分享的链接"
- "清掉我的 Memory"

Claude 主进程会：
1. 操作 ChatGPT 网页提交任务
2. Spawn 一个 background Haiku watcher 异步监控
3. 完成后把完整结果交给你

主 Sonnet 在等待期间**完全沉默**，watcher 用 Haiku 跑循环（成本低）。

## 设计原则

| 原则 | 表现 |
|---|---|
| 手册式而非工程式 | 不写 selector / 不写状态机 / 不写 manifest schema。靠 LLM 当场视觉判断 |
| 信任 LLM | 200 行 SKILL.md 主指令 + 按需 reference，不堆规则 |
| 异步原生 | Background Haiku watcher subagent，主 Sonnet 不被打扰 |
| 安全优先 | 不替用户授权 OAuth / 不绕 CAPTCHA / 不存 session / 破坏性操作必须用户确认 |
| 文件上传暂不可用 | Claude Code MCP 桥接 bug [#31210](https://github.com/anthropics/claude-code/issues/31210)，需要用户在浏览器里手动上传 |

详细设计见 [SKILL.md](SKILL.md)。

## 项目结构

```
SKILL.md                       # 主指令（Claude Code 入口）
scripts/heartbeat.sh           # fallback：纯 shell 心跳
references/
  watcher-subagent.md          # 主推异步方案
  claude-code-async.md         # fallback heartbeat 文档
  error-and-limits.md          # 10 种错误/限流场景
  manage-actions.md            # 对话/项目/Memory/库 管理操作手册
examples/                      # 5 个端到端实测场景
  auto-google-drive-list.md
  thinking-github-unread-issues.md
  deep-research-trigger.md
  pro-github-pr-review.md
  project-context-consult.md
```

## 实测覆盖（截至 2026-05-25）

- ✅ Thinking + @Google 云端硬盘 列文件（14s）
- ✅ Pro + @Google 云端硬盘 推断工作轨迹（5m 25s）
- ✅ Pro + @GitHub 评估 PR 可合并性（5m 7s，watcher 累计 4 分钟，主 Sonnet 0 次打扰）
- ✅ Pro + DSE 数学项目知识库（21m 5s，watcher 累计 19 分钟）
- ✅ 创建/重命名/分享/归档/取消归档/删除项目和对话
- ✅ 数据管理 / Memory 管理 / 库管理
- ❌ 文件上传（待 Anthropic 修 [#31210](https://github.com/anthropics/claude-code/issues/31210)）

## License

MIT
