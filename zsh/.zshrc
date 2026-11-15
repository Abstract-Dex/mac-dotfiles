# # auto-tmux before p10k instant prompt (needs a real TTY)
# if [[ -z "$TMUX" && -z "$SSH_CONNECTION" && -o interactive && -t 1 ]]; then
#   tmux new-session -A -s main
# fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# --- oh-my-zsh ---------------------------------------------------------------
# Installed by ./install.sh (oh-my-zsh, powerlevel10k, zsh-autosuggestions).
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git zsh-autosuggestions)
DISABLE_AUTO_UPDATE="true"

[[ -r "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# --- environment -------------------------------------------------------------
export EDITOR=nvim
export PATH="$HOME/.local/bin:$PATH"

if [[ "$TERM_PROGRAM" == "ghostty" ]]; then
  export TERM=xterm-256color
fi

# --- tools -------------------------------------------------------------------
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
command -v fzf >/dev/null && source <(fzf --zsh)

# --- aliases & functions -----------------------------------------------------
alias now="date +%F\ %T"

# tmux: jump to a session by name (create if missing)
ts() {
  local name="${1:-main}"
  if [[ -n "$TMUX" ]]; then
    tmux has-session -t "$name" 2>/dev/null || tmux new-session -d -s "$name"
    tmux switch-client -t "$name"
  else
    tmux new-session -A -s "$name"
  fi
}

# Machine-specific settings (secrets, work paths, conda, etc.) go here — not tracked.
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
