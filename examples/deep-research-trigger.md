# Example: 用提示词触发 Deep Research

## 触发说法

- "让 ChatGPT 做个 deep research，调研一下 X 的竞品"
- "提交个深度研究任务，主题是 ..."
- "做一份 deep research 报告：[topic]"

## 意图解析

- **模型**：用户没指定 → 用当前模型（deep research 不依赖特定模型，靠 `+` 菜单的 "深度研究" 工具）。不要主动切
- **工具**：必须打开 `+` 菜单选 **"深度研究"**（不是 `@app`）。Deep research 会自己挑信息源
- **预期产物**：5–30 分钟后的长报告
- **关键提示**：这是最慢的一类任务，**watcher 的 sleep 间隔必须设大**

## 操作步骤

1. `tabs_context_mcp` → 复用或创建 ChatGPT tab
2. 点 composer 的 `+` 按钮，弹出菜单
3. 在菜单里点 "深度研究"。**注意**：选中后 composer 会出现 "深度研究" 模式标志（chip / 顶部标签 / icon 高亮，UI 表现不一）
4. 验证 composer 进入深度研究模式（**否则发送下去就是普通问答，不是 deep research**）
5. 写 prompt：

   ```
   做一份深度调研报告：[用户给的主题]。
   要求：
   - 至少 10 个独立信息源（含中英文）
   - 每个核心论点要有 source citation
   - 末尾给一个 "信息源 / 可信度 / 时间" 表
   ```

6. 发送，等 URL 出现
7. 告诉用户："Deep research 一般 5–30 分钟。我让一个 watcher 在后台盯着，期间你想继续问别的、想走开都行，完成时我会拿着报告回来。"
8. **Spawn Haiku watcher**：sleep 间隔 120 秒（DR 慢，60s 太频）。**累计等待硬上限要从默认 30 分钟提到 45 分钟**（在 watcher prompt 里覆盖默认值）——DR 偶尔会跑很久。

## 异步等待 + 取回

- Watcher 完成时返回 DR 报告全文
- 主 Claude 呈现：
  - 报告通常很长，且含大量 source link
  - **建议落盘到 `.chatgpt-skill/results/<task-name>-<date>.md`**（用户授权后），给用户文件路径而不是把整篇贴回主对话窗口
  - 如果 watcher 状态是 TIMEOUT（45 分钟还没完）→ 给当前可见内容 + 问用户要不要再 spawn 一个 watcher 继续等

## 容易踩的坑

- **`+` 菜单选 "深度研究" 后没验证 composer 状态就发送**：会变成普通问答。必须确认 UI 上有 "深度研究" 模式的视觉标记
- **首轮 sleep 设太短**：30 秒、60 秒对 deep research 都太短，会被无意义唤醒。Watcher 模式建议 **首轮 90–120 秒**（跟操作步骤 #8 一致）。Fallback heartbeat 模式可以拉到 300 秒
- **每轮通知都打扰用户**：watcher 完成才会通知主 LLM，本来就不会中途打扰；fallback 模式下主 LLM **不要发消息打扰用户**——直接静默起下一轮 watcher / heartbeat 就行
- **deep research 弹"需要更多信息"**：ChatGPT 有时会中途反问"你是想要 X 还是 Y？"。这种情况主 LLM 看到后必须停下来，转交用户回答，不要替他选
- **取回时只拿到 "Researching..." 状态文字**：说明任务被中途打断或还在跑。重新 navigate 确认状态再决定
