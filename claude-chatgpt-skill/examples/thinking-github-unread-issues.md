# Example: Thinking + @GitHub 检查个人未读 issues

## 触发说法

- "用 Thinking 模式让 ChatGPT 帮我看看 GitHub 上有什么未读 issue"
- "切到 Thinking，调 @GitHub 列我 assigned 但没回的 issue"
- "ChatGPT 的 GitHub 连接器现在能看到我哪些待处理 issue？用思考模式分析一下哪些紧急"

## 意图解析

- **模型**：明确要切 **Thinking · 深入**
- **App**：@GitHub
- **预期产物**：未读 / unassigned / 紧急 issue 清单 + 优先级判断（Thinking 该出的价值）

## 操作步骤

1. `tabs_context_mcp` → 复用或创建 ChatGPT tab
2. 看当前页面可见的模型选择器 / 模型 pill。它可能在顶部 banner，也可能在 composer 附近。当前显示什么？
   - 已经是 Thinking → 跳过切换
   - 是别的（Instant / Pro / ChatGPT / 别的命名） → 点模型选择器，从下拉里选 "Thinking · 深入" 或当前对应 Thinking 的可见名
   - 看不到 Thinking 选项 → 报告用户实际看到的选项，让他决定
3. 验证：发送前模型选择器显示的就是 Thinking 对应的文本（页面文案可能是中文"思考"/"深入"/"Thinking"，不要写死）
4. composer 写：

   ```
   @GitHub 列一下我在所有仓库里被 assign、最近 30 天有新活动、
   且我还没回复或没关闭的 issue。
   按"距离上次活动时间"排序。然后基于 issue 标题和最新评论，
   挑出 3 个最紧急的，给我紧急原因。
   ```

   `@GitHub` 必须出现为 chip
5. 发送，等 URL 出现
6. **Spawn Haiku watcher**：sleep 间隔 60 秒（Thinking 通常 1–3 分钟）。
   Watcher prompt 里特别叮嘱：**只取 final answer，不要把 Thinking 的折叠"思考过程"一起带回**——浪费 token 且对用户是噪音。

   实操做法：watcher 用 read_page 时定位最后一条 assistant message 的 ref_id，再用 read_page 只拉那一段；不要无脑 get_page_text。

7. 主 Claude 解放

## 异步等待 + 取回

- Watcher 完成时返回 final answer 文本
- 主 Claude 呈现给用户：未读 issue 清单（含 github.com source link）+ Thinking 的优先级判断
- issue 列表里每条 source link 必须保留，方便用户点回原 issue

## 容易踩的坑

- **Thinking 名字可能漂移**：UI 上可能是 "Thinking"、"思考"、"深入"、"5.5 Thinking"。靠语义判断不靠固定字符串
- **@GitHub 后面没出 chip**：跟 Drive 例子一样，要确认 chip 才发送
- **GitHub 连接器没授权 / scope 不够**：可能看不到 private repo 的 issue。如果用户期待 private repo 的结果但出来的只有 public，**告诉用户去 ChatGPT 设置里检查 GitHub 连接的 scope**，不要替他改
- **Thinking 跑很久不返回**：超过 5 分钟还没完成时，主 LLM 应该问用户"要不要继续等"，而不是无限延长 watcher
- **取回时把思考过程带回**：用 `get_page_text` 会把折叠的思考过程也展开。一般做法是先 `read_page` 找到最后一条 assistant message 的 ref_id，再 `read_page ref_id` 只拉那一段
