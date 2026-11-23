#!/usr/bin/env bash
# Set up these dotfiles on a machine: install dependencies, then symlink every
# package into $HOME with GNU Stow. Safe to re-run — anything already linked is
# left alone, and any existing file that would be replaced is backed up first.
#
#   ./install.sh                 # everything (Homebrew + Brewfile + all packages)
#   ./install.sh nvim tmux       # only link these packages
#   ./install.sh --no-brew       # skip Homebrew / Brewfile (e.g. on Linux)
#   ./install.sh --dry-run       # show what would happen, change nothing
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_NAME="$(basename "$DOTFILES")"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
ALL_PACKAGES="aerospace fastfetch ghostty git hex nvim tmux zed zsh"
# Apps that write their own data next to their settings: link individual files
# instead of the whole folder, so that data never lands inside this repo.
NO_FOLD_PACKAGES="hex zed"

DRY_RUN=0
SKIP_BREW=0
PACKAGES=""

usage() { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; }
info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$*" >&2; }
die() { printf '\033[1;31mxx\033[0m  %s\n' "$*" >&2; exit 1; }
run() { if [ "$DRY_RUN" = 1 ]; then echo "    [dry-run] $*"; else "$@"; fi; }

while [ $# -gt 0 ]; do
  case "$1" in
    -n | --dry-run) DRY_RUN=1 ;;
    --no-brew) SKIP_BREW=1 ;;
    -h | --help) usage; exit 0 ;;
    -*) die "Unknown option: $1 (see --help)" ;;
    *) PACKAGES="$PACKAGES $1" ;;
  esac
  shift
done
[ -n "$PACKAGES" ] || PACKAGES="$ALL_PACKAGES"
for pkg in $PACKAGES; do
  [ -d "$DOTFILES/$pkg" ] || die "No such package: $pkg (available: $ALL_PACKAGES)"
done

