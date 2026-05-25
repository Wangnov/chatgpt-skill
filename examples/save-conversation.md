# Example: 把对话/产物落盘到本地

## 触发说法

- "把这个对话存下来" / "保留到本地"
- "下载刚才那个 DR" / "把这个 Canvas 落盘"
- "存这张图片"
- "我要保留 ChatGPT 给我的这个回答"

watcher 取回后用户也常说一句"存下来"。

## 操作分 3 档（参见 [references/save-conversation.md](../references/save-conversation.md)）

主 Claude 先判断当前 ChatGPT 对话是哪一档：

| 档 | 判断信号 | 路径 |
|---|---|---|
| A 普通 chat message | 无 artifact 卡片，主区域是常规文字回答 | `get_page_text` + Write `.md` |
| B Artifact（DR/Canvas）| 主区域有独立带边框的卡片，右上有 ↓ 和 ⛶ 图标 | 点 ↓ → "导出到 Markdown" → `mv` |
| C 图片 | assistant message 是图片元素 | "分享此图片"→"下载" → `mv` |

## 端到端示例 1：档 A（Pro 给的 PR review）

用户："把刚才那个 rust-silk review 存下来"

主 Claude 执行：

```
1. tabs_context_mcp → tabId, URL = /c/6a143dfe-...
2. get_page_text(tabId)
3. 提取：
   - 标题 "深度评审 rust-silk"
   - 用户提问 "@GitHub 深度 review Wangnov/rust-silk..."
   - assistant 回答（"已思考 16m 14s" 之后到 disclaimer 之前）
   - 模型 "进阶专业"（Pro）
   - app_calls: ["@GitHub"]
4. Bash: mkdir -p ~/Downloads/chatgpt-skill/
5. Bash: ls ~/Downloads/chatgpt-skill/ | grep "rust-silk_6a143dfe"  # 检查重名
6. Write: ~/Downloads/chatgpt-skill/2026-05-25_深度评审_rust-silk_6a143dfe.md
   含 YAML frontmatter + 用户提问 + 完整 review markdown
7. 告诉用户：
   "已存 ~/Downloads/chatgpt-skill/2026-05-25_深度评审_rust-silk_6a143dfe.md (8.4 KB)"
```

## 端到端示例 2：档 B（DR 报告）

用户："把那个 DR 报告下载到本地"

主 Claude 执行：

```
1. tabs_context_mcp → URL = /c/6a142e3d-...
2. 看主区域有 artifact 卡片 + accessibility tree 含 "internal://deep-research" → 判定档 B
3. 在 artifact 卡片右上找 ↓ 下载图标
4. left_click 该图标 → 弹出菜单
5. left_click "导出到 Markdown"
6. ChatGPT 下载到 ~/Downloads/deep-research-report.md（固定名）
7. Bash: mkdir -p ~/Downloads/chatgpt-skill/
8. Bash: mv "~/Downloads/deep-research-report.md" \
            "~/Downloads/chatgpt-skill/2026-05-25_中期复用浏览器对比_6a142e3d.artifact.md"
9. Write 索引：~/Downloads/chatgpt-skill/2026-05-25_中期复用浏览器对比_6a142e3d.md
   含 frontmatter + 用户提问 + 指向 artifact 文件
10. 告诉用户：
    "DR 报告已存：
     - 索引：~/Downloads/chatgpt-skill/2026-05-25_中期复用浏览器对比_6a142e3d.md
     - 全文：~/Downloads/chatgpt-skill/2026-05-25_中期复用浏览器对比_6a142e3d.artifact.md (31 KB)"
```

## 端到端示例 3：档 C（生成的图片）

用户："存这张猫的图"

主 Claude 执行：

```
1. tabs_context_mcp → URL = /c/6a13f6d5-...
2. 主区域是图片 → 判定档 C
3. find "分享此图片" button → left_click
4. 弹窗 → find "下载" button（橙色） → left_click
5. ChatGPT 下载到 ~/Downloads/ChatGPT Image 2026年5月25日 15_25_50.png
6. Bash: mkdir -p ~/Downloads/chatgpt-skill/
7. Bash: ls -t ~/Downloads/ChatGPT\ Image*.png | head -1  # 找最新一个
8. Bash: mv "<最新 PNG>" \
            "~/Downloads/chatgpt-skill/2026-05-25_橘色小猫卡通画_6a13f6d5.png"
9. 可选：Write 伴随 .md 索引
10. 告诉用户：保存路径 + 文件大小
```

## 容易踩的坑

- **DR artifact 导出文件名固定**：每次都是 `deep-research-report.md`，**多次下载会互相覆盖**。主 Claude 必须 mv 完一个再下下一个，不要批量下到 `~/Downloads/` 再统一处理
- **Thinking 模型的折叠思考过程**：get_page_text 会一起拉回。要识别"已思考 Xs"标记，**只保留 final answer**，思考过程放进 frontmatter 的 `think_time` 字段就够了
- **archived 对话 navigate 不到**：用户如果想存的对话已经归档，要先去设置 → 数据管理 → 已归档聊天 → 取消归档
- **同名文件覆盖**：Write 之前 `ls` 检查，存在则加 `(2)` `(3)` 后缀
- **对话标题含特殊字符**：sanitize 必做（`/ \ : * ? " < > |` → `_`），否则 mkdir / write 失败
- **batch 落盘可能很慢**：用户说"备份我所有的 PR review 对话"时，要逐个 navigate + 处理，一次一个，不要并发（会抢同一个 Chrome tab）

## 2026-05-25 实测路径已验证

- 档 A：`get_page_text` 实测多次拉到完整 Pro review（rust-silk 8k 字 / DSE 数学 21m 5s）
- 档 B：DR artifact 导出 Markdown 实测成功（55m 报告 31KB，22 引用，279 搜索）
- 档 C：生成图片"分享此图片→下载"实测成功（2MB PNG）
