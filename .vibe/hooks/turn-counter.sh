#!/usr/bin/env bash
# [turn-counter] VibeRails UserPromptSubmit hook
# 機械版 Smart Zone 守衛：每輪 +1，累積過門檻就在 context 裡插提醒。
# 原本的設計叫「AI 每輪背景自查是否變笨」——叫一個正在變笨的模型
# 偵測自己變笨，是這套系統自己批判過的 Dunning-Kruger 問題。
# 這個腳本用真實計數取代模型自覺。
# stdout 會被加進 context，Claude 一定看得到。

dir="${CLAUDE_PROJECT_DIR:-.}"
vibe="$dir/.vibe"
[ -d "$vibe" ] || exit 0

f="$vibe/.turn-count"
n=0
[ -f "$f" ] && n="$(cat "$f" 2>/dev/null || echo 0)"
case "$n" in ''|*[!0-9]*) n=0 ;; esac
n=$((n + 1))
echo "$n" > "$f"

echo "[turn-counter] reason: 第 $n 輪" >&2

# 30 輪起警戒，之後每 5 輪提醒一次（不洗版）
if [ "$n" -ge 30 ] && [ $((n % 5)) -eq 0 ]; then
  echo "[VibeRails Smart Zone 守衛] 本會話已累積 $n 輪。注意力成本隨上下文二次方成長，正逼近 Dumb Zone。建議向使用者提出：走 vibe-handoff 產交接便條 → /clear 開新會話接續（新會話會由 session-start hook 自動載回交接內容）。使用者說要繼續就繼續，但要誠實示警。"
fi

exit 0
