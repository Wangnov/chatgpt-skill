#!/usr/bin/env bash
# chatgpt-web-delegate 心跳脚本
#
# 路径 A 模型：脚本只当闹钟。看 ChatGPT 页面的活由主 LLM 用 claude-in-chrome MCP 完成。
# 这里不碰浏览器、不读 DOM、不存 session。
#
# 用法：
#   scripts/heartbeat.sh <SECONDS> <CONVERSATION_URL> [<NOTE>]
#
# 主 LLM 用 Bash 工具的 run_in_background:true 起这个脚本。脚本结束（exit 0）后，
# Claude Code 会在主 LLM 下一轮检查时把 stdout 作为通知交付。
# 主 LLM 收到通知后用 claude-in-chrome 重新打开 URL 看是否完成。
#
# 默认行为：单次 sleep。需要多轮自动循环时，由主 LLM 重新起一轮 heartbeat。
# 这样做的好处是：每一轮唤醒后主 LLM 都会"重新看一眼页面"，不会被 stale 状态骗。

set -euo pipefail

SECONDS_TO_WAIT="${1:?usage: heartbeat.sh <SECONDS> <CONVERSATION_URL> [<NOTE>]}"
CONVERSATION_URL="${2:?missing conversation URL}"
NOTE="${3:-}"

# 限制最大 sleep，避免误传超大值挂死后台
if [ "$SECONDS_TO_WAIT" -gt 1800 ]; then
  echo "ERROR: SECONDS=$SECONDS_TO_WAIT exceeds 1800s cap; cap it or shorten the wait." >&2
  exit 1
fi

sleep "$SECONDS_TO_WAIT"

cat <<EOF
WAKE chatgpt-web-delegate
url=$CONVERSATION_URL
waited_seconds=$SECONDS_TO_WAIT
note=$NOTE

下一步：用 claude-in-chrome 重新打开上面的 URL，检查是否已完成（看"思考中/正在搜索/Stop generating"字样消失 + 末尾 disclaimer 出现 + composer 可输入）。
- 完成：用 get_page_text 或定位最后一条 assistant message 拉回完整答案，给用户。
- 未完成：再起一轮 scripts/heartbeat.sh，参数同上或按需调整 SECONDS。
EOF
