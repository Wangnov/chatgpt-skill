# 聊天记录落盘

把 ChatGPT 对话/产物保存到本地。**显式触发**——用户说要存才存，不自动写盘。

## 何时触发

用户说类似下面的话：

- "把这个对话存下来" / "保留到本地"
- "下载刚才那个对话"
- "把那个 DR 报告存到本地" / "落盘这个 Canvas"
- "存这张图片"
- "我要保留 ChatGPT 给我的这个回答"

watcher 模式下也常见：主 Claude 把 watcher 取回的结果给用户后，用户回一句"存下来"。

## 落盘目录约定

默认根目录：**`~/Downloads/chatgpt-skill/`**（用户决定，可见性高）。如果用户明确指定别的路径就用他给的。

文件名规范：`YYYY-MM-DD_<title-sanitized>_<uuid8>.<ext>`

- `title-sanitized`：把对话标题里 `/ \ : * ? " < > |` 和空白换成 `_`；保留中文和常规标点
- `uuid8`：conversation URL 末尾的 8 位（`/c/6a142e3d-...` 取 `6a142e3d`）
- 同名重复加 `(2)` 后缀

例：`2026-05-25_中期复用浏览器对比_6a142e3d.md`

## 按内容类型分 3 档（核心分流）

判断当前对话属于哪档，走对应路径：

| 档 | 标志 | 取内容路径 |
|---|---|---|
| **A. 普通 chat message** | 默认情况，无 artifact 卡片 | `get_page_text` + 主 Claude 加工写 .md |
| **B. Artifact**（DR / Canvas）| 主区域有独立卡片，accessibility tree 含 `internal://deep-research` 或类似占位符 | **不要用 get_page_text**——点 artifact 自带导出菜单 |
| **C. 图片** | assistant message 是图片元素 | "分享此图片"→"下载"（参见 `manage-actions.md` 第 6.5 节）|

## 档 A：普通 chat message 落盘

主 Claude 直接执行：

1. `mcp__Claude_in_Chrome__tabs_context_mcp` 拿当前 tabId 和 conversation URL
2. `mcp__Claude_in_Chrome__get_page_text` 拿全文
3. 从全文里提取：
   - 用户提问（一般是顶部消息，标题"你说："之后的内容）
   - assistant 完整回答（"ChatGPT 说："之后到 disclaimer 之前）
   - 思考时间标记（"已思考 Xm Ys" / "已思考 Xs"），如有
   - 模型标记（底部模型 pill 文本，如"进阶专业" / "深入"）
4. **Thinking 模型注意剥掉折叠思考过程**——只保留 final answer，记下 think_time
5. 主 Claude 用 Bash 建目录：`mkdir -p ~/Downloads/chatgpt-skill/`
6. 主 Claude 用 Write 写文件（模板见下）

### Markdown 模板（档 A）

```markdown
---
title: <对话标题>
conversation_url: https://chatgpt.com/c/<uuid>
model: <Pro · 进阶 / Thinking · 深入 / Instant 等>
captured_at: <ISO 8601 时间戳>
think_time: <如 "5m 7s"，没有就 null>
app_calls: [<@GitHub / @Google 云端硬盘 / ...>]
sources_count: <如果末尾有"来源"段落含 N 个 link>
---

# <对话标题>

## 用户提问

<原始 prompt，原样保留 markdown 结构>

## ChatGPT 回答

<完整 assistant 回答，原样保留 markdown 结构、表格、代码块、source citation 链接>
```

## 档 B：Artifact（DR / Canvas）落盘

不要用 get_page_text——artifact 内容在 `<main>` 之外，accessibility tree 只标记 `internal://deep-research` 占位符（v0.6 取 DR 实测确认）。

步骤：

1. 在 artifact 卡片右上角找 **下载图标 ↓**（一般在 (1169, 230) 附近，但坐标会变，建议 hover 找）
2. `left_click` 该图标 → 弹出菜单：
   ```
   复制内容
   导出到 Markdown
   导出到 Word
   导出到 PDF
   ```
