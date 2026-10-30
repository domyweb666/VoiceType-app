#!/usr/bin/env bash
# [bash-guard] VibeRails PreToolUse(Bash) hook
# 機械攔截不可逆指令。AI 在長會話後期最容易忘記守門規則，
# 而那正是最危險的時候——所以這道不交給 AI 自律，交給這個腳本。
#
# 行為：偵測到危險指令時，輸出 permissionDecision=ask 的 JSON，
# 強制跳出權限確認框讓「使用者本人」點放行；使用者沒點頭就過不去。
# 這比直接 block（exit 2）好：vibe-rescue 止血時真的需要 git reset --hard，
# 差別只在「必須是人親手放行」，不是 AI 自己決定。

input="$(cat)"

# 抓出 tool_input.command；有 jq 用 jq，沒有就退回掃整包 JSON（誤攔倒向安全側）
cmd="$input"
if command -v jq >/dev/null 2>&1; then
  parsed="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
  [ -n "$parsed" ] && cmd="$parsed"
fi

ask() {
  echo "[bash-guard] reason: 偵測到不可逆指令（$1），交給使用者親手放行" >&2
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"[VibeRails 守門] 這個指令會做不可逆的事（%s）。做壞了沒有還原點。確定要放行嗎？"}}\n' "$1"
  exit 0
}

case "$cmd" in
  *"git push"*" -f"*|*"git push"*"--force"*)   ask "git push --force：覆寫遠端歷史" ;;
esac
case "$cmd" in
  *"git reset --hard"*)                        ask "git reset --hard：丟棄所有未提交的改動" ;;
esac
case "$cmd" in
  *"git clean"*"-f"*)                          ask "git clean -f：刪除未追蹤的檔案" ;;
esac
case "$cmd" in
  *"rm -rf"*|*"rm -fr"*)                       ask "rm -rf：遞迴強制刪除" ;;
esac
case "$cmd" in
  *"git checkout -- ."*|*"git restore ."*)     ask "整包丟棄工作區改動" ;;
esac

exit 0
