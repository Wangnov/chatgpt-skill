# Example: Codex 触发 Deep Research 的 Heartbeat / Pull 模式

## 触发说法

- "让 ChatGPT 做个 deep research，调研一下 X"
- "提交一个深度研究任务，主题是 ..."
- "帮我启动 DR，回来我再让你取结果"

## 意图解析

- **工具**：必须从 `添加文件等` 菜单选择 `深度研究`，不能只在普通 composer 里写 "deep research"。
- **等待策略**：Deep Research 常常跨小时；确认研究已启动后默认挂 heartbeat，不在主会话干等。
- **交付物**：启动时交给用户 conversation URL 和当前可见计划；heartbeat 完成后再取结果。automation 优先，spawn agent 是默认 fallback；两者都不可用才退回 Pull。

## 操作步骤

1. 连接 Chrome 并复用或打开 ChatGPT tab。
2. 打开 `添加文件等` 菜单，点击 `深度研究`。
3. 用 `domSnapshot()` 或截图确认 Deep Research 模式已激活：
   - composer placeholder 变成类似 `获取详细报告`。
   - composer 附近出现 `深度研究` chip 或同等视觉信号。
4. 输入用户主题和约束，例如：

   ```text
   做一份深度调研报告：[用户主题]
   要求：
   - 至少覆盖 10 个独立信息源
   - 标明关键信息的来源
   - 末尾给出结论、风险和待验证问题
   ```

5. 发送后等 conversation URL 生成。
6. 如果出现研究计划确认卡片，读取计划摘要；除非用户已明确授权启动，否则把计划和按钮状态交给用户确认。
7. 用户允许启动后，点击计划卡片里的 `开始`。如果可访问性树同时有 `开始听写`，不要用宽泛的 `/开始/` 匹配；先用截图确认计划卡按钮位置，或限定在计划卡 / iframe 内。
8. 看到正在研究的进度信号后，挂 heartbeat，而不是继续占住当前回合：
   - 计划项开始打勾或转圈。
   - 进度文本出现，例如 `Searching ...`、`Finalizing ...`。
   - 右侧出现搜索次数，例如 `25 次搜索`。
   - 计划卡右下角从 `开始` 变成停止按钮。
9. 把 URL、标题、当前计划和 heartbeat 策略告诉用户；heartbeat 只在 COMPLETE / NEEDS_USER_INPUT / TIMEOUT / ERROR 时回来：
   - 先用 tool_search 搜 `automation_update` / wakeup / reminder；当前环境有 automation / wakeup 工具时，创建 automation。
   - 当前环境没有 automation 工具时，spawn 后台 agent 作为默认 fallback。
   - 两者都不可用时，才交给用户用 URL 回来取。

## 用户回来取结果

1. 用 conversation URL 重新打开或 claim 对应 ChatGPT tab。
2. 读取 `<main>`，同时截图检查 Deep Research iframe：
   - 页面里通常会有 `iframe[title="internal://deep-research"]`。
   - 报告正文可能只渲染在 iframe 卡片里，外层 `<main>` 不一定包含正文。
   - 如果外层文本停留在旧状态，刷新 conversation URL 一次再看截图。
3. 判定状态：
   - 截图里出现 `研究完成情况：...`、报告标题，且没有停止/研究中信号：判定完成，取回摘要或报告。
   - 仍显示正在研究：告诉用户当前进度和 URL。
   - 页面要求补充信息或授权：转交用户处理。
4. 报告很长时，不默认贴满当前对话；询问用户是否要落盘到 `~/Downloads/chatgpt-skill/`。

## 容易踩的坑

- 没确认 Deep Research 模式就发送，会变成普通问答。
- 研究计划卡片不等于已经启动。要看到 `开始` 后的进度信号才算真的跑起来。
- 完成报告不一定出现在外层 `<main>` 文本里；heartbeat 要结合 iframe 截图里的完成行和报告标题。
- 不要在主会话里长时间干等；DR 启动后挂 heartbeat，automation 不可用时用 spawn agent fallback。
- 不要用 Claude 版后台 watcher 模板；Codex 版 heartbeat 只做安静状态检查。
- 不要替用户授权第三方 app，也不要绕过登录、CAPTCHA 或付费限制。
