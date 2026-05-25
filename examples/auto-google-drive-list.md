# Example: Auto 模型 + @Google 云端硬盘 列文件

## 触发说法

- "用 @Google 云端硬盘 列一下我都存了什么东西"
- "看看我 Drive 根目录有哪些文件"
- "让 ChatGPT 用 Google Drive 工具帮我列文件"

## 意图解析

- **模型**：用户没指定 → **用当前选中的模型**，不主动切
- **App**：明确要用 Google 云端硬盘
- **预期产物**：根目录或某个文件夹的文件清单

## 操作步骤

1. `tabs_context_mcp` → 找现有 ChatGPT tab；没有就 `tabs_create_mcp` + `navigate` 到 `https://chatgpt.com/`
2. `read_page` 看主页加载完成（看到 "你在忙什么？" 标题、composer 可输入）
3. 看 composer 右下角的模型 pill，记下当前是什么（Instant / Thinking / Pro / 别的）。**不要切换**
4. 在 composer 里写：

   ```
   @Google 云端硬盘 列一下我根目录的前 20 个文件，按修改时间倒序，
   给我类型、名称、创建时间三列。
   ```

   `@` 之后等 1-2 秒看是否弹出自动补全建议；选 "Google 云端硬盘" 那项让它变成正式 chip
5. 验证：发送前必须看到一个 "Google 云端硬盘" chip / 标签出现在 composer 里。**只看到 `@Google 云端硬盘` 的纯文本是不行的**——那说明 mention 没被识别成 app 调用
6. 点发送，等 3-5 秒让 URL 出现（`tabs_context_mcp` 看 `/c/<id>`）
7. **Spawn Haiku watcher**（主推方案）：

   ```
   Agent({
     description: "ChatGPT 完成监控器",
     subagent_type: "general-purpose",
     model: "haiku",
     run_in_background: true,
     prompt: <见 references/watcher-subagent.md 模板，sleep 30 秒>
   })
   ```

   Drive 检索一般 30–90 秒，watcher sleep 间隔用 30 秒。

8. 主 Claude 解放，告诉用户"已提交，watcher 在后台等结果"

## 异步等待 + 取回

- Watcher 在自己的上下文里循环 read_page → 完成时 get_page_text 返回
- 主 Claude 收到 watcher 的返回通知后，把以下信息呈现给用户：
  - 文件清单（含 source chip / Drive link，原样保留）
  - watcher 报告的"@Drive app 调用迹象"
  - 思考时间、累计等待
- 如果状态是 TIMEOUT/PARTIAL → 给当前可见内容 + 让用户决定要不要再起一轮

## 容易踩的坑

- **没看到 chip 就发送**：ChatGPT 会把 `@Google 云端硬盘` 当成普通文字处理，得到的回答是 "我没法访问你的 Google Drive"。**必须确认 chip 出现**
- **手贱切了模型**：用户没要求换，不要换。换了反而可能因为新模型对 app 的支持不同导致结果不一致
- **app 没连接**：第一次用某个 app 时 ChatGPT 会弹"连接 Google 云端硬盘"对话框，要 OAuth。**这里停下来让用户连接**，不要替他点同意。连接完用户回来说"好了"再继续
- **只读了 Drive 根目录**：用户问"我都存了什么"时，根目录列表往往不够。建议主动问"要不要顺便递归看子文件夹"，但不要自动做（一是慢，二是用户可能只想看根目录）
