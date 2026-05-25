# Background Haiku watcher subagent（异步等待主推方案）

## 总体模型

```
用户 → 主 Claude 操作 ChatGPT 提交任务 → 拿到 conversation URL
                                          ↓
主 Claude spawn 一个 Haiku watcher subagent（run_in_background: true）
                                          ↓
主 Claude 解放 → 把控制权交回用户 → 完全沉默
                                          ↓
                       [Watcher 在自己的上下文里循环：
                        read_page → 还在生成？→ sleep 60 → 重来
                                              ↓ 完成
                        get_page_text → return]
                                          ↓
                       Claude Code 把 watcher 的 return 作为通知交付给主 Claude
                                          ↓
                       主 Claude 把 watcher 返回的全文给用户
```

## Watcher 调用模板

```
Agent({
  description: "ChatGPT 完成监控器",
  subagent_type: "general-purpose",      // 必须，能用全部工具包括 claude-in-chrome MCP
  model: "haiku",                         // 必须，省钱
  run_in_background: true,                // 必须，不阻塞主 LLM
  prompt: <见下>
})
```

## Watcher prompt 模板

```
你是 ChatGPT 完成监控 watcher。任务：等到一个 ChatGPT 会话生成完成，
然后把最终的 assistant message 全文拉回来给主 Claude。

**目标会话信息**
- tabId: <从主 LLM 拿到的 tabId>
- URL: <conversation URL>
- 主题: <一句话描述用户在问什么>
- 用户的提问: <把用户原始诉求写一句话>

**工作循环（严格执行）**

**重要原则**：判断完成度**优先用 `get_page_text`**，不要用 `read_page` accessibility tree——长回答会被 `max_chars` 截断在中间，看不到末尾的 disclaimer / "已思考 Xs" 等关键信号（详见下方"异常处理"和验证记录）。

1. 调用 **mcp__Claude_in_Chrome__get_page_text**，参数 tabId: <tabId>
   - 这会拉 `<main>` 元素下的全部文本（用户消息 + assistant 回答 + footer disclaimer），不受 max_chars 截断限制
2. 在返回的全文里**从末尾向上**搜这些**完成信号**（同时满足才算 COMPLETE）：
   - 末尾包含 "**ChatGPT 也可能会犯错。请核查重要信息。**" （disclaimer，最稳的完成标志）
   - 紧邻 disclaimer 之上出现 "**已思考 Xm Ys**" 或 "**已思考 Xs**" 字样（过去时，表示思考阶段结束）
   - 全文里**含用户预期的内容关键词**（例如用户要 P0/P1/P2 review → 全文应该出现 "P0"、"P1"、文件行号；用户要写作 → 全文应该出现完整段落而不是单句进度摘要）
3. 在全文里搜**进行中信号**（任一存在 → 仍在跑）：
   - "正在思考" / "Pro 思考中" / "Researching" / "正在搜索" / "正在分析" / "Synthesizing"
4. **NEEDS_USER_INPUT 检测**（每轮都检查，优先级高于"还在生成"）：
   全文里出现下列信号 → 立刻进入步骤 7：
   - ChatGPT 末尾是反问（问号结尾 + 没有"思考中"字样 + 没有 disclaimer）
   - "连接你的 [app]" / "Authorize" / "允许 ChatGPT 访问"
   - 登录页提示 / "Please log in"
   - 速率限制 / 配额耗尽 / 模型不可用弹窗（详见 references/error-and-limits.md）
   - CAPTCHA / "Verifying you are human"
   - "Continue generating" / "继续生成" 按钮（输出被截断，要用户决定续不续）
   - **DR 特有**："开始 N" 倒计时按钮（5 步研究计划未确认）
5. 如果还在生成（既没完成信号也没 NEEDS_USER_INPUT 信号）：
   - 用 Bash 工具运行 sleep 60
   - 在你自己的笔记里累计等待秒数（从 0 开始）
   - 回到步骤 1
6. COMPLETE 路径：把 get_page_text 全文返回给主 Claude（注意提取用户提问之后的部分，过滤掉用户提问本身）
7. NEEDS_USER_INPUT 路径：把 get_page_text 当前内容 + blocker 元数据返回主 Claude
   - 如果需要更精确地找按钮 ref（如 OAuth 授权按钮），**这一步**才调用 `read_page filter: "interactive" max_chars: 5000` 看具体可点击元素

**硬性约束**

- 不要调用 navigate —— 会打断用户当前浏览器使用
- 不要开新 tab、不要切 tab、不要点页面任何按钮（**特别不要点 OAuth / 授权 / 继续生成等按钮**）
- 只读，不交互
- **每轮检查只调用一次 get_page_text**（不要为了"再确认"调多次）
- 不要给主 Claude 发任何中间状态报告。COMPLETE / NEEDS_USER_INPUT / TIMEOUT / ERROR 才返回
- **累计等待硬上限：1800 秒（30 分钟）**。到了就 get_page_text 拿当前内容 + 标注 "TIMEOUT"

**异常处理**

- get_page_text 返回错误 → 等 30 秒重试一次，仍错就返回 ERROR
- get_page_text 返回的内容里看似有 assistant 输出但 disclaimer 没出现 → 仍按"在生成"处理，继续 sleep（不要标 PARTIAL，PARTIAL 留给 TIMEOUT 后的兜底）
- 看到 disclaimer 但内容只是简短进度摘要（如"我已确认...等候选问题"）没有真正结论 → **不算 COMPLETE**——Pro 偶尔会"先报告进度等用户回复"，回 sleep + 在累计等待 > 600s 时升级为 NEEDS_USER_INPUT（blocker_type: incomplete_response）让主 Claude 决定是否追问"继续"

**为什么不用 `read_page` 判断完成度**（避免重复踩坑）

`read_page` 返回 accessibility tree 受 `max_chars` 限制：默认 50000，但长 Pro review 经常超过这个长度。截断后 watcher 看不到末尾的 disclaimer，会**误判为"还在生成"或"NEEDS_USER_INPUT 没结论"**。`get_page_text` 提取 `<main>` 元素文本无截断、压缩好，对完成度判断更可靠。

`read_page` 仍然有用：**找具体元素 ref**（如 OAuth 按钮、删除按钮）时才用——它返回的 accessibility tree 含 ref_id，是 click/find 的前提。但**完成度判断和内容取回都用 `get_page_text`**。

**输出格式**

​```
状态: COMPLETE / NEEDS_USER_INPUT / TIMEOUT / ERROR / PARTIAL
累计等待: <秒数>
ChatGPT 显示的思考时间: <如 "5m 25s"，没显示就写"未显示">
所用 app 调用迹象: <YES/NO + 简短证据>

