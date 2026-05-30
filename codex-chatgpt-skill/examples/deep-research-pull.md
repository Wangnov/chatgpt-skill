# Example: Codex 触发 Deep Research 的 Pull 模式

## 触发说法

- "让 ChatGPT 做个 deep research，调研一下 X"
- "提交一个深度研究任务，主题是 ..."
- "帮我启动 DR，回来我再让你取结果"

## 意图解析

- **工具**：必须从 `添加文件等` 菜单选择 `深度研究`，不能只在普通 composer 里写 "deep research"。
- **等待策略**：Deep Research 常常跨小时，Codex 不挂后台 watcher；默认 Pull 模式。
- **交付物**：确认研究已启动后，交给用户 conversation URL 和当前可见计划；用户回来再让 Codex 取结果。

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
7. 用户允许启动后，点击 `开始`。
8. 看到正在研究的进度信号后，不继续长时间占住当前回合；把 URL、标题和当前计划告诉用户。

## 用户回来取结果

1. 用 conversation URL 重新打开或 claim 对应 ChatGPT tab。
2. 读取 `<main>`：
   - 报告正文出现且没有进行中信号：取回完整报告。
   - 仍显示正在研究：告诉用户当前进度和 URL。
   - 页面要求补充信息或授权：转交用户处理。
3. 报告很长时，不默认贴满当前对话；询问用户是否要落盘到 `~/Downloads/chatgpt-skill/`。

## 容易踩的坑

- 没确认 Deep Research 模式就发送，会变成普通问答。
- 研究计划卡片不等于已经启动。要看到 `开始` 后的进度信号才算真的跑起来。
- 不要用 Claude 版后台 watcher 模板；Codex 版默认让用户用 URL 回来取。
- 不要替用户授权第三方 app，也不要绕过登录、CAPTCHA 或付费限制。