has_pkg() { case " $PACKAGES " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
is_no_fold() { case " $NO_FOLD_PACKAGES " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

backup() { # move $HOME/<rel> into the backup folder
  local rel="$1"
  info "Backing up existing ~/$rel"
  run mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
  run mv "$HOME/$rel" "$BACKUP_DIR/$rel"
}

# --- 1. Homebrew + Brewfile (macOS) -----------------------------------------
if [ "$(uname -s)" = Darwin ] && [ "$SKIP_BREW" = 0 ]; then
  if ! xcode-select -p >/dev/null 2>&1; then
    info "Installing Xcode Command Line Tools — re-run this script when it finishes"
    xcode-select --install
    exit 1
  fi
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$b" ]; then eval "$("$b" shellenv)"; break; fi
  done
  if ! command -v brew >/dev/null; then
    info "Installing Homebrew"
    run /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
      if [ -x "$b" ]; then eval "$("$b" shellenv)"; break; fi
    done
  fi
  if command -v brew >/dev/null; then
    info "Installing packages from Brewfile"
    run brew bundle --file="$DOTFILES/Brewfile" ||
      warn "Some Brewfile entries failed (apps installed outside Homebrew show up here) — continuing"
  fi
fi

command -v stow >/dev/null || die "GNU Stow is required: brew install stow  (or: sudo apt install stow)"
command -v git >/dev/null || die "git is required"

# --- 2. zsh framework: oh-my-zsh + powerlevel10k + autosuggestions -----------
clone_if_missing() {
  [ -d "$2" ] && return 0
  info "Cloning $1"
  run git clone --depth=1 "$1" "$2"
}
if has_pkg zsh; then
  clone_if_missing https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
  clone_if_missing https://github.com/romkatv/powerlevel10k.git "$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
  clone_if_missing https://github.com/zsh-users/zsh-autosuggestions.git "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
fi

# --- 3. Move anything in the way, then symlink with stow ---------------------
# A "unit" is what stow will link: for normal packages that's each top-level
# entry (or each entry under .config/, e.g. .config/nvim); for no-fold packages
# it's every individual file.
units_for() {
  (
    cd "$DOTFILES/$1"
    if is_no_fold "$1"; then
      find . -type f ! -name .DS_Store ! -name .gitignore | sed 's#^\./##'
      return
    fi
    for e in .[!.]* *; do
      [ -e "$e" ] || continue
      case "$e" in .DS_Store | .gitignore) continue ;; esac
      if [ "$e" = .config ] && [ -d "$e" ]; then
        for c in .config/.[!.]* .config/*; do [ -e "$c" ] && echo "$c"; done
      else
        echo "$e"
      fi
    done
  )
}

MOVED=0 # set when clear_way had to move something out of the way
clear_way() {
  local pkg="$1" u dst link
  MOVED=0
  for u in $(units_for "$pkg"); do
    dst="$HOME/$u"
    if [ -L "$dst" ]; then
      link="$(readlink "$dst")"
      case "$link" in
        *"$REPO_NAME/$pkg/"*) continue ;; # already linked by this package
        *"$REPO_NAME/"*) info "Removing stale link ~/$u -> $link"; run rm "$dst"; MOVED=1 ;; # old repo layout
        *) if [ -e "$dst" ]; then backup "$u"; else run rm "$dst"; fi; MOVED=1 ;; # foreign / dangling link
      esac
    elif [ -e "$dst" ]; then
      [ "$dst" -ef "$DOTFILES/$pkg/$u" ] && continue # inside a folder that is already linked
      backup "$u"
      MOVED=1
    fi
  done
}

run mkdir -p "$HOME/.config" # never let stow turn all of ~/.config into one symlink

for pkg in $PACKAGES; do
  clear_way "$pkg"
  flags="--restow"
  is_no_fold "$pkg" && flags="$flags --no-folding"
  info "Linking $pkg"
  if [ "$DRY_RUN" = 1 ] && [ "$MOVED" = 1 ]; then
    echo "    [dry-run] stow $flags $pkg (after the moves above)"
  elif [ "$DRY_RUN" = 1 ]; then
    stow --simulate --verbose=1 --dir="$DOTFILES" --target="$HOME" --ignore='\.DS_Store' $flags "$pkg" 2>&1 |
      sed 's/^/    /' || true
  else
    stow --dir="$DOTFILES" --target="$HOME" --ignore='\.DS_Store' $flags "$pkg"
  fi
done

# Ghostty on macOS also reads ~/Library/Application Support/com.mitchellh.ghostty/config
# and lets it override ~/.config/ghostty. Move it aside so the repo config wins.
if has_pkg ghostty && [ "$(uname -s)" = Darwin ]; then
  for f in config config.ghostty; do
    rel="Library/Application Support/com.mitchellh.ghostty/$f"
    if [ -f "$HOME/$rel" ] && [ ! -L "$HOME/$rel" ]; then backup "$rel"; fi
  done
fi

# git identity is kept out of the (public) repo, in ~/.gitconfig.local.
if has_pkg git && [ ! -f "$HOME/.gitconfig.local" ]; then
  if [ "$DRY_RUN" = 1 ]; then
    echo "    [dry-run] would ask for your git name/email and write ~/.gitconfig.local"
  elif [ -t 0 ]; then
    info "Set your git identity (saved to ~/.gitconfig.local, never committed)"
    printf '    Name:  '; read -r git_name
    printf '    Email: '; read -r git_email
    if [ -n "$git_name" ] && [ -n "$git_email" ]; then
      printf '[user]\n\tname = %s\n\temail = %s\n' "$git_name" "$git_email" >"$HOME/.gitconfig.local"
    else
      warn "Skipped — create ~/.gitconfig.local yourself (see README)"
    fi
  else
    warn "No ~/.gitconfig.local yet — create it with your [user] name/email (see README)"
  fi
fi

# --- 4. Done ------------------------------------------------------------------
echo
[ -d "$BACKUP_DIR" ] && info "Replaced files were backed up to $BACKUP_DIR"
info "Done. Next steps:"
cat <<'EOF'
    • Open a new terminal (or `exec zsh`) to load the shell config.
    • tmux installs its plugins automatically the first time it starts.
    • nvim installs LazyVim + plugins the first time it starts.
    • AeroSpace / Ghostty / Zed pick up their config on next launch.
    • Machine-only settings go in ~/.zshrc.local and ~/.gitconfig.local (not tracked).
EOF
