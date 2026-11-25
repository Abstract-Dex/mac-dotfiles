# Bring Claude Code back after Rex restores a session.
#
# Rex restores sessions, tabs, splits, block IDs and each terminal's folder after the
# server restarts (Mac reboot, Rex update, `rex server stop`), but every terminal comes
# back as a fresh shell. This remembers which Rex pane (REX_BLOCK) was running Claude,
# and which conversation, and resumes it the first time that pane's shell shows a prompt.
#
#   * Exiting Claude normally (/exit, Ctrl-D) forgets the pane, so it won't come back.
#   * If Claude was killed (reboot, server stop), the pane resumes with
#     `claude --resume <id>`, or `claude --continue` if that conversation can't be found.
#   * Set REX_CLAUDE_RESUME=0 to turn the auto-resume off; `rex-claude-forget` clears
#     the current pane's record.
# Claude's transcripts live in ~/.claude/projects; nothing here touches them.

[[ -n "$REX_BLOCK" && -o interactive ]] || return 0

_rex_claude_dir="${XDG_STATE_HOME:-$HOME/.local/state}/rex-claude"
_rex_claude_mark="$_rex_claude_dir/${REX_BLOCK//[^A-Za-z0-9._-]/_}"

claude() {
  # Subcommands and one-shot prompts aren't interactive sessions: don't track them.
  case "$1" in
    mcp|config|update|doctor|install|migrate-installer|setup-token|plugin|plugins|agents|auth|-v|--version|-h|--help)
      command claude "$@"; return ;;
  esac
  local a prev="" sid="" track=1 own_session=0
  for a in "$@"; do
    case "$prev" in
      -r|--resume|--session-id) [[ "$a" == -* ]] || sid="$a" ;;
    esac
    case "$a" in
      -p|--print) track=0 ;;
      --resume=*|--session-id=*) own_session=1; sid="${a#*=}" ;;
      -r|--resume|-c|--continue|--session-id) own_session=1 ;;
    esac
    prev="$a"
  done
  # --fork-session starts a new conversation id we can't know: fall back to --continue.
  (( ${@[(Ie)--fork-session]} )) && sid=""
  if (( ! track )); then command claude "$@"; return; fi

  mkdir -p "$_rex_claude_dir"
  if (( ! own_session )); then
    sid="$(uuidgen | tr '[:upper:]' '[:lower:]')"
    set -- --session-id "$sid" "$@"
  fi
  print -r -- "$PWD"$'\t'"$sid" >| "$_rex_claude_mark"

  command claude "$@"
  local rc=$?
  # 128+ means Claude was killed by a signal (server stop, shutdown): keep the record.
  (( rc < 128 )) && rm -f "$_rex_claude_mark"
  return $rc
}

rex-claude-forget() { rm -f "$_rex_claude_mark"; }

_rex_claude_resume() {
  add-zsh-hook -d precmd _rex_claude_resume
  [[ "${REX_CLAUDE_RESUME:-1}" == 1 && -f "$_rex_claude_mark" ]] || return 0
  local dir sid
  IFS=$'\t' read -r dir sid < "$_rex_claude_mark"
  [[ -d "$dir" ]] && cd "$dir"
  local -a found
  [[ -n "$sid" ]] && found=( ~/.claude/projects/*/"$sid".jsonl(N) )
  if (( ${#found} )); then
    print -P "%F{8}rex: resuming Claude session $sid%f"
    claude --resume "$sid"
  else
    print -P "%F{8}rex: resuming the latest Claude session in $PWD%f"
    claude --continue
  fi
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _rex_claude_resume

# Drop records for panes that haven't been used in 30 days.
find "$_rex_claude_dir" -type f -mtime +30 -delete 2>/dev/null
