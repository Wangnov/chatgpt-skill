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

1. 调用 mcp__Claude_in_Chrome__read_page，参数 tabId: <tabId>, filter: "all", max_chars: 10000
2. 在返回的 accessibility tree 里搜这些信号判断是否还在生成：
   - "Pro 思考中" / "正在思考" / "Thinking" / "Researching" / "正在搜索" / "正在分析"
   - 任何 stop generating 按钮 / spinner / progress indicator
3. **NEEDS_USER_INPUT 检测**（每轮 read_page 后都检查，优先级高于"还在生成"）：
   如果页面出现任何下列信号，立刻进入步骤 7（不要继续等）：
   - ChatGPT 在反问用户、要求 clarification（assistant message 末尾是问号 + 没有"思考中"字样）
   - 出现 OAuth / 授权弹窗（"连接你的 [app]"、"Authorize"、"允许 ChatGPT 访问"）
   - 出现登录页 / session 过期提示
   - 出现速率限制 / 配额耗尽 / 模型不可用弹窗（详见 references/error-and-limits.md 的信号列表）
   - 出现 CAPTCHA / 人机验证
   - 出现 "Continue generating" 按钮（说明输出被截断，需要用户决定要不要续）
4. 如果还在生成（且没有上述 NEEDS_USER_INPUT 信号）：
   - 用 Bash 工具运行 sleep 60
   - 在你自己的笔记里累计等待秒数（从 0 开始）
   - 回到步骤 1
5. 如果生成完成的标志同时满足：
   - 没有"思考中/正在..."字样
   - 末尾出现 "ChatGPT 也可能会犯错。请核查重要信息。" 或类似 disclaimer
   - 底部 composer 区回到可输入态
   - 进入步骤 6
6. 调用 mcp__Claude_in_Chrome__get_page_text，参数 tabId: <tabId>，拿全文 → 返回给主 Claude（COMPLETE 状态）
7. NEEDS_USER_INPUT 路径：调用 mcp__Claude_in_Chrome__get_page_text 拿当前可见内容 → 返回给主 Claude（NEEDS_USER_INPUT 状态 + 描述具体看到了什么 + 用户需要做什么动作）

**硬性约束**

- 不要调用 navigate —— 会打断用户当前浏览器使用
- 不要开新 tab、不要切 tab、不要点页面任何按钮（**特别不要点 OAuth / 授权 / 继续生成等按钮**）
- 只读，不交互
- 每轮检查只调用一次 read_page
- 不要给主 Claude 发任何中间状态报告。完成 / NEEDS_USER_INPUT / 超时才返回
- **累计等待硬上限：1800 秒（30 分钟）**。到了就 get_page_text 拿当前可见内容 + 标注 "TIMEOUT"

**异常处理**

- read_page 返回错误 → 等 30 秒重试一次，再错就返回错误信息（ERROR 状态）
- get_page_text 返回的内容里没有最近的 assistant message → 返回当前可见内容 + 标注 "PARTIAL"

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

2026-05-25 跑通：Pro + @GitHub 评估 `claude-code-statusline-pro` 仓库 PR 是否可合并

- Watcher 实际运行 4m 52s
- 累计等待 240s（4 个 60s 周期）
- ChatGPT 思考 5m 7s
- Watcher 工具调用 10 次，消耗 86,681 token（Haiku）
- 主 Sonnet 被打扰 **0 次**
- 返回内容完整、带结构化元数据（状态/等待/思考时间/app 调用迹象/全文）