如果状态是 NEEDS_USER_INPUT，额外提供：
- blocker_type: clarification_question / oauth / login / rate_limit / quota / captcha / continue_generating / other
- blocker_visible_text: <你在页面上看到的具体文本，原样引用>
- suggested_user_action: <一句话告诉用户需要做什么>

=== assistant 完整输出 ===
<把 get_page_text 拿到的、用户提问之后的 assistant 部分原样贴这里>
​```

开始监控吧。
```

## 各任务类型的 sleep 间隔参考

Watcher 内部循环用 `sleep 60` 作为默认。可以让 watcher 自己根据 read_page 的反馈调整：

| 任务类型 | 建议 sleep | 备注 |
|---|---|---|
| Instant 短咨询 | 20–30 秒 | 一般 30 秒内就完了 |
| Thinking | 30–60 秒 | 大部分 1–3 分钟 |
| Pro | 60 秒 | Pro 经常 5–10 分钟，60s 是合理粒度 |
| Deep Research | 90–120 秒 | 经常 10–20 分钟 |

写进 watcher prompt 时直接给数值，不要让 watcher 自己决定（Haiku 不需要做这个判断）。

## 主 LLM 收到 watcher 完成通知后

通知的形态：

```
<task-notification>
<status>completed</status>
<result>
状态: COMPLETE
累计等待: 240 秒
ChatGPT 显示的思考时间: 已思考 5m 7s
所用 app 调用迹象: YES - 看到 "已调用工具" + GitHub PR 链接

=== assistant 完整输出 ===
...
</result>
</task-notification>
```

主 Claude 拿到后：

1. **结构化呈现给用户**：会话 URL、模型、思考时间、watcher 累计等待、app 调用确认
2. **完整内容**：watcher 返回的 assistant 输出。一般不要总结/改写，原样给（除非很长可以分节摘要）
3. **如果状态是 NEEDS_USER_INPUT**：
   - 把 watcher 报告的 `blocker_visible_text` 原样引述给用户
   - 说明 `blocker_type` 和需要用户做什么
   - **不要自己替用户回答 clarification 问题、不要自己点 OAuth 授权按钮**——这些必须用户在浏览器里亲自做
   - 用户完成后，问他要不要 spawn 一个新 watcher 继续等
4. **如果状态是 TIMEOUT / ERROR / PARTIAL**：把 watcher 拿到的部分给用户 + 解释发生了什么 + 让用户决定要不要再起一轮 watcher 或换模型

## 跟 fallback heartbeat 模式的对比

