# Example: Pro 模型 + @GitHub 对 PR 做深度 Review

## 触发说法

- "用 Pro 模型 + @GitHub 帮我深度 review 这个 PR：[PR URL]"
- "切 Pro，调 GitHub 连接器拉 PR 内容，给我个 review"
- "让 Pro 深度审一下 [repo]#[pr-number]"

## 意图解析

- **模型**：明确要 **Pro · 进阶**
- **App**：@GitHub（取 PR diff、文件、评论上下文）
- **预期产物**：Pro 级别的深度 review —— 不是表面 lint，要看设计、并发、边界、API 兼容
- **关键点**：Pro + apps **可以一起用**（5.5 之前错判了；2026-05 实测可用）。不要预设 Pro 必须 fallback

## 操作步骤

1. `tabs_context_mcp` → 复用或创建 ChatGPT tab
2. 模型选择器 / 模型 pill：
   - 当前不是 Pro → 点当前页面可见的模型选择器，选 "Pro · 进阶"（UI 文案可能漂移，但语义识别"Pro"）
   - 已经是 Pro → 跳过
3. 验证模型选择器显示 Pro
4. composer 写：

   ```
   @GitHub 帮我深度 review 这个 PR：[完整 PR URL]

   重点：
   - 设计合理性、潜在并发问题、错误处理覆盖
   - 是否有 breaking change / API 兼容性问题
   - 安全角度（注入、权限、secrets）
   - 不要只列表面 lint 问题

   返回结构：
   1. 总体判断（merge / request changes / hold）
   2. 必修问题（按严重程度排序）
   3. 建议改进（可选）
   4. 看不懂的地方 / 需要作者补充上下文的问题
   ```

5. 验证 @GitHub 出 chip 之后再发送
6. 等 3-5 秒让 URL 出现
7. **Spawn Haiku watcher**：sleep 间隔 60 秒（Pro PR review 经常 5-10 分钟，60s 是合理粒度）

## 异步等待 + 取回

- Watcher 完成时返回完整评审
- 主 Claude 呈现：
  - 总体推荐（哪些可合并、哪些要改、哪些要拖）
  - 逐 PR 评估表格
  - Pro 找到的具体代码问题（行号、错误类型）
  - **建议长 review 落盘到 `.chatgpt-skill/results/pr-review-<repo>-<pr>-<date>.md`**，给用户文件路径
  - 保留所有 github.com source link（行内引用通常跳到具体文件 line）

## 容易踩的坑

- **被 5.5 那个旧规则误导**：千万不要"先用 Thinking 调 GitHub 取数据，再切 Pro 合成"——这是 5.5 错判后留下的反模式。Pro + @GitHub **直接能用**
- **PR 太大被截断**：超大 PR（几千行 diff）ChatGPT 可能只取部分文件。如果用户期望全量审核：
  - 提示用户："PR 太大，ChatGPT 可能没全读，建议分文件 review"
  - 或者引导用户给 ChatGPT 明确的 file path 列表
- **private repo 没权限**：@GitHub 连接的 scope 决定能不能看 private。看不到时 ChatGPT 会说 "I don't have access" —— 转交用户去 ChatGPT 设置里调整 GitHub scope
- **Pro 思考链路过长无响应**：Pro 有时跑 10+ 分钟。watcher 累计等到 600s+ 还没完 → 主 Claude 应该问用户当前已等多久，让他决定继续还是改用别的模式
- **拿回来的"review"全是 markdown 标题，正文是 placeholder**：极少见，但说明 Pro 出错了一次。重新发送同样 prompt 不一定能复现 —— 先给用户看到的内容，让他决定要不要重跑

## 2026-05-25 端到端验证记录

| 指标 | 数值 |
|---|---|
| 仓库 | `Wangnov/claude-code-statusline-pro`（2 个 open PR） |
| 模型 | Pro · 进阶 |
| Pro 思考时间 | 5m 7s |
| Watcher 累计等待 | 240s（4 个 60s 周期） |
| Watcher token | 86,681 Haiku |
| 工具调用 | 10 次 |
| 主 Sonnet 被打扰 | 0 次 |
| 意外收获 | Pro 定位到精确代码失败行：`src/git/service.rs` 的 `head.shorthand()` 和 `commit.summary()`——指出 git2 0.21 改了返回类型 |
