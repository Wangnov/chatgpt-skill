# Changelog

按 [Keep a Changelog](https://keepachangelog.com/) 格式记录，本项目遵循语义化版本（pre-1.0 阶段）。

## [v0.8.0] - 2026-05-31

### Added
- 基于 v0.7.3 的视觉和 README 口径，新增 Codex 可用的第二个 Skill 包。
- 仓库改为双 Skill 分发：`claude-chatgpt-skill` 保留原 Claude Code + `claude-in-chrome` 实现，`codex-chatgpt-skill` 新增 Codex + Codex Chrome Extension 实现。
- 两个 Skill 都新增 `agents/openai.yaml`，便于 `npx skills add -s <name> -a <agent>` 精确安装。
- Codex 版新增 `references/codex-chrome-runtime.md` 和 `references/codex-waiting.md`，描述 browser-client 接入、当前回合轮询、Deep Research heartbeat、Pull fallback、file chooser 上传和下载处理。
- Codex 版新增 `examples/file-upload-roundtrip.md` 和 `examples/deep-research-pull.md`，覆盖已实测的文件上传闭环和 Deep Research heartbeat / Pull fallback。

### Changed
- 根 README 改为双 Skill 安装说明，使用 skills v1.5.9 实测可用的 `-l`、`-g`、`-s`、`-a`、`-y` 参数，不再提不存在的 full-depth 参数。
- Codex 版使用当前回合轮询和 Deep Research heartbeat：先找 automation / wakeup 工具；没有 automation 时默认 spawn agent fallback；两者都不可用时才 Pull，避免把 Claude background Haiku watcher 模板误带进 Codex。

### Verified
- Codex Chrome Extension 在停掉其它 Chrome debugger 控制方后，可以复用用户已登录的 ChatGPT tab，读取页面结构和截图，展开模型菜单和 app 菜单，上传文件，提交带附件 prompt，等待完成并读取回答。
- Codex Deep Research 已跑通：计划卡 → `开始` → 研究进度 → heartbeat 完成；完成报告渲染在 `iframe[title="internal://deep-research"]`，截图可见 `研究完成情况：3m · 3 次引用 · 68 个搜索`。
- `npx skills add . -l` 可列出 `claude-chatgpt-skill` 和 `codex-chatgpt-skill`。

---

## [v0.7.3] - 2026-05-31

### Changed
- **Logo / banner 完全重设计** —— 主题从 v0.7.2 的抽象"黑洞星系"改为**直白表达项目内核：Codex 和 Claude Code 两个智能体"操控" ChatGPT**：
  - `assets/logo.png`（1024×1024）—— 两个光泽 3D 机器人吉祥物合捧中央 ChatGPT 球：**左侧蓝紫机器人身上带终端 `>_`（Codex）**，**右侧橙色机器人身上带像素格（Claude Code）**，中央深色球体是 ChatGPT 经典六瓣结。亲和 + 品牌辨识 + "操控"关系一眼可读
  - `assets/banner.png`（2400×800）—— 横版故事场景：蓝紫 Codex 机器人在左、橙色 Claude Code 机器人在右，**两边各射出一束"命令粒子流"汇入中央 ChatGPT 球**；浅紫→浅橙柔和渐变底
  - 出图流程：`gpt-image-2-skill`（Codex provider）先并发出 **10 个"操控"隐喻方向**（提线木偶 / 齿轮驱动 / 双光标点击 / 卫星指令 / 机器人合捧 / 双终端打命令 / 指挥棒 / 电路核心 / 瞄准三角 / 磁极转向）→ 选定"机器人合捧"方向 → 4 轮品牌化迭代 → 2K 定稿
- **banner.svg 改用 CSS `@keyframes` 动画（不用 SMIL）**：GitHub 通过 `<img>` 加载 SVG 时 SMIL (`<animate>` / `<animateTransform>`) 渲染不稳定（很多浏览器/上下文不播放），CSS keyframes 才稳定。叠加动效：中央 ChatGPT 球**脉动光晕** + 两侧**命令粒子流向中心汇聚** + 背景浮游粒子。PNG 以 base64 JPEG 嵌进 SVG，单文件自洽
- **README 内容更正** —— v0.7.2 README 高估了非 Claude Code host 的支持，本版按真相重写：
  - 删掉 "Codex CLI 主推"、"Cursor / Cline / … ✅ 兼容" 这类**未实测的声明**
  - `file_upload` 表里 "Claude Code / Codex CLI = ❌" 改成只标 Claude Code ❌，Codex CLI 标 "未测"（codex 不依赖 Claude app 的 `validateLocalFileAccess`）
  - "整套机制走 claude-in-chrome MCP（或同等浏览器接入工具）" 改成 "**强制** 走 `claude-in-chrome`"，跟 SKILL.md 接入方式口径对齐
  - "双主线 Host" 改成 "主要 host: Claude Code；Skill 文件是通用 Markdown 可被其他 host 加载，但 watcher 异步等待是 Claude Code 的 `Agent({run_in_background:true})` 专属 API"
  - 新增 "已知限制 #2"：watcher 异步等待不是通用模式，其他 host 需各自适配 background-subagent 等价物
  - badge 从 `hosts-Claude Code · Codex CLI · Cursor · Cline` 简化为 `primary host: Claude Code` + `browser MCP: claude-in-chrome`；banner alt text 同步改为机器人场景描述

### Notes
- SKILL.md / references / examples / scripts 与 v0.7.1 完全一致 —— 本版是**品牌视觉重设计 + 文档对齐**，不影响装机用户的实际能力
- 如果未来真把 Codex CLI / Cursor 跑通了 watcher 等价物，再开 v0.8 加该 host 的专属指令分支

---

## [v0.7.2] - 2026-05-31

### Added
- **自制项目视觉资产**（用 `gpt-image-2-skill` + lobehub icons 生成）：
  - `assets/logo.png`（1024×1024）—— 黑洞 + 双色螺旋臂的抽象宇宙图腾（蓝紫色 Codex 旋臂、橙色 Claude Code 旋臂围绕中央黑洞 ChatGPT）。前后 3 轮共 12 个备选，用户选了 H 方向（最具艺术感、最抽象）
  - `assets/banner.png`（2400×800）—— 横版宇宙星云底图，黑洞居中 + 双色螺旋臂左右护法
  - `assets/banner.svg`（77KB）—— **在 PNG 底图基础上叠加 SVG SMIL 动画**：脉动黑洞光晕（`<animate>` r 70→110）、4 条蓝紫/橙色椭圆轨道（`<animateTransform type="rotate">` 22s/26s/34s/40s 反向旋转）、6 个浮游粒子（cy + opacity 动画）。PNG 用 base64 嵌进 SVG，单文件自洽，GitHub 直接渲染
- **README.md 完整双语重写**（对标 [wangnov/mailpilot](https://github.com/wangnov/mailpilot) 规格）：
  - 顶部 banner.svg + h1 + tagline + 6 枚 badge（skill version / install / license / platform / hosts / zero credentials）
  - 中英文双锚点导航
  - 9 项特性 emoji 标题（零依赖 / 双主线 host / 浏览器复用 / watcher subagent / pull 模式 / 落盘 / 管理 / 安全 / 手册式）
  - 模型矩阵表 + Host 兼容性表 + 验证场景表
  - 项目结构树、设计原则、已知边界（file_upload 章节）、CHANGELOG pointer
  - 末尾压缩版 English section 提供英文入口

### Changed
- `.gitignore` 由 `assets/` 整目录忽略改为 `assets/refs/` + `assets/tmp/`，让正式产物可入库、实验素材仍 ignore

### Notes
- 这是**纯品牌 / 文档**版本，Skill 主指令 / references / examples / scripts 与 v0.7.1 完全一致——不影响装机用户的实际能力
- banner.svg 在 GitHub README 渲染时动画会自动播放（GitHub 支持 SVG SMIL）；本地 IDE 预览或 Markdown 渲染器若不支持 SMIL 会退化为静态首帧

---

## [v0.7.1] - 2026-05-31

### Changed
- **file_upload 根因更正**（用户 codex 反编译 Claude app 发现）：之前以为是 [#31210](https://github.com/anthropics/claude-code/issues/31210) "等 Anthropic 修就好的 bug"，**实际是产品边界**——`validateLocalFileAccess` 第一关要求 session id 以 `local_` 开头。Claude Code session 是普通 UUID（`c9cf...`），**永久过不了**这关。Claude Cowork（local-agent-mode）的 session id 是 `local_*` 才能用
- SKILL.md 第 3 节"文件 / 图片上传" 整段重写为 host 分级表（Claude Code ❌ / Claude Cowork ✅ 限沙盒 / 其他 agent 未测）
- `references/manage-actions.md` 两处旧 `#31210` 引用改为 host 分级描述
- README.md 同步更新

### Fixed
- 错误信息 `only files the user has shared with this session can be uploaded` 是误导性的——它不区分"session 类型不对" vs "路径没共享"。文档说明了真实根因

### Verified
- 用户在 Claude Cowork 实测上传文件**成功**（local-agent-mode session 路径里的文件）
- Claude Code 里所有路径都失败（cwd / Downloads / @-path / session tmp dir 全部撞同一个错）

---

## [v0.7] - 2026-05-25

### Added
- **聊天记录落盘**——把 ChatGPT 对话/Artifact/图片保存到本地，按 3 档分流：
  - 档 A 普通 chat message：`get_page_text` + 主 Claude 写 `.md`
  - 档 B Artifact（DR / Canvas）：点 artifact 自带 ↓ 菜单 → "导出到 Markdown" → `mv`
  - 档 C 图片：复用 v0.5 "分享此图片→下载" → `mv`
- `references/save-conversation.md`（240 行）—— 完整落盘手册：3 档详细操作、Markdown 模板（YAML frontmatter）、文件名规范、跟 watcher 衔接、6 类踩坑
- `examples/save-conversation.md` —— 3 个端到端示例（rust-silk review / DR 报告 / 生成图片）
- SKILL.md 加 "聊天记录落盘到本地" 节 + description 触发语扩展（"存下来 / 下载这个对话 / 保留这张图片到本地"）

### Verified
- 档 A：之前多次 `get_page_text` 实测拉到完整 Pro review（rust-silk / codex-asr / DSE 数学）
- 档 B：DR artifact 导出 Markdown 实测成功（55m 报告 31KB，22 引用，279 搜索）
- 档 C：生成图片"分享此图片→下载"实测成功（2MB PNG）

### Design Choices
- **显式触发**：用户没说要存就不写盘，避免污染硬盘（防止 watcher COMPLETE 后自动堆积大量对话副本）
- **默认目录 `~/Downloads/chatgpt-skill/`**：可见性高，便于用户在 Finder 看到。改用 `~/.chatgpt-skill/` 隐藏目录可在后续版本切换
- **文件名约定** `YYYY-MM-DD_<title>_<uuid8>.<ext>`：保留中文标题、防文件系统不友好字符、用 uuid8 防同名冲突
- **DR/Canvas artifact 不用 get_page_text**：v0.6 取 DR 时发现 artifact 内容在 `<main>` 之外，accessibility tree 只标记 `internal://deep-research` 占位——必须走 artifact 自带的 ↓ 导出菜单

### Discovered
- **DR artifact 导出文件名固定**（`deep-research-report.md`），多次下载会互相覆盖——主 Claude 必须 `mv` 完一个再下下一个，不能批量下到 `~/Downloads/` 再统一处理
- **ChatGPT artifact 自带导出菜单**：右上 ↓ 图标 → 4 选项（复制内容 / 导出 Markdown / 导出 Word / 导出 PDF）—— 这是档 B 的核心入口

---

## [v0.6] - 2026-05-25

### Added
- **Deep Research Pull 模式**——跨小时任务的正解：主 Claude 提交后**不 spawn watcher**，直接报 conversation URL，用户回来（哪怕新 session）主动取。`SKILL.md` 第 5 节"异步等待"加 pull 模式段
- `examples/deep-research-trigger.md` 完全重写：pull 模式操作步骤、6 种 DR 特有 UI 状态信号清单、跨小时任务的安全做法

### Discovered
- **DR 提交后不立刻跑**——会先弹研究计划确认卡（5 步 todo + N 秒倒计时 + 编辑/取消/开始）。watcher 模式会卡在 NEEDS_USER_INPUT
- **DR 模式激活的视觉信号**：composer placeholder 变 "获取详细报告"，下方出现 `+/深度研究/应用/站点/Pro` 专属控件
- **DR 完成判定**：5 步 checkbox 全部 ✓ + 报告正文出现（不再是"思考中"+disclaimer）
- **DR 跑起来后"开始"按钮变"更新"**——用户可中途调整研究计划

### Verified
- Pull 模式提交一个 DR 任务（2026 年 agentic browsing 工具横向对比）
- URL: `https://chatgpt.com/c/6a142e3d-a7a0-83ea-bf11-2f64484f4635`
- 主 Claude 报 URL 后立刻撤，不挂 watcher——验证用户跨 session 取回链路（待用户回来时完成）

---

## [v0.5] - 2026-05-25

### Added
- **产物下载流程**：实测三种产物（PDF/CSV 链接、生成图片、库历史文件）的下载路径都走浏览器原生通道 → `~/Downloads/`，跟 `file_upload` 的 bug 路径完全相反
- `references/manage-actions.md` 第 6.5 节 — 产物下载手册：入口位置 / 触发方式 / 命名规则 / 屏蔽掉的旁路 / 主 Claude 找文件的 Bash 命令
- `SKILL.md` 第 3 节加 **产物下载** 子节（与"文件上传暂不可用"形成对偶）

### Changed
- **修正"分享 = 创建公开 URL" 规则**：
  - 对话级"分享"：打开弹窗即创建（实测确认）
  - 图片"分享此图片"：打开**不会**自动创建，只在点"复制链接"时创建，所以为下载点开是安全的
- `references/manage-actions.md` 安全总则第 1 条限定为"对话级"

### Fixed
- `manage-actions.md` 第 7 节死引用："见 SKILL.md 第 3 节"改为"见本文件第 4-5 节"

### Verified
- ChatGPT 给的 PDF 下载链接（`W7D3_joint_variation_ratio_algebra_guide.pdf`，200KB）→ ~/Downloads/ ✅
- Instant 生成图片（`ChatGPT Image 2026年5月25日 15_25_50.png`，2MB）→ ~/Downloads/ ✅
- `javascript_tool` 取 `img.src` → 返回 `[BLOCKED: Cookie/query string data]`（确认 claude-in-chrome 屏蔽含凭证 URL）

---

## [v0.4] - 2026-05-25

### Added
- **`references/manage-actions.md`**（235 行）— 管理 ChatGPT 完整手册：
  1. 对话级管理（普通 vs 项目内 `...` 菜单差异）
  2. 项目级管理（创建/设置/删除）
  3. Message 级 `...`（branch、source、朗读）
  4. 数据管理面板（共享链接 / 归档 / 导出）
  5. 个性化面板（含 Memory `[管理]`、用户隐私字段警告）
  6. 全局页面（库 / 应用 / 安排）
  7. URL 形态 cheat sheet（6 种格式）
  8. 安全总则（8 条）
- `SKILL.md` 新增"管理 ChatGPT"节，含 3 条特别警告

### Verified
- 创建/重命名/分享/归档/取消归档/删除项目和对话端到端跑通
- DSE 数学项目知识库自动引用（Pro 21m 5s 实测，watcher 累计 19 分钟，主 Sonnet 0 次打扰）
- 共享链接管理（撤销公开 URL 路径）
- 数据管理面板 13 个 tab 全部查看

### Discovered (Safety-Critical)
- **打开"分享"弹窗即创建公开 URL**——哪怕不复制不发送（v0.5 修正为"对话级独有，图片不会"）
- **删除项目永久删除所有项目内对话**——有二次确认弹窗
- **删除对话不自动清 Memory**——必须单独去个性化 → 记忆 [管理] 删
- **项目内对话不能置顶**——点了报 toast
- **个性化的"你的详情"字段含用户隐私**——绝不导出到外部

---

## [v0.3] - 2026-05-25

### Added
- **Watcher subagent 模式**（异步等待主推方案）：spawn 一个 `background: true` 的 Haiku watcher subagent，循环 `read_page` 看完成，主 Sonnet 全程沉默
- `references/watcher-subagent.md`（175 行）— Agent 调用模板 + watcher prompt 模板 + 4 类任务的 sleep 间隔表 + NEEDS_USER_INPUT 检测分支
- `references/error-and-limits.md`（158 行）— 10 种错误/限流场景的可见信号和处理：
  - 速率限制 / Pro 配额耗尽 / 模型不可用
  - CAPTCHA / OAuth / session 过期
  - Continue generating 截断 / 中途反问
  - 文件上传失败 / ChatGPT 整体故障

### Changed
- 异步等待主推方案从 `scripts/heartbeat.sh`（v0.2）改为 watcher subagent
- heartbeat 模式降级为 fallback（环境不支持 Agent 工具时用）
- 4 个 examples 全部从 heartbeat 改成 watcher

### Verified
- Pro + @GitHub PR review：watcher 累计 240s，ChatGPT 思考 5m 7s，**主 Sonnet 0 次被打扰**，watcher 消耗 86k Haiku token
- Pro + 项目 PDF 知识库：21m 5s 长任务下 watcher 模式稳定

---

## [v0.2] - 2026-05-25 (初版)

### Added
- **`SKILL.md`** 主指令 — 200 行内手册式 Skill：何时触发 / 接入方式（强制 claude-in-chrome MCP，禁 Playwright）/ 操作流程（4 条原则）/ 完成判定 / 异步等待 / 绝对不做
- **`scripts/heartbeat.sh`** — 40 行 shell fallback：sleep + exit + 让主 LLM 在唤醒时静默检查
- **`references/claude-code-async.md`** — heartbeat fallback 文档
- **5 个 examples**：
  - `auto-google-drive-list.md` — 默认模型 + @Google 云端硬盘
  - `thinking-github-unread-issues.md` — Thinking + @GitHub
  - `deep-research-trigger.md` — `+` 菜单触发深度研究
  - `pro-github-pr-review.md` — Pro + @GitHub PR 审核
  - `project-context-consult.md` — 进项目主页用项目知识库

### Design Principles
- **手册式而非工程式**：不写 selector / 不写状态机 / 不写 manifest schema。靠 LLM 当场视觉判断
- **信任 LLM**：主指令短、按需 reference、不堆规则
- **安全优先**：不替用户授权 OAuth / 不绕 CAPTCHA / 不存 session / 破坏性操作必须用户确认
- **文件上传暂不可用**：Claude Code MCP 桥接 bug [#31210](https://github.com/anthropics/claude-code/issues/31210)，需要用户在浏览器里手动上传

### Verified
- Thinking + @Google 云端硬盘 列文件（14s）
- Pro + @Google 云端硬盘 推断工作轨迹（5m 25s）
- 5 类模型切换 / app mention 验证 / 三种 URL 格式探测

---

## 待办（按优先级）

- [ ] Pro 模型 message 级 `...` 是否真有"安排"创建定时任务的入口（v0.4 留下的悬而未决项）
- [ ] Canvas / artifact 取回流程（watcher 的 get_page_text 是否够用还是需要专门处理）
- [ ] ADA (Advanced Data Analysis) 上传 csv → 跑分析 → 下载结果链路
- [ ] 等 Anthropic 修 [#31210](https://github.com/anthropics/claude-code/issues/31210) 解锁 file_upload，回头补完整上传 + 等待 + 下载 闭环
- [ ] 发布到 [skills.sh](https://skills.sh) 索引（待 v1.0）