3. 默认点 **"导出到 Markdown"**（保留结构 + source citation + 引用编号）。除非用户明确要 PDF/Word
4. ChatGPT 下载到 `~/Downloads/deep-research-report.md`（固定名，每次都覆盖前一个！）
5. 主 Claude 立刻 `mv` 到约定目录 + 改成规范文件名：
   ```bash
   mkdir -p ~/Downloads/chatgpt-skill/
   mv "~/Downloads/deep-research-report.md" \
      "~/Downloads/chatgpt-skill/2026-05-25_中期复用浏览器对比_6a142e3d.artifact.md"
   ```
6. 主 Claude 再写一个**索引 markdown**（同样命名，但不带 `.artifact`）含 frontmatter 指向 artifact 文件：

```markdown
---
title: 中期复用浏览器对比
conversation_url: https://chatgpt.com/c/6a142e3d-...
model: Pro · 进阶（Deep Research）
captured_at: 2026-05-25T22:30:00+09:00
think_time: 55m
artifact_type: deep_research
artifact_file: ./2026-05-25_中期复用浏览器对比_6a142e3d.artifact.md
sources_count: 22
search_count: 279
---

# 中期复用浏览器对比

DR 报告以 artifact 形式存于 `<file>.artifact.md`，本文件是元数据索引。

## 用户提问

<原始 prompt>
```

**关键：ChatGPT 导出的文件名固定（`deep-research-report.md`）**，**多次下载会互相覆盖**。主 Claude 必须**先 mv 再下下一个**，否则丢数据。

## 档 C：图片落盘

参见 `manage-actions.md` 第 6.5 节"产物下载"——走"分享此图片→下载"。下载到 `~/Downloads/ChatGPT Image YYYY年M月D日 HH_MM_SS.png`。

主 Claude 立刻 `mv` 到约定目录 + 改名：
```bash
mkdir -p ~/Downloads/chatgpt-skill/
mv "~/Downloads/ChatGPT Image 2026年5月25日 15_25_50.png" \
   "~/Downloads/chatgpt-skill/2026-05-25_橘色小猫卡通画_6a13f6d5.png"
```

可选：写一个伴随 `.md` 索引：

```markdown
---
title: 橘色小猫卡通画
conversation_url: https://chatgpt.com/c/6a13f6d5-...
model: Instant
captured_at: 2026-05-25T15:25:50+09:00
artifact_type: image
artifact_file: ./2026-05-25_橘色小猫卡通画_6a13f6d5.png
image_size: 2.0MB
image_dimensions: 1024x1024
---

# 橘色小猫卡通画

## 用户提问
画一个卷起来睡觉的橘色小猫...

## ChatGPT 生成
图片存于 `<file>.png`。
```

## 跟 v0.6 watcher 的衔接

watcher 取回完成 → 主 Claude 把结果呈现给用户 → **如果用户回应"存下来" / "保留" / "下载到本地"** → 主 Claude 按上面 3 档分流落盘。

watcher prompt 不需要改，落盘是主 Claude 收到 watcher 结果后**才决定要不要做**的下一步。

## 触发流程总览

```
用户："把这个对话存下来" / "把那个 DR 落盘" / 等
        ↓
主 Claude：判断当前对话是 A / B / C 哪一档
        ↓
A 档 → get_page_text → 加 frontmatter → Write .md
B 档 → 点 artifact 下载 ↓ → 选 Markdown → mv 改名 → 写索引 .md
C 档 → 点"分享此图片"→ 下载 → mv 改名 → 写索引 .md
        ↓
告诉用户：保存路径 + 文件大小
```

## 易踩的坑

- **DR artifact 导出文件名固定 `deep-research-report.md`**，多次下载互相覆盖。**必须每次 mv 再下下一个**
- **Thinking 折叠思考过程**会被 get_page_text 一起拉回。要从全文里**剥掉**（识别"已思考 Xs"之前的文本），只保留 final answer
- **同名文件**：直接覆盖会丢上次。主 Claude 写文件前用 `ls` 检查冲突，存在则加 `(2)` `(3)` 后缀
- **对话标题里含 `/`**：sanitize 一定要做，否则 `mkdir` 失败
- **`~/Downloads/chatgpt-skill/` 不存在**：第一次落盘要 `mkdir -p` 创建
- **不要落盘 ChatGPT 设置/Memory/隐私信息**：这是 chat message 内容才能落盘，不要去 `#settings/Personalization` 里读"你的详情"字段写盘
