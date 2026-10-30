#!/usr/bin/env bash
# [session-start] VibeRails SessionStart hook
# 把 .vibe/ 的交接便條、規矩檔、狀態快取直接注入新會話的 context。
# 這是機械強制版的「啟動先讀 HANDOFF.md」——不靠 AI 記得去讀。
# stdout 會被 Claude Code 加進會話 context。

dir="${CLAUDE_PROJECT_DIR:-.}"
vibe="$dir/.vibe"
[ -d "$vibe" ] || exit 0

echo "[session-start] reason: 注入 .vibe/ 交接與規矩進新會話 context" >&2

if [ -f "$vibe/HANDOFF.md" ]; then
  echo "=== .vibe/HANDOFF.md（上個會話留的交接便條。先向使用者摘要「上次做完什麼、卡在哪」，等他點頭再動工）==="
  cat "$vibe/HANDOFF.md"
  echo ""
fi

if [ -f "$vibe/規矩檔.md" ]; then
  echo "=== .vibe/規矩檔.md（AI 每次動工前必讀，違反任何一條就停下）==="
  cat "$vibe/規矩檔.md"
  echo ""
fi

if [ -f "$vibe/state.json" ]; then
  echo "=== .vibe/state.json（機器狀態快取。與 切片帳本.md 不一致時，以帳本為準並重建本檔）==="
  cat "$vibe/state.json"
  echo ""
fi

# 新會話輪數歸零（turn-counter.sh 用）
echo 0 > "$vibe/.turn-count" 2>/dev/null || true

exit 0
