# ChatGPT 错误、限流、配额的可见信号与处理

> 轮询流程和主 Codex 都可能在任何时刻撞上下面这些状态。**永远不要静默重试**，永远把你看到的可见文本原样报告给用户，让他决定下一步。

## 1. 速率限制 / "Too many requests"

### 可见信号

- 弹窗或顶部红色 banner，文本含 "rate limit"、"too many requests"、"速率限制"、"请求过多"、"请稍后再试"
- composer 被禁用 + 发送按钮变灰
- assistant 消息位置出现错误卡片（红色边框 + 错误图标）
- 有时会显示具体重试时间："Try again in X seconds/minutes"

### 处理

- **不要自动重试**，哪怕看到具体倒计时
- 报告：原始可见文本 + 是否给了倒计时 + 当前模型
- 让用户决定：等、换模型、换账号

## 2. Pro / Plus 配额耗尽（"You've reached the limit"）

### 可见信号

- 弹窗或 banner，文本含 "reached the limit"、"达到使用上限"、"Pro 用量已达上限"、"limit on GPT-X" 这类
- 经常附带 "Resets at YYYY-MM-DD HH:MM" 或 "Resets in X hours"
- 模型选择器 / 模型 pill 可能自动降级（"Pro" 灰掉，自动选了别的模型）

### 处理

- 报告：原始文本 + 重置时间（如果有）
- **不要自动降级到别的模型**——用户选了 Pro 是有理由的，静默换模型会让结果对用户不可信
- 让用户决定：等到 reset、换账号、显式同意降级

## 3. 模型不可用 / 临时下线

### 可见信号

- 模型选择器 / 模型 pill 文本变成 "(unavailable)" 或带感叹号
- 选模型时该选项变灰、置底、带 "Temporarily unavailable" 副标题
- 提交后立刻出错："This model is currently unavailable"
- 偶尔伴随服务状态页面的链接

### 处理

- 报告看到的具体模型 + 文本
- 让用户决定：换模型、等、去 status.openai.com 看

## 4. CAPTCHA / 人机验证

### 可见信号

- Cloudflare 拦截页（"Just a moment..."、"Verifying you are human"）
- ChatGPT 内部弹出 hCaptcha / Turnstile 框
- composer 被替换成"Verify"按钮

### 处理

- **绝对不要尝试自动完成 CAPTCHA**（违反 ChatGPT TOS + 安全边界）
- 轮询流程立刻返回 NEEDS_USER_INPUT，blocker_type: captcha
- 让用户在浏览器里亲自完成验证，完成后让他通知主 Codex 继续轮询

## 5. OAuth / 第三方 app 授权弹窗

### 可见信号

- 弹窗标题类似 "Connect Google Drive to ChatGPT" / "Authorize GitHub"
- "Continue with [Google/GitHub/...]" 按钮
- 跳到 accounts.google.com / github.com/login/oauth/authorize 的 URL
- "ChatGPT 想要访问以下权限：..." 列出的 scope 清单

### 处理

- **绝对不要替用户点同意/Continue/Authorize 按钮**（参见 SKILL.md "绝对不做" 第 3 条）
- 轮询流程返回 NEEDS_USER_INPUT，blocker_type: oauth
- blocker_visible_text 引述完整的"将要访问"列表（让用户审查 scope）
- 让用户决定要不要授权 + 自己点

## 6. Session 过期 / 需要重新登录

### 可见信号

- 重定向到 https://auth.openai.com/login 或 /auth/login
- "Please log in to continue" 提示
- ChatGPT 主页变成 landing page（不是侧栏布局）

### 处理

- 轮询流程返回 NEEDS_USER_INPUT，blocker_type: login
- 让用户在浏览器里亲自登录
- **绝对不要替用户输入密码 / OTP**
- 登录完成后让他继续轮询

## 7. "Continue generating" 截断

### 可见信号

- 最新 assistant message 末尾出现 "Continue generating" 或 "继续生成" 按钮
- 内容看起来戛然而止（半句话、表格半截、代码块没闭合）

### 处理

- 这不一定是错误，可能只是 ChatGPT 输出太长被自动截断
- 轮询流程返回 NEEDS_USER_INPUT，blocker_type: continue_generating
- 让用户决定：要不要让 ChatGPT 续、是否已经够了
- **不要让轮询流程自己点 Continue**——这是用户级别决策，可能再续几千 token 才停

## 8. ChatGPT 中途反问 / 要求 clarification

### 可见信号

- 没有"思考中"、没有 stop 按钮（说明已经停了）
- 最新 assistant message 是个问题（问号结尾 / "你是想要 X 还是 Y" / "Could you clarify..."）

### 处理

- 轮询流程返回 NEEDS_USER_INPUT，blocker_type: clarification_question
- blocker_visible_text 引用 ChatGPT 的原问题
- **不要替用户回答**——这违背委托的初衷，用户委托是希望 ChatGPT 帮他想，不是让 Codex 替他做选择
- 让用户回答后继续轮询

## 9. 文件上传失败

### 可见信号

- 上传的 chip 显示红色边框 / 感叹号
- "Upload failed" / "File too large" / "Unsupported format" 提示
- 文件 chip 旁出现 retry 按钮但没有缩略图

### 处理

- 这种在**提交前**就能看到，轮询流程不会处理这个
- 主 Codex 在 send 之前看 chip 状态，发现失败就报告：原文件名 + 错误文本 + 文件大小
- 让用户决定：换文件、改格式、压缩

## 10. ChatGPT 服务整体故障

### 可见信号

- 页面长时间无响应（domSnapshot 多次失败）
- 整页 5xx 错误
- 网络面板大量失败请求（但轮询流程看不到这层）

### 处理

- 轮询流程的异常处理路径：domSnapshot 失败重试 1 次后仍失败 → 返回 ERROR
- 让用户去 status.openai.com 看 + 决定要不要等

## 总原则

| 现象 | 默认动作 |
|---|---|
| 可重试的瞬时错误（网络抖动） | 轮询流程自动重试 1 次 |
| 速率限制 / 配额 | **永不自动重试**，让用户决定 |
| 需要用户交互（OAuth / CAPTCHA / login / clarification） | **永不替用户做**，立刻 NEEDS_USER_INPUT |
| 模型不可用 | **永不静默降级**，让用户选 |
| 文件 / 上传错误 | 提交前发现，让用户换 |

每一种"让用户决定"都要把**你在页面上实际看到的文本原样引述**给用户，不要解读不要省略，让他基于事实判断。