| | Watcher（主推） | Fallback heartbeat |
|---|---|---|
| 跑在哪 | Haiku subagent | shell + 主 Sonnet 唤醒 |
| 主 LLM 被打扰 | 0 次 | 每轮 sleep 结束都唤醒 |
| 每轮 token 成本 | Haiku × 几千 | Sonnet × 几千 |
| 需要主 LLM 静默自律 | 否（watcher 不在主上下文里） | 是（要主 LLM 严格控制不输出） |
| MCP 工具访问 | ✅ subagent 也能用 | ✅ 唤醒主 LLM 后用 |
| 适用场景 | Claude Code | 纯 SDK / 无 Agent 工具的环境 |

## 特殊产物形态的取回

| 产物形态 | get_page_text 够吗 | 备注 |
|---|---|---|
| 普通 chat message | ✅ 够 | 默认情况 |
| **Canvas / artifact** | ✅ 够 | 2026-05-25 实测：当前版本 Canvas 集成在主 chat 区作为带标题+分段的容器，不是独立右侧面板。get_page_text 一次拿完整内容（610 字短文实测全拿到）。**不需要特殊处理** |
| Pro 长篇带表格 / 时间序列卡片 | ✅ 够 | 天气查询实测：表格数据展开后 get_page_text 也都包含 |
| Thinking 折叠思考过程 | ⚠️ 注意 | get_page_text 会一起拉回。要的是 final answer，需要从结果文本里剥掉"已思考 Xs"之前的部分 |
| 图片生成 | n/a | 图片走下载路径，见 [manage-actions.md](manage-actions.md) 第 6.5 节 |
| ChatGPT 给的文件下载链接 | n/a | get_page_text 能拿到链接锚文本，但实际下载要主 Claude `left_click` 链接 |

## 已知限制

1. **多个 watcher 并发**：如果用户同时提交两个 ChatGPT 任务，需要两个 watcher 各跑各的。Agent 工具支持并发 spawn，但 watcher 之间要用不同的 tabId 或 URL 区分
2. **Tab 失焦**：watcher 只 read 不 navigate，所以不抢用户焦点。但如果用户在等待中关闭了 ChatGPT tab，watcher 的 read_page 会失败 → 走异常处理路径
3. **NEEDS_USER_INPUT 检测靠 watcher prompt 注入**（已在上方工作循环步骤 3 实现）：如果某个错误类型这里没列，watcher 会一直等到 30 分钟超时。补救路径是用户走开后回来发现 watcher 超时返回，主 Claude 把 PARTIAL 内容给用户。

## 验证记录

### 2026-05-25 #1：Pro + @GitHub 评估 PR 可合并性（成功）

- Watcher 实际运行 4m 52s
- 累计等待 240s（4 个 60s 周期）
- ChatGPT 思考 5m 7s
- Watcher 工具调用 10 次，消耗 86,681 token（Haiku）
- 主 Sonnet 被打扰 **0 次**
- 返回内容完整、带结构化元数据（状态/等待/思考时间/app 调用迹象/全文）

### 2026-05-25 #2：Pro + @GitHub review `rust-silk` 项目（成功）

- Watcher 累计等待 870s（14.5 分钟）
- Pro 思考 16m 14s
- 完整 P0/P1/P2 review 取回，含 6 条 P1 + 9 条 P2 + 落地顺序

### 2026-05-25 #3：Pro + @GitHub review `codex-asr` 项目（**失败两次，暴露设计缺陷**）

第一个 watcher 用 `read_page max_chars: 10000` 判断完成度：
- 累计 750s 后误判 NEEDS_USER_INPUT，但实际上 **Pro 第一轮已经写完了完整 P0/P1/P2 review**——`read_page` accessibility tree 在 10000 char 处截断，watcher 看不到末尾 disclaimer，以为还没生成

主 Claude 误判后追加 "继续，请给完整 P0/P1/P2" 让 Pro 又重写一轮。第二个 watcher 用 `read_page max_chars: 30000` 判断：
- 累计 540s 后又误判 INCOMPLETE——同样是 accessibility tree 截断，仍然看不到 footer

最后主 Claude **直接调 `get_page_text` 一次性拉全文**才发现两轮都已经完整写完。

**根因 + 教训**：
- `read_page` accessibility tree 总会受 `max_chars` 限制。长 Pro review（rust-silk 那次正文约 8000 字，codex-asr 两轮约 30000 字）一定截断
- 截断后 watcher 看不到末尾的"ChatGPT 也可能会犯错" disclaimer，错误判定"还在生成"
- **正解**：完成度判断改用 `get_page_text`（拉 `<main>` 元素全文，无截断），只在需要找按钮 ref 时才 `read_page`
- 这次教训直接驱动了本文档"工作循环"部分的重写
