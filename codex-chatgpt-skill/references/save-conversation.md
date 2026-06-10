# 聊天记录落盘

把 ChatGPT 对话/产物保存到本地。显式触发：用户说要存才存，不自动写盘。

## 何时触发

用户说类似下面的话：

- "把这个对话存下来" / "保留到本地"
- "下载刚才那个对话"
- "把那个 DR 报告存到本地" / "落盘这个 Canvas"
- "存这张图片"
- "我要保留 ChatGPT 给我的这个回答"

Codex 取回结果后，用户回一句"存下来"也触发本流程。

## 落盘目录约定

默认根目录：`~/Downloads/chatgpt-skill/`。如果用户明确指定别的路径就用他给的。

文件名规范：`YYYY-MM-DD_<title-sanitized>_<uuid8>.<ext>`

- `title-sanitized`：把对话标题里 `/ \ : * ? " < > |` 和空白换成 `_`；保留中文和常规标点
- `uuid8`：conversation URL 末尾的 8 位（`/c/6a142e3d-...` 取 `6a142e3d`）
- 同名重复加 `(2)` `(3)` 后缀

## 按内容类型分 3 档

| 档 | 标志 | 取内容路径 |
|---|---|---|
| A. 普通 chat message | 默认情况，无 artifact 卡片 | `<main>` 文本 + Codex 写 `.md` |
| B. Artifact（DR / Canvas）| 主区域有独立卡片、下载菜单或 `internal://deep-research` 类占位 | 点 artifact 自带导出菜单 |
| C. 图片 | assistant message 是图片元素 | "分享此图片" → "下载" |

## 档 A：普通 chat message

主 Codex 执行：

1. 从 `tab.url()` 或当前地址栏记录 conversation URL。
2. 用 `<main>` 文本拿全文：
   ```js
   const text = await tab.playwright.evaluate(() =>
     document.querySelector("main")?.innerText ?? document.body?.innerText ?? ""
   );
   ```
3. 从全文里提取：
   - 用户提问
   - assistant 完整回答（到 disclaimer 之前）
   - 思考时间标记（"已思考 Xm Ys" / "已思考 Xs"），如有
   - 模型标记（当前页面的模型选择器 / 模型 pill 可见文本；位置可能在顶部 banner 或 composer 附近）
4. Thinking 模型注意剥掉折叠思考过程，只保留 final answer，思考耗时写入 `think_time`。
5. 主 Codex 用 shell 建目录：`mkdir -p ~/Downloads/chatgpt-skill/`。
6. 写 Markdown 文件。

### Markdown 模板

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

## 档 B：Artifact（DR / Canvas）

普通 `<main>` 文本有时能拿到 Canvas 短文，但 DR / 独立 artifact 更稳的路径是导出。

步骤：

1. 在 artifact 卡片右上角找下载图标或导出菜单。不要依赖固定坐标，先用 snapshot 或截图确认。
2. 点开菜单后选择 "导出到 Markdown"。除非用户明确要 PDF/Word。
3. ChatGPT 常把 DR 下载为 `~/Downloads/deep-research-report.md`。这个名字可能固定，必须马上移动改名，避免下一次下载覆盖。
4. 移动到约定目录：
   ```bash
   mkdir -p ~/Downloads/chatgpt-skill/
   mv "$HOME/Downloads/deep-research-report.md" \
      "$HOME/Downloads/chatgpt-skill/2026-05-25_中期复用浏览器对比_6a142e3d.artifact.md"
   ```
5. 再写一个同名索引 markdown（不带 `.artifact`）含 frontmatter 指向 artifact 文件。

## 档 C：图片

走"分享此图片" → "下载"。下载到 `~/Downloads/ChatGPT Image YYYY年M月D日 HH_MM_SS.png` 后立刻移动改名：

```bash
mkdir -p ~/Downloads/chatgpt-skill/
mv "$HOME/Downloads/ChatGPT Image 2026年5月25日 15_25_50.png" \
   "$HOME/Downloads/chatgpt-skill/2026-05-25_橘色小猫卡通画_6a13f6d5.png"
```

可选：写一个伴随 `.md` 索引，记录 prompt、conversation URL、模型、图片文件名、捕获时间。

## 触发流程总览

```
用户："把这个对话存下来" / "把那个 DR 落盘" / 等
        ↓
主 Codex：判断当前对话是 A / B / C 哪一档
        ↓
A 档 → <main> 文本 → 加 frontmatter → 写 .md
B 档 → 导出 Markdown → mv 改名 → 写索引 .md
C 档 → 分享此图片 → 下载 → mv 改名 → 写索引 .md
        ↓
告诉用户：保存路径 + 文件大小
```

## 易踩的坑

- DR artifact 导出文件名可能固定为 `deep-research-report.md`，多次下载会互相覆盖。必须每次先 mv 再下下一个。
- `<main>` 文本可能在页面刚加载时只返回 footer。看到只有模型名和免责声明时，等几秒再取一次。
- Thinking 折叠思考过程可能被一起拉回。只保留 final answer。
- 同名文件直接覆盖会丢数据。写文件前检查冲突，存在则加 `(2)` `(3)` 后缀。
- 对话标题里含 `/` 会导致路径错误，必须 sanitize。
- 不要落盘 ChatGPT 设置/Memory/隐私信息。只有用户明确要求保存的 chat message / artifact / 图片可以落盘。
